#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Define the modes
modes=("lto" "cfi" "sidecfi" "safestack" "sidestack" "asan" "sideasan")

# Choose size of inputs
#size="ref"
#size="test"
size=train
laps=1

# Spec2006 directory
spec06_dir="$SCRIPT_DIR/../benchmarks/spec2006"

# check if directory exists
# if not check env variable $SPEC06_PATH
if [ ! -d "$spec06_dir" ]; then
    if [ -z "$SPEC06_PATH" ]; then
        echo "Please set the SPEC06_PATH environment variable to the path of the SPEC CPU2017 directory"
        exit 1
    else
        spec06_dir="$SPEC06_PATH"
    fi
fi

# Define the base directory where the Runxxx directories are located
base_dir="$SCRIPT_DIR/../results/raw"

# Find the last Runxxx directory
next_run=$(ls -1 "$base_dir" | grep -E '^Run[0-9]{3}$' | sort | tail -n 1)

# cd to spec06 directory run ./shrc and then come back
cd "$spec06_dir" || exit
source ./shrc
cd "$SCRIPT_DIR" || exit

export ASAN_OPTIONS='detect_leaks=0'

# Loop through each mode and print the mode and throughput in CSV format
for mode in "${modes[@]}"; do
    if [ "$mode" == "asan" ]; then
        llvm_path="$SCRIPT_DIR/../sidecar/install/llvm-orig"
    else
        llvm_path="$SCRIPT_DIR/../sidecar/install/llvm-sidecar"
    fi

    # Run the spec06 benchmark
    taskset -c 0 runspec --action=run --config=$mode --size=$size --label=$mode \
      --iterations=${laps} --threads=1 --tune=base -define gcc_dir=${llvm_path} --output_format=csv \
      --noreportable speedint

    # Find the latest csv file in spec06 directory under result
    csv_file=$(ls -1t "$spec06_dir/result/"*.csv | head -n 1)

    if [ "$size" == "ref" ]; then
	grep "refspeed(ref)" "$csv_file" > "$base_dir/$next_run/spec06.$mode.csv"
    else
	grep "${size} iteration" "$csv_file" > "$base_dir/$next_run/spec06.$mode.csv"
    fi
done
