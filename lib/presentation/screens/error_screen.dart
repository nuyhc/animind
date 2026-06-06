import 'package:flutter/material.dart';

/// 오류 상태 화면
///
/// 감정 분류 처리 중 오류가 발생했을 때 표시되는 화면.
/// 오류 메시지와 함께 재시도 및 메인 복귀 버튼을 제공한다.
///
/// Requirements: 3.6, 4.7
class ErrorScreen extends StatelessWidget {
  /// 표시할 오류 메시지
  final String errorMessage;

  /// 재시도 버튼 콜백
  final VoidCallback? onRetry;

  /// 메인 화면 복귀 버튼 콜백
  final VoidCallback? onGoHome;

  const ErrorScreen({
    super.key,
    required this.errorMessage,
    this.onRetry,
    this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('오류'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 오류 아이콘
                Icon(
                  Icons.error_outline,
                  size: 72,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 24),

                // 오류 메시지
                Text(
                  errorMessage,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // 재시도 버튼 (최소 터치 영역 44x44dp)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('재시도'),
                  ),
                ),
                const SizedBox(height: 16),

                // 메인으로 버튼 (최소 터치 영역 44x44dp)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: onGoHome,
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('메인으로'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
