#!/usr/bin/env python3
import subprocess
import json
import re
import os
import sys
import platform
import shutil
import glob
import argparse
import shlex
import datetime
import socket
import hashlib
import tarfile
import urllib.request
import statistics
import tempfile
import time

# Configuration
FIO_TEMP_FILE = "testfile.tmp"
FIO_JSON_FILE = "fio_results.json"
GB_CPU_JSON = "gb_cpu.json"
GB_GPU_JSON = "gb_gpu.json"
FIO_NOCOW_DIR = ".fio_nocow"

# ffmpeg: synthetic source so no sample file needs to be bundled or downloaded
FFMPEG_SOURCE = "ffmpeg_source.mkv"
FFMPEG_SECONDS = 10
FFMPEG_FPS = 30

# compile: CPython builds natively on macOS and Linux, so results are comparable across both
CPYTHON_VERSION = "3.12.16"
CPYTHON_URL = f"https://www.python.org/ftp/python/{CPYTHON_VERSION}/Python-{CPYTHON_VERSION}.tar.xz"
# Computed from the tarball downloaded over HTTPS (not taken from a published hash)
CPYTHON_SHA256 = "b5796915dc45ff745cfb4e990a7e7c93d6f546328a102ce31448d69ebc37575c"
CACHE_DIR = os.path.expanduser("~/.cache/system-benchmark")

# podman: tags are pinned for repeatability; bump deliberately
PODMAN_IMAGE = "docker.io/library/alpine:3.20"
PODMAN_PULL_IMAGE = "docker.io/library/python:3.12-slim"
PODMAN_STARTUP_RUNS = 20
PODMAN_BIND_FILES = 20000
PODMAN_BUILD_TAG = "localhost/system-benchmark-build:tmp"

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

# ---------------------------------------------------------------- 7zip

def find_7z():
    for cmd in ("7zz", "7z", "7za"):
        if shutil.which(cmd):
            return cmd
    return None

def sevenzip_deps():
    return [] if find_7z() else ["7zip"]

def run_7z_bench(extra):
    out = run_command([find_7z(), "b", *extra])
    if not out:
        return "N/A"
    match = re.search(r"^Tot:\s+(?:\d+\s+)+?(\d+)\s*$", out, re.M)
    return match.group(1) if match else "N/A"

def run_sevenzip(cores, results):
    print("\nRunning 7-Zip benchmark...")
    print("  Running 7z b (1 thread)...")
    single = run_7z_bench(["-mmt1"])
    print(f"  Running 7z b ({cores} threads)...")
    multi = run_7z_bench([f"-mmt{cores}"])
    results["7zip"] = {"single": single, "multi": multi}

def summary_sevenzip(results):
    print(f"7-Zip Single-Thread:          {results['7zip']['single']} MIPS")
    print(f"7-Zip Multi-Thread:           {results['7zip']['multi']} MIPS")

# ---------------------------------------------------------------- compile

def compile_deps():
    return [] if shutil.which("cc") and shutil.which("make") else ["compiler"]

def fetch_cpython():
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, os.path.basename(CPYTHON_URL))
    def verified():
        if not os.path.exists(path):
            return False
        with open(path, "rb") as f:
            return hashlib.file_digest(f, "sha256").hexdigest() == CPYTHON_SHA256
    if not verified():
        print(f"  Downloading CPython {CPYTHON_VERSION}...")
        urllib.request.urlretrieve(CPYTHON_URL, path)
        if not verified():
            os.remove(path)
            raise RuntimeError("CPython tarball checksum mismatch")
    return path

def run_compile(cores, results):
    r = results["compile"] = {}
    print(f"\nRunning CPython {CPYTHON_VERSION} compile...")
    try:
        tarball = fetch_cpython()
    except Exception as e:
        print(f"  Error fetching CPython source: {e}")
        return
    with tempfile.TemporaryDirectory(dir=os.getcwd()) as build_dir:
        with tarfile.open(tarball) as tar:
            tar.extractall(build_dir)
        src = os.path.join(build_dir, f"Python-{CPYTHON_VERSION}")
        print("  ./configure (serial)...")
        start = time.monotonic()
        if subprocess.run(["./configure", "-q"], cwd=src, capture_output=True).returncode != 0:
            print("  Error: configure failed")
            return
        r["configure_s"] = round(time.monotonic() - start, 2)
        print(f"  make -j{cores}...")
        start = time.monotonic()
        if subprocess.run(["make", f"-j{cores}"], cwd=src, capture_output=True).returncode != 0:
            print("  Error: make failed")
            return
        r["make_s"] = round(time.monotonic() - start, 2)
        r["jobs"] = cores

