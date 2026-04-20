#!/usr/bin/env python3
import subprocess
import json
import re
import os
import sys
import platform
import shutil
import glob

# Configuration
FIO_TEMP_FILE = "testfile.tmp"
FIO_JSON_FILE = "fio_results.json"
GB_CPU_JSON = "gb_cpu.json"
GB_GPU_JSON = "gb_gpu.json"
FIO_NOCOW_DIR = ".fio_nocow"

def setup_fio_target(filename):
    if platform.system() != "Linux":
        return filename
    
    try:
        # Check if the current directory is on btrfs
        fs_type = subprocess.check_output(["stat", "-f", "-c", "%T", "."], text=True).strip()
        if fs_type == "btrfs":
            print("  Detected btrfs, disabling CoW for FIO output...")
            if not os.path.exists(FIO_NOCOW_DIR):
                os.makedirs(FIO_NOCOW_DIR)
                # +C disables CoW on btrfs. Must be set on empty dir/file.
                subprocess.run(["chattr", "+C", FIO_NOCOW_DIR], check=True)
            return os.path.join(FIO_NOCOW_DIR, filename)
    except Exception as e:
        print(f"  Warning: Could not configure NOCOW for btrfs: {e}")
    
    return filename

def get_geekbench_path():
    system = platform.system()
    if system == "Darwin":
        mac_path = "/Applications/Geekbench 6.app/Contents/Resources/geekbench6"
        if os.path.exists(mac_path):
            return mac_path
    elif system == "Linux":
        downloads_dir = os.path.expanduser("~/Downloads")
        pattern = os.path.join(downloads_dir, "Geekbench-6.*-Linux", "geekbench6")
        matches = glob.glob(pattern)
        if matches:
            def extract_version(path):
                match = re.search(r"Geekbench-(6\.\d+\.\d+)-Linux", path)
                if match:
                    return tuple(map(int, match.group(1).split('.')))
                return (0, 0, 0)
            matches.sort(key=extract_version, reverse=True)
            return matches[0]
    
    return shutil.which("geekbench6")

GEEKBENCH_PATH = get_geekbench_path()

def check_dependencies():
    missing = []
    for cmd in ['sysbench', 'fio']:
        if not shutil.which(cmd):
            missing.append(cmd)
    if not GEEKBENCH_PATH or not os.path.exists(GEEKBENCH_PATH):
        missing.append(f"Geekbench 6 (not found in path or standard directories)")
    
    if missing:
        print(f"Error: Missing dependencies: {', '.join(missing)}")
        sys.exit(1)

