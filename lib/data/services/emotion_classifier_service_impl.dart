import 'dart:math';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:animind/domain/models/models.dart';
import 'package:animind/domain/services/emotion_classifier_service.dart';

/// 감정 분류 서비스 구현체
///
/// TFLite 모델을 사용하여 전처리된 이미지에서 감정을 분류한다.
/// 후처리 로직(softmax, 정렬, 불확실 판정)은 [processRawOutput]으로 분리하여
/// 모델 없이도 단위 테스트가 가능하다.
class EmotionClassifierServiceImpl implements EmotionClassifierService {
  /// TFLite 모델 파일 경로
  static const String _modelPath = 'assets/models/emotion_model.tflite';

  /// 불확실 판정 임계값 (50%)
  static const double uncertaintyThreshold = 0.5;

  /// 감정 카테고리 인덱스 매핑
  /// index 0 → angry, 1 → happy, 2 → sad, 3 → other
  static const List<EmotionCategory> categoryMapping = [
    EmotionCategory.angry,
    EmotionCategory.happy,
    EmotionCategory.sad,
    EmotionCategory.other,
  ];

  Interpreter? _interpreter;

  @override
  Future<void> initialize() async {
    // TFLite 모델을 assets에서 로딩한다
    _interpreter = await Interpreter.fromAsset(_modelPath);
  }

  @override
  Future<ClassificationResult> classify(PreprocessedImage image) async {
    try {
      final interpreter = _interpreter;
      if (interpreter == null) {
        return const InferenceError(
          errorMessage: '모델이 초기화되지 않았습니다. initialize()를 먼저 호출하세요.',
        );
      }

      // 모델 출력 버퍼 준비 (4개 카테고리의 logit 값)
      final output = List.filled(4, 0.0).reshape([1, 4]);

      // 추론 실행
      interpreter.run(image.tensorData, output);

      // 원시 출력(logits) 추출
      final rawLogits = List<double>.from(output[0] as List);

      // 후처리: softmax → 정렬 → 불확실 판정
      return processRawOutput(rawLogits);
    } catch (e) {
      // 추론 실패 시 InferenceError 반환
      return InferenceError(errorMessage: '감정 분류 추론 실패: $e');
    }
  }

  @override
  void dispose() {
    // 인터프리터 리소스 해제
    _interpreter?.close();
    _interpreter = null;
  }

  /// 원시 모델 출력(logits)을 후처리하여 분류 결과를 반환한다.
  ///
  /// TFLite 인터프리터 없이도 독립적으로 테스트 가능하다.
  /// 1. Softmax 정규화 (수치 안정성을 위해 max 값 차감)
  /// 2. 4개 카테고리에 대한 EmotionPrediction 생성
  /// 3. 신뢰도 내림차순 정렬
  /// 4. 불확실 판정 (최상위 신뢰도 < 0.5)
  ClassificationResult processRawOutput(List<double> logits) {
    if (logits.length != 4) {
      return const InferenceError(
        errorMessage: '모델 출력이 4개 카테고리가 아닙니다.',
      );
    }

    // Softmax 정규화
    final probabilities = _softmax(logits);

    // 각 카테고리별 예측 결과 생성
    final predictions = <EmotionPrediction>[];
    for (var i = 0; i < 4; i++) {
      predictions.add(EmotionPrediction(
        category: categoryMapping[i],
        confidence: probabilities[i],
      ));
    }

    // 신뢰도 내림차순 정렬
    predictions.sort((a, b) => b.confidence.compareTo(a.confidence));

    // 최상위 예측 추출
    final topPrediction = predictions.first;

    // 불확실 판정: 최상위 신뢰도가 50% 미만인 경우
    final isUncertain = topPrediction.confidence < uncertaintyThreshold;

    return ClassificationSuccess(
      topPrediction: topPrediction,
      allPredictions: predictions,
      isUncertain: isUncertain,
    );
  }

  /// Softmax 정규화 함수
  ///
  /// 수치 안정성을 위해 최대값을 차감한 후 지수 함수를 적용한다.
  /// 결과의 합계는 1.0이 된다 (부동소수점 허용 오차 내).
  List<double> _softmax(List<double> logits) {
    // 수치 안정성: 최대값 차감
    final maxLogit = logits.reduce(max);
    final shifted = logits.map((x) => x - maxLogit).toList();

    // exp 계산
    final exps = shifted.map((x) => exp(x)).toList();

    // 합계 계산
    final sumExps = exps.reduce((a, b) => a + b);

    // 정규화
    return exps.map((e) => e / sumExps).toList();
  }
}
