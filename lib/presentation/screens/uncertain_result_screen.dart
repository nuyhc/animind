import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/models/formatted_result.dart';

/// 불확실 결과 화면
///
/// 분석이 완료되었으나 최상위 신뢰도가 50% 미만인 경우 표시되는 화면.
/// 입력 이미지, 불확실 안내 문구, 상위 3개 감정 후보 목록을 표시한다.
/// 각 후보 항목은 이모지, 한국어 카테고리명, 신뢰도 백분율을 포함한다.
/// 하단에 "다시 분석하기", "이력 보기" 버튼을 제공한다.
///
/// 접근성 준수 사항:
/// - 모든 이미지/후보 항목에 스크린 리더용 Semantics 라벨 제공
/// - Material Design 3 ColorScheme으로 WCAG AA 명도 대비 보장
/// - theme.textTheme 사용으로 시스템 글자 크기 확대 대응
/// - 주요 버튼의 터치 영역 최소 44x44dp 이상
class UncertainResultScreen extends StatelessWidget {
  /// 분석에 사용된 입력 이미지 파일
  final File imageFile;

  /// 포맷된 분석 결과 (isUncertain == true)
  final FormattedResult result;

  /// 다시 분석하기 콜백
  final VoidCallback? onAnalyzeAgain;

  /// 이력 보기 콜백
  final VoidCallback? onViewHistory;

  const UncertainResultScreen({
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

              // 불확실 안내 문구
              _buildUncertainNotice(theme, colorScheme),
              const SizedBox(height: 24),

              // 상위 3개 감정 후보 목록
              _buildTopPredictionsList(theme, colorScheme),
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

  /// 불확실 안내 문구를 표시한다
  Widget _buildUncertainNotice(ThemeData theme, ColorScheme colorScheme) {
    return Semantics(
      label: '분석 결과: 표정이 분명하지 않아요',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              color: colorScheme.onTertiaryContainer,
              size: 24,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '표정이 분명하지 않아요',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 상위 3개 감정 후보 목록을 표시한다
  Widget _buildTopPredictionsList(ThemeData theme, ColorScheme colorScheme) {
    final predictions = result.topThree;
    if (predictions == null || predictions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: '상위 감정 후보 목록',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 제목
          Text(
            '감정 후보',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // 후보 목록
          ...predictions.map(
            (prediction) => _buildPredictionItem(
              prediction,
              theme,
              colorScheme,
            ),
          ),
        ],
      ),
    );
  }

  /// 개별 예측 항목을 표시한다 (이모지 + 카테고리명 + 신뢰도)
  Widget _buildPredictionItem(
    FormattedPrediction prediction,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Semantics(
      label:
          '${prediction.categoryName}: ${prediction.confidencePercent}퍼센트',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 감정 이모지
            Text(
              prediction.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 12),

            // 한국어 카테고리명
            Expanded(
              child: Text(
                prediction.categoryName,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 신뢰도 백분율
            Text(
              '${prediction.confidencePercent}%',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 다시 분석하기, 이력 보기 버튼을 표시한다
  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Column(
      children: [
        // 다시 분석하기 버튼 (최소 44dp 터치 영역 보장)
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: onAnalyzeAgain,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 분석하기'),
          ),
        ),
        const SizedBox(height: 12),

        // 이력 보기 버튼 (최소 44dp 터치 영역 보장)
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onViewHistory,
            icon: const Icon(Icons.history),
            label: const Text('이력 보기'),
          ),
        ),
      ],
    );
  }
}
