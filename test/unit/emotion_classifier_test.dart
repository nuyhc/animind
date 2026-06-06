import 'package:flutter_test/flutter_test.dart';
import 'package:animind/data/services/emotion_classifier_service_impl.dart';
import 'package:animind/domain/models/models.dart';

void main() {
  late EmotionClassifierServiceImpl classifier;

  setUp(() {
    classifier = EmotionClassifierServiceImpl();
  });

  group('processRawOutput - Softmax 정규화', () {
    test('모든 확률의 합은 1.0이어야 한다 (허용 오차 1e-3)', () {
      final result = classifier.processRawOutput([1.0, 2.0, 3.0, 4.0]);

      expect(result, isA<ClassificationSuccess>());
      final success = result as ClassificationSuccess;
      final sum = success.allPredictions.fold(
        0.0,
        (acc, p) => acc + p.confidence,
      );
      expect(sum, closeTo(1.0, 1e-3));
    });

    test('동일한 logits 입력 시 균등 분포를 반환한다', () {
      final result = classifier.processRawOutput([0.0, 0.0, 0.0, 0.0]);

      expect(result, isA<ClassificationSuccess>());
      final success = result as ClassificationSuccess;
      for (final prediction in success.allPredictions) {
        expect(prediction.confidence, closeTo(0.25, 1e-3));
      }
    });

    test('큰 값의 logits에서도 수치 안정성이 유지된다', () {
      final result = classifier.processRawOutput([1000.0, 999.0, 998.0, 997.0]);

      expect(result, isA<ClassificationSuccess>());
      final success = result as ClassificationSuccess;
      final sum = success.allPredictions.fold(
        0.0,
        (acc, p) => acc + p.confidence,
      );
      expect(sum, closeTo(1.0, 1e-3));
    });

    test('음수 logits에서도 정상 동작한다', () {
      final result =
          classifier.processRawOutput([-10.0, -20.0, -30.0, -5.0]);

      expect(result, isA<ClassificationSuccess>());
      final success = result as ClassificationSuccess;
      final sum = success.allPredictions.fold(
        0.0,
        (acc, p) => acc + p.confidence,
      );
      expect(sum, closeTo(1.0, 1e-3));
    });
  });

  group('processRawOutput - 카테고리 매핑', () {
    test('정확히 4개 카테고리를 반환한다', () {
      final result = classifier.processRawOutput([1.0, 2.0, 3.0, 4.0]);

      expect(result, isA<ClassificationSuccess>());
      final success = result as ClassificationSuccess;
      expect(success.allPredictions.length, equals(4));

      // 4개 카테고리 모두 포함되어야 한다
      final categories =
          success.allPredictions.map((p) => p.category).toSet();
      expect(categories, containsAll(EmotionCategory.values));
    });

    test('인덱스 매핑이 올바르다 (0=angry, 1=happy, 2=sad, 3=other)', () {
      // index 3 (other)이 가장 높은 logit을 가진 경우
      final result = classifier.processRawOutput([0.0, 0.0, 0.0, 10.0]);

      expect(result, isA<ClassificationSuccess>());
      final success = result as ClassificationSuccess;
      expect(success.topPrediction.category, equals(EmotionCategory.other));
    });
  });

  group('processRawOutput - 내림차순 정렬', () {
    test('예측 결과가 신뢰도 내림차순으로 정렬된다', () {
      final result = classifier.processRawOutput([1.0, 4.0, 2.0, 3.0]);

      expect(result, isA<ClassificationSuccess>());
      final success = result as ClassificationSuccess;

      for (var i = 0; i < success.allPredictions.length - 1; i++) {
        expect(
          success.allPredictions[i].confidence,
          greaterThanOrEqualTo(success.allPredictions[i + 1].confidence),
        );
      }
    });

    test('최상위 예측이 가장 높은 신뢰도를 가진다', () {
      // index 1 (happy)이 가장 높은 값
      final result = classifier.processRawOutput([1.0, 10.0, 2.0, 3.0]);

      expect(result, isA<ClassificationSuccess>());
      final success = result as ClassificationSuccess;
      expect(success.topPrediction.category, equals(EmotionCategory.happy));
      expect(
        success.topPrediction.confidence,
        equals(success.allPredictions.first.confidence),
      );
    });
  });

  group('processRawOutput - 불확실 판정', () {
    test('최상위 신뢰도가 50% 미만이면 불확실로 판정한다', () {
      // 균등 분포: 각각 ~25%
      final result = classifier.processRawOutput([0.0, 0.0, 0.0, 0.0]);

      expect(result, isA<ClassificationSuccess>());
      final success = result as ClassificationSuccess;
      expect(success.isUncertain, isTrue);
    });

    test('최상위 신뢰도가 50% 이상이면 불확실이 아니다', () {
      // index 0 (angry)이 매우 높은 값 → 신뢰도 > 50%
      final result = classifier.processRawOutput([10.0, 0.0, 0.0, 0.0]);

      expect(result, isA<ClassificationSuccess>());
      final success = result as ClassificationSuccess;
      expect(success.isUncertain, isFalse);
      expect(success.topPrediction.confidence, greaterThanOrEqualTo(0.5));
    });

    test('경계값: 정확히 50%에서는 불확실이 아니다', () {
      // 두 카테고리가 동일하고 나머지가 매우 작은 경우 → 약 50%씩
      // ln(2) 차이 → softmax에서 약 2:1 비율
      // [ln(2), 0, -inf, -inf] → [2/3, 1/3, ~0, ~0]
      final result =
          classifier.processRawOutput([10.0, 10.0, -1000.0, -1000.0]);

      expect(result, isA<ClassificationSuccess>());
      final success = result as ClassificationSuccess;
      // 두 개가 ~50%씩이므로 최상위는 약 50%
      expect(success.topPrediction.confidence, closeTo(0.5, 0.01));
      expect(success.isUncertain, isFalse);
    });
  });

  group('processRawOutput - 오류 처리', () {
    test('logits 길이가 4가 아니면 InferenceError를 반환한다', () {
      final result = classifier.processRawOutput([1.0, 2.0, 3.0]);

      expect(result, isA<InferenceError>());
    });

    test('빈 logits에 대해 InferenceError를 반환한다', () {
      final result = classifier.processRawOutput([]);

      expect(result, isA<InferenceError>());
    });
  });

  group('classify - 초기화 검증', () {
    test('초기화 없이 classify 호출 시 InferenceError를 반환한다', () async {
      final image = PreprocessedImage(
        tensorData: [
          List.generate(
            224,
            (_) => List.generate(224, (_) => List.filled(3, 0.5)),
          ),
        ],
      );

      final result = await classifier.classify(image);
      expect(result, isA<InferenceError>());
      final error = result as InferenceError;
      expect(error.errorMessage, contains('초기화'));
    });
  });
}
