"""Generate a simple flat AMSCP sample image dataset.

The dataset is deliberately synthetic and lightweight for EduQual Level 6 demo
purposes. It is not a production industrial inspection dataset. Production use
would require real labelled images from the target material/process and threshold
calibration by material family.

Flat layout, intentionally simple:

sample_data/
  good_material.png
  defective_material.png
  good_material_01.png ... good_material_12.png
  defective_material_01.png ... defective_material_12.png
  labels.csv
"""
from __future__ import annotations

import csv
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "sample_data"
IMG_SIZE = 256
GOOD_COUNT = 12
DEFECTIVE_COUNT = 12


def _base_material(seed: int, base_level: int = 155) -> Image.Image:
    rng = np.random.default_rng(seed)
    gradient_x = np.linspace(-8, 8, IMG_SIZE, dtype=np.float32)
    gradient_y = np.linspace(-5, 5, IMG_SIZE, dtype=np.float32)[:, None]
    base = np.full((IMG_SIZE, IMG_SIZE), base_level, dtype=np.float32)
    texture = rng.normal(0, 3.5, size=(IMG_SIZE, IMG_SIZE)).astype(np.float32)
    arr = np.clip(base + gradient_x + gradient_y + texture, 0, 255).astype(np.uint8)
    img = Image.fromarray(arr, mode="L").convert("RGB")
    # Subtle non-defective machining texture so the good samples are not blank.
    draw = ImageDraw.Draw(img)
    for y in range(18, IMG_SIZE, 42):
        shade = int(base_level + rng.integers(-8, 8))
        draw.line((0, y, IMG_SIZE, y + int(rng.integers(-2, 3))), fill=(shade, shade, shade), width=1)
    return img.filter(ImageFilter.GaussianBlur(radius=0.25))


def _good_sample(index: int) -> Image.Image:
    material_levels = [150, 154, 158, 162]
    img = _base_material(202600 + index, material_levels[index % len(material_levels)])
    draw = ImageDraw.Draw(img)
    # Very faint inspection marker only; it should stay below the defect threshold.
    if index % 4 == 0:
        draw.ellipse((95, 95, 160, 160), outline=(145, 145, 145), width=1)
    return img


def _defective_sample(index: int) -> Image.Image:
    img = _base_material(303000 + index, 152 + (index % 4) * 2)
    draw = ImageDraw.Draw(img)
    rng = np.random.default_rng(404000 + index)

    # Clear defects: dark crack, pitting/void, bright contamination, and scratch.
    draw.line((25, 205, 232, 45 + int(index % 5)), fill=(8, 8, 8), width=5 + (index % 3))
    cx = int(rng.integers(80, 150))
    cy = int(rng.integers(70, 150))
    draw.ellipse((cx - 28, cy - 22, cx + 32, cy + 30), fill=(18, 18, 18))
    draw.rectangle((166, 165, 216, 214), fill=(238, 238, 238))
    for _ in range(6):
        px = int(rng.integers(20, 230))
        py = int(rng.integers(20, 230))
        r = int(rng.integers(4, 9))
        draw.ellipse((px - r, py - r, px + r, py + r), fill=(25, 25, 25))
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png"):
        old.unlink()
    labels: list[dict[str, str]] = []

    for i in range(1, GOOD_COUNT + 1):
        name = f"good_material_{i:02d}.png"
        _good_sample(i).save(OUT / name)
        labels.append({"filename": name, "label": "good", "target": "0", "expected_result": "PASS"})

    for i in range(1, DEFECTIVE_COUNT + 1):
        name = f"defective_material_{i:02d}.png"
        _defective_sample(i).save(OUT / name)
        labels.append({"filename": name, "label": "defective", "target": "1", "expected_result": "FAIL"})

    # Stable demo aliases used by scripts, docs and slides.
    (OUT / "good_material.png").write_bytes((OUT / "good_material_01.png").read_bytes())
    (OUT / "defective_material.png").write_bytes((OUT / "defective_material_01.png").read_bytes())
    labels.insert(0, {"filename": "good_material.png", "label": "good", "target": "0", "expected_result": "PASS"})
    labels.insert(1, {"filename": "defective_material.png", "label": "defective", "target": "1", "expected_result": "FAIL"})

    with (OUT / "labels.csv").open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=["filename", "label", "target", "expected_result"])
        writer.writeheader()
        writer.writerows(labels)

    print(f"Created simple flat dataset in {OUT}")
    print(f"Good images: {GOOD_COUNT} + alias good_material.png")
    print(f"Defective images: {DEFECTIVE_COUNT} + alias defective_material.png")
    print(f"Labels: {OUT / 'labels.csv'}")


if __name__ == "__main__":
    main()