def summary_compile(results):
    r = results["compile"]
    print(f"CPython {CPYTHON_VERSION} build:")
    print(f"  configure (serial):   {r.get('configure_s', 'N/A')} s")
    print(f"  make -j{r.get('jobs', '?')}:".ljust(24) + f"{r.get('make_s', 'N/A')} s")

# ---------------------------------------------------------------- ffmpeg

FFMPEG_REQUIRED_ENCODERS = ("libx264", "libx265")

def ffmpeg_deps():
    if not shutil.which("ffmpeg"):
        return ["ffmpeg"]
    # Distro builds (e.g. Fedora's ffmpeg-free) can lack the software encoders this suite measures
    out = run_command(["ffmpeg", "-hide_banner", "-encoders"]) or ""
    available = set(re.findall(r"^\s*V\S*\s+(\S+)", out, re.M))
    return [] if all(e in available for e in FFMPEG_REQUIRED_ENCODERS) else ["ffmpeg-codecs"]

def time_command(cmd):
    start = time.monotonic()
    out = run_command(cmd)
    elapsed = time.monotonic() - start
    return (elapsed, out) if out is not None else (None, None)

def run_ffmpeg(cores, results):
    results["ffmpeg"] = {}
    frames = FFMPEG_SECONDS * FFMPEG_FPS
    print("\nRunning ffmpeg software encodes...")
    print("  Generating source clip (1080p, lossless)...")
    gen = ["ffmpeg", "-v", "error", "-y", "-f", "lavfi",
           "-i", f"testsrc2=size=1920x1080:rate={FFMPEG_FPS}:duration={FFMPEG_SECONDS}",
           "-pix_fmt", "yuv420p", "-c:v", "ffv1", FFMPEG_SOURCE]
    if run_command(gen) is None:
        return
    for codec in ("libx264", "libx265"):
        for label, threads in [("single", 1), ("multi", cores)]:
            print(f"  Encoding {codec} ({threads} thread(s))...")
            # -threads must come after -i: before it, it only limits the (lossless) decoder.
            # libx265 ignores -threads, so its thread pool is capped via x265-params.
            extra = []
            if codec == "libx265":
                frame_threads = 1 if threads == 1 else 0
                extra = ["-x265-params", f"log-level=error:pools={threads}:frame-threads={frame_threads}"]
            cmd = ["ffmpeg", "-v", "error", "-y", "-i", FFMPEG_SOURCE,
                   "-c:v", codec, "-preset", "medium", "-crf", "23", "-threads", str(threads),
                   *extra, "-f", "null", "-"]
            elapsed, _ = time_command(cmd)
            results["ffmpeg"][f"{codec}_{label}"] = round(frames / elapsed, 2) if elapsed else None

def summary_ffmpeg(results):
    r = results["ffmpeg"]
    print("ffmpeg software encode (1080p, preset medium, crf 23, FPS):")
    for codec in ("libx264", "libx265"):
        print(f"  {codec}:  Single: {r.get(codec + '_single') or 'N/A'} / Multi: {r.get(codec + '_multi') or 'N/A'}")

# ---------------------------------------------------------------- podman

def podman_deps():
    if not shutil.which("podman"):
        return ["podman"]
    if subprocess.run(["podman", "info"], capture_output=True).returncode != 0:
        return ["podman-running"]
    return []

def podman_run_script(script, volume=None):
    cmd = ["podman", "run", "--rm", "--security-opt", "label=disable"]
    if volume:
        cmd += ["-v", f"{volume}:/mnt/bind"]
    return run_command(cmd + [PODMAN_IMAGE, "sh", "-c", script])

