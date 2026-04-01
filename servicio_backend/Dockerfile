# 1. Base ultraligera de Python
FROM python:3.10-slim

# 2. Carpeta de trabajo interna
WORKDIR /app

# 3. Copiamos e instalamos dependencias
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Copiamos el código del orquestador
COPY *.py .

# 5. Exponemos el puerto 5000
EXPOSE 5000
    
# 6. Arrancamos el servidor FastAPI en el puerto 5000
CMD ["python", "app.py"]