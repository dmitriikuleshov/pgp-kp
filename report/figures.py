#!/usr/bin/env python3
"""Build report figures from measured data and frames rendered by the project."""

import csv
from pathlib import Path
import struct

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.patches import FancyArrowPatch
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "report"
IMAGES = REPORT / "images"
RUNS = ROOT / "build" / "report-runs"


def read_image(path):
    data = path.read_bytes()
    width, height = struct.unpack("<ii", data[:8])
    assert len(data) == 8 + width * height * 4
    return Image.frombytes("RGBA", (width, height), data[8:]).convert("RGB")


def pair(left, right, names, output, scale=1):
    size = (left.width * scale, left.height * scale)
    left = left.resize(size, Image.Resampling.NEAREST)
    right = right.resize(size, Image.Resampling.NEAREST)
    image = Image.new("RGB", (2 * size[0] + 20, size[1] + 52), "white")
    image.paste(left, (0, 45))
    image.paste(right, (size[0] + 20, 45))
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype("/mnt/c/Windows/Fonts/times.ttf", 27)
    draw.text((6, 4), names[0], fill="black", font=font)
    draw.text((size[0] + 26, 4), names[1], fill="black", font=font)
    image.save(output)


def main():
    IMAGES.mkdir(exist_ok=True)
    font_manager.fontManager.addfont("/mnt/c/Windows/Fonts/times.ttf")
    plt.rcParams.update({"font.family": "Times New Roman", "font.size": 12,
                         "mathtext.fontset": "stix", "svg.fonttype": "path",
                         "axes.spines.top": False, "axes.spines.right": False,
                         "figure.facecolor": "white", "savefig.facecolor": "white"})
    with (REPORT / "benchmark_results.csv").open() as source:
        rows = list(csv.DictReader(source))
    baseline = rows[:3]
    figure, axis = plt.subplots(figsize=(6.4, 3.7), layout="constrained")
    x = [int(row["width"]) * int(row["height"]) / 1000 for row in baseline]
    axis.plot(x, [float(row["cpu_ms"]) for row in baseline], "o-", color="#17476e", label="CPU, 1 поток")
    axis.plot(x, [float(row["gpu_ms"]) for row in baseline], "s-", color="#a04416", label="GPU, блок 16 × 16")
    axis.set(xlabel="Количество пикселей, тыс.", ylabel="Время кадра, мс", yscale="log")
    axis.grid(axis="both", alpha=.22)
    axis.legend()
    figure.savefig(IMAGES / "resolution_time.svg")
    plt.close(figure)

    figure, axis = plt.subplots(figsize=(6.4, 3.4), layout="constrained")
    path = [(-.45, .2), (0, .2 + .6*.45/3.15), (1, .2 + .6*1.45/3.15),
            (0, .2 + .6*2.45/3.15), (.7, .8)]
    axis.plot([0, 0], [0, 1], color="#333333", linewidth=2)
    axis.plot([1, 1], [0, 1], color="#333333", linewidth=2)
    for a, b in zip(path, path[1:]):
        axis.add_patch(FancyArrowPatch(a, b, arrowstyle="->", mutation_scale=13,
                                      color="#17476e", linewidth=1.5))
    axis.scatter([-.45, .7], [.2, .8], c=["#333333", "#a04416"], s=[30, 65], zorder=3)
    axis.text(-.55, .08, "Камера")
    axis.text(.69, .88, "Лампочка")
    axis.text(-.08, 1.05, "Грань A")
    axis.text(.92, 1.05, "Грань B")
    axis.text(.3, .15, "$W=\\tau r^2$")
    axis.set(xlim=(-.6, 1.25), ylim=(-.02, 1.2), aspect="equal")
    axis.axis("off")
    figure.savefig(IMAGES / "reflection_path.svg")
    plt.close(figure)

    full = read_image(RUNS / "preview/animation/frame_0.data")
    full.save(IMAGES / "scene_0.png")
    shallow = read_image(RUNS / "preview/shallow/frame_0.data")
    region = (370, 310, 565, 535)
    pair(shallow.crop(region), full.crop(region), ["Глубина 1", "Глубина 10"],
         IMAGES / "depth_detail.png", scale=2)
    s1 = read_image(RUNS / "320x240_d4_s1/gpu/frame_0.data")
    s3 = read_image(RUNS / "320x240_d4_s3/gpu/frame_0.data")
    region = (120, 95, 200, 180)
    pair(s1.crop(region), s3.crop(region), ["SSAA = 1", "SSAA = 3"],
         IMAGES / "ssaa_detail.png", scale=4)
    print("Report figures generated")


if __name__ == "__main__":
    main()