def run_podman(cores, results):
    r = results["podman"] = {}
    print("\nRunning podman benchmarks...")

    print("  Preparing base image...")
    if run_command(["podman", "pull", "-q", PODMAN_IMAGE]) is None:
        return

    print(f"  Startup latency ({PODMAN_STARTUP_RUNS} x `run --rm true`)...")
    times = []
    for _ in range(PODMAN_STARTUP_RUNS):
        elapsed, _out = time_command(["podman", "run", "--rm", PODMAN_IMAGE, "true"])
        if elapsed:
            times.append(elapsed * 1000)
    if times:
        r["startup_ms_median"] = round(statistics.median(times), 1)
        r["startup_ms_mean"] = round(statistics.mean(times), 1)

    print(f"  Image pull + unpack ({PODMAN_PULL_IMAGE})...")
    run_command(["podman", "rmi", "-f", PODMAN_PULL_IMAGE])
    elapsed, _out = time_command(["podman", "pull", "-q", PODMAN_PULL_IMAGE])
    r["pull_s"] = round(elapsed, 2) if elapsed else None

    print("  Image build (no cache)...")
    with tempfile.TemporaryDirectory(dir=os.getcwd()) as ctx:
        with open(os.path.join(ctx, "Containerfile"), "w") as f:
            f.write(f"FROM {PODMAN_IMAGE}\n"
                    "RUN apk add --no-cache gcc musl-dev make\n"
                    "RUN dd if=/dev/zero of=/blob bs=1M count=256 && sha256sum /blob\n")
        elapsed, _out = time_command(["podman", "build", "-q", "--no-cache", "-t", PODMAN_BUILD_TAG, ctx])
        r["build_s"] = round(elapsed, 2) if elapsed else None
    run_command(["podman", "rmi", "-f", PODMAN_BUILD_TAG])

    print("  In-container Sysbench CPU...")
    out = podman_run_script("apk add -q --no-cache sysbench >/dev/null 2>&1 && "
                            "n=$(nproc) && echo threads=$n && "
                            "sysbench cpu --threads=1 run && sysbench cpu --threads=$n run")
    if out:
        eps = re.findall(r"events per second:\s+([\d.]+)", out)
        threads = re.search(r"threads=(\d+)", out)
        if len(eps) == 2:
            r["cpu_single"], r["cpu_multi"] = eps
            r["cpu_threads"] = threads.group(1) if threads else "?"

    print(f"  Small-file I/O, bind mount vs container fs ({PODMAN_BIND_FILES} files)...")
    with tempfile.TemporaryDirectory(dir=os.getcwd()) as bind_dir:
        script = (
            "now() { cut -d' ' -f1 /proc/uptime; }; "
            "bench() { mkdir -p $1; s=$(now); i=0; "
            f"while [ $i -lt {PODMAN_BIND_FILES} ]; do echo x > $1/f$i; i=$((i+1)); done; "
            "cat $1/* >/dev/null; rm -rf $1; e=$(now); echo \"$2 $s $e\"; }; "
            "bench /mnt/bind/t bind; bench /tmp/t local")
        out = podman_run_script(script, volume=bind_dir)
    if out:
        for name, s, e in re.findall(r"^(bind|local) ([\d.]+) ([\d.]+)$", out, re.M):
            r[f"smallfiles_{name}_s"] = round(float(e) - float(s), 2)

def summary_podman(results):
    r = results["podman"]
    print("Podman:")
    print(f"  Startup (run --rm true):  median {r.get('startup_ms_median', 'N/A')} ms / mean {r.get('startup_ms_mean', 'N/A')} ms")
    print(f"  Image pull + unpack:      {r.get('pull_s', 'N/A')} s")
    print(f"  Image build (no cache):   {r.get('build_s', 'N/A')} s")
    print(f"  Sysbench CPU in container ({r.get('cpu_threads', '?')} cores): "
          f"single {r.get('cpu_single', 'N/A')} / multi {r.get('cpu_multi', 'N/A')} events/s")
    print(f"  Small files ({PODMAN_BIND_FILES}): bind mount {r.get('smallfiles_bind_s', 'N/A')} s / container fs {r.get('smallfiles_local_s', 'N/A')} s")

