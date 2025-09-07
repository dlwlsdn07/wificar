import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini ESP Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: const IpInputScreen(),
    );
  }
}

// IP 주소 입력 화면
class IpInputScreen extends StatefulWidget {
  const IpInputScreen({super.key});

  @override
  State<IpInputScreen> createState() => _IpInputScreenState();
}

class _IpInputScreenState extends State<IpInputScreen> {
  final TextEditingController _ipController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _connect() {
    if (_ipController.text.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ControlScreen(ipAddress: _ipController.text),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IP 주소를 입력해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32-CAM 연결'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'ESP32 IP 주소',
                  hintText: '예: 192.168.1.10',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _connect,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('연결'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// RC카 조종 및 비디오 스트리밍 화면
class ControlScreen extends StatefulWidget {
  final String ipAddress;

  const ControlScreen({super.key, required this.ipAddress});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  bool isLedOn = false;
  bool isStreaming = true; // 스트리밍 상태를 제어하는 변수

  Future<void> _sendCommand(String command) async {
    try {
      final url = Uri.parse('http://${widget.ipAddress}/action?go=$command');
      await http.get(url).timeout(const Duration(seconds: 1));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('명령 전송 실패: $e')),
        );
      }
    }
  }

  void _toggleLed() {
    setState(() {
      isLedOn = !isLedOn;
    });
    _sendCommand(isLedOn ? 'led_on' : 'led_off');
  }

  void _toggleStreaming() {
    setState(() {
      isStreaming = !isStreaming;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('조종 화면: ${widget.ipAddress}'),
        actions: [
          // 스트리밍 제어 버튼
          IconButton(
            icon: Icon(isStreaming ? Icons.videocam_off : Icons.videocam),
            onPressed: _toggleStreaming,
            tooltip: isStreaming ? '스트리밍 중지' : '스트리밍 시작',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 비디오 스트리밍 배경
          Center(
            child: Mjpeg(
              stream: 'http://${widget.ipAddress}:81/stream',
              isLive: isStreaming, // 상태 변수와 연결
              error: (context, error, stack) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('비디오 스트림 오류', style: TextStyle(color: Colors.white)),
                      Text('$error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _toggleStreaming,
                        child: const Text('다시 시도'),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
          // 조종 버튼 UI
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20.0),
              color: Colors.black.withOpacity(0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 64),
                      ControlButton(
                        icon: Icons.arrow_upward,
                        command: 'forward',
                        onCommand: _sendCommand,
                      ),
                      ControlButton(
                        icon: isLedOn ? Icons.lightbulb : Icons.lightbulb_outline,
                        onPress: _toggleLed,
                        color: isLedOn ? Colors.yellow : Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ControlButton(
                        icon: Icons.arrow_back,
                        command: 'left',
                        onCommand: _sendCommand,
                      ),
                      ControlButton(
                        icon: Icons.stop_circle_outlined,
                        command: 'stop',
                        onCommand: _sendCommand,
                      ),
                      ControlButton(
                        icon: Icons.arrow_forward,
                        command: 'right',
                        onCommand: _sendCommand,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                       ControlButton(
                        icon: Icons.remove,
                        command: 'minus',
                        onCommand: _sendCommand,
                      ),
                      ControlButton(
                        icon: Icons.arrow_downward,
                        command: 'backward',
                        onCommand: _sendCommand,
                      ),
                       ControlButton(
                        icon: Icons.add,
                        command: 'plus',
                        onCommand: _sendCommand,
                      ),
                    ],
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

// 조종 버튼 위젯
class ControlButton extends StatelessWidget {
  final IconData icon;
  final String? command;
  final Function(String)? onCommand;
  final VoidCallback? onPress;
  final Color? color;

  const ControlButton({
    super.key,
    required this.icon,
    this.command,
    this.onCommand,
    this.onPress,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onPress != null) {
          onPress!();
        }
      },
      onLongPressStart: (_) {
        if (command != null && onCommand != null) {
          onCommand!(command!);
        }
      },
      onLongPressEnd: (_) {
        if (command != null && onCommand != null) {
          if (['forward', 'backward', 'left', 'right'].contains(command)) {
             onCommand!('stop');
          }
        }
      },
      child: CircleAvatar(
        radius: 30,
        backgroundColor: Colors.white.withOpacity(0.3),
        child: Icon(icon, size: 30, color: color ?? Colors.white),
      ),
    );
  }
}