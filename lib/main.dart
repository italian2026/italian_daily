import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Italian Daily',
      home: Scaffold(
        appBar: AppBar(title: const Text('意大利语每日一句')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Buongiorno!', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('早上好！', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}
