import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// 部署 Worker 后回来替换这个地址
const String workerUrl = 'https://REPLACE-ME.workers.dev';
// 第一轮先保持 change-me，和 Worker 默认值一致
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
  String _result = '等待录音';

  final List<Map<String, String>> _sentences = [
    {'it': 'Chi va piano va sano e va lontano.', 'zh': '慢走走得稳，走得远。'},
    {'it': 'Meglio tardi che mai.', 'zh': '迟做总比不做好。'},
    {'it': 'Buongiorno!', 'zh': '早上好！'},
    {'it': 'In bocca al lupo!', 'zh': '祝你好运！'},
    {'it': 'Mamma mia!', 'zh': '我的天哪！'},
  ];

  Map<String, String> get _today {
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
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
    } catch (e) {
      setState(() => _result = 'TTS 初始化失败：$e');
    }
  }

  Future<void> _speak() async {
    await _tts.stop();
    await _tts.speak(_today['it']!);
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() {
        _recording = false;
        _recordPath = path;
        _result = path == null ? '录音失败' : '录音完成，点“上传评测”';
      });
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      setState(() => _result = '没有麦克风权限，请到设置里允许录音');
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
      _result = '录音中……再点一次停止';
    });
  }

  Future<void> _upload() async {
    if (_recordPath == null) {
      setState(() => _result = '还没有录音');
      return;
    }

    final bytes = await File(_recordPath!).readAsBytes();
    final body = jsonEncode({
      'text': _today['it'],
      'language': 'it-IT',
      'audio_base64': base64Encode(bytes),
    });

    try {
      setState(() => _result = '上传中……');
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
      setState(() => _result = '上传失败：$e');
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
              _today['it']!,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _today['zh']!,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _speak,
              icon: const Icon(Icons.volume_up),
              label: const Text('播放意大利语范读'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _toggleRecord,
              icon: Icon(_recording ? Icons.stop : Icons.mic),
              label: Text(_recording ? '停止录音' : '开始录音'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _upload,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('上传评测'),
            ),
            const SizedBox(height: 24),
            const Text('结果：', style: TextStyle(fontWeight: FontWeight.bold)),
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
