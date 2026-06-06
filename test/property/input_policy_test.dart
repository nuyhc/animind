// 속성 기반 테스트: 비대상 이미지 입력 정책
// Feature: animal-emotion-recognition, Property 15: 비대상 이미지 의미 검증 제외
//
// **Validates: Requirements 1.9, 2.6, 2.7**
//
// 임의의 유효한 4차원 logits(비대상 이미지 포함 모든 입력을 대표)에 대해:
// - 시스템은 "동물 미감지" 또는 "종 분류" 결과를 반환하지 않음
// - 결과는 항상 ClassificationSuccess(4개 감정 카테고리) 또는 InferenceError
// - 성공 시 isUncertain은 true 또는 false (거부 상태 없음)
// - "rejected", "no animal" 같은 제3의 상태가 존재하지 않음

import 'package:glados/glados.dart';
import 'package:animind/data/services/emotion_classifier_service_impl.dart';
import 'package:animind/domain/models/classification_result.dart';
import 'package:animind/domain/models/emotion_category.dart';

void main() {
  late EmotionClassifierServiceImpl service;

  setUp(() {
    service = EmotionClassifierServiceImpl();
  });

  group(
    'Property 15: 비대상 이미지 의미 검증 제외',
    () {
      // 임의의 4차원 logits에 대해 processRawOutput()을 호출하면
      // 항상 ClassificationSuccess(4개 감정 카테고리)를 반환하고,
      // 별도의 거부/미감지 상태가 존재하지 않음을 검증한다.
      Glados(any.doubleInRange(-1000.0, 1000.0), ExploreConfig(numRuns: 100))
          .test(
        '임의 logits에 대해 항상 4개 감정 분류 흐름으로 처리된다 (거부 상태 없음)',
        (logit0) {
          // 4개의 임의 logits 생성 (극단값 포함)
          // Glados가 하나의 값을 생성하므로, 시드 기반으로 나머지를 파생
          final logits = [
            logit0,
            logit0 * 0.5 - 3.0,
            logit0 * -0.3 + 7.0,
            logit0 * 1.2 - 1.0,
          ];

          final result = service.processRawOutput(logits);

          // 결과가 ClassificationSuccess여야 한다 (4개 유효 logits이므로 InferenceError 아님)
          expect(result, isA<ClassificationSuccess>(),
              reason: 'logits=$logits: 유효한 4차원 logits는 항상 '
                  'ClassificationSuccess를 반환해야 한다');

          final success = result as ClassificationSuccess;

          // 정확히 4개 감정 카테고리를 포함해야 한다
          expect(success.allPredictions.length, 4,
              reason: 'logits=$logits: 결과는 정확히 4개 감정 예측을 포함해야 한다');

          // 4개 카테고리가 모두 존재해야 한다 (angry, happy, sad, other)
          final categories =
              success.allPredictions.map((p) => p.category).toSet();
          expect(categories, containsAll(EmotionCategory.values),
              reason: 'logits=$logits: 4개 감정 카테고리가 모두 포함되어야 한다');

          // isUncertain은 반드시 bool 값 (true 또는 false) — "거부" 상태가 없음
          expect(success.isUncertain, isA<bool>(),
              reason: 'logits=$logits: isUncertain은 boolean이어야 한다');

          // topPrediction이 4개 카테고리 중 하나여야 한다 (미감지/종 분류 없음)
          expect(EmotionCategory.values, contains(success.topPrediction.category),
              reason: 'logits=$logits: topPrediction은 4개 감정 카테고리 중 하나여야 한다');
        },
      );

      // 극단값 logits(매우 크거나 작은 값)에 대해서도 동일한 정책 적용 검증
      Glados(any.doubleInRange(-1e10, 1e10), ExploreConfig(numRuns: 100))
          .test(
        '극단값 logits에 대해서도 거부 없이 4개 감정 분류를 수행한다',
        (extremeLogit) {
          // 극단적인 값을 포함하는 logits 조합
          final logits = [
            extremeLogit,
            -extremeLogit,
            extremeLogit * 0.01,
            0.0,
          ];

          final result = service.processRawOutput(logits);

          // 유효한 4차원 logits이면 항상 ClassificationSuccess
          expect(result, isA<ClassificationSuccess>(),
              reason: 'extremeLogits=$logits: 극단값도 '
                  'ClassificationSuccess를 반환해야 한다');

          final success = result as ClassificationSuccess;

          // "동물 미감지" 또는 "종 분류" 같은 제3의 상태가 없음을 확인
          // allPredictions에 4개 감정 카테고리만 존재
          expect(success.allPredictions.length, 4,
              reason: 'extremeLogits=$logits: 정확히 4개 예측 결과만 반환해야 한다');

          // isUncertain이 boolean으로만 표현됨 (거부 상태 아님)
          expect(success.isUncertain, isA<bool>(),
              reason: 'extremeLogits=$logits: isUncertain은 boolean이어야 한다');

          // 결과의 각 예측이 유효한 감정 카테고리
          for (final prediction in success.allPredictions) {
            expect(EmotionCategory.values, contains(prediction.category),
                reason: 'extremeLogits=$logits: '
                    '모든 예측이 유효한 감정 카테고리여야 한다');
            // 신뢰도가 0 이상 1 이하
            expect(prediction.confidence, greaterThanOrEqualTo(0.0),
                reason: 'extremeLogits=$logits: 신뢰도는 0.0 이상이어야 한다');
            expect(prediction.confidence, lessThanOrEqualTo(1.0),
                reason: 'extremeLogits=$logits: 신뢰도는 1.0 이하여야 한다');
          }
        },
      );
      // Tag: Feature: animal-emotion-recognition, Property 15: 비대상 이미지 의미 검증 제외
    },
  );
}
