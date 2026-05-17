from fastapi import FastAPI, UploadFile, File
from ultralytics import YOLOE
from PIL import Image
import io

CLASES = [
    "person",
    "step",
    "stairs",
    "traffic light",
    "wall",
    "puddle",
    "door",
    "construction barrier",
    "pole",
    "fence",
    "car",
    "bus",
    "bike",
    "motorcycle",
    "crosswalk",
    "pothole",
    "tree",
    "chair",
    "table",
    "notebook",
    "laptop"
]

TRADUCCIONES = {
    "person": "persona",
    "step": "escalón",
    "stairs": "escalera",
    "traffic light": "semáforo",
    "wall": "pared",
    "puddle": "charco",
    "door": "puerta",
    "construction barrier": "valla de obra",
    "pole": "poste",
    "fence": "valla",
    "car": "coche",
    "bus": "autobús",
    "bike": "bicicleta",
    "motorcycle": "motocicleta",
    "crosswalk": "paso de peatones",
    "pothole": "bache",
    "tree": "árbol",
    "chair": "silla",
    "table": "mesa",
    "notebook": "libreta",
    "laptop": "portátil"
}


app = FastAPI(title="Microservicio YOLOE26")

# Cargamos el modelo en memoria
print("Cargando modelo YOLO en CPU...")
modelo_yolo = YOLOE("yoloe-26m-seg.pt")
modelo_yolo.set_classes(CLASES)

@app.post("/detect")
async def detectar_objetos(file: UploadFile = File(...)):
    # 1. Leemos la imagen enviada por HTTP
    imagen_bytes = await file.read()
    imagen = Image.open(io.BytesIO(imagen_bytes)).convert("RGB")
    
    # 2. Pasamos la imagen por el modelo
    resultados = modelo_yolo.predict(imagen, device="cpu")
    
    objetos_detectados = []
    
    # 3. Extraemos las cajas, confianzas y nombres en formato limpio
    for caja in resultados[0].boxes:
        clase_id = int(caja.cls[0].item())
        objetos_detectados.append({
            "clase": TRADUCCIONES.get(modelo_yolo.names[clase_id], modelo_yolo.names[clase_id]),
            "confianza": round(float(caja.conf[0].item()), 2),
            "coordenadas": {
                "x1": round(float(caja.xyxy[0][0].item()), 2),
                "y1": round(float(caja.xyxy[0][1].item()), 2),
                "x2": round(float(caja.xyxy[0][2].item()), 2),
                "y2": round(float(caja.xyxy[0][3].item()), 2)
            }
        })
    
    # 4. Devolvemos un JSON puro
    return {"status": "success", "detecciones": objetos_detectados}