from flask import Flask
from flask import request
from flask import jsonify
from flask import send_file
from utils import *
from model import *

app = Flask(__name__)

@app.route("/")
def hello_world():
    return "<p>Hello, World!</p>"

@app.route('/check_status', methods=['GET'])
def health_check():
    return jsonify({
        "status": "ready",
        "system": "Clarity Backend"
    }), 200

@app.route('/analyze', methods=['POST'])
def analyze(image):
    save_log("Procesando imagen")
    try:
        # especificar de donde viene  
        # file_path = os.path.join("../images", image)
        file = request.files['file']
        file_path = upload_image(file)
        # preprocess_image(file_path)
        detections = predict_environment(file_path)
        advice = calculate_route_advice(detections)
        get_audio_description(advice)
        
        return jsonify({
            "status": "success",
            "message": "Imagen procesada con éxito",
            "description": advice
        }), 200
    
    except Exception as e:
        save_log(f"Error en procesar la imagen: {e}")
        return jsonify({
            "error": str(e)
        }), 500

@app.route('/metrics', methods=['GET'])
def metrics():
    return jsonify(get_system_metrics()), 200

@app.route('/get_audio/<text>', methods=['GET'])
def get_audio_description(text):
    if not text:
        return jsonify({
            "error": "El texto está vacío"
        }), 400
    
    try:
        save_log(f"Generando audio para: {text}")
        audio_path = generate_audio(text)
        return send_file(audio_path, mimetype="audio/mpeg")
    
    except Exception as e:
        save_log(f"Error generando audio: {e}")
        return jsonify({
            "error": "No se pudo generar el audio"
        }), 500

@app.route('/clean_audio/<file_path>', methods=['GET'])
def clean_audio(file_path):
    try:
        deleted = clean_temporary_files(f"../audios/{file_path}")
        if deleted:
            return jsonify({
                "message": f"Archivo {file_path} borrado"
            }), 200    
        else :
            return jsonify({
                "message": f"El archivo {file_path} no existe en el servidor"
            }), 400
    
    except Exception as e:
        save_log(f"Error en ruta file_path: {e}")
        return jsonify({
            "error": str(e)
        }), 500
    
@app.route('/clean_image/<file_path>', methods=['GET'])
def clean_image(file_path):
    try:
        deleted = clean_temporary_files((f"../images/{file_path}"))
        if deleted:
            return jsonify({
                "message": f"Archivo {file_path} borrado"
            }), 200     
        else :
            return jsonify({
                "message": f"El archivo {file_path} no existe"
            }), 400
    
    except Exception as e:
        save_log(f"Error en ruta file_path: {e}")
        return jsonify({
            "error": str(e)
        }), 500

@app.route('/test_log', methods=['GET'])
def test_log():
    save_log("Testeo de save_log")
    return jsonify({
        "message": "Funciona"
    }), 200

if __name__ == '__main__':
    # host='0.0.0.0' para que la VM sea accesible desde fuera
    app.run(host='0.0.0.0', port=5000, debug=True) 