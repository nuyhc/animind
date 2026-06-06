import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/models/emotion_category.dart';
import '../../domain/models/formatted_result.dart';

/// 일반 결과 화면
///
/// 분석이 완료되고 최상위 신뢰도가 50% 이상인 경우 표시되는 화면.
/// 입력 이미지, 감정 이모지, 감정 카테고리, 정수 신뢰도, 한국어 결과 문장을 표시한다.
/// 하단에 "다시 분석하기", "이력 보기" 버튼을 제공한다.
///
/// 접근성 준수 사항:
/// - 모든 이미지/이모지에 스크린 리더용 Semantics 라벨 제공
/// - Material Design 3 ColorScheme으로 WCAG AA 명도 대비 보장
/// - theme.textTheme 사용으로 시스템 글자 크기 확대 대응
/// - 주요 버튼의 터치 영역 최소 44x44dp 이상
class ResultScreen extends StatelessWidget {
  /// 분석에 사용된 입력 이미지 파일
  final File imageFile;

  /// 포맷된 분석 결과
  final FormattedResult result;

  /// 다시 분석하기 콜백
  final VoidCallback? onAnalyzeAgain;

  /// 이력 보기 콜백
  final VoidCallback? onViewHistory;

  const ResultScreen({
    super.key,
    required this.imageFile,
    required this.result,
    this.onAnalyzeAgain,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('분석 결과'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 입력 이미지 표시
              _buildInputImage(context),
              const SizedBox(height: 24),

              // 감정 이모지 (크게 표시)
              _buildEmoji(),
              const SizedBox(height: 16),

              // 한국어 결과 문장
              _buildSentence(theme),
              const SizedBox(height: 12),

              // 감정 카테고리 및 신뢰도
              _buildCategoryAndConfidence(theme, colorScheme),
              const SizedBox(height: 32),

              // 액션 버튼들
              _buildActionButtons(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  /// 입력 이미지를 둥근 모서리로 표시한다
  Widget _buildInputImage(BuildContext context) {
    return Semantics(
      label: '분석에 사용된 입력 이미지',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          imageFile,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.image_not_supported,
                size: 48,
                color: Colors.grey,
              ),
            );
          },
        ),
      ),
    );
  }

  /// 감정 이모지를 크게 표시한다
  Widget _buildEmoji() {
    return Semantics(
      label: '감정 이모지: ${result.emoji}',
      child: Text(
        result.emoji,
        style: const TextStyle(fontSize: 64),
      ),
    );
  }

  /// 한국어 결과 문장을 표시한다
  Widget _buildSentence(ThemeData theme) {
    return Semantics(
      label: '분석 결과: ${result.sentence}',
      child: Text(
        result.sentence,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.visible,
        softWrap: true,
      ),
    );
  }

  /// 감정 카테고리와 신뢰도를 표시한다
  Widget _buildCategoryAndConfidence(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 감정 카테고리명
          Text(
            _getCategoryDisplayName(result.category),
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),

          // 구분선
          Container(
            width: 1,
            height: 20,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(width: 12),

          // 신뢰도 백분율
          Text(
            '${result.confidencePercent}%',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// 다시 분석하기, 이력 보기 버튼을 표시한다
  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Column(
      children: [
        // 다시 분석하기 버튼
        SizedBox(
          width: double.infinity,
          height: 48, // 최소 44dp 이상 보장
          child: FilledButton.icon(
            onPressed: onAnalyzeAgain,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 분석하기'),
          ),
        ),
        const SizedBox(height: 12),

        // 이력 보기 버튼
        SizedBox(
          width: double.infinity,
          height: 48, // 최소 44dp 이상 보장
          child: OutlinedButton.icon(
            onPressed: onViewHistory,
            icon: const Icon(Icons.history),
            label: const Text('이력 보기'),
          ),
        ),
      ],
    );
  }

  /// 감정 카테고리의 한국어 표시명을 반환한다
  String _getCategoryDisplayName(EmotionCategory category) {
    switch (category) {
      case EmotionCategory.angry:
        return '화남';
      case EmotionCategory.happy:
        return '행복';
      case EmotionCategory.sad:
        return '슬픔';
      case EmotionCategory.other:
        return '기타';
    }
  }
}
