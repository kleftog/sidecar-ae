#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

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

function load_ptw_module {
    ptw_module_path="$SCRIPT_DIR/../sidecar/sidecar-driver/x86-64/ptw.ko"

    # Check if the ptw.ko file exists
    if [[ ! -f "$ptw_module_path" ]]; then
        echo "Error: $ptw_module_path does not exist."
        exit 1
    fi

    # Try to load the ptw module with sudo
    echo "Loading the ptw kernel module..."
    if sudo insmod "$ptw_module_path"; then
        echo "ptw kernel module loaded successfully."
    else
        echo "Error: Failed to load the ptw kernel module."
        echo "Please reboot the system and try again."
        exit 1
    fi
}

check_and_remove_ptw
load_ptw_module

# Define the modes
modes=("sidecfi" "sidestack")

# Choose size of inputs
size=train
laps=1

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

# cd to spec06 directory run ./shrc and then come back
cd "$spec06_dir" || exit
source ./shrc
cd "$SCRIPT_DIR" || exit

llvm_path="$SCRIPT_DIR/../sidecar/install/llvm-sidecar"

# Check if sidecfi.cfg and sidestack.cfg exist under the spec2006 config directory
if [ ! -f "$spec06_dir/config/sidecfi.cfg" ] || [ ! -f "$spec06_dir/config/sidestack.cfg" ]; then
    cp "$SCRIPT_DIR/../benchmarks/cpu2006/config/sidecfi.cfg" "$spec06_dir/config/"
    cp "$SCRIPT_DIR/../benchmarks/cpu2006/config/sidestack.cfg" "$spec06_dir/config/"
    echo "Config files copied to SPEC CPU2006."
fi

# Perform a run to set up the run directories for each mode
for mode in "${modes[@]}"; do
    if ! ls "$spec06_dir/benchspec/CPU2006/400.perlbench/run/run_base_train_$mode".* 1> /dev/null 2>&1; then
        runspec --action run --config $mode --size $size \
          --iterations ${laps} --threads 1 --tune base -define gcc_dir=${llvm_path} --output_format csv \
          --noreportable int
    fi
done

# Compile the monitors
sidecfi_dir="$SCRIPT_DIR/../benchmarks/cpu-usage/sidecfi"
sidestack_dir="$SCRIPT_DIR/../benchmarks/cpu-usage/sidestack"
cd "$sidecfi_dir" || exit
make clean all
cd "$sidestack_dir" || exit
make clean all
cd "$SCRIPT_DIR" || exit

# List of integer benchmarks in SPEC2006
int_benchmarks=("400.perlbench" "401.bzip2" "403.gcc" "429.mcf" "445.gobmk" "456.hmmer" "458.sjeng" "462.libquantum" "464.h264ref" "471.omnetpp" "473.astar" "483.xalancbmk")

# Initialize an associative array to hold the benchmark commands
declare -A benchmark_commands
declare -A benchmark_binaries

# Create the target directory for copying files
cpu_usage_dir="$SCRIPT_DIR/../build/cpu-usage"
rm -rf "$cpu_usage_dir"
mkdir -p "$cpu_usage_dir"

# Iterate over each integer benchmark in order
for benchmark in "${int_benchmarks[@]}"; do
    benchmark_dir="$spec06_dir/benchspec/CPU2006/$benchmark"
    run_dir="$benchmark_dir/run"
    build_dir="$benchmark_dir/build"
    
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
        
        if [[ "$benchmark" == "400.perlbench" ]]; then
          cmd=$(tail -n 1 "$speccmds_file")
        else
          cmd=$(awk '/^-C/ {getline; print; exit} /^-o/ {print; exit}' "$speccmds_file")
        fi
        
        if [ -n "$cmd" ]; then
            # Copy the run directory to the target location
            target_dir="$cpu_usage_dir/${benchmark##*.}_$mode"
            cp -r "$latest_run_dir" "$target_dir"
            
            # Find and copy the .typemap file, renaming it
            typemap_file=$(ls "$build_dir/build_base_$mode".*/ | grep -m 1 ".typemap")
            if [ -n "$typemap_file" ]; then
                typemap_basename=$(basename "$typemap_file")
                
                # Determine the correct binary name based on the actual benchmark
                binary_name=$(ls "$latest_run_dir" | grep -E ".*_base.$mode" | head -n 1)
                typemap_target_name="${binary_name}.typemap"
                
                cp "$build_dir/build_base_$mode".*/"$typemap_basename" "$target_dir/$typemap_target_name"
                
                # Store the binary name and target directory for later use
                benchmark_binaries["${benchmark}_${mode}"]="$binary_name"
                
                # Change directory to the new folder and run gen_tp.sh
                cd "$target_dir"
                ../../../sidecar/tools/gen_tp.sh "$binary_name"
            else
                echo "No typemap file found for $benchmark in $build_dir/build_base_$mode"
            fi
            
            benchmark_commands["${benchmark}_${mode}"]="path: $target_dir\ncmd: $cmd"
        else
            echo "No command found in speccmds.cmd for $benchmark"
        fi
    done
done

cpu_usage_file="$SCRIPT_DIR/../results/parsed/cpu-usage.csv"
rm -f "$cpu_usage_file"

