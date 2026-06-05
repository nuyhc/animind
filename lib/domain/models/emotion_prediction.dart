import 'emotion_category.dart';

/// 감정 예측 결과
///
/// 단일 감정 카테고리에 대한 예측 확률을 나타낸다.
class EmotionPrediction {
  final EmotionCategory category;

  /// 신뢰도 값 (0.0 ~ 1.0)
  final double confidence;

  const EmotionPrediction({required this.category, required this.confidence});

  /// 백분율 형태의 신뢰도 (정수)
  int get confidencePercent => (confidence * 100).round();
}
