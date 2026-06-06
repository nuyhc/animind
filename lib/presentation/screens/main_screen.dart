import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animind/presentation/providers/memory_warning_provider.dart';

/// 메인 화면
///
/// 카메라 촬영, 갤러리 선택, 이력 진입 버튼을 제공하고,
/// 지원 입력 조건(JPG/PNG, 10MB 이하, 최소 50x50, 반려동물 표정 권장)을 안내한다.
///
/// 메모리 경고 발생 시 캐시 정리 알림 SnackBar를 표시한다.
///
/// 접근성 준수 사항:
/// - 모든 주요 버튼의 터치 영역은 최소 44x44dp 이상
/// - Material Design 3 ColorScheme으로 WCAG AA 명도 대비 보장
/// - theme.textTheme 사용으로 시스템 글자 크기 확대 대응
/// - 스크린 리더용 Semantics 라벨 제공
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 메모리 경고 상태를 감시하여 SnackBar 표시
    ref.listen<MemoryWarningState>(memoryWarningProvider, (previous, next) {
      _showMemoryWarningSnackBar(next);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Animind'),
        centerTitle: true,
        actions: [
          // 이력 진입 버튼 (최소 44x44dp 터치 영역)
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '분석 이력',
            onPressed: () {
              // TODO: 이력 화면으로 이동
            },
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // 앱 소개 영역
              Semantics(
                label: '반려동물 감정 분석 앱 아이콘',
                excludeSemantics: true,
                child: Icon(
                  Icons.pets,
                  size: 64,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '반려동물 감정 분석',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
              const SizedBox(height: 8),
              Text(
                '사진을 촬영하거나 선택하여\n반려동물의 감정을 알아보세요',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
              const Spacer(flex: 2),
              // 카메라 촬영 버튼 (최소 44x44dp 터치 영역)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () {
                    // TODO: 카메라 촬영 실행
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('카메라로 촬영하기'),
                ),
              ),
              const SizedBox(height: 12),
              // 갤러리 선택 버튼 (최소 44x44dp 터치 영역)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: 갤러리 선택 실행
                  },
                  icon: const Icon(Icons.photo_library),
                  label: const Text('갤러리에서 선택하기'),
                ),
              ),
              const SizedBox(height: 16),
              // 이력 보기 버튼 (최소 44x44dp 터치 영역)
              SizedBox(
                height: 48,
                child: TextButton.icon(
                  onPressed: () {
                    // TODO: 이력 화면으로 이동
                  },
                  icon: const Icon(Icons.history, size: 20),
                  label: const Text('분석 이력 보기'),
                ),
              ),
              const Spacer(flex: 1),
              // 지원 입력 조건 안내
              const _InputConditionsNotice(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// 메모리 경고 상태에 따라 SnackBar를 표시한다
  void _showMemoryWarningSnackBar(MemoryWarningState state) {
    if (state is MemoryWarningCacheCleared) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('캐시가 정리되었습니다'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '확인',
            onPressed: () {
              ref.read(memoryWarningProvider.notifier).acknowledge();
            },
          ),
        ),
      );
      // 알림 표시 후 상태 초기화
      ref.read(memoryWarningProvider.notifier).acknowledge();
    } else if (state is MemoryWarningInsufficient) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('메모리 부족으로 분석을 수행할 수 없습니다'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: '확인',
            textColor: Theme.of(context).colorScheme.onError,
            onPressed: () {
              ref.read(memoryWarningProvider.notifier).acknowledge();
            },
          ),
        ),
      );
      ref.read(memoryWarningProvider.notifier).acknowledge();
    }
  }
}

/// 지원 입력 조건 안내 위젯
///
/// JPG/PNG, 10MB 이하, 최소 50x50, 반려동물 표정 이미지 권장을 안내한다.
class _InputConditionsNotice extends StatelessWidget {
  const _InputConditionsNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: '입력 조건 안내: 지원 형식 JPG, PNG, 파일 크기 10MB 이하, '
          '최소 해상도 50×50 픽셀, 반려동물 표정이 잘 보이는 사진 권장',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '입력 조건 안내',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.visible,
                    softWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• 지원 형식: JPG, PNG\n'
              '• 파일 크기: 10MB 이하\n'
              '• 최소 해상도: 50×50 픽셀\n'
              '• 반려동물 표정이 잘 보이는 사진을 권장합니다',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }
}
