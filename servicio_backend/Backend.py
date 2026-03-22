from fastapi import FastAPI, UploadFile, File
import httpx
import asyncio
import os
import cv2
import numpy as np
import json

app = FastAPI(title="Servicio Backend")

# Variables de entorno
URL_YOLO = os.getenv("URL_YOLO", "http://localhost:8001/detectar")
URL_MIDAS = os.getenv("URL_MIDAS", "http://localhost:8002/profundidad")
URL_LLM = os.getenv("URL_LLM", "http://localhost:8080/v1/chat/completions")

def traducir_posicion(x1, x2, ancho_img):
    # Calcula si el objeto está a la izquierda, centro o derecha.
    centro_x = (x1 + x2) / 2
    if centro_x < (ancho_img * 0.33):
        return "izquierda"
    elif centro_x > (ancho_img * 0.66):
        return "derecha"
    else:
        return "delante"

def traducir_distancia(valor_pixel):
    # Traduce la profundidad de MiDaS (0-255) a lenguaje natural.
    if valor_pixel > 140:
        return "muy cerca"
    elif valor_pixel > 100:
        return "cerca"
    else:
        return "lejos"

@app.post("/analizar_escena")
async def analizar_escena(file: UploadFile = File(...)):
    imagen_bytes = await file.read()
    
    # Averiguamos el ancho de la imagen para calcular posiciones
    np_img = np.frombuffer(imagen_bytes, np.uint8)
    img_cv = cv2.imdecode(np_img, cv2.IMREAD_COLOR)
    alto_img, ancho_img, _ = img_cv.shape

    # 1. Llamamos a YOLO y MiDaS AL MISMO TIEMPO
    async with httpx.AsyncClient(timeout=30.0) as client:
        archivos = {"file": ("imagen.jpg", imagen_bytes, "image/jpeg")}
        
        # Disparamos ambas peticiones en paralelo
        peticion_yolo = client.post(URL_YOLO, files=archivos)
        peticion_midas = client.post(URL_MIDAS, files=archivos)
        
        # Esperamos a que ambas terminen
        res_yolo, res_midas = await asyncio.gather(peticion_yolo, peticion_midas)

    # 2. Procesar respuestas
    datos_yolo = res_yolo.json().get("detecciones", []) if res_yolo.status_code == 200 else []
    
    # 3. Cruzar Datos (El cerebro del Orquestador)
    escena_estructurada = []
    
    if res_midas.status_code == 200:
        # Convertimos los bytes de MiDaS a una matriz matemática (imagen en blanco y negro)
        np_depth = np.frombuffer(res_midas.content, np.uint8)
        mapa_profundidad = cv2.imdecode(np_depth, cv2.IMREAD_GRAYSCALE)
        
        for obj in datos_yolo:
            c = obj["coordenadas"]
            x1, y1, x2, y2 = int(c["x1"]), int(c["y1"]), int(c["x2"]), int(c["y2"])
            
            # Recortamos la zona del objeto en el mapa de profundidad
            zona_objeto = mapa_profundidad[y1:y2, x1:x2]
            
            # Calculamos la media de profundidad. Si la caja es muy pequeña y da error, ponemos 0
            profundidad_media = np.mean(zona_objeto) if zona_objeto.size > 0 else 0
            
            # Traducimos a lenguaje natural
            posicion = traducir_posicion(x1, x2, ancho_img)
            distancia = traducir_distancia(profundidad_media)
            
            escena_estructurada.append({
                "objeto": obj["clase"],
                "ubicacion": posicion,
                "distancia": distancia
            })

    # 4. Preparar el Prompt para el LLM
    # Pasamos de un JSON técnico a un JSON semántico súper digerible para Qwen
    json_para_llm = json.dumps(escena_estructurada, ensure_ascii=False)
    
    payload_llm = {
        "messages": [
            {
                "role": "system", 
                "content": "Vas a recibir un JSON con objetos, su posición y distancia. Responde sólamente con UNA sola frase natural, breve y directa describiendo lo que hay en la escena. NO saludes, NO hables de más. Sólamente la frase descriptiva"
            },
            {
                "role": "user", 
                "content": f"{json_para_llm}"
            }
        ],
        "temperature": 0.3,
        "max_tokens": 80
    }

    # 5. Consultar al LLM
    respuesta_final = "No se pudo analizar la escena."
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            res_llm = await client.post(URL_LLM, json=payload_llm)
            if res_llm.status_code == 200:
                respuesta_final = res_llm.json()["choices"][0]["message"]["content"]
        except Exception as e:
            respuesta_final = f"Error en LLM: {str(e)}"

    # 6. Devolver el resultado completo
    return {
        "status": "success",
        "descripcion_audio": respuesta_final,
        "datos_tecnicos": escena_estructurada
    }