# ---------------------------------------------------------------- sysbench / geekbench / fio

def sysbench_deps():
    return [] if shutil.which("sysbench") else ["sysbench"]

# sysbench's cpu test reports absurd, non-comparable numbers on Apple Silicon
# (https://github.com/akopytov/sysbench/issues/469), so don't collect them.
SYSBENCH_CPU_BROKEN = platform.system() == "Darwin" and platform.machine() == "arm64"
SYSBENCH_CPU_SKIPPED = "skipped (sysbench cpu is unreliable on Apple Silicon)"

def run_sysbench(cores, results):
    print("Running Sysbench benchmarks...")
    if SYSBENCH_CPU_BROKEN:
        print("  Skipping Sysbench CPU: known-bad results on Apple Silicon (sysbench issue #469)")
        results["sysbench_cpu"] = {"single": SYSBENCH_CPU_SKIPPED, "multi": SYSBENCH_CPU_SKIPPED}
    else:
        results["sysbench_cpu"] = {"single": run_sysbench_cpu(1), "multi": run_sysbench_cpu(cores)}
    results["sysbench_mem"] = {"single": run_sysbench_mem(1), "multi": run_sysbench_mem(cores)}

def summary_sysbench(results):
    unit = lambda v, u: f"{v} {u}" if SYSBENCH_CPU_SKIPPED != v else v
    print(f"Sysbench CPU Single-Thread:   {unit(results['sysbench_cpu']['single'], 'events/s')}")
    print(f"Sysbench CPU Multi-Thread:    {unit(results['sysbench_cpu']['multi'], 'events/s')}")
    print(f"Sysbench Mem Single-Thread:   {results['sysbench_mem']['single']} MiB/s")
    print(f"Sysbench Mem Multi-Thread:    {results['sysbench_mem']['multi']} MiB/s")

def geekbench_deps():
    if not GEEKBENCH_PATH or not os.path.exists(GEEKBENCH_PATH):
        return ["geekbench"]
    return []

GPU_API = "Metal" if platform.system() == "Darwin" else "Vulkan"

def run_geekbench(cores, results):
    results["geekbench"] = {}
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

    print(f"Running Geekbench 6 GPU ({GPU_API})...")
    run_command([GEEKBENCH_PATH, "--compute", GPU_API, "--no-upload", "--export-json", GB_GPU_JSON])
    if os.path.exists(GB_GPU_JSON):
        with open(GB_GPU_JSON, 'r') as f:
            gb_gpu_data = json.load(f)
            results["geekbench"]["gpu"] = gb_gpu_data.get("score", 0)

def summary_geekbench(results):
    gb = results["geekbench"]
    print(f"Geekbench 6 CPU Single-Core:  {gb.get('cpu_single', 'N/A')}")
    print(f"Geekbench 6 CPU Multi-Core:   {gb.get('cpu_multi', 'N/A')}")
    print(f"Geekbench 6 GPU ({GPU_API}):{' '*(11-len(GPU_API))} {gb.get('gpu', 'N/A')}")

def fio_deps():
    return [] if shutil.which("fio") else ["fio"]

def run_fio(cores, results):
    fio_target = setup_fio_target(FIO_TEMP_FILE)
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

def summary_fio(results):
    fio = results["fio"]
    print("FIO Disk (MiB/s):")
    print(f"  Sequential (Q8T1):   Read: {fio.get('seq_q8t1_r', 0):.2f} / Write: {fio.get('seq_q8t1_w', 0):.2f}")
    print(f"  Sequential (Q1T1):   Read: {fio.get('seq_q1t1_r', 0):.2f} / Write: {fio.get('seq_q1t1_w', 0):.2f}")
    print(f"  Random 4K  (Q32T1):  Read: {fio.get('rnd_q32t1_r', 0):.2f} / Write: {fio.get('rnd_q32t1_w', 0):.2f}")
    print(f"  Random 4K  (Q1T1):   Read: {fio.get('rnd_q1t1_r', 0):.2f} / Write: {fio.get('rnd_q1t1_w', 0):.2f}")

