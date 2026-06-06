import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// 권한 안내 화면
///
/// 카메라/갤러리 접근 권한이 거부되었을 때 표시되는 화면.
/// 권한 필요 안내 메시지와 설정 이동 버튼, 메인 복귀 버튼을 제공한다.
///
/// Requirements: 4.8
class PermissionScreen extends StatelessWidget {
  /// 메인 화면 복귀 버튼 콜백
  final VoidCallback? onGoHome;

  const PermissionScreen({
    super.key,
    this.onGoHome,
  });

  /// 기기의 앱 설정 화면을 연다
  Future<void> _openSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('권한 필요'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 권한 아이콘
                Icon(
                  Icons.lock_outline,
                  size: 72,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 24),

                // 권한 필요 메시지
                Text(
                  '카메라/갤러리 사용을 위해\n권한이 필요합니다',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // 안내 부가 설명
                Text(
                  '설정에서 카메라 및 사진 접근 권한을\n허용해주세요.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // 설정 열기 버튼 (최소 터치 영역 44x44dp)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings),
                    label: const Text('설정 열기'),
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
