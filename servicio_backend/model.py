import os
import cv2
import numpy as np
import requests
import json
from utils import save_log

# Configuración de URLs (Variables de entorno)
URL_YOLO = os.getenv("URL_YOLO", "http://localhost:8001/detectar")
URL_MIDAS = os.getenv("URL_MIDAS", "http://localhost:8002/profundidad")
URL_LLM = os.getenv("URL_LLM", "http://localhost:8080/v1/chat/completions")

PROMPT = """Eres un asistente de accesibilidad visual rápido y directo.
Tu única tarea es leer un JSON con datos de objetos detectados.

REGLAS ESTRICTAS:
1. Responde SOLO con la frase descriptiva.
2. Prioriza los objetos marcados como "cerca".
3. No inventes objetos ni detalles que no estén en el JSON.
4. Si hay varios objetos del mismo tipo juntos agrúpalos (ej. "Hay varias personas cerca a tu derecha" o "Hay múltiples coches lejos a tu izquierda")
5. Usa un tono neutro y directo (ej. "Tienes cerca una persona delante y lejos un coche a la derecha")."""

def traducir_posicion(x1, x2, ancho_img):
    centro_x = (x1 + x2) / 2
    if centro_x < (ancho_img * 0.25): return "izquierda"
    elif centro_x > (ancho_img * 0.75): return "derecha"
    else: return "delante"

def traducir_distancia(valor_pixel):
    if valor_pixel > 140: return "muy cerca"
    elif valor_pixel > 100: return "cerca"
    else: return "lejos"

def predict_environment(file_path):
    """Fusiona YOLO y MiDaS para entender la escena"""
    save_log(f"Analizando escena técnica: {file_path}")
    
    img_cv = cv2.imread(file_path)
    alto_img, ancho_img, _ = img_cv.shape
    
    with open(file_path, 'rb') as f:
        img_bytes = f.read()
        files = {"file": ("imagen.jpg", img_bytes, "image/jpeg")}
        
        try:
            res_yolo = requests.post(URL_YOLO, files=files, timeout=10)
            res_midas = requests.post(URL_MIDAS, files=files, timeout=10)
            
            datos_yolo = res_yolo.json().get("detecciones", []) if res_yolo.status_code == 200 else []
            
            escena_estructurada = []
            if res_midas.status_code == 200:
                np_depth = np.frombuffer(res_midas.content, np.uint8)
                mapa_profundidad = cv2.imdecode(np_depth, cv2.IMREAD_GRAYSCALE)
                
                for obj in datos_yolo:
                    c = obj["coordenadas"]
                    x1, y1, x2, y2 = int(c["x1"]), int(c["y1"]), int(c["x2"]), int(c["y2"])
                    zona_objeto = mapa_profundidad[y1:y2, x1:x2]
                    profundidad_media = np.mean(zona_objeto) if zona_objeto.size > 0 else 0
                    
                    escena_estructurada.append({
                        "objeto": obj["clase"],
                        "ubicacion": traducir_posicion(x1, x2, ancho_img),
                        "distancia": traducir_distancia(profundidad_media)
                    })
            return escena_estructurada
        except Exception as e:
            save_log(f"Error en servicios ML: {e}")
            return []

def calculate_route_advice(escena_estructurada):
    """Consulta al LLM para obtener la frase natural"""
    if not escena_estructurada:
        return "No detecto nada claro frente a ti. Continúa con cuidado."

    json_para_llm = json.dumps(escena_estructurada, ensure_ascii=False)
    payload_llm = {
        "messages": [
            {
                "role": "system", 
                "content": PROMPT
            },
            {"role": "user", "content": json_para_llm}
        ],
        "temperature": 0.3,
        "max_tokens": 80
    }

    try:
        res_llm = requests.post(URL_LLM, json=payload_llm, timeout=15)
        if res_llm.status_code == 200:
            return res_llm.json()["choices"][0]["message"]["content"]
    except Exception as e:
        save_log(f"Error LLM: {e}")
    
    return "Error al generar la descripción verbal."