import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

// Definición de los estados del catcher
enum CatcherState { ready, catching, locked }

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Juego de Captura Mejorado',
      home: GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  // Posición del objeto que cae
  double _fallingObjectX = 0.0;
  double _fallingObjectY = 0.0;

  // Tamaño del objeto que cae
  double _fallingObjectWidth = 20.0;
  double _fallingObjectHeight = 100.0;

  // Tamaño del catcher
  final double _catcherWidth = 30.0;
  final double _catcherHeight = 125.0;

  // Posición del catcher
  double _catcherX = 0.0;
  double _catcherY = 10.0;

  // Estado del catcher
  CatcherState _catcherState = CatcherState.ready;
  Timer? _catcherTimer; // Temporizador para el estado de atrapar

  bool _isGameOver = false;
  int _score = 0;
  int _level = 1;

  Timer? _timer;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  // Variables de pantalla
  double _screenWidth = 0.0;
  double _screenHeight = 0.0;

  // Variables para el contador
  int _countdown = 3; // Contador inicial en segundos
  bool _isCountingDown = true; // Indica si el contador está activo
  Timer? _countdownTimer; // Temporizador para el contador

  @override
  void initState() {
    super.initState();
    _listenToMagnetometer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Obtener el tamaño de la pantalla
    if (_screenWidth == 0.0 && _screenHeight == 0.0) {
      final size = MediaQuery.of(context).size;
      _screenWidth = size.width;
      _screenHeight = size.height;

      // Posicionar el catcher en el centro inferior
      _catcherX = (_screenWidth - _catcherWidth) / 2;
      _catcherY = _screenHeight - 250; // 100 píxeles desde el fondo

      // Posicionar el objeto que cae al centro superior
      _fallingObjectX = (_screenWidth - _fallingObjectWidth) / 2;
      _fallingObjectY = 0.0;

      // Iniciar el juego
      _startGame();
    }
  }

  void _startGame() {
    setState(() {
      _isGameOver = false;
      _score = 0;
      _level = 1;
      _fallingObjectY = 0.0;
      _fallingObjectX = (_screenWidth - _fallingObjectWidth) / 2;
      _catcherState = CatcherState.ready;
      _fallingObjectHeight = 100.0;
      _fallingObjectWidth = 20.0;
      _countdown = 3;
      _isCountingDown = true;
    });

    // Iniciar el contador
    _startCountdown();

    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      if (!_isCountingDown && !_isGameOver) {
        setState(() {
          // Aumentar la velocidad de caída con cada nivel
          double fallingSpeed = 20.0 + (_level - 1) * 0.5;
          _fallingObjectY += fallingSpeed;

          // Verificar colisión
          if (_checkCollision()) {
            _score++;
            // Incrementar nivel cada 5 puntos
            if (_score % 5 == 0) {
              _level++;
              // Reducir el tamaño del objeto que cae
              _fallingObjectWidth =
                  (_fallingObjectWidth * 0.9).clamp(30.0, _screenWidth);
            }
            _resetFallingObject();
          }

          // Verificar si el objeto ha caído fuera de la pantalla
          if (_fallingObjectY > _screenHeight) {
            _isGameOver = true;
            _timer?.cancel();
            // Opcional: Puedes reiniciar el juego automáticamente después de unos segundos
            // Timer(Duration(seconds: 3), _restartGame);
          }
        });
      }
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = 3;
    _isCountingDown = true;

    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        setState(() {
          _countdown = 0;
          _isCountingDown = false;
        });
        _countdownTimer?.cancel();
      }
    });
  }

  void _resetFallingObject() {
    setState(() {
      _isCountingDown = true;
      _countdown = 3;
      _fallingObjectY = 0.0;
      _fallingObjectX = (_screenWidth - _fallingObjectWidth) / 2;
    });

    _startCountdown();
  }

  bool _checkCollision() {
    // Coordenadas del objeto que cae
    double fallingLeft = _fallingObjectX;
    double fallingRight = _fallingObjectX + _fallingObjectWidth;
    double fallingTop = _fallingObjectY;
    double fallingBottom = _fallingObjectY + _fallingObjectHeight;

    // Coordenadas del catcher
    double catcherLeft = _catcherX;
    double catcherRight = _catcherX + _catcherWidth;
    double catcherTop = _catcherY;
    double catcherBottom = _catcherY + _catcherHeight;

    // Verificar si hay intersección
    bool overlapX = fallingRight >= catcherLeft && fallingLeft <= catcherRight;
    bool overlapY = fallingBottom >= catcherTop && fallingTop <= catcherBottom;

    // Solo cuenta la colisión si el catcher está en estado de atrapar
    bool collision =
        overlapX && overlapY && _catcherState == CatcherState.catching;

    if (collision) {
      print('¡Objeto atrapado!');
    }

    return collision;
  }

  void _listenToMagnetometer() {
    _magnetometerSubscription =
        magnetometerEventStream().listen((MagnetometerEvent event) {
      // El magnetómetro mide el campo magnético en microTesla (µT)
      // Usamos el valor en el eje Z para detectar la rotación
      if (event.x < -20 && _catcherState == CatcherState.ready) {
        // Activar estado de atrapar cuando se detecta una rotación significativa
        setState(() {
          _catcherState = CatcherState.catching;
        });

        // Iniciar temporizador para desactivar el estado después de 1 segundo
        _catcherTimer?.cancel();
        _catcherTimer = Timer(Duration(seconds: 1), () {
          setState(() {
            _catcherState = CatcherState.locked;
          });
        });
      } else if (event.x > 20 && _catcherState == CatcherState.locked) {
        // Activar estado Ready al rotar en la dirección opuesta
        setState(() {
          _catcherState = CatcherState.ready;
        });
      }
    });
  }

  void _restartGame() {
    setState(() {
      _score = 0;
      _level = 1;
      _isGameOver = false;
      _fallingObjectY = 0.0;
      _fallingObjectX = (_screenWidth - _fallingObjectWidth) / 2;
      _catcherState = CatcherState.ready;
      _fallingObjectHeight = 100.0;
      _fallingObjectWidth = 20.0;
      _countdown = 3;
      _isCountingDown = true;
    });

    _timer?.cancel();
    _countdownTimer?.cancel();
    _catcherTimer?.cancel();
    _startGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Objeto que cae (Rectángulo)
          Positioned(
            left: _fallingObjectX,
            top: _fallingObjectY,
            child: Container(
              width: _fallingObjectWidth,
              height: _fallingObjectHeight,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          // Catcher (Objeto que atrapa)
          Positioned(
            left: _catcherX,
            top: _catcherY,
            child: Container(
              width: _catcherWidth,
              height: _catcherHeight,
              decoration: BoxDecoration(
                color: _catcherState == CatcherState.catching
                    ? Colors.green
                    : Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Puntuación y Nivel
          Positioned(
            left: 20,
            top: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score: $_score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Nivel: $_level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Indicador del Estado del Catcher
          Positioned(
            right: 20,
            top: 40,
            child: Text(
              _catcherState == CatcherState.catching
                  ? 'Atrapar'
                  : _catcherState == CatcherState.locked
                      ? 'Bloqueado'
                      : 'Normal',
              style: TextStyle(
                color: _catcherState == CatcherState.catching
                    ? Colors.green
                    : _catcherState == CatcherState.locked
                        ? Colors.orange
                        : Colors.grey,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Contador
          if (_isCountingDown)
            Center(
              child: Text(
                '$_countdown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          // Pantalla de Game Over
          if (_isGameOver)
            Center(
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '¡Game Over!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tu Puntaje: $_score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _restartGame,
                      child: Text('Reiniciar'),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        textStyle: TextStyle(fontSize: 20),
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

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _catcherTimer?.cancel();
    _magnetometerSubscription?.cancel();
    super.dispose();
  }
}
