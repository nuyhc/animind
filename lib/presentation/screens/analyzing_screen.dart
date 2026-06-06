import 'dart:io';

import 'package:flutter/material.dart';

/// 감정 분석 진행 중 상태를 표시하는 화면
///
/// 입력 이미지 미리보기, 로딩 인디케이터, 진행 중 문구를 표시한다.
/// [imageFile]은 사용자가 선택하거나 촬영한 이미지 파일이다.
///
/// 접근성 준수 사항:
/// - 이미지에 스크린 리더용 Semantics 라벨 제공
/// - Material Design 3 ColorScheme으로 WCAG AA 명도 대비 보장
/// - theme.textTheme 사용으로 시스템 글자 크기 확대 대응
class AnalyzingScreen extends StatelessWidget {
  /// 분석할 이미지 파일
  final File imageFile;

  const AnalyzingScreen({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 입력 이미지 미리보기
                _buildImagePreview(colorScheme),
                const SizedBox(height: 40),

                // 로딩 인디케이터
                CircularProgressIndicator(
                  color: colorScheme.primary,
                  strokeWidth: 3.0,
                ),
                const SizedBox(height: 24),

                // 진행 중 문구
                Text(
                  '감정을 분석하고 있어요...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  semanticsLabel: '감정 분석 진행 중',
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
                const SizedBox(height: 8),

                // 보조 안내 문구
                Text(
                  '잠시만 기다려 주세요',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 입력 이미지를 둥근 모서리 카드 형태로 미리보기 표시
  Widget _buildImagePreview(ColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Semantics(
          label: '분석 중인 이미지 미리보기',
          child: Image.file(
            imageFile,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // 이미지 로딩 실패 시 대체 아이콘 표시
              return Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: 48,
                  color: colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
