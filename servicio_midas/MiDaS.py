from fastapi import FastAPI, UploadFile, File
from fastapi.responses import Response
from transformers import pipeline
from PIL import Image
import io
import time

app = FastAPI(title="Microservicio MiDaS")

print("Cargando modelo MiDaS en CPU...")
estimador_profundidad = pipeline(
    task="depth-estimation", 
    model="Intel/dpt-swinv2-tiny-256", 
    device="cpu"
)

@app.post("/depth")
async def estimar_profundidad(file: UploadFile = File(...)):
    inicio = time.perf_counter()
    
    # 1. Leemos la imagen
    imagen_bytes = await file.read()
    imagen = Image.open(io.BytesIO(imagen_bytes)).convert("RGB")
    
    # 2. Inferencia con MiDaS
    resultado = estimador_profundidad(imagen)
    imagen_profundidad = resultado["depth"]
    
    # 3. Convertimos el resultado a bytes para enviarlo por HTTP
    buffer = io.BytesIO()
    imagen_profundidad.save(buffer, format="PNG")
    buffer.seek(0)
    
    final = time.perf_counter()
    print(f"Tiempo de procesamiento: {final - inicio:.2f} segundos")
    
    # 4. Devolvemos la imagen directamente
    return Response(content=buffer.getvalue(), media_type="image/png")