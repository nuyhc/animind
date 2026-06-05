import 'emotion_prediction.dart';

/// 분류 결과
sealed class ClassificationResult {
  const ClassificationResult();
}

/// 성공적인 분류 결과
class ClassificationSuccess extends ClassificationResult {
  final EmotionPrediction topPrediction;

  /// 4개 감정 카테고리의 예측 결과. 신뢰도 내림차순으로 정렬한다.
  final List<EmotionPrediction> allPredictions;

  /// 최상위 신뢰도 50% 미만 여부
  final bool isUncertain;

  const ClassificationSuccess({
    required this.topPrediction,
    required this.allPredictions,
    required this.isUncertain,
  });

  /// 상위 3개 예측 결과
  List<EmotionPrediction> get topThreePredictions =>
      allPredictions.take(3).toList();
}

/// 추론 실패 오류
class InferenceError extends ClassificationResult {
  final String errorMessage;

  const InferenceError({required this.errorMessage});
}