def run_command(cmd, shell=False):
    try:
        result = subprocess.run(cmd, shell=shell, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error running {' '.join(cmd) if isinstance(cmd, list) else cmd}:")
        if e.stdout: print(f"STDOUT: {e.stdout}")
        if e.stderr: print(f"STDERR: {e.stderr}")
        return None

def get_logical_cores():
    if platform.system() == "Darwin":
        return int(run_command(["sysctl", "-n", "hw.logicalcpu"]).strip())
    return os.cpu_count()

def run_sysbench_cpu(threads):
    print(f"  Running Sysbench CPU ({threads} thread(s))...")
    out = run_command(["sysbench", "cpu", f"--threads={threads}", "run"])
    match = re.search(r"events per second:\s+([\d.]+)", out)
    return match.group(1) if match else "N/A"

def run_sysbench_mem(threads):
    print(f"  Running Sysbench Memory ({threads} thread(s))...")
    out = run_command(["sysbench", "memory", f"--threads={threads}", "--memory-block-size=1M", "--memory-total-size=10G", "run"])
    match = re.search(r"([\d.]+) MiB/sec", out)
    return match.group(1) if match else "N/A"

def parse_fio_results():
    if not os.path.exists(FIO_JSON_FILE):
        return {}
    with open(FIO_JSON_FILE, 'r') as f:
        data = json.load(f)
    
    results = {}
    for job in data['jobs']:
        name = job['jobname']
        rw = job.get('job options', {}).get('rw', '')
        # Convert bytes/sec to MiB/sec
        if 'read' in rw or 'randread' in rw:
            results[name] = job['read']['bw_bytes'] / 1024 / 1024
        else:
            results[name] = job['write']['bw_bytes'] / 1024 / 1024
    return results

def get_system_info():
    info = {"cpu": "Unknown", "memory": "Unknown"}
    system = platform.system()
    try:
        if system == "Darwin":
            info["cpu"] = run_command(["sysctl", "-n", "machdep.cpu.brand_string"]).strip()
            mem_bytes = int(run_command(["sysctl", "-n", "hw.memsize"]).strip())
            info["memory"] = f"{mem_bytes / (1024**3):.1f} GB"
        elif system == "Linux":
            if os.path.exists("/proc/cpuinfo"):
                with open("/proc/cpuinfo", "r") as f:
                    for line in f:
                        if "model name" in line:
                            info["cpu"] = line.split(":", 1)[1].strip()
                            break
            if os.path.exists("/proc/meminfo"):
                with open("/proc/meminfo", "r") as f:
                    for line in f:
                        if "MemTotal" in line:
                            mem_kb = int(line.split()[1])
                            info["memory"] = f"{mem_kb / (1024**2):.1f} GB"
    except Exception:
        pass
    return info

def main():
    check_dependencies()
    cores = get_logical_cores()
    sys_info = get_system_info()
    print("="*50)
    print(f"System:   {platform.system()} {platform.machine()}")
    print(f"CPU:      {sys_info['cpu']}")
    print(f"Memory:   {sys_info['memory']}")
    print(f"Cores:    {cores} logical cores")
    print("="*50)
    print("\nStarting benchmarks...\n")

    results = {
        "sysbench_cpu": {},
        "sysbench_mem": {},
        "geekbench": {},
        "fio": {}
    }

    fio_target = setup_fio_target(FIO_TEMP_FILE)

    try:
        # --- Sysbench ---
        print("Running Sysbench benchmarks...")
        results["sysbench_cpu"]["single"] = run_sysbench_cpu(1)
        results["sysbench_cpu"]["multi"] = run_sysbench_cpu(cores)
        results["sysbench_mem"]["single"] = run_sysbench_mem(1)
        results["sysbench_mem"]["multi"] = run_sysbench_mem(cores)

        # --- Geekbench ---
        # Note: --no-upload and --export-json to prevent hanging
        print("\nRunning Geekbench 6 CPU...")
        run_command([GEEKBENCH_PATH, "--cpu", "--no-upload", "--export-json", GB_CPU_JSON])
        if os.path.exists(GB_CPU_JSON):
            with open(GB_CPU_JSON, 'r') as f:
                gb_data = json.load(f)
                results["geekbench"]["cpu_single"] = gb_data.get("score", 0)
                # Geekbench JSON structure for multi-core varies, but 'score' is usually top-level for the run
                # Actually, in GB6 JSON, it's often in 'sections' or top-level.
                # If we want specific sub-scores, we parse them here.
                results["geekbench"]["cpu_multi"] = gb_data.get("multicore_score", "See report") 
                # Re-reading: GB6 JSON has 'score' (single) and 'multicore_score'
        
        gpu_api = "Metal" if platform.system() == "Darwin" else "Vulkan"
        print(f"Running Geekbench 6 GPU ({gpu_api})...")
        run_command([GEEKBENCH_PATH, "--compute", gpu_api, "--no-upload", "--export-json", GB_GPU_JSON])
        if os.path.exists(GB_GPU_JSON):
            with open(GB_GPU_JSON, 'r') as f:
                gb_gpu_data = json.load(f)
                results["geekbench"]["gpu"] = gb_gpu_data.get("score", 0)

        # --- FIO ---
        ioengine = "posixaio" if platform.system() == "Darwin" else "libaio"
        print("\nRunning FIO (AmorphousDiskMark style)...")
        fio_cmd = [
            "fio", "--output-format=json", f"--filename={fio_target}", "--size=1G", "--runtime=30", 
            "--direct=1", "--group_reporting", f"--ioengine={ioengine}",
            "--name=seq_q8t1_r", "--rw=read", "--bs=1M", "--iodepth=8",
            "--name=seq_q8t1_w", "--stonewall", "--rw=write", "--bs=1M", "--iodepth=8",
            "--name=seq_q1t1_r", "--stonewall", "--rw=read", "--bs=1M", "--iodepth=1",
            "--name=seq_q1t1_w", "--stonewall", "--rw=write", "--bs=1M", "--iodepth=1",
            "--name=rnd_q32t1_r", "--stonewall", "--rw=randread", "--bs=4k", "--iodepth=32",
            "--name=rnd_q32t1_w", "--stonewall", "--rw=randwrite", "--bs=4k", "--iodepth=32",
            "--name=rnd_q1t1_r", "--stonewall", "--rw=randread", "--bs=4k", "--iodepth=1",
            "--name=rnd_q1t1_w", "--stonewall", "--rw=randwrite", "--bs=4k", "--iodepth=1"
        ]
        fio_out = run_command(fio_cmd)
        if fio_out:
            with open(FIO_JSON_FILE, 'w') as f:
                f.write(fio_out)
            results["fio"] = parse_fio_results()
        else:
            print("Warning: FIO produced no output.")
            results["fio"] = {}

        # --- Output Summary ---
        print("\n" + "="*50)
        print("                BENCHMARK RESULTS")
        print("="*50)
        print(f"Geekbench 6 CPU Single-Core:  {results['geekbench'].get('cpu_single', 'N/A')}")
        print(f"Geekbench 6 CPU Multi-Core:   {results['geekbench'].get('cpu_multi', 'N/A')}")
        print(f"Geekbench 6 GPU ({gpu_api}):{' '*(11-len(gpu_api))} {results['geekbench'].get('gpu', 'N/A')}")
        print("-" * 50)
        print(f"Sysbench CPU Single-Thread:   {results['sysbench_cpu']['single']} events/s")
        print(f"Sysbench CPU Multi-Thread:    {results['sysbench_cpu']['multi']} events/s")
        print(f"Sysbench Mem Single-Thread:   {results['sysbench_mem']['single']} MiB/s")
        print(f"Sysbench Mem Multi-Thread:    {results['sysbench_mem']['multi']} MiB/s")
        print("-" * 50)
        print("FIO Disk (MiB/s):")
        print(f"  Sequential (Q8T1):   Read: {results['fio'].get('seq_q8t1_r', 0):.2f} / Write: {results['fio'].get('seq_q8t1_w', 0):.2f}")
        print(f"  Sequential (Q1T1):   Read: {results['fio'].get('seq_q1t1_r', 0):.2f} / Write: {results['fio'].get('seq_q1t1_w', 0):.2f}")
        print(f"  Random 4K  (Q32T1):  Read: {results['fio'].get('rnd_q32t1_r', 0):.2f} / Write: {results['fio'].get('rnd_q32t1_w', 0):.2f}")
        print(f"  Random 4K  (Q1T1):   Read: {results['fio'].get('rnd_q1t1_r', 0):.2f} / Write: {results['fio'].get('rnd_q1t1_w', 0):.2f}")
        print("="*50)

    finally:
        # Cleanup
        for f in [fio_target, FIO_JSON_FILE, GB_CPU_JSON, GB_GPU_JSON]:
            if os.path.exists(f):
                os.remove(f)
        if os.path.exists(FIO_NOCOW_DIR):
            shutil.rmtree(FIO_NOCOW_DIR)

if __name__ == "__main__":
    main()
