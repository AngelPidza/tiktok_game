import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Juego de Captura',
      home: GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Posición del objeto que cae
  double _fallingObjectX = 0.0;
  double _fallingObjectY = 0.0;
  // Tamaño del objeto que cae
  final double _fallingObjectSize = 20.0;

  // Posición del catcher (objeto que atrapa)
  double _catcherX = 0.0;
  double _catcherY = 0.0;
  // Tamaño del catcher
  final double _catcherWidth = 50.0;
  final double _catcherHeight = 20.0;

  bool _isGameOver = false;
  int _score = 0;

  Timer? _timer;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // Variables de pantalla
  double _screenWidth = 0.0;
  double _screenHeight = 0.0;

  @override
  void initState() {
    super.initState();
    // Iniciar la escucha del acelerómetro
    _listenToAccelerometer();
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
      _catcherY = _screenHeight - 100; // 100 píxeles desde el fondo

      // Posicionar el objeto que cae al centro superior
      _fallingObjectX = (_screenWidth - _fallingObjectSize) / 2;
      _fallingObjectY = 0.0;

      // Iniciar el juego
      _startGame();
    }
  }

  void _startGame() {
    setState(() {
      _isGameOver = false;
      _score = 0;
      _fallingObjectY = 0.0;
      _fallingObjectX = (_screenWidth - _fallingObjectSize) / 2;
      _catcherX = (_screenWidth - _catcherWidth) / 2;
    });

    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      setState(() {
        // Actualizar la posición del objeto que cae
        _fallingObjectY += 4.0; // Velocidad de caída

        // Verificar colisión
        if (_checkCollision()) {
          _score++;
          _resetFallingObject();
        }

        // Verificar si el objeto ha caído fuera de la pantalla
        if (_fallingObjectY > _screenHeight) {
          _isGameOver = true;
          _timer?.cancel();
        }
      });
    });
  }

  void _resetFallingObject() {
    _fallingObjectY = 0.0;
    _fallingObjectX = (_screenWidth - _fallingObjectSize) / 2;
  }

  bool _checkCollision() {
    // Coordenadas del objeto que cae
    double fallingLeft = _fallingObjectX;
    double fallingRight = _fallingObjectX + _fallingObjectSize;
    double fallingTop = _fallingObjectY;
    double fallingBottom = _fallingObjectY + _fallingObjectSize;

    // Coordenadas del catcher
    double catcherLeft = _catcherX;
    double catcherRight = _catcherX + _catcherWidth;
    double catcherTop = _catcherY;
    double catcherBottom = _catcherY + _catcherHeight;

    // Verificar si hay intersección
    bool overlapX = fallingRight >= catcherLeft && fallingLeft <= catcherRight;
    bool overlapY = fallingBottom >= catcherTop && fallingTop <= catcherBottom;

    return overlapX && overlapY;
  }

  void _listenToAccelerometer() {
    _accelerometerSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        // Ajustar la posición del catcher basado en la inclinación
        // Puedes ajustar la sensibilidad multiplicando/dividiendo el valor
        _catcherX += event.x * 10;

        // Limitar la posición del catcher dentro de la pantalla
        _catcherX = _catcherX.clamp(0.0, _screenWidth - _catcherWidth);
      });
    });
  }

  void _restartGame() {
    setState(() {
      _score = 0;
      _isGameOver = false;
      _fallingObjectY = 0.0;
      _fallingObjectX = (_screenWidth - _fallingObjectSize) / 2;
      _catcherX = (_screenWidth - _catcherWidth) / 2;
    });

    _timer?.cancel();
    _startGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Objeto que cae
          Positioned(
            left: _fallingObjectX,
            top: _fallingObjectY,
            child: Container(
              width: _fallingObjectSize,
              height: _fallingObjectSize,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
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
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Puntuación
          Positioned(
            left: 20,
            top: 40,
            child: Text(
              'Score: $_score',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Pantalla de Game Over
          if (_isGameOver)
            Center(
              child: Container(
                color: Colors.black54,
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '¡Game Over!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Tu Puntaje: $_score',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                      ),
                    ),
                    SizedBox(height: 30),
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
    _accelerometerSubscription?.cancel();
    super.dispose();
  }
}
