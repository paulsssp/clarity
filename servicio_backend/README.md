# Clarity - Backend
Este repositorio contiene el Backend del proyecto **Clarity**, una aplicación de reconocimiento del entorno diseñada para personas con discapacidad visual. El servicio está construido con Flask y actúa como el núcleo central que conecta la aplicación móvil Android con los modelos de Inteligencia Artificial.

## Estructura del Proyecto
Siguiendo una arquitectura modular, el código se divide en:

- `app.py`  Punto de entrada de la aplicación Flask. Define los endpoints de la API, gestiona las peticiones de la App y coordina el flujo de datos.

- `model.py`   Contiene la lógica de Integración de Machine Learning. Se encarga del preprocesamiento de imágenes, detección de objetos y de ejecutar las predicciones para detectar obstáculos y rutas.

- `utils.py`    Funciones auxiliares para la gestión de métricas, registro de logs, generación de audios y limpieza de archivos temporales para garantizar la privacidad de los datos.

## Instalación
Asegúrate de tener **Python 3.14** instalado. Luego, sigue estos pasos:

1. Instalación local del repositorio
```bash
git clone git@github.com:paulsssp/clarity.git
cd clarity/clarity-backend
mkdir -p images
mkdir -p audios
```

2. Creación del entorno virtual e instalación de dependencias
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

3. Ejecución
```bash
flask --app app run
```

Backend desarrollado por Paula Pérez.