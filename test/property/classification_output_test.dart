// 속성 기반 테스트: 분류 출력 불변조건
// Feature: animal-emotion-recognition, Property 3: 분류 출력 불변조건
//
// **Validates: Requirements 2.2, 2.3, 2.4**
//
// 임의의 4차원 실수 벡터(logits)에 대해:
// (a) 결과는 정확히 4개의 감정 카테고리(Angry, Happy, Sad, Other)를 포함
// (b) 모든 확률값의 합계 == 1.0 (허용 오차 ±1e-3)
// (c) 반환된 최상위 카테고리가 실제로 가장 높은 확률을 가진 카테고리

import 'package:glados/glados.dart';

import 'package:animind/data/services/emotion_classifier_service_impl.dart';
import 'package:animind/domain/models/models.dart';

void main() {
  late EmotionClassifierServiceImpl service;

  setUp(() {
    service = EmotionClassifierServiceImpl();
  });

  group(
    'Property 3: 분류 출력 불변조건',
    () {
      // (a) 정확히 4개 감정 카테고리를 포함하는지 검증
      Glados(
        any.combine4(
          any.doubleInRange(-100, 100),
          any.doubleInRange(-100, 100),
          any.doubleInRange(-100, 100),
          any.doubleInRange(-100, 100),
          (double a, double b, double c, double d) => <double>[a, b, c, d],
        ),
        ExploreConfig(numRuns: 100),
      ).test(
        '(a) 임의 logits에 대해 결과는 정확히 4개 감정 카테고리를 포함한다',
        (List<double> logits) {
          final result = service.processRawOutput(logits);

          // 분류 성공이어야 한다
          expect(result, isA<ClassificationSuccess>());
          final success = result as ClassificationSuccess;

          // 정확히 4개의 예측 결과
          expect(
            success.allPredictions.length,
            equals(4),
            reason: 'logits=$logits: 정확히 4개 카테고리가 반환되어야 한다',
          );

          // 4개 카테고리가 모두 존재하는지 확인
          final categories =
              success.allPredictions.map((p) => p.category).toSet();
          expect(
            categories,
            containsAll(EmotionCategory.values),
            reason: 'logits=$logits: Angry, Happy, Sad, Other 모두 포함해야 한다',
          );

          // 중복 카테고리가 없는지 확인
          expect(
            categories.length,
            equals(4),
            reason: 'logits=$logits: 카테고리가 중복 없이 4개여야 한다',
          );
        },
      );

      // (b) 확률값 합계 == 1.0 (허용 오차 ±1e-3)
      Glados(
        any.combine4(
          any.doubleInRange(-100, 100),
          any.doubleInRange(-100, 100),
          any.doubleInRange(-100, 100),
          any.doubleInRange(-100, 100),
          (double a, double b, double c, double d) => <double>[a, b, c, d],
        ),
        ExploreConfig(numRuns: 100),
      ).test(
        '(b) 임의 logits에 대해 확률 합계는 1.0이다 (허용 오차 ±1e-3)',
        (List<double> logits) {
          final result = service.processRawOutput(logits);

          expect(result, isA<ClassificationSuccess>());
          final success = result as ClassificationSuccess;

          // 모든 확률값의 합계 계산
          final sum = success.allPredictions
              .map((p) => p.confidence)
              .reduce((a, b) => a + b);

          expect(
            sum,
            closeTo(1.0, 1e-3),
            reason:
                'logits=$logits: 확률 합계=$sum, 1.0과의 차이가 1e-3 이내여야 한다',
          );
        },
      );

      // (c) 최상위 카테고리가 실제로 가장 높은 확률을 가진 카테고리인지 검증
      Glados(
        any.combine4(
          any.doubleInRange(-100, 100),
          any.doubleInRange(-100, 100),
          any.doubleInRange(-100, 100),
          any.doubleInRange(-100, 100),
          (double a, double b, double c, double d) => <double>[a, b, c, d],
        ),
        ExploreConfig(numRuns: 100),
      ).test(
        '(c) 반환된 최상위 카테고리는 실제 최고 확률 카테고리이다',
        (List<double> logits) {
          final result = service.processRawOutput(logits);

          expect(result, isA<ClassificationSuccess>());
          final success = result as ClassificationSuccess;

          // topPrediction이 allPredictions 중 가장 높은 확률인지 확인
          final maxConfidence = success.allPredictions
              .map((p) => p.confidence)
              .reduce((a, b) => a > b ? a : b);

          expect(
            success.topPrediction.confidence,
            equals(maxConfidence),
            reason:
                'logits=$logits: topPrediction 신뢰도(${success.topPrediction.confidence})가 '
                '최대 신뢰도($maxConfidence)와 같아야 한다',
          );

          // allPredictions가 내림차순으로 정렬되어 있는지 검증
          for (var i = 0; i < success.allPredictions.length - 1; i++) {
            expect(
              success.allPredictions[i].confidence,
              greaterThanOrEqualTo(success.allPredictions[i + 1].confidence),
              reason:
                  'logits=$logits: allPredictions[$i]의 신뢰도가 '
                  '[${i + 1}]보다 크거나 같아야 한다 (내림차순)',
            );
          }

          // topPrediction이 allPredictions의 첫 번째 항목과 동일한지 확인
          expect(
            success.topPrediction.category,
            equals(success.allPredictions.first.category),
            reason:
                'logits=$logits: topPrediction 카테고리가 정렬된 목록의 첫 번째와 같아야 한다',
          );
        },
      );
    },
  );
}
