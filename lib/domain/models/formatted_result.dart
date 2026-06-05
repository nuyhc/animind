import 'emotion_category.dart';

/// 포맷된 결과
class FormattedResult {
  /// 한국어 감정 문장 또는 불확실 안내 문구
  final String sentence;

  /// 감정 이모지
  final String emoji;

  /// 정수 백분율
  final int confidencePercent;

  /// 감정 카테고리
  final EmotionCategory category;

  /// 불확실 결과 여부
  final bool isUncertain;

  /// 불확실 시 상위 3개 예측 결과
  final List<FormattedPrediction>? topThree;

  const FormattedResult({
    required this.sentence,
    required this.emoji,
    required this.confidencePercent,
    required this.category,
    this.isUncertain = false,
    this.topThree,
  });
}

/// 개별 예측 결과 포맷
class FormattedPrediction {
  /// 감정 이모지
  final String emoji;

  /// 한국어 카테고리명
  final String categoryName;

  /// 정수 백분율 신뢰도
  final int confidencePercent;

  const FormattedPrediction({
    required this.emoji,
    required this.categoryName,
    required this.confidencePercent,
  });
}
