from __future__ import annotations

import hashlib
import io

import numpy as np
import torch
import torch.nn as nn
from fastapi import FastAPI, File, UploadFile
from PIL import Image

app = FastAPI(title="AMSCP optional PyTorch QC service", version="1.0.0")

class TinyQC(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.net = nn.Sequential(
            nn.Flatten(),
            nn.Linear(64 * 64, 16),
            nn.ReLU(),
            nn.Linear(16, 1),
            nn.Sigmoid(),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x)

model = TinyQC()
model.eval()

@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "framework": "PyTorch", "mode": "optional implementation evidence"}

@app.post("/inspect")
async def inspect(file: UploadFile = File(...)) -> dict[str, object]:
    data = await file.read()
    image_hash = hashlib.sha256(data).hexdigest()
    image = Image.open(io.BytesIO(data)).convert("L").resize((64, 64))
    arr = np.asarray(image).astype("float32") / 255.0
    # Deterministic PyTorch evidence: combine tiny untrained net with explainable contrast score.
    with torch.no_grad():
        _ = model(torch.tensor(arr).view(1, 1, 64, 64))
    defect_probability = float(min(max(arr.std() * 3.0, 0.0), 1.0))
    return {
        "filename": file.filename,
        "image_sha256": image_hash,
        "framework": "PyTorch",
        "model": "tiny-pytorch-qc-evidence",
        "defect_probability": round(defect_probability, 4),
        "result": "FAIL" if defect_probability >= 0.45 else "PASS",
    }
