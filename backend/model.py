from utils import save_log

# TODO
def preprocess_image(file_path):
    save_log(f"ML -> Normalizando píxeles de: {file_path}...")

def predict_environment(file_path):
    # llamar a yolo
    detections = ["paso_de_cebra"] 
    return detections

# modificar que retorne mas de una frase si hay mas de un objeto analizado
def calculate_route_advice(detections):
    save_log("ML -> Calculando ruta...")
    if "obstaculo_derecha" in detections:
        return f"He detectado un obstaculo. Desvíate a la izquierda."
    if "obstaculo_izquierda" in detections:
        return f"He detectado un obstaculo. Desvíate a la derecha."
    if "puerta" in detections:
        return "Hay una puerta frente a ti. Puedes avanzar con calma."
    if "semaforo_rojo" in detections:
        return "Semaforo en rojo, detente."
    if "semaforo_verde" in detections:
        return "Semaforo en verde. Puedes avanzar con calma."
    if "paso_de_cebra" in detections:
        return "Hay un paso de cebra frente a ti. Puedes avanzar con calma."
    if not detections:
        return "No he detectado nada. Continua con normalidad."
