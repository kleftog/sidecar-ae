import os
import subprocess
import sys

# Resolve the absolute path to the directory containing this script
script_dir = os.path.dirname(os.path.abspath(__file__))

# Define paths to LLVM toolchains
llvm_sidecar_path = os.path.abspath(
    os.path.join(script_dir, "../sidecar/install/llvm-sidecar")
)
llvm_orig_path = os.path.abspath(
    os.path.join(script_dir, "../sidecar/install/llvm-orig")
)

# List of values to use as arguments
build_types = ["lto", "cfi", "sidecfi", "safestack", "sidestack", "asan", "sideasan"]

# List of build scripts to execute
build_scripts = [
    os.path.join(script_dir, "build_bind.sh"),
    os.path.join(script_dir, "build_httpd.sh"),
    os.path.join(script_dir, "build_lighttpd.sh"),
    os.path.join(script_dir, "build_memcached.sh"),
]

spec_install_dir = os.path.abspath(os.path.join(script_dir, "../benchmarks/spec2017"))
spec_tar_path = ""


def get_spec_path():
    global spec_install_dir
    global spec_tar_path

    # First, check if SPEC17_PATH environment variable is defined
    spec17_path_l = os.getenv("SPEC17_PATH")
    if spec17_path_l and os.path.isdir(spec17_path_l):
        spec_install_dir = spec17_path_l
        return

    # check default installation
    if os.path.isdir(spec_install_dir):
        return

    # If not found, check for the cpu2017-patched.tar file
    spec_tar_path_l = os.path.abspath(
        os.path.join(script_dir, "../benchmarks/cpu2017/cpu2017-patched.tar")
    )
    if os.path.exists(spec_tar_path_l):
        spec_tar_path = spec_tar_path_l
        return

    # If none of the above conditions are met, print an error and exit
    print("Error: SPEC CPU2017 is not installed at the default path.")
    print(
        "Please set the SPEC17_PATH environment variable to the SPEC CPU2017 installation directory."
    )
    sys.exit(1)


get_spec_path()

# Check if ptw is already loaded and rmmod
ptw_module = "ptw"
ptw_loaded = subprocess.run(
    f"lsmod | grep {ptw_module}", shell=True, stdout=subprocess.PIPE
).stdout.decode("utf-8")

if ptw_loaded:
    print(f"Removing {ptw_module} module...")
    subprocess.run(f"sudo rmmod {ptw_module}", shell=True, check=True)
    print(f"{ptw_module} module removed.\n")

ptw_module_path = os.path.abspath(
    os.path.join(script_dir, "../sidecar/sidecar-driver/x86-64")
)

# Build the ptw kernel module
print("Building the ptw kernel module...")
subprocess.run(
    f"make -C {ptw_module_path} clean && make -C {ptw_module_path}",
    shell=True,
    check=True,
)

# Load the ptw kernel module with sudo and check if it is loaded
# If not loaded, print an error message and exit
print("Loading the ptw kernel module...")
subprocess.run(f"sudo insmod {ptw_module_path}/ptw.ko pause=0", shell=True, check=True)
ptw_loaded = subprocess.run(
    f"lsmod | grep {ptw_module}", shell=True, stdout=subprocess.PIPE
).stdout.decode("utf-8")

if not ptw_loaded:
    print("Error: Failed to load the ptw kernel module.")
    print("Please reboot the system and try again.")
    sys.exit(1)

