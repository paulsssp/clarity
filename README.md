# 👁️ Asistente de Navegabilidad con IA (Backend)

Este repositorio contiene la arquitectura de microservicios del backend para la aplicación de asistencia a personas con discapacidad visual. El sistema procesa imágenes en tiempo real, detecta obstáculos, calcula su distancia y genera una advertencia auditiva en lenguaje natural.

## 🏗️ Arquitectura del Sistema

1. **Orquestador (FastAPI):** Expone el endpoint principal, coordina las peticiones asíncronas y cruza los datos espaciales. `(Puerto 8000)`
2. **Servicio YOLO (Ultralytics YOLOE-26):** Modelo *Open Vocabulary* configurado para detectar obstáculos específicos (escalones, postes, pasos de cebra). `(Puerto 8001)`

3. **Servicio MiDaS (PyTorch):** Red neuronal que estima el mapa de profundidad monocular de la escena. `(Puerto 8002)`

4. **Servicio LLM (Qwen 0.8B/1.5B):** Servidor local basado en `llama.cpp` que redacta la advertencia final basándose en el JSON estructurado. `(Puerto 8080)`


# TODO: instrucciones para nosotros
terminal1:
cd servicio_backend
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
flask --app app run --host=0.0.0.0 --port=5000

terminal2:
cd clarity_app
flutter run