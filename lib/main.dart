import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

const String workerUrl = 'https://REPLACE-ME.workers.dev';
const String appToken = 'change-me';

void main() => runApp(const ItalianDailyApp());

class ItalianDailyApp extends StatelessWidget {
  const ItalianDailyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Italian Daily',
      home: PracticePage(),
    );
  }
}

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _recorder = AudioRecorder();

  bool _recording = false;
  String? _recordPath;
  String _result = 'Waiting for record...';

  final List<String> _sentences = [
    'Chi va piano va sano e va lontano.',
    'Meglio tardi che mai.',
    'Buongiorno!',
    'In bocca al lupo!',
    'Mamma mia!',
  ];

  String get _today {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final index = now.difference(start).inDays % _sentences.length;
    return _sentences[index];
  }

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('it-IT');
      await _tts.setSpeechRate(0.45);
    } catch (e) {
      setState(() => _result = 'TTS error: $e');
    }
  }

  Future<void> _speak() async {
    await _tts.stop();
    await _tts.speak(_today);
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() {
        _recording = false;
        _recordPath = path;
        _result = path == null ? 'Record failed' : 'Record done. Tap Upload.';
      });
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      setState(() => _result = 'No microphone permission.');
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/record_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    setState(() {
      _recording = true;
      _result = 'Recording... Tap stop.';
    });
  }

  Future<void> _upload() async {
    if (_recordPath == null) {
      setState(() => _result = 'No record found.');
      return;
    }

    final bytes = await File(_recordPath!).readAsBytes();
    final body = jsonEncode({
      'text': _today,
      'language': 'it-IT',
      'audio_base64': base64Encode(bytes),
    });

    try {
      setState(() => _result = 'Uploading...');
      final resp = await http
          .post(
            Uri.parse(workerUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $appToken',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      setState(() => _result = 'HTTP ${resp.statusCode}\n\n${resp.body}');
    } catch (e) {
      setState(() => _result = 'Upload failed: $e');
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Italian Daily')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(
              _today,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _speak,
              icon: const Icon(Icons.volume_up),
              label: const Text('Play Audio'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _toggleRecord,
              icon: Icon(_recording ? Icons.stop : Icons.mic),
              label: Text(_recording ? 'Stop Record' : 'Start Record'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _upload,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload'),
            ),
            const SizedBox(height: 24),
            const Text('Result:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(child: Text(_result)),
            ),
          ],
        ),
      ),
    );
  }
}
