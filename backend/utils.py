from gtts import gTTS
import logging
import psutil
import sys
import os

# logger personalizado
my_logger = logging.getLogger("clarity")
my_logger.setLevel(logging.INFO)
# evita mensajes duplicados
my_logger.propagate = False 
# handler para la terminal
handler = logging.StreamHandler(sys.stdout)
formatter = logging.Formatter('[%(asctime)s] "%(message)s"', datefmt='%d/%b/%Y %H:%M:%S')
handler.setFormatter(formatter)

# evita añadir múltiples handlers si flask reinicia el servidor
if not my_logger.handlers:
    my_logger.addHandler(handler)

def save_log(message):
    my_logger.info(message)

def get_system_metrics():
    cpu = psutil.cpu_percent()
    ram = psutil.virtual_memory().percent
    return {"cpu_percent": cpu, "ram_percent": ram} 

def clean_temporary_files(file_path):
    if os.path.exists(file_path):
        try:
            os.remove(file_path)
            return True
        except Exception as e:
            save_log(f"Error al borrar {file_path}: {e}")
            return False
    else:
        save_log(f"El archivo {file_path} no existe, no se puede borrar.")
        return False

def generate_audio(text):
    folder = '../audios'
    if not os.path.exists(folder):
        try:
            os.makedirs(folder)
            save_log(f"Carpeta creada: {folder}")
        except Exception as e:
            save_log(f"Error crear la carpeta {folder}: {e}")
            raise
   
    file_path = os.path.join(folder, f"{text[:15]}.mp3")
    clean_path = file_path.replace(" ", "-")
   
    try:
        tts = gTTS(text=text, lang='es')
        tts.save(clean_path)
        save_log(f"Audio generado con éxito, guardado en: {clean_path}")
        return clean_path
    except Exception as e:
        save_log(f"Error en gTTS al guardar {clean_path}: {e}")
        raise

def upload_image(file):
    folder = '../images'
    if not os.path.exists(folder):
        try:
            os.makedirs(folder)
            save_log(f"Carpeta creada: {folder}")
        except Exception as e:
            save_log(f"Error crear la carpeta {folder}: {e}")
            raise
    
    file_path = os.path.join(folder, file.filename)
    file.save(file_path)
    save_log(f"Archivo guardado en: {file_path}")
    return file_path