# Package names per package manager. Dependencies with no entry for the detected
# manager are reported with a manual hint instead.
PACKAGES = {
    "sysbench": {"apt": "sysbench", "dnf": "sysbench", "pacman": "sysbench", "brew": "sysbench"},
    "fio":      {"apt": "fio", "dnf": "fio", "pacman": "fio", "brew": "fio"},
    # Fedora/RHEL need RPM Fusion/EPEL for a full-featured ffmpeg (libx264/libx265)
    "ffmpeg":   {"apt": "ffmpeg", "dnf": "ffmpeg", "pacman": "ffmpeg", "brew": "ffmpeg"},
    "7zip":     {"apt": "7zip", "dnf": "7zip", "pacman": "7zip", "brew": "sevenzip"},
    "podman":   {"apt": "podman", "dnf": "podman", "pacman": "podman", "brew": "podman"},
    "compiler": {"apt": "build-essential", "dnf": "gcc make", "pacman": "base-devel"},
}

HINTS = {
    "geekbench": "Geekbench 6 (not found; download from https://www.geekbench.com/download/ "
                 "or put geekbench6 on your PATH)",
    "podman-running": "podman is installed but not responding (macOS: `podman machine init` "
                      "then `podman machine start`)",
    "compiler": "C compiler and make (macOS: run `xcode-select --install`)",
    "ffmpeg-codecs": "ffmpeg is installed but lacks libx264 and/or libx265 (Fedora/RHEL: enable RPM Fusion, "
                     "then `sudo dnf swap ffmpeg-free ffmpeg --allowerasing`)",
}

INSTALL_COMMANDS = {
    "apt": ["apt-get", "install", "-y"],
    "dnf": ["dnf", "install", "-y"],
    "pacman": ["pacman", "-S", "--noconfirm"],
    "brew": ["brew", "install"],
}

def detect_package_manager():
    order = ["brew", "apt-get", "dnf", "pacman"] if platform.system() == "Darwin" \
        else ["apt-get", "dnf", "pacman", "brew"]
    for cmd in order:
        if shutil.which(cmd):
            return "apt" if cmd == "apt-get" else cmd
    return None

def install_packages(manager, packages):
    cmd = INSTALL_COMMANDS[manager] + packages
    if manager != "brew" and os.geteuid() != 0:
        cmd = ["sudo"] + cmd
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd).returncode == 0   # inherits the terminal so sudo can prompt

def resolve_dependencies(selected, install_mode):
    """Return the unresolved dependency keys after (optionally) installing what we can."""
    def find_missing():
        return list(dict.fromkeys(m for s in selected for m in SUITES[s][0]()))

    missing = find_missing()
    if not missing:
        return []
    manager = detect_package_manager()
    installable = {m: PACKAGES[m][manager].split() for m in missing
                   if manager and m in PACKAGES and manager in PACKAGES[m]}
    if installable and install_mode != "never":
        packages = [p for pkgs in installable.values() for p in pkgs]
        print(f"Missing: {', '.join(installable)}")
        if install_mode == "always":
            go = True
        elif sys.stdin.isatty():
            go = input(f"Install via {manager} ({' '.join(packages)})? [y/N] ").strip().lower() in ("y", "yes")
        else:
            go = False
            print(f"Not interactive; re-run with --install or install manually: {' '.join(packages)}")
        if go:
            if not install_packages(manager, packages):
                print("Warning: package installation reported a failure.")
            missing = find_missing()
    return missing

# ---------------------------------------------------------------- environment

