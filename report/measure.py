#!/usr/bin/env python3
"""Collect reproducible frame timings and CPU/GPU image differences for the report."""

import csv
import hashlib
import json
from pathlib import Path
import platform
import statistics
import struct
import subprocess
import time


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "report"
RUNS = ROOT / "build" / "report-runs"
CASES = [
    ("160x120_d4_s1", 160, 120, 4, 1),
    ("320x240_d4_s1", 320, 240, 4, 1),
    ("640x480_d4_s1", 640, 480, 4, 1),
    ("320x240_d4_s2", 320, 240, 4, 2),
    ("320x240_d4_s3", 320, 240, 4, 3),
    ("320x240_d8_s1", 320, 240, 8, 1),
]


def command(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def configuration(base, directory, width, height, depth, ssaa, frames=4):
    lines = base.splitlines()
    lines[0] = str(frames)
    lines[1] = str(directory / "frame_%d.data")
    lines[2] = f"{width} {height} {lines[2].split()[2]}"
    lines[-1] = f"{depth} {ssaa}"
    return "\n".join(lines) + "\n"


def image_difference(cpu_path, gpu_path):
    cpu, gpu = cpu_path.read_bytes(), gpu_path.read_bytes()
    assert cpu[:8] == gpu[:8], "Image dimensions differ"
    width, height = struct.unpack("<ii", cpu[:8])
    assert len(cpu) == len(gpu) == 8 + width * height * 4
    maximum = total = different_pixels = 0
    for offset in range(8, len(cpu), 4):
        delta = [abs(cpu[offset + channel] - gpu[offset + channel])
                 for channel in range(3)]
        maximum = max(maximum, *delta)
        total += sum(delta)
        different_pixels += any(delta)
    return maximum, total / (width * height * 3), different_pixels


def main():
    RUNS.mkdir(parents=True, exist_ok=True)
    logs = REPORT / "measurements"
    logs.mkdir(exist_ok=True)
    base = command(str(ROOT / "build/kp"), "--default") + "\n"
    (REPORT / "scene.txt").write_text(base, encoding="utf-8")
    metadata = {
        "date": time.strftime("%Y-%m-%d"),
        "platform": platform.platform(),
        "os_release": Path("/etc/os-release").read_text(),
        "cpu": command("lscpu"),
        "gpu": command("nvidia-smi", "--query-gpu=name,driver_version,memory.total,compute_cap",
                       "--format=csv,noheader"),
        "nvcc": command("/usr/local/cuda/bin/nvcc", "--version"),
        "binary_sha256": hashlib.sha256((ROOT / "build/kp").read_bytes()).hexdigest(),
        "source_sha256": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                          for path in sorted((ROOT / "src").rglob("*")) if path.is_file()},
        "warmup_frames": [0],
        "measured_frames": [1, 2, 3],
        "method": "Program frame timer; includes device allocation/copy/free, excludes file output."
    }
    (REPORT / "environment.json").write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n")
    results = []
    for name, width, height, depth, ssaa in CASES:
        modes = {}
        for mode in ("gpu", "cpu"):
            directory = RUNS / name / mode
            directory.mkdir(parents=True, exist_ok=True)
            config = configuration(base, directory, width, height, depth, ssaa)
            (logs / f"{name}_{mode}.txt").write_text(config)
            print(f"Running {name} {mode}", flush=True)
            process = subprocess.run([str(ROOT / "build/kp"), f"--{mode}"], input=config,
                                     cwd=ROOT, text=True, capture_output=True,
                                     check=True, timeout=1200)
            (logs / f"{name}_{mode}.tsv").write_text(process.stdout)
            (logs / f"{name}_{mode}.log").write_text(process.stderr)
            rows = []
            for line in process.stdout.splitlines():
                frame, milliseconds, rays = line.split()
                rows.append({"frame": int(frame), "ms": float(milliseconds), "rays": int(rays)})
            assert [row["frame"] for row in rows] == [0, 1, 2, 3]
            modes[mode] = rows
        differences = [image_difference(RUNS / name / "cpu" / f"frame_{frame}.data",
                                        RUNS / name / "gpu" / f"frame_{frame}.data")
                       for frame in range(4)]
        cpu_ms = statistics.mean(row["ms"] for row in modes["cpu"][1:])
        gpu_ms = statistics.mean(row["ms"] for row in modes["gpu"][1:])
        row = dict(case=name, width=width, height=height, depth=depth, ssaa=ssaa,
                   cpu_ms=round(cpu_ms, 6), gpu_ms=round(gpu_ms, 6),
                   speedup=round(cpu_ms / gpu_ms, 6),
                   rays_mean=round(statistics.mean(item["rays"] for item in modes["gpu"][1:]), 3),
                   primary_rays=width * height * ssaa * ssaa,
                   max_rgb_error=max(item[0] for item in differences),
                   mean_rgb_error=statistics.mean(item[1] for item in differences),
                   different_pixels=sum(item[2] for item in differences),
                   ray_counts_equal=all(a["rays"] == b["rays"]
                                        for a, b in zip(modes["cpu"], modes["gpu"])))
        results.append(row)
        with (REPORT / "benchmark_results.csv").open("w", newline="") as output:
            writer = csv.DictWriter(output, fieldnames=list(row))
            writer.writeheader()
            writer.writerows(results)
        print(json.dumps(row), flush=True)

    preview = RUNS / "preview"
    preview.mkdir(exist_ok=True)
    for name, depth, ssaa, frames in [("animation", 10, 3, 4), ("shallow", 1, 3, 1)]:
        directory = preview / name
        directory.mkdir(exist_ok=True)
        config = configuration(base, directory, 960, 720, depth, ssaa, frames)
        (logs / f"preview_{name}.txt").write_text(config)
        print(f"Rendering preview {name}", flush=True)
        process = subprocess.run([str(ROOT / "build/kp"), "--gpu"], input=config,
                                 cwd=ROOT, text=True, capture_output=True, check=True,
                                 timeout=1200)
        (logs / f"preview_{name}.tsv").write_text(process.stdout)
    print("Report measurements completed", flush=True)


if __name__ == "__main__":
    main()
