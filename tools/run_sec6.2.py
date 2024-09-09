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
RIPE_TESTER="$SCRIPT_DIR/../benchmarks/ripe64/ripe_tester.py"

# Define the modes
modes=("clang_cfi" "clang_sidecfi" "clang_safestack" "clang_sidestack")

check_and_remove_ptw
load_ptw_module_int

# Loop through the modes and run ripe_tester for each mode
for mode in "${modes[@]}"; do
    echo "Running ripe_tester for mode: $mode"
    log_file="${CUR_RUN_DIR}/ripe_${mode}.log"
    if python3 "$RIPE_TESTER" both 1 "$mode" > "$log_file" 2>&1; then
        echo "Successfully ran ripe_tester for mode: $mode. Log saved to $log_file."
    else
        echo "Error: ripe_tester failed for mode: $mode. Check $log_file for details."
        exit 1
    fi
done

