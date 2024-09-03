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
        echo "Please set the SPEC06_PATH environment variable to the path of the SPEC CPU2017 directory"
        exit 1
    else
        spec06_dir="$SPEC06_PATH"
    fi
fi

echo "SPEC06 directory: $spec06_dir"
