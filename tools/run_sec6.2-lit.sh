#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." &> /dev/null && pwd)"
RES_DIR=${ROOT_DIR}/results
RAW_DIR=${RES_DIR}/raw
PARSE_DIR=${RES_DIR}/parsed

mkdir -p "${RES_DIR}"
mkdir -p "${RAW_DIR}"
mkdir -p "${PARSE_DIR}"

# Get the latest Runxxx folder, or start from Run000 if none exists
last_run=$(ls -1 "${RAW_DIR}" | grep -E '^Run[0-9]{3}$' | sort -V | tail -n 1)

if [ -z "$last_run" ]; then
    CUR_DIR="Run000"
else
    # Extract the numeric part, increment it, and handle wrap-around using modulo 1000
    run_number=$(( (10#${last_run:3} + 1) % 1000 ))
    CUR_DIR=$(printf "Run%03d" "$run_number")
fi

# Create the new directory
mkdir -p "${RAW_DIR}/${CUR_DIR}"

echo "New directory created: ${RAW_DIR}/${CUR_DIR}"

CUR_RUN_DIR="${RAW_DIR}/${CUR_DIR}"

function check_and_remove_ptw {
    ptw_module="ptw"

    # Check if ptw is loaded
    ptw_loaded=$(lsmod | grep "$ptw_module")

    if [[ -n "$ptw_loaded" ]]; then
        echo "Removing $ptw_module module..."
        # Try to remove the ptw module with sudo
        if sudo rmmod "$ptw_module" --force; then
            echo "$ptw_module module removed."
        else
            echo "Error: Failed to remove $ptw_module module."
            exit 1
        fi
    fi
}


function load_ptw_module_int {
    ptw_module_path="$SCRIPT_DIR/../sidecar/sidecar-driver/x86-64"
    cd "$ptw_module_path" || exit
    make
    make clean all

    # Check if the ptw.ko file exists
    if [[ ! -f "$ptw_module_path/ptw.ko" ]]; then
        echo "Error: $ptw_module_path/ptw.ko does not exist."
        exit 1
    fi

    # Try to load the ptw module with sudo
    echo "Loading the ptw kernel module with interrupts enabled..."
    if sudo insmod "$ptw_module_path/ptw.ko"; then
        echo "ptw kernel module loaded successfully."
    else
        echo "Error: Failed to load the ptw kernel module."
        echo "Please reboot the system and try again."
        exit 1
    fi
}

# Compile the monitors
sideasan_dir="$SCRIPT_DIR/../sidecar/sidecar-monitors/sideasan/x86-64"
cd "$sideasan_dir" || exit
make clean all

ORIG_BUILD="$SCRIPT_DIR/../sidecar/build/llvm-orig"
SIDECAR_BUILD="$SCRIPT_DIR/../sidecar/build/llvm-sidecar"
LIT_SRC="$SCRIPT_DIR/../sidecar/sidecar-llvm/compiler-rt/test/asan"

cp "$LIT_SRC/lit.cfg.py.original" "$LIT_SRC/lit.cfg.py"

rm -r "$ORIG_BUILD/projects/compiler-rt/test/asan/X86_64LinuxConfig/TestCasesOriginal/Linux/"
rm -r "$SIDECAR_BUILD/projects/compiler-rt/test/asan/X86_64LinuxConfig/TestCasesDecoupled/Linux/"
rm -r "$PARSE_DIR/lit_results.txt"

echo "Running ASAN LIT tests."

pass_count=0
fail_count=0

# Loop through original asan LIT
cd "$ORIG_BUILD" || exit 1

for test_file in "$LIT_SRC/TestCasesOriginal/Linux/"*; do
	file_name=$(basename "$test_file")

	output=$(./bin/llvm-lit -v "$ORIG_BUILD/projects/compiler-rt/test/asan/X86_64LinuxConfig/TestCasesOriginal/Linux/$file_name")

	# Check the result of each test
     	if echo "$output" | grep -q "PASS:"; then
		((pass_count++))
	elif echo "$output" | grep -q "FAIL:"; then
		((fail_count++))
	fi
	echo "$output"
done >> $CUR_RUN_DIR/lit-asan.log

for test_file in "$LIT_SRC/TestCasesOriginal/Base/"*; do
	file_name=$(basename "$test_file")

	output=$(./bin/llvm-lit -v "$ORIG_BUILD/projects/compiler-rt/test/asan/X86_64LinuxConfig/TestCasesOriginal/Base/$file_name")

	# Check the result of each test
     	if echo "$output" | grep -q "PASS:"; then
		((pass_count++))
	elif echo "$output" | grep -q "FAIL:"; then
		((fail_count++))
	fi
	echo "$output"
done >> $CUR_RUN_DIR/lit-asan.log

echo "ASAN Total Passed: $pass_count" >> "$PARSE_DIR/lit_results.txt"
echo "ASAN Total Failed: $fail_count" >> "$PARSE_DIR/lit_results.txt"

check_and_remove_ptw
load_ptw_module_int

cp "$LIT_SRC/lit.cfg.py.sidecar" "$LIT_SRC/lit.cfg.py"
find "$LIT_SRC/TestCasesDecoupled" -type f -exec sed -i 's|SIDECAR_BASE|'$ROOT_DIR'|g' {} +
echo "Running SideASAN LIT tests."

pass_count=0
fail_count=0

# Loop through original asan LIT
cd "$SIDECAR_BUILD" || exit 1

for test_file in "$LIT_SRC/TestCasesDecoupled/Linux/"*; do
	file_name=$(basename "$test_file")

	output=$(./bin/llvm-lit -v "$SIDECAR_BUILD/projects/compiler-rt/test/asan/X86_64LinuxConfig/TestCasesDecoupled/Linux/$file_name")

	# Check the result of each test
     	if echo "$output" | grep -q "PASS:"; then
		((pass_count++))
	elif echo "$output" | grep -q "FAIL:"; then
		((fail_count++))
	fi
	echo "$output"
done >> $CUR_RUN_DIR/lit-sideasan.log

for test_file in "$LIT_SRC/TestCasesDecoupled/Base/"*; do
	file_name=$(basename "$test_file")

	output=$(./bin/llvm-lit -v "$SIDECAR_BUILD/projects/compiler-rt/test/asan/X86_64LinuxConfig/TestCasesDecoupled/Base/$file_name")

	# Check the result of each test
     	if echo "$output" | grep -q "PASS:"; then
		((pass_count++))
	elif echo "$output" | grep -q "FAIL:"; then
		((fail_count++))
	fi
	echo "$output"
done >> $CUR_RUN_DIR/lit-sideasan.log

echo "SideASAN Total Passed: $pass_count" >> "$PARSE_DIR/lit_results.txt"
echo "SideASAN Total Failed: $fail_count" >> "$PARSE_DIR/lit_results.txt"

