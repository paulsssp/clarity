import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart'; 
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/services.dart';

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

    // Si ambos permisos están concedidos de antes:
    if (statusCamara.isGranted && statusMicrofono.isGranted) {
      // Nos saltamos la voz, buscamos la cámara y pasamos a inicializar la app
      await _irAPantallaPrincipal();
      return; // Actúa como "break"
    }

    // 2. Si no hay permisos: Configuramos la voz y damos la bienvenida
    await flutterTts.setLanguage("es-ES");
    await flutterTts.setPitch(1.0);
    // Usamos la voz solo la primera vez
    await flutterTts.speak("Bienvenido a Clarity. Por favor, acepta los permisos de la cámara y el micrófono en la pantalla para poder ver tu entorno.");

    // Pedimos los permisos oficialmente (saldrá el cartelito de Android)
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    // 3. Se comprueba que ambos permisos se han dado
    if (statuses[Permission.camera]!.isGranted && statuses[Permission.microphone]!.isGranted) {
      await _irAPantallaPrincipal();

    } 
    else {
      setState(() {
        mensajeState = "Clarity requiere permisos para funcionar";
      });
      await flutterTts.speak("Has denegado los permisos. La aplicación no puede funcionar sin la cámara y el micrófono.");
    }
  }

  Future<void> _irAPantallaPrincipal() async {
    try {
      cameras = await availableCameras();
      setState(() {
        mensajeState = "Iniciando cámara...";
      });
      
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
  late stt.SpeechToText _speech;
  bool listen = false;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
    bool _isRecording = false;
  Timer? _captureTimer;
  final int _intervaloSeg = 5;
  bool _enviandoImagen = false;
  final FlutterTts flutterTts = FlutterTts();

  Future<void> _enviarImagen(XFile image) async {
    final url = Uri.parse('http://10.4.41.67:30050/analyze');
    if (_enviandoImagen) {
      return;
    }

    _enviandoImagen = true;
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
        await flutterTts.speak(descripcion); 
        print("Descripción: $descripcion");
      } else {
        print("Error en el servidor: ${response.statusCode}");
      }
    } finally {
        _enviandoImagen = false;
      }
  }

  @override
  void initState() {
    super.initState();
    _iniciarCamara();
    _inicializarSTT();
  }

  void _inicializarSTT() async {
    _speech = stt.SpeechToText();
    bool disponible = await _speech.initialize(
      onError: (error) => print("STT Error: $error"),
      onStatus: (status) {
        // Si el reconocedor se detiene inesperadamente, lo reiniciamos
        if (status == 'done' || status == 'notListening') {
          _escucharComandos();
        }
      },
    );

    if (disponible) {
      _escucharComandos();
    } 
  }

  void _escucharComandos() async {
  if (!_speech.isAvailable) return;

  setState(() => listen = true);

  await _speech.listen(
    localeId: 'es-ES',
    listenFor: const Duration(seconds: 30),
    pauseFor: const Duration(seconds: 5),
    onResult: (resultado) {
      final texto = resultado.recognizedWords.toLowerCase();
      print("Voz reconocida: $texto");

      if (texto.contains('tomar foto')) {
        _tomarFoto();
      } else if (texto.contains('comenzar grabación') ||
                 texto.contains('empezar grabación') ||
                 texto.contains('comenzar grabacion') ||
                 texto.contains('empezar grabacion')) {
        if (!_isRecording) _comenzarAGrabar();
      } else if (texto.contains('detener grabación') ||
                 texto.contains('parar grabación') ||
                 texto.contains('detener grabacion') ||
                 texto.contains('parar grabacion')) {
        if (_isRecording) _detenerGrabacion();
      }
    },

  );
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

  //Función para tomar fotos
  Future<void> _tomarFoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isRecording) return; 

    try {
      final image = await _cameraController!.takePicture();
      print("¡FOTO TOMADA!");
      await _enviarImagen(image); 
    } catch (e) {
      print("Error al tomar la foto: $e");
    }
  }

  // Grabación vídeo
  void _comenzarAGrabar() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() => _isRecording = true);

    _tomarFotoYEnviar();

    _captureTimer = Timer.periodic(
      Duration(seconds: _intervaloSeg),
      (_) => _tomarFotoYEnviar(),
    );

  }

  void _detenerGrabacion() {
    _captureTimer?.cancel();
    _captureTimer = null;
    setState(() => _isRecording = false);
  }

  Future<void> _tomarFotoYEnviar() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final image = await _cameraController!.takePicture();
      await _enviarImagen(image);
    } catch (e) {
      print("Error en captura periódica: $e");
    }
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _cameraController?.dispose();
    _speech.cancel(); 
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
          // CAPA 1: Cámara Live
          OrientationBuilder(
            builder: (context, orientation) {
              return SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: orientation == Orientation.portrait
                        ? _cameraController!.value.previewSize!.height
                        : _cameraController!.value.previewSize!.width,
                    height: orientation == Orientation.portrait
                        ? _cameraController!.value.previewSize!.width
                        : _cameraController!.value.previewSize!.height,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              );
            },
          ),
          // CAPA 2: Botones de Foto/Vídeo
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              // Usamos un Row para poner los botones uno al lado del otro
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  
                  // Botón de Foto
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

                  // Botón de vídeo
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
          Positioned(
            top: 50,
            right: 16,
            child: AnimatedOpacity(
              opacity: listen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, color: Colors.greenAccent, size: 18),
                    SizedBox(width: 6),
                    Text("Escuchando", style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}