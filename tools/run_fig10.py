import csv
import math
import os
import subprocess
from collections import defaultdict
from pathlib import Path

import numpy as np

script_dir = os.path.dirname(os.path.abspath(__file__))
spec06_path = Path(script_dir) / "run_spec06.sh"

# Constants for directory structure
BASE_DIR = Path(script_dir) / "../results"
RAW_DIR = BASE_DIR / "raw"
PARSED_DIR = BASE_DIR / "parsed"
PLOTS_DIR = BASE_DIR / "plots"

# Spec CSV file modes
SPEC_MODES = [
    "spec06.lto.csv",
    "spec06.sideguard.csv",
]

# Hardcoded Griffin performance data
performance_griffin = {
    "perlbench": 74.63,
    "bzip2": 93.02,
    "gcc": 78.12,
    "mcf": 96.62,
    "gobmk": 88.89,
    "hmmer": 95.69,
    "sjeng": 74.91,
    "libquantum": 88.89,
    "h264ref": 87.34,
    "omnetpp": 90.91,
    "astar": 94.79,
    "xalancbmk": 77.82,
}

benchmarks = [
    "perlbench",
    "bzip2",
    "gcc",
    "mcf",
    "gobmk",
    "hmmer",
    "sjeng",
    "libquantum",
    "h264ref",
    "omnetpp",
    "astar",
    "xalancbmk",
]


def setup_directories():
    # Create base directories if they don't exist
    for dir_path in [RAW_DIR, PARSED_DIR, PLOTS_DIR]:
        if not dir_path.exists():
            os.makedirs(dir_path)

    # Determine the next RunXXX directory
    existing_runs = sorted(RAW_DIR.glob("Run*"))
    next_run_num = len(existing_runs)
    next_run_dir = RAW_DIR / f"Run{next_run_num:03d}"

    # Create the next RunXXX directory
    os.makedirs(next_run_dir)

    # Touch all the necessary raw files
    for file_name in SPEC_MODES:
        (next_run_dir / file_name).touch()

    return next_run_dir


def parse_spec_mode(file_path):
    spec_data = defaultdict(list)
    with open(file_path, "r") as f:
        reader = csv.reader(f)
        for row in reader:
            benchmark = row[0].split(".")[1]  # Extract the benchmark name after the dot
            if row[2].strip():
                try:
                    value = float(row[2])
                except ValueError:
                    value = 0.0  # Assign 0 if conversion fails
            else:
                value = 0.0
            spec_data[benchmark].append(value)  # Est. Base Ratio (3rd index)

    avg_data = {
        benchmark: round(np.mean(results), 2)
        for benchmark, results in spec_data.items()
    }
    return avg_data


def calculate_performance_over_lto(lto_data, mode_data):
    performance_data = {}
    for benchmark, lto_avg in lto_data.items():
        if benchmark in mode_data:
            mode_avg = mode_data[benchmark]
            performance = (lto_avg / mode_avg) * 100
            performance_data[benchmark] = round(performance, 2)
        else:
            performance_data[benchmark] = -1.0
    return performance_data


def calculate_geomean(values):
    filtered_values = [v for v in values if 0 < v <= 100]
    if not filtered_values:
        return 0.0
    return round(np.exp(np.mean(np.log(filtered_values))), 2)


def parse_spec_results(run_dir):
    mode_data = {}

    for mode in SPEC_MODES:
        file_path = run_dir / mode
        mode_name = mode.split(".")[1]  # Extracting the mode name from the filename
        mode_data[mode_name] = parse_spec_mode(file_path)

    lto_data = mode_data.pop("lto")  # LTO is the baseline

    final_results = {
        "griffin": performance_griffin,  # Use the hardcoded Griffin data
    }

    for mode, data in mode_data.items():
        final_results[mode] = calculate_performance_over_lto(lto_data, data)

    return final_results


def save_parsed_spec_results(final_results):
    with open(PARSED_DIR / "spec06.csv", "w", newline="") as f:
        writer = csv.writer(f)

        # Write rows for each benchmark
        for benchmark in benchmarks:
            griffin_overhead = final_results["griffin"].get(benchmark, "-")
            sideguard_overhead = final_results["sideguard"].get(benchmark, "-")
            writer.writerow([benchmark, griffin_overhead, sideguard_overhead])

        # Calculate geomean for all modes
        griffin_geomean = calculate_geomean(list(final_results["griffin"].values()))
        sideguard_geomean = calculate_geomean(list(final_results["sideguard"].values()))

        # Write geomean row
        writer.writerow(["geomean", griffin_geomean, sideguard_geomean])


def execute_spec06(file_path):
    # Call the bash script and capture its output
    result = subprocess.run(["bash", spec06_path], stdout=subprocess.PIPE, text=True)


def install_ptw_module():
    # Check if ptw is already loaded and remove it
    ptw_module = "ptw"
    ptw_loaded = subprocess.run(
        f"lsmod | grep {ptw_module}", shell=True, stdout=subprocess.PIPE
    ).stdout.decode("utf-8")

    if ptw_loaded:
        print(f"Removing {ptw_module} module...")
        try:
            subprocess.run(f"sudo rmmod {ptw_module}", shell=True, check=True)
            print(f"{ptw_module} module removed.\n")
        except subprocess.CalledProcessError as e:
            print(f"Error removing {ptw_module} module: {e}")
            sys.exit(1)

    # Specify the path to the kernel module
    ptw_module_path = os.path.abspath(
        os.path.join(script_dir, "../sidecar/sidecar-driver/x86-64")
    )

    # Ensure the ptw.ko file exists before trying to load it
    ptw_ko_path = os.path.join(ptw_module_path, "ptw.ko")
    if not os.path.exists(ptw_ko_path):
        print(f"Error: {ptw_ko_path} does not exist.")
        sys.exit(1)

    # Load the ptw kernel module with sudo and check if it is loaded
    print("Loading the ptw kernel module...")
    try:
        subprocess.run(f"sudo insmod {ptw_ko_path} pause=0", shell=True, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error loading {ptw_module}: {e}")
        print("Please reboot the system and try again.")
        sys.exit(1)

    # Verify the module was successfully loaded
    ptw_loaded = subprocess.run(
        f"lsmod | grep {ptw_module}", shell=True, stdout=subprocess.PIPE
    ).stdout.decode("utf-8")

    if not ptw_loaded:
        print("Error: Failed to load the ptw kernel module.")
        print("Please reboot the system and try again.")
        sys.exit(1)

    print("ptw kernel module loaded successfully.\n")


def main():
    print("Installing the ptw kernel module...")
    install_ptw_module()

    print("Setting up directories...")
    run_dir = setup_directories()

    print(f"Running spec06 for {run_dir}...")
    execute_spec06(run_dir / "spec06.results.csv")

    print("Parsing results...")
    final_results = parse_spec_results(run_dir)

    print("Saving parsed results...")
    save_parsed_spec_results(final_results)

    print("Done.")


if __name__ == "__main__":
    main()
