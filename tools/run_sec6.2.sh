#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." &> /dev/null && pwd)"
RES_DIR=${ROOT_DIR}/results
RAW_DIR=${RES_DIR}/raw

mkdir -p "${RES_DIR}"
mkdir -p "${RAW_DIR}"

# Get the latest Runxxx folder, or create Run000 if none exists
last_run=$(ls -1 "${RAW_DIR}" | grep -E '^Run[0-9]{3}$' | sort | tail -n 1)

if [[ -z "$last_run" ]]; then
    # No Runxxx directories found, create Run000
    CUR_DIR="Run000"
else
    # Extract the number from the last Runxxx and increment it
    last_run_num=$(echo "$last_run" | sed 's/Run\([0-9]\+\)/\1/')
    new_run_num=$(printf "%03d" $((last_run_num + 1)))
    CUR_DIR="Run${new_run_num}"
fi

# Create the new directory
mkdir "${RAW_DIR}/${CUR_DIR}"

echo "New directory created: ${RAW_DIR}/${CUR_DIR}"

CUR_RUN_DIR="${RAW_DIR}/${CUR_DIR}"

function check_and_remove_ptw {
    ptw_module="ptw"

    # Check if ptw is loaded
    ptw_loaded=$(lsmod | grep "$ptw_module")

    if [[ -n "$ptw_loaded" ]]; then
        echo "Removing $ptw_module module..."
        # Try to remove the ptw module with sudo
        if sudo rmmod "$ptw_module"; then
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

# Path to the ripe_tester.py script
RIPE_PATH="$SCRIPT_DIR/../benchmarks/ripe64"

# Define the modes
modes=("clang_cfi" "clang_sidecfi" "clang_safestack" "clang_sidestack")

check_and_remove_ptw
load_ptw_module_int

# Loop through the modes and run ripe_tester for each mode
for mode in "${modes[@]}"; do
    echo "Running ripe_tester for mode: $mode"
    log_file="${CUR_RUN_DIR}/ripe_${mode}.log"
    cd "$RIPE_PATH" || exit 1
    if python3 ripe_tester.py both 1 "$mode" > "$log_file" 2>&1; then
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

# Compare results between cfi and sidecfi, and safestack and sidestack
function compare_results {
    cfi_fail=$(echo "$1" | grep -oP 'FAIL: \K[0-9]+')
    sidecfi_fail=$(echo "$2" | grep -oP 'FAIL: \K[0-9]+')
    safestack_fail=$(echo "$3" | grep -oP 'FAIL: \K[0-9]+')
    sidestack_fail=$(echo "$4" | grep -oP 'FAIL: \K[0-9]+')

    total_attacks=$(echo "$1" | grep -oP 'Total Attacks: \K[0-9]+')

    if [[ $cfi_fail -lt $sidecfi_fail ]]; then
        echo "Total attacks: $total_attacks"
        echo "Stopped by cfi: $((total_attacks - cfi_fail))"
        echo "Stopped by sidecfi: $((total_attacks - sidecfi_fail)) (100%)"
    fi

    if [[ $safestack_fail -lt $sidestack_fail ]]; then
        echo "Stopped by safestack: $((total_attacks - safestack_fail))"
        echo "Stopped by sidestack: $((total_attacks - sidestack_fail)) (100%)"
    fi
}

# Path to the ripe_tester log files
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
compare_results "$results_cfi" "$results_sidecfi" "$results_safestack" "$results_sidestack"

