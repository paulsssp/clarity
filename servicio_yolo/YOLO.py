from fastapi import FastAPI, UploadFile, File
from ultralytics import YOLO
from PIL import Image
import io

TRADUCCIONES_COCO = {
    "person": "persona", "bicycle": "bicicleta", "car": "coche", "motorcycle": "moto",
    "airplane": "avión", "bus": "autobús", "train": "tren", "truck": "camión", 
    "boat": "barco", "traffic light": "semáforo", "fire hydrant": "boca de incendios",
    "stop sign": "señal de stop", "parking meter": "parquímetro", "bench": "banco", 
    "bird": "pájaro", "cat": "gato", "dog": "perro", "horse": "caballo", 
    "sheep": "oveja", "cow": "vaca", "elephant": "elefante", "bear": "oso", 
    "zebra": "cebra", "giraffe": "jirafa", "backpack": "mochila", "umbrella": "paraguas", 
    "handbag": "bolso", "tie": "corbata", "suitcase": "maleta", "frisbee": "frisbee", 
    "skis": "esquís", "snowboard": "snowboard", "sports ball": "pelota", "kite": "cometa", 
    "baseball bat": "bate de béisbol", "baseball glove": "guante de béisbol", 
    "skateboard": "monopatín", "surfboard": "tabla de surf", "tennis racket": "raqueta de tenis", 
    "bottle": "botella", "wine glass": "copa de vino", "cup": "taza", "fork": "tenedor", 
    "knife": "cuchillo", "spoon": "cuchara", "bowl": "bol", "banana": "plátano", 
    "apple": "manzana", "sandwich": "sándwich", "orange": "naranja", "broccoli": "brócoli", 
    "carrot": "zanahoria", "hot dog": "perrito caliente", "pizza": "pizza", "donut": "donut", 
    "cake": "pastel", "chair": "silla", "couch": "sofá", "potted plant": "planta", 
    "bed": "cama", "dining table": "mesa", "toilet": "inodoro", "tv": "televisor", 
    "laptop": "portátil", "mouse": "ratón", "remote": "mando a distancia", 
    "keyboard": "teclado", "cell phone": "teléfono móvil", "microwave": "microondas", 
    "oven": "horno", "toaster": "tostadora", "sink": "fregadero", "refrigerator": "nevera", 
    "book": "libro", "clock": "reloj", "vase": "jarrón", "scissors": "tijeras", 
    "teddy bear": "oso de peluche", "hair drier": "secador de pelo", "toothbrush": "cepillo de dientes"
}

app = FastAPI(title="Microservicio YOLOv11n")

# Cargamos el modelo en memoria
print("Cargando modelo YOLO en CPU...")
modelo_yolo = YOLO("yolo26s.pt") 

@app.post("/detect")
async def detectar_objetos(file: UploadFile = File(...)):
    # 1. Leemos la imagen enviada por HTTP
    imagen_bytes = await file.read()
    imagen = Image.open(io.BytesIO(imagen_bytes)).convert("RGB")
    
    # 2. Pasamos la imagen por el modelo
    resultados = modelo_yolo(imagen, device="cpu")
    
    objetos_detectados = []
    
    # 3. Extraemos las cajas, confianzas y nombres en formato limpio
    for caja in resultados[0].boxes:
        clase_id = int(caja.cls[0].item())
        objetos_detectados.append({
            "clase": TRADUCCIONES_COCO.get(modelo_yolo.names[clase_id], modelo_yolo.names[clase_id]),
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