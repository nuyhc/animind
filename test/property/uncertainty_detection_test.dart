// 속성 기반 테스트: 불확실 판정 정확성
// Feature: animal-emotion-recognition, Property 4: 불확실 판정 정확성
//
// **Validates: Requirements 2.5**
//
// 임의의 4개 확률 분포에서:
// (a) 최대 확률 < 50% → isUncertain == true, 상위 3개 카테고리가 내림차순으로 정렬
// (b) 최대 확률 >= 50% → isUncertain == false

import 'package:glados/glados.dart';
import 'package:animind/data/services/emotion_classifier_service_impl.dart';
import 'package:animind/domain/models/models.dart';

void main() {
  late EmotionClassifierServiceImpl classifier;

  setUp(() {
    classifier = EmotionClassifierServiceImpl();
  });

  group('Property 4: 불확실 판정 정확성', () {
    // (a) softmax 결과의 최대값이 50% 미만인 logits → isUncertain == true
    // 전략: 4개 값을 매우 좁은 범위(-0.4 ~ 0.4)에서 생성하면 softmax max가 항상 < 0.5
    // 증명: 최악 케이스 [0.4, -0.4, -0.4, -0.4] → e^0.8/(e^0.8+3) ≈ 0.426 < 0.5
    Glados(
      any.listWithLength(4, any.doubleInRange(-0.4, 0.4)),
      ExploreConfig(numRuns: 100),
    ).test(
      '(a) 좁은 범위의 logits는 불확실 판정(isUncertain=true)과 내림차순 상위 3개를 반환한다',
      (logits) {
        final result = classifier.processRawOutput(logits);

        // processRawOutput은 항상 ClassificationSuccess를 반환해야 함 (logits 길이 4)
        expect(result, isA<ClassificationSuccess>());
        final success = result as ClassificationSuccess;

        // 좁은 범위(-0.4~0.4)의 logits는 softmax max가 항상 < 0.5
        expect(success.isUncertain, isTrue,
            reason:
                '좁은 범위 logits의 max 확률(${success.topPrediction.confidence.toStringAsFixed(4)})은 50% 미만이어야 한다');

        // 상위 3개가 내림차순으로 정렬되어야 한다
        final topThree = success.topThreePredictions;
        expect(topThree.length, equals(3));
        for (var i = 0; i < topThree.length - 1; i++) {
          expect(topThree[i].confidence >= topThree[i + 1].confidence, isTrue,
              reason: '상위 3개 예측이 내림차순으로 정렬되어야 한다');
        }
      },
    );

    // (a) 확실하게 max < 0.5가 되는 logits 생성 (동일 기준값 + 작은 노이즈)
    Glados2(
      any.doubleInRange(-5.0, 5.0), // 기준값
      any.listWithLength(4, any.doubleInRange(-0.5, 0.5)), // 노이즈
      ExploreConfig(numRuns: 100),
    ).test(
      '(a) 균등 분포에 가까운 logits는 항상 불확실 판정을 반환한다',
      (baseValue, noise) {
        // 기준값 + 작은 노이즈로 logits 생성 (값이 비슷하므로 softmax max < 0.5)
        final logits = noise.map((n) => baseValue + n).toList();

        final result = classifier.processRawOutput(logits);
        expect(result, isA<ClassificationSuccess>());
        final success = result as ClassificationSuccess;

        // 노이즈 범위가 [-0.5, 0.5]이면 softmax max는 약 0.36 이하
        expect(success.isUncertain, isTrue,
            reason:
                '균등 분포에 가까운 logits(max conf: ${success.topPrediction.confidence.toStringAsFixed(4)})는 불확실 판정이어야 한다');

        // 상위 3개 내림차순 정렬 검증
        final topThree = success.topThreePredictions;
        expect(topThree.length, equals(3));
        for (var i = 0; i < topThree.length - 1; i++) {
          expect(topThree[i].confidence >= topThree[i + 1].confidence, isTrue,
              reason: '상위 3개 예측이 내림차순으로 정렬되어야 한다');
        }
      },
    );

    // (b) softmax 결과의 최대값이 50% 이상인 logits → isUncertain == false
    // 전략: 하나의 값을 크게(>= 5), 나머지는 0 근처로 설정하면 softmax max >= 0.5
    Glados2(
      any.doubleInRange(5.0, 20.0), // 지배적인 높은 값
      any.listWithLength(3, any.doubleInRange(-2.0, 2.0)), // 나머지 3개
      ExploreConfig(numRuns: 100),
    ).test(
      '(b) 지배적 값이 큰 logits는 isUncertain이 false이다',
      (dominantValue, otherValues) {
        // 지배적인 값을 첫 번째 위치에 배치
        final logits = <double>[dominantValue, ...otherValues];

        final result = classifier.processRawOutput(logits);
        expect(result, isA<ClassificationSuccess>());
        final success = result as ClassificationSuccess;

        // 큰 값(>= 5)과 작은 값들(-2~2)의 차이가 최소 3 이상이므로
        // softmax에서 지배적 값의 확률이 50%를 넘는다
        expect(success.isUncertain, isFalse,
            reason:
                '최대 확률(${success.topPrediction.confidence.toStringAsFixed(4)})이 50% 이상이면 isUncertain이 false여야 한다');
      },
    );

    // (b) 임의 logits에 대해 속성 검증: max >= threshold이면 isUncertain == false
    Glados(
      any.listWithLength(4, any.doubleInRange(-10.0, 10.0)),
      ExploreConfig(numRuns: 100),
    ).test(
      '(b) 임의 logits에서 최대 확률 >= 50%이면 isUncertain은 항상 false이다',
      (logits) {
        final result = classifier.processRawOutput(logits);
        expect(result, isA<ClassificationSuccess>());
        final success = result as ClassificationSuccess;

        final maxConfidence = success.topPrediction.confidence;

        if (maxConfidence >=
            EmotionClassifierServiceImpl.uncertaintyThreshold) {
          // 최대 확률 >= 50%이면 불확실 판정이 아니어야 한다
          expect(success.isUncertain, isFalse,
              reason:
                  '최대 확률(${maxConfidence.toStringAsFixed(4)})이 50% 이상이면 isUncertain이 false여야 한다');
        }
      },
    );
  });
}