def get_filesystem_info(path):
    """Filesystem the tests run on (fio file, compile dir and podman bind mounts all live here)."""
    info = {"test_directory": os.path.abspath(path)}
    try:
        usage = shutil.disk_usage(path)
        info["total_gb"] = round(usage.total / 1024**3, 1)
        info["free_gb"] = round(usage.free / 1024**3, 1)
        if platform.system() == "Linux" and shutil.which("findmnt"):
            out = run_command(["findmnt", "-n", "-P", "-T", path, "-o", "TARGET,SOURCE,FSTYPE,OPTIONS"])
            fields = dict(tok.split("=", 1) for tok in shlex.split(out or "") if "=" in tok)
            info.update({"mountpoint": fields.get("TARGET"), "device": fields.get("SOURCE"),
                         "fstype": fields.get("FSTYPE"), "mount_options": fields.get("OPTIONS")})
        else:
            df = (run_command(["df", "-P", path]) or "").strip().splitlines()
            if len(df) > 1:
                parts = df[-1].split()
                info["device"], info["mountpoint"] = parts[0], " ".join(parts[5:])
                for line in (run_command(["mount"]) or "").splitlines():
                    m = re.match(r"^(\S+) on (.+) \(([^)]*)\)$", line)
                    if m and m.group(2) == info["mountpoint"]:
                        opts = [o.strip() for o in m.group(3).split(",")]
                        info["fstype"], info["mount_options"] = opts[0], ",".join(opts[1:])
                        break
    except Exception as e:
        info["error"] = str(e)
    return info

