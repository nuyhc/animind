import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animind/presentation/screens/main_screen.dart';

void main() {
  // 플랫폼 채널/위젯 바인딩을 보장한다.
  // MemoryMonitorImpl 등이 WidgetsBinding에 의존하므로 runApp 이전에 필요하다.
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter 프레임워크 내부에서 발생한 오류를 처리한다.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    // TODO: 크래시 리포팅 서비스 연동 (예: Firebase Crashlytics)
  };

  // 프레임워크가 잡지 못한 비동기/플랫폼 오류를 처리한다.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught platform error: $error');
    // TODO: 크래시 리포팅 서비스 연동
    return true;
  };

  // 위젯 빌드 오류 시 사용자 친화적인 대체 화면을 표시한다.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _AppErrorWidget(details: details);
  };

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
      home: const MainScreen(),
    );
  }
}

/// 위젯 빌드 오류 발생 시 표시되는 대체 위젯
///
/// 디버그 빌드에서는 상세 정보를, 릴리스 빌드에서는 간단한 안내만 표시한다.
class _AppErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;

  const _AppErrorWidget({required this.details});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFFFDEDED),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFB3261E)),
            const SizedBox(height: 16),
            const Text(
              '화면을 표시하는 중 문제가 발생했어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF410E0B),
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF410E0B)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
