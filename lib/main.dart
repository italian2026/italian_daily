import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Italian Daily',
      home: const TtsPage(),
    );
  }
}

class TtsPage extends StatefulWidget {
  const TtsPage({super.key});

  @override
  State<TtsPage> createState() => _TtsPageState();
}

class _TtsPageState extends State<TtsPage> {
  final FlutterTts tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    tts.setLanguage("it-IT");
    tts.setSpeechRate(0.45);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('意大利语每日一句')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Buongiorno!', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('早上好！', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => tts.speak("Buongiorno!"),
              icon: const Icon(Icons.volume_up),
              label: const Text('播放范读'),
            ),
          ],
        ),
      ),
    );
  }
}
