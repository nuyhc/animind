import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: AnimindApp()));
}

/// 동물 감정 인식 앱의 루트 위젯
class AnimindApp extends StatelessWidget {
  const AnimindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Animind - 동물 감정 인식',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Animind - 동물 감정 인식'),
        ),
      ),
    );
  }
}
