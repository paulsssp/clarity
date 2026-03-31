FROM python:3.10-slim
WORKDIR /app

RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY YOLO.py .

EXPOSE 8001
CMD ["uvicorn", "YOLO:app", "--host", "0.0.0.0", "--port", "8001"]