# Loop over each build type and each script
for build_type in build_types:
    for build_script in build_scripts:
        try:
            script_name = os.path.basename(build_script)
            print(f"Building {script_name} with {build_type}...")
            # Execute the script with the current build type
            result = subprocess.run(
                [build_script, build_type, "all"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            print(f"Build completed for {script_name} with {build_type}.\n")
            print(result.stdout.decode("utf-8"))
        except subprocess.CalledProcessError as e:
            print(f"An error occurred while building {script_name} with {build_type}.")
            print(e.stderr.decode("utf-8"))

print("App builds completed.")

# Paths to wrk and memtier_benchmark
wrk_path = os.path.join(script_dir, "../benchmarks/wrk")
memtier_path = os.path.join(script_dir, "../benchmarks/memtier_benchmark")

# Build directory
ins_dir = os.path.join(script_dir, "../install/tools")

os.makedirs(ins_dir, exist_ok=True)

wrk_commands = [
    f"make -C {wrk_path}",
    f"cp {os.path.join(wrk_path, 'wrk')} {os.path.join(ins_dir, 'wrk')}",
]

# Execute the wrk build and installation commands
for command in wrk_commands:
    try:
        print(f"Executing: {command}")
        subprocess.run(
            command,
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        print(f"Installation completed: {command}\n")
    except subprocess.CalledProcessError as e:
        print(f"An error occurred during wrk installation.")


memtier_commands = [
    f"cd {memtier_path} && autoreconf -fi && ./configure",
    f"make -C {memtier_path}",
    f"cp {os.path.join(memtier_path, 'memtier_benchmark')} {os.path.join(ins_dir, 'memtier_benchmark')}",
]


# Execute the memtier_benchmark build and installation commands
for command in memtier_commands:
    try:
        print(f"Executing: {command}")
        subprocess.run(
            command,
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        print(f"Installation completed: {command}\n")
    except subprocess.CalledProcessError as e:
        print(f"An error occurred during memtier_benchmark installation.")
        print(e.stderr.decode("utf-8"))

print("Testing-tool builds completed.")

# check if spec_tar_path is set and if it is do something
if spec_tar_path != "" and not os.path.isdir(spec_install_dir):
    # Untar and install SPEC2017
    try:
        print(f"Creating installation directory at {spec_install_dir}...")
        os.makedirs(spec_install_dir, exist_ok=True)
        print("Untarring and installing SPEC2017...")
        subprocess.run(
            f"tar -xvf {spec_tar_path} -C {spec_install_dir} --strip-components=1",
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        print("SPEC2017 untarred successfully.")
    except subprocess.CalledProcessError as e:
        print("An error occurred while untarring SPEC2017.")
        print(e.stderr.decode("utf-8"))

# Copy config files
spec_configs_src = os.path.abspath(
    os.path.join(script_dir, "../benchmarks/cpu2017/config")
)
spec_configs_dst = os.path.join(spec_install_dir, "config")

# check if spec_configs_dst includes a config by the name of sidecfi.cfg
# if it does, then we don't need to copy the config files
if os.path.exists(os.path.join(spec_configs_dst, "sidecfi.cfg")):
    print("SPEC2017 config files already exist.")
else:
    try:
        print("Copying SPEC2017 config files...")
        subprocess.run(
            f"cp -r {spec_configs_src}/*.cfg {spec_configs_dst}/",
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        print("SPEC2017 config files copied successfully.")
    except subprocess.CalledProcessError as e:
        print("An error occurred while copying SPEC2017 config files.")
        print(e.stderr.decode("utf-8"))

print("SPEC2017 installation and configuration completed.")

"""
# Path to SPEC2017 directory
spec_dir = os.path.abspath(os.path.join(script_dir, "../benchmarks/spec2017"))

# Source the SPEC2017 shrc file
os.chdir(spec_dir)
subprocess.run("source shrc", shell=True, executable="/bin/bash")

# Loop over each build type and build SPEC2017
for build_type in build_types:
    gcc_dir = llvm_sidecar_path if build_type != "asan" else llvm_orig_path
    spec_command = (
        f"runcpu --action=build --config={build_type} --label={build_type} "
        f"-define gcc_dir={gcc_dir} mcf_s"
    )
    try:
        print(f"Building SPEC2017 with {build_type} using {gcc_dir}...")
        result = subprocess.run(
            spec_command,
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=spec_dir,
            executable="/bin/bash",
        )
        print(f"SPEC2017 build completed for {build_type}.\n")
        print(result.stdout.decode("utf-8"))
    except subprocess.CalledProcessError as e:
        print(f"An error occurred during SPEC2017 build with {build_type}.")
        print(e.stderr.decode("utf-8"))
"""

print("All builds completed.")