def read_file(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None

def get_power_state():
    """Snapshot of power/thermal settings that affect benchmark results."""
    state = {}
    try:
        if platform.system() == "Linux":
            supplies = []
            for d in glob.glob("/sys/class/power_supply/*"):
                kind = read_file(os.path.join(d, "type"))
                if kind == "Battery":
                    supplies.append({"battery": True, "percent": read_file(os.path.join(d, "capacity")),
                                     "status": read_file(os.path.join(d, "status"))})
                elif kind in ("Mains", "USB"):
                    supplies.append({"mains": kind, "online": read_file(os.path.join(d, "online")) == "1"})
            if supplies:
                state["on_ac"] = any(x.get("online") for x in supplies if "mains" in x)
                batt = [x for x in supplies if x.get("battery")]
                if batt:
                    state["battery_percent"], state["battery_status"] = batt[0]["percent"], batt[0]["status"]
            cpu = "/sys/devices/system/cpu"
            state["cpu_governor"] = read_file(f"{cpu}/cpu0/cpufreq/scaling_governor")
            state["cpu_epp"] = read_file(f"{cpu}/cpu0/cpufreq/energy_performance_preference")
            state["cpu_cur_mhz"] = (lambda v: round(int(v) / 1000) if v else None)(read_file(f"{cpu}/cpu0/cpufreq/scaling_cur_freq"))
            state["turbo_disabled"] = {"1": True, "0": False}.get(read_file(f"{cpu}/intel_pstate/no_turbo"))
            if shutil.which("powerprofilesctl"):
                state["power_profile"] = (run_command(["powerprofilesctl", "get"]) or "").strip() or None
        elif platform.system() == "Darwin":
            batt = run_command(["pmset", "-g", "batt"]) or ""
            m = re.search(r"Now drawing from '([^']+)'", batt)
            if m:
                state["power_source"] = m.group(1)
                state["on_ac"] = m.group(1) == "AC Power"
            m = re.search(r"(\d+)%;\s*([^;]+);", batt)
            if m:
                state["battery_percent"], state["battery_status"] = m.group(1), m.group(2).strip()
            settings = run_command(["pmset", "-g"]) or ""
            for key in ("lowpowermode", "powermode", "highpowermode"):
                m = re.search(rf"^\s*{key}\s+(\d+)", settings, re.M)
                if m:
                    state[key] = int(m.group(1))
            therm = run_command(["pmset", "-g", "therm"]) or ""
            m = re.search(r"CPU_Speed_Limit\s*=\s*(\d+)", therm)
            if m:
                state["cpu_speed_limit_pct"] = int(m.group(1))
    except Exception as e:
        state["error"] = str(e)
    return {k: v for k, v in state.items() if v is not None}

def check_sanity(results):
    """Flag results that look wrong, so they aren't trusted blindly later."""
    warnings = []
    for suite in ("sysbench_cpu", "sysbench_mem", "7zip"):
        r = results.get(suite, {})
        try:
            if float(r["multi"]) < float(r["single"]):
                warnings.append(f"{suite}: multi-thread ({r['multi']}) is lower than single-thread ({r['single']})")
        except (KeyError, TypeError, ValueError):
            pass
    return warnings

def describe_power(state):
    bits = []
    if "on_ac" in state:
        bits.append("AC power" if state["on_ac"] else "BATTERY")
    for key in ("power_profile", "cpu_governor"):
        if state.get(key):
            bits.append(state[key])
    if state.get("lowpowermode"):
        bits.append("Low Power Mode ON")
    return ", ".join(bits) or "unknown"

TOOL_VERSION_COMMANDS = {
    "sysbench": ["sysbench", "--version"],
    "fio": ["fio", "--version"],
    "ffmpeg": ["ffmpeg", "-version"],
    "podman": ["podman", "--version"],
    "compile": ["cc", "--version"],
}

def get_tool_versions(selected):
    versions = {}
    for suite, cmd in TOOL_VERSION_COMMANDS.items():
        if suite in selected and shutil.which(cmd[0]):
            out = run_command(cmd)
            if out:
                versions[suite] = out.splitlines()[0].strip()
    if "7zip" in selected and find_7z():
        out = run_command([find_7z()]) or ""
        match = re.search(r"7-Zip[^\n]*", out)
        versions["7zip"] = match.group(0).strip() if match else find_7z()
    if "geekbench" in selected and GEEKBENCH_PATH:
        versions["geekbench"] = GEEKBENCH_PATH
    return versions

def save_results(output_dir, selected, cores, sys_info, results, environment, warnings):
    now = datetime.datetime.now().astimezone()
    host = socket.gethostname().split(".")[0]
    record = {
        "timestamp": now.isoformat(timespec="seconds"),
        "hostname": host,
        "system": {
            "os": platform.system(),
            "os_release": platform.release(),
            "os_version": platform.version(),
            "arch": platform.machine(),
            "cpu": sys_info["cpu"],
            "memory": sys_info["memory"],
            "logical_cores": cores,
        },
        "suites": selected,
        "environment": environment,
        "warnings": warnings,
        "tool_versions": get_tool_versions(selected),
        "test_config": {
            "cpython_version": CPYTHON_VERSION,
            "podman_image": PODMAN_IMAGE,
            "podman_pull_image": PODMAN_PULL_IMAGE,
            "podman_startup_runs": PODMAN_STARTUP_RUNS,
            "podman_bind_files": PODMAN_BIND_FILES,
            "ffmpeg_clip": f"1080p {FFMPEG_FPS}fps {FFMPEG_SECONDS}s testsrc2",
        },
        "units": {
            "sysbench_cpu": "events/s", "sysbench_mem": "MiB/s", "fio": "MiB/s",
            "7zip": "MIPS", "ffmpeg": "FPS", "compile": "seconds",
            "podman": "*_ms milliseconds, *_s seconds, cpu_* events/s",
            "geekbench": "score",
        },
        "results": results,
    }
    os.makedirs(output_dir, exist_ok=True)
    path = os.path.join(output_dir, f"{host}_{now.strftime('%Y%m%d-%H%M%S')}.json")
    with open(path, "w") as f:
        json.dump(record, f, indent=2)
        f.write("\n")
    return path

def describe_missing(key):
    return HINTS.get(key) or key

# name -> (dependency check, runner, summary printer); dict order is run/print order
SUITES = {
    "sysbench":  (sysbench_deps,  run_sysbench,  summary_sysbench),
    "geekbench": (geekbench_deps, run_geekbench, summary_geekbench),
    "fio":       (fio_deps,       run_fio,       summary_fio),
    "7zip":      (sevenzip_deps,  run_sevenzip,  summary_sevenzip),
    "compile":   (compile_deps,   run_compile,   summary_compile),
    "ffmpeg":    (ffmpeg_deps,    run_ffmpeg,    summary_ffmpeg),
    "podman":    (podman_deps,    run_podman,    summary_podman),
}

# Suites that only run when explicitly requested (--only or --with)
OPT_IN = {"geekbench"}

def parse_args():
    parser = argparse.ArgumentParser(description="Cross-platform (macOS/Linux) system benchmarks.")
    parser.add_argument("--only", metavar="SUITE[,SUITE]", help="run only these suites (comma-separated)")
    parser.add_argument("--skip", metavar="SUITE[,SUITE]", help="run the default suites except these")
    parser.add_argument("--with", dest="with_", metavar="SUITE[,SUITE]",
                        help=f"also run opt-in suites ({', '.join(sorted(OPT_IN))})")
    parser.add_argument("--list", action="store_true", help="list available suites and exit")
    parser.add_argument("--output-dir", default="results", metavar="DIR",
                        help="where to save the JSON results file (default: ./results)")
    parser.add_argument("--no-save", action="store_true", help="don't write a results file")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--install", action="store_true",
                       help="install missing dependencies via apt/dnf/pacman/brew without asking")
    group.add_argument("--no-install", action="store_true", help="never offer to install missing dependencies")
    args = parser.parse_args()
    if args.list:
        print("\n".join(f"{s}{' (opt-in)' if s in OPT_IN else ''}" for s in SUITES))
        sys.exit(0)
    split = lambda s: [x.strip() for x in s.split(",") if x.strip()] if s else []
    only, skip, extra = split(args.only), split(args.skip), split(args.with_)
    unknown = [s for s in only + skip + extra if s not in SUITES]
    if unknown:
        parser.error(f"unknown suite(s): {', '.join(unknown)} (choose from: {', '.join(SUITES)})")
    base = only if only else [s for s in SUITES if s not in OPT_IN]
    selected = [s for s in SUITES if (s in base or s in extra) and s not in skip]
    if not selected:
        parser.error("no suites selected")
    install_mode = "always" if args.install else "never" if args.no_install else "ask"
    output_dir = None if args.no_save else args.output_dir
    return selected, install_mode, output_dir

