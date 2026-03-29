import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart'; // <-- NUEVO: Importamos el locutor
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

List<CameraDescription> cameras = [];

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clarity',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: Colors.blueAccent),
      ),
      home: const MyHomePage(title: 'Home Page'),
    );
  }
}
class ClarityService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final String baseUrl = "http://TU_IP:5000"; // Cambia por tu IP de Manjaro

  Future<void> analyzeAndSpeak(String imagePath) async {
    try {
      // 1. Enviar imagen al backend (/analyze)
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        String audioFileName = data['audio_file']; // El nombre que enviamos desde Flask

        // 2. Configurar el "borrado" automático al terminar de sonar
        _audioPlayer.onPlayerComplete.listen((event) async {
          print("Audio terminado. Enviando orden de borrado...");
          await _deleteAudioFromServer(audioFileName);
        });

        // 3. Reproducir el audio desde la URL de tu backend
        Source urlSource = UrlSource('$baseUrl/get_audio/$audioFileName');
        await _audioPlayer.play(urlSource);
      }
    } catch (e) {
      print("Error en el proceso: $e");
    }
  }

  // Función interna para llamar a tu ruta /clean_audio
  Future<void> _deleteAudioFromServer(String fileName) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/clean_audio/$fileName'));
      if (response.statusCode == 200) {
        print("Servidor: Archivo $fileName borrado con éxito.");
      }
    } catch (e) {
      print("No se pudo borrar el archivo en el servidor: $e");
    }
  }
}
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String mensajeState = "Iniciando Clarity...";
  final FlutterTts flutterTts = FlutterTts(); 

  @override
  void initState() {
    super.initState();
    _inicializarApp();
  }

  

  void _inicializarApp() async {
    // 1. Mirar si ya tenemos los permisos guardados
    PermissionStatus statusCamara = await Permission.camera.status;
    PermissionStatus statusMicrofono = await Permission.microphone.status;

    // Si ambos permisos YA están concedidos de antes...
    if (statusCamara.isGranted && statusMicrofono.isGranted) {
      // Nos saltamos la voz, buscamos la cámara y pasamos a la siguiente pantalla
      await _irAPantallaPrincipal();
      return; // El "return" hace que la función termine aquí y no lea lo de abajo
    }

    // 2. SI NO HAY PERMISOS: Configuramos la voz y damos la bienvenida
    await flutterTts.setLanguage("es-ES");
    await flutterTts.setPitch(1.0);
    // Usamos la voz solo la primera vez
    await flutterTts.speak("Bienvenido a Clarity. Por favor, acepta los permisos de la cámara y el micrófono en la pantalla para poder ver tu entorno.");

    // Pedimos los permisos oficialmente (saldrá el cartelito de Android)
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    // 3. COMPROBAR QUÉ HA RESPONDIDO EL USUARIO
    if (statuses[Permission.camera]!.isGranted && statuses[Permission.microphone]!.isGranted) {
      await _irAPantallaPrincipal();
    } else {
      setState(() {
        mensajeState = "Clarity requiere permisos para funcionar";
      });
      await flutterTts.speak("Has denegado los permisos. La aplicación no puede funcionar sin la cámara y el micrófono.");
    }
  }

  // --- NUEVA FUNCIÓN DE APOYO ---
  // He sacado este trozo aquí para no repetir código arriba
  Future<void> _irAPantallaPrincipal() async {
    try {
      cameras = await availableCameras();
      setState(() {
        mensajeState = "Iniciando cámara...";
      });
      
      // Una pausa muy cortita para que la transición sea suave
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PantallaPrincipal()),
        );
      }
    } catch (e) {
      setState(() {
        mensajeState = "Error: cámara no detectada";
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: mensajeState,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 30),
                Text(
                  mensajeState,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  
  // Variables para controlar el vídeo
  bool _isRecording = false;
  XFile? _videoFile;

  final FlutterTts flutterTts = FlutterTts();
  Future<void> _enviarImagen(XFile image) async {
    final url = Uri.parse('http://192.168.1.44:5000/analyze');
    try {
      var request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath(
        'file', image.path,
        contentType: MediaType('image', 'jpeg'),
      ));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        String descripcion = data['description'];
        await flutterTts.speak(descripcion); // ✅ Esto faltaba
        print("Descripción: $descripcion");
      } else {
        print("Error en el servidor: ${response.statusCode}");
      }
    } catch (e) {
      print("Error de conexión: $e");
      await flutterTts.speak("Error al conectar con el servidor");
    }
  }
  @override
  void initState() {
    super.initState();
    _iniciarCamara();
  }

  void _iniciarCamara() async {
    final camera = cameras.first;
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true, 
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print("Error al inicializar la cámara: $e");
    }
  }

  // === FUNCIÓN PARA FOTOS ===
  Future<void> _tomarFoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isRecording) return; // Por seguridad, no dejamos hacer foto si está grabando

    try {
      final image = await _cameraController!.takePicture();
      print("¡FOTO TOMADA! Guardada en: ${image.path}");
      await _enviarImagen(image); // ✅ Añadir esto
      // Aquí en el futuro enviaremos "image.path" a la IA
    } catch (e) {
      print("Error al tomar la foto: $e");
    }
  }

  // === FUNCIONES PARA VÍDEO ===
  Future<void> _comenzarAGrabar() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
      print("Grabación de VÍDEO iniciada...");
    } catch (e) {
      print("Error al empezar a grabar: $e");
    }
  }

  Future<void> _detenerGrabacion() async {
    if (_cameraController == null || !_isRecording) return;

    try {
      final file = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _videoFile = file;
      });
      print("VÍDEO DETENIDO. Guardado en: ${_videoFile!.path}");
    } catch (e) {
      print("Error al parar de grabar: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // CAPA 1: La cámara en vivo
          CameraPreview(_cameraController!),

          // CAPA 2: BOTONES DE CÁMARA (Abajo)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              // Usamos un Row para poner los botones uno al lado del otro
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  
                  // --- BOTÓN DE FOTO ---
                  if (!_isRecording) ...[
                    Semantics(
                      button: true,
                      label: "Tomar foto",
                      onTapHint: "Pulse para tomar una fotografía",
                      child: GestureDetector(
                        onTap: _tomarFoto,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade400, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.black, size: 30),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40), // Espacio entre los dos botones
                  ],

                  // --- BOTÓN DE VÍDEO ---
                  Semantics(
                    button: true,
                    label: _isRecording ? "Detener grabación" : "Grabar vídeo",
                    onTapHint: _isRecording ? "Pulse para parar" : "Pulse para empezar a grabar",
                    child: GestureDetector(
                      onTap: () {
                        if (_isRecording) {
                          _detenerGrabacion();
                        } else {
                          _comenzarAGrabar();
                        }
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isRecording ? Colors.red : Colors.grey.shade400, 
                            width: 3
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _isRecording ? Icons.stop : Icons.videocam, 
                            color: Colors.red, 
                            size: 35,
                          ),
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}