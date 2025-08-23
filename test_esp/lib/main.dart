import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart'; // kIsWeb 사용을 위해 추가
import 'package:flutter/services.dart'; // RawKeyDownEvent와 RawKeyUpEvent 사용을 위해 추가

const String esp32Ip = "여기에_IP_입력"; // ESP32의 IP 주소

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ControlScreen(),
    );
  }
}

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  _ControlScreenState createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  double _handleHorizontalPosition = 0; // 핸들의 수평 위치
  String _lastCommand = ""; // 마지막으로 보낸 명령
  Timer? _commandTimer; // 버튼 명령 타이머
  final Set<String> _pressedKeys = HashSet(); // 현재 눌린 키들

  // 명령 전송 함수
  Future<void> _sendCommand(String command) async {
    if (_lastCommand == command) return; // 동일한 명령은 무시
    _lastCommand = command;
    try {
      await http.get(Uri.parse('http://$esp32Ip:80/action?go=$command')).timeout(const Duration(seconds: 1));
    } catch (e) {
      print("명령 전송 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 배경: MJPEG 비디오 스트림
          Positioned.fill(
            child: Image.network(
              'http://$esp32Ip:81/stream',
              gaplessPlayback: true,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Text(
                    '스트림 연결 실패',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ),
          // 전경: 제어 UI
          SafeArea(
            child: Stack(
              children: [
                // 스티어링 핸들
                Positioned(
                  left: 20,
                  bottom: 20,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _handleHorizontalPosition += details.delta.dx;
                        _handleHorizontalPosition = _handleHorizontalPosition.clamp(-50, 50);
                        if (_handleHorizontalPosition > 0) {
                          _sendCommand("right");
                        } else if (_handleHorizontalPosition < 0) {
                          _sendCommand("left");
                        }
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      setState(() {
                        _handleHorizontalPosition = 0;
                        _sendCommand("stop");
                      });
                    },
                    child: Transform.translate(
                      offset: Offset(_handleHorizontalPosition, 0),
                      child: Image.asset('assets/images/handle.png', width: 100),
                    ),
                  ),
                ),
                // 전진/후진 버튼
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTapDown: (_) {
                          _commandTimer = Timer.periodic(const Duration(milliseconds: 100), (_) => _sendCommand("forward"));
                        },
                        onTapUp: (_) {
                          _commandTimer?.cancel();
                          _sendCommand("stop");
                        },
                        onTapCancel: () {
                          _commandTimer?.cancel();
                          _sendCommand("stop");
                        },
                        child: Image.asset('assets/images/accel.png', width: 80),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTapDown: (_) {
                          _commandTimer = Timer.periodic(const Duration(milliseconds: 100), (_) => _sendCommand("backward"));
                        },
                        onTapUp: (_) {
                          _commandTimer?.cancel();
                          _sendCommand("stop");
                        },
                        onTapCancel: () {
                          _commandTimer?.cancel();
                          _sendCommand("stop");
                        },
                        child: Image.asset('assets/images/brake.png', width: 80),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 키보드 제어 (웹 환경 전용)
          if (kIsWeb)
            KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is RawKeyDownEvent) {
                  _pressedKeys.add(event.logicalKey.keyLabel);
                } else if (event is RawKeyUpEvent) {
                  _pressedKeys.remove(event.logicalKey.keyLabel);
                }

                if (_pressedKeys.contains("w") || _pressedKeys.contains("ArrowUp")) {
                  _sendCommand("forward");
                } else if (_pressedKeys.contains("s") || _pressedKeys.contains("ArrowDown")) {
                  _sendCommand("backward");
                } else if (_pressedKeys.contains("a") || _pressedKeys.contains("ArrowLeft")) {
                  _sendCommand("left");
                } else if (_pressedKeys.contains("d") || _pressedKeys.contains("ArrowRight")) {
                  _sendCommand("right");
                } else {
                  _sendCommand("stop");
                }
              },
              child: Container(), // child 추가
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commandTimer?.cancel();
    super.dispose();
  }
}
