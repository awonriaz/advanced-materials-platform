FROM tensorflow/tensorflow:2.16.1

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    MODEL_PATH=/app/models/material_qc.keras \
    DATASET_DIR=/app/sample_data \
    IMG_SIZE=128 \
    DEFECT_THRESHOLD=0.60

COPY services/tensorflow-qc/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY services/tensorflow-qc/main.py ./main.py
COPY sample_data ./sample_data
RUN mkdir -p /app/models

EXPOSE 8501
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8501"]
