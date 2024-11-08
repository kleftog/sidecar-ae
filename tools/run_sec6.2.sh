#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." &> /dev/null && pwd)"
RES_DIR=${ROOT_DIR}/results
RAW_DIR=${RES_DIR}/raw
PARSE_DIR=${RES_DIR}/parsed

mkdir -p "${RES_DIR}"
mkdir -p "${RAW_DIR}"

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
    ptw_module_path="$SCRIPT_DIR/../sidecar/sidecar-driver/x86-64/ptw.ko"

    # Check if the ptw.ko file exists
    if [[ ! -f "$ptw_module_path" ]]; then
        echo "Error: $ptw_module_path does not exist."
        exit 1
    fi

    # Try to load the ptw module with sudo
    echo "Loading the ptw kernel module with interrupts enabled..."
    if sudo insmod "$ptw_module_path"; then
        echo "ptw kernel module loaded successfully."
    else
        echo "Error: Failed to load the ptw kernel module."
        echo "Please reboot the system and try again."
        exit 1
    fi
}

# Compile the monitors
sidecfi_dir="$SCRIPT_DIR/../sidecar/sidecar-monitors/sidecfi/x86-64"
sidestack_dir="$SCRIPT_DIR/../sidecar/sidecar-monitors/sidestack/x86-64"
cd "$sidecfi_dir" || exit
make clean all
cd "$sidestack_dir" || exit
make clean all
cd "$SCRIPT_DIR" || exit

# Path to the ripe_tester.py script
RIPE_PATH="$SCRIPT_DIR/../benchmarks/ripe64"

# Define the modes
modes=("clang_cfi" "clang_sidecfi" "clang_safestack" "clang_sidestack")

check_and_remove_ptw
load_ptw_module_int
  
cd "$RIPE_PATH" || exit 1
make clean all

# Loop through the modes and run ripe_tester for each mode
for mode in "${modes[@]}"; do
    echo "Running ripe_tester for mode: $mode"
    log_file="${CUR_RUN_DIR}/ripe_${mode}.log"
    if python3 ripe_tester.py both 3 "$mode" --only-summary --format-bash > "$log_file" 2>&1; then
        echo "Successfully ran ripe_tester for mode: $mode. Log saved to $log_file."
    else
        echo "Error: ripe_tester failed for mode: $mode. Check $log_file for details."
        exit 1
    fi
done

# Extract relevant results from log files
function extract_results {
    log_file="$1"
    grep -E "OK: [0-9]+ SOME: [0-9]+ FAIL: [0-9]+ NP: [0-9]+ Total Attacks: [0-9]+" "$log_file"
}

function compare_results {
    # Extract FAIL and SOME counts for Clang CFI
    cfi_fail=$(echo "$1" | grep -oP 'FAIL: \K[0-9]+' | paste -sd+ - | bc)
    cfi_some=$(echo "$1" | grep -oP 'SOME: \K[0-9]+' | paste -sd+ - | bc)
    cfi_fail=$((cfi_fail + cfi_some))
    cfi_ok=$(echo "$1" | grep -oP 'OK: \K[0-9]+')
    
    # Extract FAIL and SOME counts for SideCFI
    sidecfi_fail=$(echo "$2" | grep -oP 'FAIL: \K[0-9]+' | paste -sd+ - | bc)
    sidecfi_some=$(echo "$2" | grep -oP 'SOME: \K[0-9]+' | paste -sd+ - | bc)
    sidecfi_fail=$((sidecfi_fail + sidecfi_some))
    sidecfi_ok=$(echo "$2" | grep -oP 'OK: \K[0-9]+')
    
    # Extract FAIL and SOME counts for Clang SafeStack
    safestack_fail=$(echo "$3" | grep -oP 'FAIL: \K[0-9]+' | paste -sd+ - | bc)
    safestack_some=$(echo "$3" | grep -oP 'SOME: \K[0-9]+' | paste -sd+ - | bc)
    safestack_fail=$((safestack_fail + safestack_some))
    safestack_ok=$(echo "$3" | grep -oP 'OK: \K[0-9]+')
    
    # Extract FAIL and SOME counts for SideStack
    sidestack_fail=$(echo "$4" | grep -oP 'FAIL: \K[0-9]+' | paste -sd+ - | bc)
    sidestack_some=$(echo "$4" | grep -oP 'SOME: \K[0-9]+' | paste -sd+ - | bc)
    sidestack_fail=$((sidestack_fail + sidestack_some))
    sidestack_ok=$(echo "$4" | grep -oP 'OK: \K[0-9]+')

    # Extract the total number of attacks for CFI and SafeStack
    total_attacks_cfi=$((cfi_fail + cfi_ok))
    total_attacks_safestack=$((safestack_fail + safestack_ok))

    # Calculate percentages relative to Clang CFI and SafeStack
    sidecfi_percentage=$(echo "scale=2; ($sidecfi_fail / $cfi_fail) * 100" | bc)
    sidestack_percentage=$(echo "scale=2; ($sidestack_fail / $safestack_fail) * 100" | bc)

    # Write the results to the output file in a visually appealing way
    {
        echo "========================================="
        echo "             Attack Results              "
        echo "========================================="
        printf "%-30s : %s\n" "Total attacks (FWD)" "$total_attacks_cfi"
        printf "%-30s : %s\n" "Total attacks (BWD)" "$total_attacks_safestack"
        echo "-----------------------------------------"
        printf "%-30s : %s\n" "Stopped by Clang CFI" "$cfi_fail"
        printf "%-30s : %s (%s%%)\n" "Stopped by SideCFI" "$sidecfi_fail" "$sidecfi_percentage"
        echo "-----------------------------------------"
        printf "%-30s : %s\n" "Attacks passed Clang CFI" "$cfi_ok"
        printf "%-30s : %s\n" "Attacks passed SideCFI" "$sidecfi_ok"
        echo "-----------------------------------------"
        printf "%-30s : %s\n" "Stopped by Clang SafeStack" "$safestack_fail"
        printf "%-30s : %s (%s%%)\n" "Stopped by SideStack" "$sidestack_fail" "$sidestack_percentage"
        echo "-----------------------------------------"
        printf "%-30s : %s\n" "Attacks passed Clang SafeStack" "$safestack_ok"
        printf "%-30s : %s\n" "Attacks passed SideStack" "$sidestack_ok"
        echo "========================================="
    } >> ${PARSE_DIR}/ripe64_results.txt
}

# Path to the ripe_tester log files
log="${CUR_RUN_DIR}/ripe_clang.log"
log_cfi="${CUR_RUN_DIR}/ripe_clang_cfi.log"
log_sidecfi="${CUR_RUN_DIR}/ripe_clang_sidecfi.log"
log_safestack="${CUR_RUN_DIR}/ripe_clang_safestack.log"
log_sidestack="${CUR_RUN_DIR}/ripe_clang_sidestack.log"

# Extract and compare results
results_cfi=$(extract_results "$log_cfi")
results_sidecfi=$(extract_results "$log_sidecfi")
results_safestack=$(extract_results "$log_safestack")
results_sidestack=$(extract_results "$log_sidestack")

# Compare and print
rm -rf ${PARSE_DIR}/ripe64_results.txt
compare_results "$results_cfi" "$results_sidecfi" "$results_safestack" "$results_sidestack"