def main():
    selected, install_mode, output_dir = parse_args()
    missing = resolve_dependencies(selected, install_mode)
    if missing:
        print(f"Error: Missing dependencies: {', '.join(describe_missing(m) for m in missing)}")
        print("(use --skip to leave out suites you can't run)")
        sys.exit(1)

    cores = get_logical_cores()
    sys_info = get_system_info()
    print("="*50)
    print(f"System:   {platform.system()} {platform.machine()}")
    print(f"CPU:      {sys_info['cpu']}")
    print(f"Memory:   {sys_info['memory']}")
    print(f"Cores:    {cores} logical cores")
    print(f"Suites:   {', '.join(selected)}")
    fs_info = get_filesystem_info(os.getcwd())
    power_start = get_power_state()
    print(f"Test dir: {fs_info['test_directory']} ({fs_info.get('fstype', '?')} on {fs_info.get('device', '?')})")
    print(f"Power:    {describe_power(power_start)}")
    if power_start.get("on_ac") is False:
        print("Warning:  running on battery; results will be lower and less comparable.")
    print("="*50)
    print("\nStarting benchmarks...\n")

    results = {}
    warnings = []
    try:
        for name in selected:
            SUITES[name][1](cores, results)

        print("\n" + "="*50)
        print("                BENCHMARK RESULTS")
        print("="*50)
        for i, name in enumerate(selected):
            if i:
                print("-" * 50)
            SUITES[name][2](results)
        warnings = check_sanity(results)
        for w in warnings:
            print(f"WARNING: {w}")
        print("="*50)

    finally:
        if output_dir and results:
            environment = {"filesystem": fs_info, "power_start": power_start, "power_end": get_power_state()}
            print(f"\nResults saved to: {save_results(output_dir, selected, cores, sys_info, results, environment, warnings)}")
        # Cleanup
        for f in [FIO_TEMP_FILE, os.path.join(FIO_NOCOW_DIR, FIO_TEMP_FILE), FIO_JSON_FILE,
                  GB_CPU_JSON, GB_GPU_JSON, FFMPEG_SOURCE]:
            if os.path.exists(f):
                os.remove(f)
        if os.path.exists(FIO_NOCOW_DIR):
            shutil.rmtree(FIO_NOCOW_DIR)

if __name__ == "__main__":
    main()