# Iterate over benchmarks and run the commands
for benchmark in "${int_benchmarks[@]}"; do
    cpu_usage_sidecfi=""
    cpu_usage_sidestack=""
    for mode in "${modes[@]}"; do
        if [ -n "${benchmark_commands["${benchmark}_${mode}"]}" ]; then
            echo "running $benchmark in $mode mode"
            
            # Extract the path and command from the associative array
            path=$(echo -e "${benchmark_commands["${benchmark}_${mode}"]}" | grep "path:" | awk '{print $2}')
            cmd=$(echo -e "${benchmark_commands["${benchmark}_${mode}"]}" | grep "cmd:" | cut -d' ' -f2-)
            
            # Retrieve the stored binary name
            binary_name="${benchmark_binaries["${benchmark}_${mode}"]}"
            
            # Modify the command to handle gobmk's input
            if [[ "$benchmark" == "445.gobmk" ]]; then
                input_file=$(echo "$cmd" | grep -oP '(?<=-i )[^ ]+')
                cmd=$(echo "$cmd" | sed 's/-i [^ ]*//g' | sed "s|^\(.*\)$|./$binary_name < $input_file|")
            else
                # Remove -o and -e flags along with their arguments
                cmd=$(echo "$cmd" | sed 's/-o [^ ]*//g' | sed 's/-e [^ ]*//g')
                # Modify the command to start with the binary and remove "../run_base_train_$mode.0000/"
                cmd=$(echo "$cmd" | sed "s|\.\./run_base_train_$mode.0000/$binary_name|./$binary_name|")
            fi

            # Execute the monitor for the mode
            if [ "$mode" == "sidecfi" ]; then
                monitor_cmd="$sidecfi_dir/monitor"
                monitor_output="$sidecfi_dir/monitor_output.txt"
            elif [ "$mode" == "sidestack" ]; then
                monitor_cmd="$sidestack_dir/monitor"
                monitor_output="$sidestack_dir/monitor_output.txt"
            else
                echo "Unknown mode: $mode"
                continue
            fi

            #echo "$monitor_cmd"
            taskset -c 3 $monitor_cmd  > "$monitor_output" &
            monitor_pid=$!
            sleep 1

            # Change to the directory and execute the command
            #echo "cd $path"
            cd "$path"
            
            # Run the corrected command silently
            #echo "$cmd"
            taskset -c 0 bash -c "$cmd" > /dev/null 2>&1

            # Wait for the monitor to finish using monitor_pid
            wait $monitor_pid

            # Extract CPU usage from the monitor output
            cpu_usage=$(grep "CPU usage" "$monitor_output" | awk '{print $NF}')
            
            # Store the CPU usage based on the mode
            if [ "$mode" == "sidecfi" ]; then
                cpu_usage_sidecfi="$cpu_usage"
            elif [ "$mode" == "sidestack" ]; then
                cpu_usage_sidestack="$cpu_usage"
            fi
            
        fi
    done

    # Append the results to the CPU usage file
    echo "$benchmark,$cpu_usage_sidecfi,$cpu_usage_sidestack" >> "$cpu_usage_file"
done

# Function to calculate geometric mean
geomean() {
    nums=("$@")
    product=1
    count=${#nums[@]}
    
    for num in "${nums[@]}"; do
        if [[ "$num" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            product=$(echo "$product * $num" | bc -l)
        else
            echo "Invalid number detected: $num"
            return 1
        fi
    done
    
    # Calculate the nth root of the product
    geomean=$(echo "e(l($product)/$count)" | bc -l)
    
    # Format the result to 2 decimal places
    printf "%.2f" "$geomean"
}

# Parse the cpu_usage_file and extract the columns for SideCFI and SideStack
sidecfi_usages=()
sidestack_usages=()

while IFS=, read -r benchmark sidecfi sidestack; do
    if [ "$benchmark" != "Benchmark" ]; then
        # Remove potential percentage signs and handle empty lines
        sidecfi="${sidecfi%\%}"
        sidestack="${sidestack%\%}"
        
        if [[ -n "$sidecfi" && -n "$sidestack" ]]; then
            sidecfi_usages+=("$sidecfi")
            sidestack_usages+=("$sidestack")
        fi
    fi
done < "$cpu_usage_file"

# Calculate the geometric means
geomean_sidecfi=$(geomean "${sidecfi_usages[@]}")
geomean_sidestack=$(geomean "${sidestack_usages[@]}")

# Check if geometric means were calculated successfully
if [[ -z "$geomean_sidecfi" || -z "$geomean_sidestack" ]]; then
    echo "Failed to calculate geometric means due to invalid input."
    exit 1
fi

# Generate the Markdown table
cpu_usage_clean="$SCRIPT_DIR/../results/parsed/cpu-usage.md"

{
    echo "| **Benchmark** | **SideCFI** | **SideStack** |"
    echo "| ------------- | ----------- | ------------- |"
    while IFS=, read -r benchmark sidecfi sidestack; do
        if [ "$benchmark" != "Benchmark" ]; then
            echo "| $benchmark | ${sidecfi}% | ${sidestack}% |"
        fi
    done < "$cpu_usage_file"
    echo "| **geomean** | **${geomean_sidecfi}%** | **${geomean_sidestack}%** |"
} > "$cpu_usage_clean"

echo "CPU usage results have been saved to $cpu_usage_clean"

