# 1. Base ultraligera de Python
FROM python:3.10-slim

# 2. Carpeta de trabajo interna
WORKDIR /app

# 3. Copiamos e instalamos dependencias
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Copiamos el código del orquestador
COPY Backend.py .

# 5. Exponemos el puerto 8000
EXPOSE 8000
    
# 6. Arrancamos el servidor FastAPI en el puerto 8000
CMD ["uvicorn", "Backend:app", "--host", "0.0.0.0", "--port", "8000"]