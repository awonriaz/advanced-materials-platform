from __future__ import annotations

import hashlib
from io import BytesIO
from typing import Any

import numpy as np

try:
    import cv2  # type: ignore
except Exception:  # pragma: no cover - OpenCV is optional at runtime
    cv2 = None
from PIL import Image, UnidentifiedImageError


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def extract_features(image_bytes: bytes) -> dict[str, float]:
    """Extract lightweight computer-vision features for demo quality inspection.

    This is intentionally CPU-friendly for an 8 GB exam environment. A production system
    would replace this with a trained CNN/ViT model and keep these features as
    explainable diagnostics.
    """
    try:
        image = Image.open(BytesIO(image_bytes)).convert("L").resize((128, 128))
    except UnidentifiedImageError as exc:
        raise ValueError("Uploaded file is not a valid image") from exc

    arr = np.asarray(image, dtype=np.float32)
    mean_brightness = float(arr.mean())
    contrast = float(arr.std())
    dark_ratio = float((arr < 55).mean())
    bright_ratio = float((arr > 230).mean())

    dx = np.abs(np.diff(arr, axis=1))
    dy = np.abs(np.diff(arr, axis=0))
    edge_density = float(((dx > 35).mean() + (dy > 35).mean()) / 2.0)

    # Scratch proxy: percentage of strong horizontal or vertical transitions.
    scratch_proxy = float(max((dx > 60).mean(), (dy > 60).mean()))

    return {
        "mean_brightness": round(mean_brightness, 4),
        "contrast": round(contrast, 4),
        "dark_ratio": round(dark_ratio, 6),
        "bright_ratio": round(bright_ratio, 6),
        "edge_density": round(edge_density, 6),
        "scratch_proxy": round(scratch_proxy, 6),
    }


def defect_score(features: dict[str, float]) -> float:
    brightness_penalty = abs(features["mean_brightness"] - 150.0) / 150.0 * 8.0
    contrast_penalty = min(features["contrast"] / 80.0, 1.0) * 12.0
    dark_penalty = min(features["dark_ratio"] * 100.0, 1.0) * 25.0
    bright_penalty = min(features["bright_ratio"] * 100.0, 1.0) * 10.0
    edge_penalty = min(features["edge_density"] * 100.0, 1.0) * 18.0
    scratch_penalty = min(features["scratch_proxy"] * 100.0, 1.0) * 22.0
    score = brightness_penalty + contrast_penalty + dark_penalty + bright_penalty + edge_penalty + scratch_penalty
    return round(float(score), 4)


def inspect_image(image_bytes: bytes, threshold: float) -> dict[str, Any]:
    features = extract_features(image_bytes)
    score = defect_score(features)
    result = "FAIL" if score >= threshold else "PASS"
    return {
        "result": result,
        "defect_score": score,
        "threshold": threshold,
        "features": features,
        "image_sha256": sha256_bytes(image_bytes),
    }
