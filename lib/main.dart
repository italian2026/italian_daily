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
  bool _loading = false;
  String? _recordPath;
  
  // 评测结果相关
  int? _score;
  List<dynamic> _wordResults = [];
  List<dynamic> _tips = [];
  String? _errorMsg;

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
      debugPrint('TTS error: $e');
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
      });
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有麦克风权限')));
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
      _score = null;
      _wordResults.clear();
      _tips.clear();
      _errorMsg = null;
    });
  }

  Future<void> _uploadAndEvaluate() async {
    if (_recordPath == null) return;

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final bytes = await File(_recordPath!).readAsBytes();
    final body = jsonEncode({
      'text': _today,
      'language': 'it-IT',
      'audio_base64': base64Encode(bytes),
    });

    try {
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

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          _score = data['score'];
          _wordResults = data['words'] ?? [];
          _tips = data['tips'] ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _errorMsg = '服务器返回错误: ${resp.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = '网络错误: $e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _tts.stop();
    super.dispose();
  }

  Widget _buildResultArea() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMsg != null) {
      return Text(_errorMsg!, style: const TextStyle(color: Colors.red));
    }
    if (_score == null) {
      return const Text('请先录音，然后点击“评测发音”', style: TextStyle(color: Colors.grey));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('发音得分', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                '$_score 分',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _score! >= 80 ? Colors.green : (_score! >= 60 ? Colors.orange : Colors.red),
                ),
              ),
            ],
          ),
          const Divider(),
          if (_wordResults.isNotEmpty) ...[
            const Text('逐词分析:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _wordResults.map((w) {
                final bool ok = w['ok'] ?? true;
                return Chip(
                  label: Text(w['word'] ?? ''),
                  backgroundColor: ok ? Colors.green[100] : Colors.red[100],
                  labelStyle: TextStyle(color: ok ? Colors.green[800] : Colors.red[800]),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (_tips.isNotEmpty) ...[
            const Text('改进建议:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Expanded(child: Text(tip, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                )),
          ]
        ],
      ),
    );
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
            Text(
              _today,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _speak,
                  icon: const Icon(Icons.volume_up),
                  label: const Text('听范读'),
                ),
                ElevatedButton.icon(
                  onPressed: _toggleRecord,
                  icon: Icon(_recording ? Icons.stop : Icons.mic),
                  label: Text(_recording ? '停止' : '录音'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _recording ? Colors.red[100] : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _recordPath != null && !_recording && !_loading ? _uploadAndEvaluate : null,
              child: const Text('获取发音评测'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: _buildResultArea(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
