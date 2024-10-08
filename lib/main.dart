import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';

enum CatcherState { ready, catching, locked }

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Juego de Captura Espacial',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Orbitron',
      ),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Posición del objeto que cae
  double _fallingObjectX = 0.0;
  double _fallingObjectY = 0.0;
  double _speed = 0.0;

  // Tamaño del objeto que cae
  double _fallingObjectWidth = 20.0;
  double _fallingObjectHeight = 100.0;

  // Tamaño del catcher
  final double _catcherWidth = 100.0;
  final double _catcherHeight = 100.0;

  // Posición del catcher
  double _catcherX = 0.0;
  double _catcherY = 10.0;

  // Estado del catcher
  CatcherState _catcherState = CatcherState.ready;
  Timer? _catcherTimer; // Temporizador para el estado de atrapar

  bool _isGameOver = false;
  bool _stop = false;
  int _score = 0;
  int _level = 1;

  Timer? _timer;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  // Variables de pantalla
  double _screenWidth = 0.0;
  double _screenHeight = 0.0;

  // Variables para el contador
  int _countdown = 3; // Contador inicial en segundos
  int _countDelay = 3; // Contador delay en segundos
  bool _isCountingDown = true; // Indica si el contador está activo
  Timer? _countdownTimer; // Temporizador para el contador
  Timer? _delayGame; // Temporizador para el delay

  // Factor de escala para la imagen mano_abierta.png
  final double _openHandScale = 1.2; // Ajusta este valor según sea necesario

  String _messageWin = 'WIN';
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    _listenToMagnetometer();

    // Inicializar la animación del fondo
    _backgroundController = AnimationController(
      duration: const Duration(minutes: 2),
      vsync: this,
    )..repeat();
    _backgroundAnimation =
        Tween<double>(begin: 0, end: 1).animate(_backgroundController);
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

  // Método para generar una posición X aleatoria para el objeto que cae
  void _randomizeFallingObjectPosition() {
    setState(() {
      _fallingObjectX =
          Random().nextDouble() * (_screenWidth - _fallingObjectWidth);
    });
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
      _stop = false;
      _speed = 0.0;
      _messageWin = 'WIN';
    });

    // Iniciar el contador
    _startCountdown();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!_isCountingDown && !_isGameOver) {
        setState(() {
          // Aumentar la velocidad de caída con cada nivel
          double fallingSpeed = 20.0 + (_level - 1) * 0.5 + _speed;
          !_stop ? _fallingObjectY += fallingSpeed : null;

          // Verificar colisión
          if (_checkCollision() && !_stop) {
            // Aumentar los puntos2
            _score++;
            // Aumentar la velocidad de cañada con cada punto
            _speed += 2.0;
            _delay();
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

  void _delay() {
    _delayGame?.cancel();
    _countDelay = 3;
    _stop = true;
    _delayGame = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countDelay > 1) {
        setState(() {
          _countDelay--;
        });
      } else {
        setState(() {
          _countDelay = 0;
          // Cambiar el mensaje
          _score == 8 ? _messageWin = '!WIN THIS GAME!' : null;
          // Incrementar nivel cada 5 puntos
          if (_score % 3 == 0) {
            _level++;
            // Reducir el tamaño del objeto que cae
            _fallingObjectHeight = (_fallingObjectHeight * 0.75);
          }
        });
        _resetFallingObject();
        _delayGame?.cancel();
      }
      if (kDebugMode) {
        print(_countDelay);
      }
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = 3;
    _isCountingDown = true;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
      _stop = false;
      _isCountingDown = true;
      _countdown = 3;
      _fallingObjectY = 0.0;
      _fallingObjectX = (_screenWidth - _fallingObjectWidth) / 2;
    });
    _randomizeFallingObjectPosition();
    _startCountdown();
  }

  bool _checkCollision() {
    // Centros del objeto que cae
    double fallingCenterX = _fallingObjectX + _fallingObjectWidth / 2;
    double fallingCenterY = _fallingObjectY + _fallingObjectHeight / 2;
    double fallingRadius = min(_fallingObjectWidth, _fallingObjectHeight) / 2;

    // Centros del catcher
    double catcherCenterX = _catcherX + _catcherWidth / 2;
    double catcherCenterY = _catcherY + _catcherHeight / 2;
    double catcherRadius = min(_catcherWidth, _catcherHeight) / 2;

    // Calcular la distancia entre los centros
    double distance = sqrt(pow(fallingCenterX - catcherCenterX, 2) +
        pow(fallingCenterY - catcherCenterY, 2));

    // Verificar si la distancia es menor o igual a la suma de los radios
    bool collision = distance <= (fallingRadius + catcherRadius) &&
        _catcherState == CatcherState.catching;

    if (collision) {
      if (kDebugMode) {
        print('¡Objeto atrapado!');
      }
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
        _catcherTimer = Timer(const Duration(seconds: 1), () {
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

  void _moveCatcher(Offset position) {
    setState(() {
      // Actualizar la posición X del catcher, manteniendo los límites de la pantalla
      _catcherX = (position.dx - _catcherWidth / 2)
          .clamp(0, _screenWidth - _catcherWidth);
      // La posición Y del catcher no cambia
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onPanUpdate: (details) {
          _moveCatcher(details.localPosition);
        },
        onTapDown: (details) {
          _moveCatcher(details.localPosition);
        },
        child: AnimatedBuilder(
          animation: _backgroundAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    HSVColor.fromAHSV(
                            1, _backgroundAnimation.value * 360, 0.8, 0.8)
                        .toColor(),
                    HSVColor.fromAHSV(
                            1,
                            (_backgroundAnimation.value * 360 + 180) % 360,
                            0.8,
                            0.8)
                        .toColor(),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Estrellas de fondo
                  ...List.generate(50, (index) {
                    return Positioned(
                      left: Random().nextDouble() *
                          MediaQuery.of(context).size.width,
                      top: Random().nextDouble() *
                          MediaQuery.of(context).size.height,
                      child:
                          const Icon(Icons.star, color: Colors.white, size: 10),
                    );
                  }),

                  // El Catcher (nave espacial) y el objeto que cae (meteorito)
                  Positioned.fill(
                    child: Stack(
                      children: [
                        if (_catcherState == CatcherState.catching || _stop)
                          Positioned(
                            left: _catcherX,
                            top: _catcherY,
                            child: Image.asset(
                              'assets/images/mano_cerrada.png',
                              width: _catcherWidth,
                              height: _catcherHeight,
                            ),
                          ),
                        Positioned(
                          left: _fallingObjectX,
                          top: _fallingObjectY,
                          child: Container(
                            width: _fallingObjectWidth,
                            height: _fallingObjectHeight,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.yellowAccent.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_catcherState == CatcherState.catching || _stop)
                          Positioned(
                            left: _catcherX,
                            top: _catcherY,
                            child: Image.asset(
                              'assets/images/mano_cerrada_capa.png',
                              width: _catcherWidth,
                              height: _catcherHeight,
                            ),
                          ),
                        if (_catcherState != CatcherState.catching && !_stop)
                          Positioned(
                            left: _catcherX,
                            top: _catcherY,
                            child: Transform.scale(
                              scale: _openHandScale,
                              child: Image.asset(
                                'assets/images/mano_abierta.png',
                                width: _catcherWidth,
                                height: _catcherHeight,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Panel de información
                  Positioned(
                    left: 20,
                    top: 40,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Score: $_score',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Nivel: $_level',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Indicador del Estado del Catcher
                  Positioned(
                    right: 20,
                    top: 40,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _catcherState == CatcherState.catching
                            ? 'Capturando'
                            : _catcherState == CatcherState.locked
                                ? 'Cargando'
                                : 'Listo',
                        style: TextStyle(
                          color: _catcherState == CatcherState.catching
                              ? Colors.green
                              : _catcherState == CatcherState.locked
                                  ? Colors.orange
                                  : Colors.blue,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Mostrar "Win" si el objeto ha sido atrapado
                  if (_stop)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _messageWin,
                          style: const TextStyle(
                            color: Color.fromARGB(237, 255, 201, 52),
                            fontSize: 50,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // Contador
                  if (_isCountingDown)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_countdown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Pantalla de Game Over
                  if (_isGameOver)
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '¡Game Over!',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Tu Puntaje: $_score',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                              ),
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              onPressed: _restartGame,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 15,
                                ),
                                textStyle: const TextStyle(fontSize: 24),
                                backgroundColor:
                                    const Color.fromARGB(118, 101, 12, 10),
                              ),
                              child: const Text(
                                'Reiniciar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Orbitron',
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
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _catcherTimer?.cancel();
    _magnetometerSubscription?.cancel();
    _backgroundController.dispose();
    super.dispose();
  }
}
