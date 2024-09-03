#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Define the modes
modes=("sideguard")

# Spec2006 directory
spec06_dir="$SCRIPT_DIR/../benchmarks/spec2006"

# check if directory exists
# if not check env variable $SPEC06_PATH
if [ ! -d "$spec06_dir" ]; then
    if [ -z "$SPEC06_PATH" ]; then
        echo "Please set the SPEC06_PATH environment variable to the path of the SPEC CPU2006 directory"
        exit 1
    else
        spec06_dir="$SPEC06_PATH"
    fi
fi

# List of integer benchmarks in SPEC2006
int_benchmarks=("400.perlbench" "401.bzip2" "403.gcc" "429.mcf" "445.gobmk" "456.hmmer" "458.sjeng" "462.libquantum" "464.h264ref" "471.omnetpp" "473.astar" "483.xalancbmk")

# Initialize an associative array to hold the benchmark commands
declare -A benchmark_commands

# Iterate over each integer benchmark
for benchmark in "${int_benchmarks[@]}"; do
    benchmark_dir="$spec06_dir/benchspec/CPU2006/$benchmark"
    run_dir="$benchmark_dir/run"
    
    # Check if the benchmark directory exists
    if [ ! -d "$benchmark_dir" ]; then
        echo "Benchmark directory not found: $benchmark_dir"
        continue
    fi

    # Iterate over the modes and find the latest run directory
    for mode in "${modes[@]}"; do
        latest_run_dir=$(ls -td "$run_dir/run_base_train_$mode".* | head -n 1)
        
        if [ -z "$latest_run_dir" ]; then
            echo "No run directory found for $benchmark with mode $mode"
            continue
        fi
        
        # Path to speccmds.cmd
        speccmds_file="$latest_run_dir/speccmds.cmd"
        
        # Check if the speccmds.cmd file exists
        if [ ! -f "$speccmds_file" ]; then
            echo "speccmds.cmd not found for $benchmark in $latest_run_dir"
            continue
        fi
        
        # Extract the first command starting with -o
        cmd=$(grep -m 1 "^-o" "$speccmds_file")
        
        if [ -n "$cmd" ]; then
            benchmark_commands[$benchmark]="path: $latest_run_dir\ncmd: $cmd"
        else
            echo "No command found in speccmds.cmd for $benchmark"
        fi
    done
done

# Loop over the benchmarks and output the commands
for benchmark in "${!benchmark_commands[@]}"; do
    echo "running $benchmark"
    echo -e "${benchmark_commands[$benchmark]}"
    echo ""
done

