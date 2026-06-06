// 속성 기반 테스트: 결과 포맷팅
// Feature: animal-emotion-recognition, Property 5: 결과 한국어 포맷팅
// Feature: animal-emotion-recognition, Property 6: 불확실 결과 포맷팅
//
// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**
//
// Property 5 - 임의의 감정 카테고리에 대해:
// (a) 생성된 문장은 "[감정 표현] 것 같아요" 구조를 따른다 (동물명/주어 미포함)
// (b) 사용된 감정 표현이 해당 카테고리의 정의된 표현 템플릿 목록에 포함된다
// (c) 표시된 이모지가 해당 카테고리에 매핑된 이모지와 일치한다
// (d) 신뢰도 점수가 정수 백분율로 표시된다
//
// Property 6 - 임의의 불확실 판정 결과(신뢰도 < 50%)에 대해:
// (a) 결과 문장이 감정 문장 대신 불확실 안내 문구("표정이 분명하지 않아요")를 표시
// (b) 상위 3개 항목에 올바른 감정 이모지, 한국어 카테고리명, 정수 백분율 신뢰도 포함
// (c) 상위 3개 항목이 신뢰도 내림차순으로 정렬

import 'dart:math';

import 'package:glados/glados.dart';
import 'package:animind/data/services/result_formatter_impl.dart';
import 'package:animind/domain/models/models.dart';
import 'package:animind/domain/models/emotion_mapping.dart';

/// 최대값이 0.5 미만인 4개 확률 분포를 생성하는 헬퍼
/// Dirichlet-유사 방식으로 4개 양수를 생성한 뒤 합계 1.0으로 정규화하고,
/// 최대값이 0.5 이상이면 재분배하여 max < 0.5를 보장한다.
List<double> _generateUncertainDistribution(List<double> rawValues) {
  // 양수로 변환 (지수 함수 사용)
  final positives = rawValues.map((v) => exp(v.clamp(-2.0, 2.0))).toList();
  final sum = positives.reduce((a, b) => a + b);

  // 합계 1.0으로 정규화
  var distribution = positives.map((v) => v / sum).toList();

  // max < 0.5 보장: 최대값이 0.5 이상이면 평탄화
  final maxVal = distribution.reduce(max);
  if (maxVal >= 0.5) {
    // 균등 분포 방향으로 보간하여 max < 0.5 보장
    const uniform = 0.25;
    distribution =
        distribution.map((v) => v * 0.4 + uniform * 0.6).toList();
    // 재정규화
    final newSum = distribution.reduce((a, b) => a + b);
    distribution = distribution.map((v) => v / newSum).toList();
  }

  return distribution;
}

/// 확률 분포로부터 ClassificationSuccess(불확실) 객체를 생성
ClassificationSuccess _createUncertainResult(List<double> distribution) {
  final categories = EmotionCategory.values;

  // 예측 목록 생성
  final predictions = <EmotionPrediction>[];
  for (var i = 0; i < 4; i++) {
    predictions.add(EmotionPrediction(
      category: categories[i],
      confidence: distribution[i],
    ));
  }

  // 내림차순 정렬
  predictions.sort((a, b) => b.confidence.compareTo(a.confidence));

  return ClassificationSuccess(
    topPrediction: predictions.first,
    allPredictions: predictions,
    isUncertain: true,
  );
}

void main() {
  late ResultFormatterImpl formatter;

  setUp(() {
    formatter = ResultFormatterImpl(random: Random(42));
  });

  group('Property 5: 결과 한국어 포맷팅', () {
    // 카테고리 인덱스(0~3)와 신뢰도(0.5~1.0)를 생성하여
    // 일반 결과(isUncertain=false)에 대한 포맷팅 속성을 검증한다
    Glados2(
      any.intInRange(0, 4), // 카테고리 인덱스 (0: angry, 1: happy, 2: sad, 3: other)
      any.doubleInRange(0.5, 1.0), // 신뢰도 (50% 이상 → isUncertain = false)
      ExploreConfig(numRuns: 100),
    ).test(
      '(a)(b)(c)(d) 임의 감정 카테고리에 대해 문장 구조, 템플릿, 이모지, 정수 백분율을 검증한다',
      (categoryIndex, confidence) {
        final category = EmotionCategory.values[categoryIndex];

        // ClassificationSuccess 생성 (isUncertain=false, 신뢰도 >= 0.5)
        final topPrediction = EmotionPrediction(
          category: category,
          confidence: confidence,
        );

        // 나머지 카테고리에 대한 예측 생성 (남은 확률 균등 분배)
        final remainingConfidence = 1.0 - confidence;
        final otherCategories =
            EmotionCategory.values.where((c) => c != category).toList();
        final allPredictions = <EmotionPrediction>[topPrediction];
        for (var i = 0; i < otherCategories.length; i++) {
          allPredictions.add(EmotionPrediction(
            category: otherCategories[i],
            confidence: remainingConfidence / otherCategories.length,
          ));
        }

        final classificationResult = ClassificationSuccess(
          topPrediction: topPrediction,
          allPredictions: allPredictions,
          isUncertain: false,
        );

        final result = formatter.format(classificationResult);

        // (a) "[감정 표현] 것 같아요" 구조 검증
        expect(result.sentence.endsWith(' 것 같아요'), isTrue,
            reason: '문장("${result.sentence}")은 " 것 같아요"로 끝나야 한다');

        // 문장에서 감정 표현 부분 추출
        final expression = result.sentence
            .substring(0, result.sentence.length - ' 것 같아요'.length);
        expect(expression.isNotEmpty, isTrue,
            reason: '감정 표현 부분이 비어있으면 안 된다');

        // (b) 사용된 표현이 해당 카테고리 템플릿 목록에 포함되는지 검증
        final templates = EmotionMapping.expressionTemplates[category]!;
        expect(templates.contains(expression), isTrue,
            reason:
                '표현("$expression")이 $category 카테고리의 템플릿 목록 $templates에 포함되어야 한다');

        // (c) 이모지가 해당 카테고리에 매핑된 이모지와 일치하는지 검증
        final expectedEmoji = EmotionMapping.emojis[category]!;
        expect(result.emoji, equals(expectedEmoji),
            reason:
                '이모지("${result.emoji}")가 $category 카테고리의 매핑 이모지("$expectedEmoji")와 일치해야 한다');

        // (d) 신뢰도가 정수 백분율로 표시되는지 검증
        final expectedPercent = (confidence * 100).round();
        expect(result.confidencePercent, equals(expectedPercent),
            reason:
                '신뢰도(${result.confidencePercent})가 정수 백분율($expectedPercent)이어야 한다');
        expect(result.confidencePercent, isA<int>(),
            reason: '신뢰도는 int 타입이어야 한다');
        expect(
            result.confidencePercent >= 0 && result.confidencePercent <= 100,
            isTrue,
            reason: '신뢰도(${result.confidencePercent})는 0~100 범위여야 한다');
      },
    );

    // 무작위 Random을 사용하여 템플릿 선택의 무작위성에서도 속성 유지를 검증
    Glados2(
      any.intInRange(0, 4),
      any.doubleInRange(0.5, 1.0),
      ExploreConfig(numRuns: 100),
    ).test(
      '(a)(b) 무작위 Random에서도 선택된 표현이 항상 유효한 템플릿 목록에 포함된다',
      (categoryIndex, confidence) {
        final category = EmotionCategory.values[categoryIndex];

        // 무작위 Random 사용 (실제 운영 환경과 동일)
        final randomFormatter = ResultFormatterImpl();

        final topPrediction = EmotionPrediction(
          category: category,
          confidence: confidence,
        );

        final otherCategories =
            EmotionCategory.values.where((c) => c != category).toList();
        final remainingConfidence = 1.0 - confidence;
        final allPredictions = <EmotionPrediction>[topPrediction];
        for (var i = 0; i < otherCategories.length; i++) {
          allPredictions.add(EmotionPrediction(
            category: otherCategories[i],
            confidence: remainingConfidence / otherCategories.length,
          ));
        }

        final classificationResult = ClassificationSuccess(
          topPrediction: topPrediction,
          allPredictions: allPredictions,
          isUncertain: false,
        );

        final result = randomFormatter.format(classificationResult);

        // (a) 문장 구조 검증
        expect(result.sentence.endsWith(' 것 같아요'), isTrue,
            reason: '문장은 " 것 같아요"로 끝나야 한다');

        // (b) 표현 템플릿 유효성 검증
        final expression = result.sentence
            .substring(0, result.sentence.length - ' 것 같아요'.length);
        final templates = EmotionMapping.expressionTemplates[category]!;
        expect(templates.contains(expression), isTrue,
            reason:
                '무작위 선택된 표현("$expression")이 유효한 템플릿 목록에 포함되어야 한다');

        // (c) 이모지 매핑 일치 검증
        expect(result.emoji, equals(EmotionMapping.emojis[category]!));

        // (d) 정수 백분율 검증
        expect(result.confidencePercent, equals((confidence * 100).round()));
      },
    );
  });

  group('Property 6: 불확실 결과 포맷팅', () {
    // (a) 불확실 결과에서 안내 문구 검증
    Glados(
      any.listWithLength(4, any.doubleInRange(-2.0, 2.0)),
      ExploreConfig(numRuns: 100),
    ).test(
      '(a) 불확실 판정 시 "표정이 분명하지 않아요" 안내 문구를 표시한다',
      (rawValues) {
        final distribution = _generateUncertainDistribution(rawValues);
        final classificationResult = _createUncertainResult(distribution);

        final formatted = formatter.format(classificationResult);

        // 불확실 안내 문구 검증 - 단정적 감정 문장 대신 안내 문구
        expect(formatted.sentence, equals('표정이 분명하지 않아요'),
            reason: '불확실 판정 시 "표정이 분명하지 않아요" 안내 문구를 표시해야 한다');
        expect(formatted.isUncertain, isTrue,
            reason: '불확실 결과의 isUncertain 플래그는 true여야 한다');

        // 감정 문장 패턴("것 같아요")이 아닌 것을 검증
        expect(formatted.sentence.contains('것 같아요'), isFalse,
            reason: '불확실 결과는 단정적 감정 문장을 포함하지 않아야 한다');
      },
    );

    // (b) 상위 3개 항목의 이모지, 한국어 카테고리명, 정수 백분율 검증
    Glados(
      any.listWithLength(4, any.doubleInRange(-2.0, 2.0)),
      ExploreConfig(numRuns: 100),
    ).test(
      '(b) 상위 3개 항목에 올바른 이모지, 한국어 카테고리명, 정수 백분율이 포함된다',
      (rawValues) {
        final distribution = _generateUncertainDistribution(rawValues);
        final classificationResult = _createUncertainResult(distribution);

        final formatted = formatter.format(classificationResult);

        // 상위 3개 항목이 존재해야 한다
        expect(formatted.topThree, isNotNull,
            reason: '불확실 결과에는 상위 3개 항목이 포함되어야 한다');
        expect(formatted.topThree!.length, equals(3),
            reason: '상위 항목 수는 정확히 3개여야 한다');

        // 입력의 상위 3개 예측과 대조하여 검증
        final topThreePredictions = classificationResult.topThreePredictions;

        for (var i = 0; i < 3; i++) {
          final formattedItem = formatted.topThree![i];
          final originalPrediction = topThreePredictions[i];
          final category = originalPrediction.category;

          // (b-1) 올바른 감정 이모지
          final expectedEmoji = EmotionMapping.emojis[category]!;
          expect(formattedItem.emoji, equals(expectedEmoji),
              reason:
                  '${category.name} 카테고리의 이모지는 $expectedEmoji여야 한다');

          // (b-2) 한국어 카테고리명
          final expectedName = EmotionMapping.koreanNames[category]!;
          expect(formattedItem.categoryName, equals(expectedName),
              reason:
                  '${category.name} 카테고리의 한국어명은 $expectedName여야 한다');

          // (b-3) 정수 백분율 신뢰도
          final expectedPercent = originalPrediction.confidencePercent;
          expect(formattedItem.confidencePercent, equals(expectedPercent),
              reason: '신뢰도는 정수 백분율이어야 한다');
          expect(formattedItem.confidencePercent, isA<int>(),
              reason: '신뢰도는 int 타입이어야 한다');
        }
      },
    );

    // (c) 상위 3개 항목의 내림차순 정렬 검증
    Glados(
      any.listWithLength(4, any.doubleInRange(-2.0, 2.0)),
      ExploreConfig(numRuns: 100),
    ).test(
      '(c) 상위 3개 항목은 신뢰도 내림차순으로 정렬되어 있다',
      (rawValues) {
        final distribution = _generateUncertainDistribution(rawValues);
        final classificationResult = _createUncertainResult(distribution);

        final formatted = formatter.format(classificationResult);

        expect(formatted.topThree, isNotNull);
        final topThree = formatted.topThree!;

        // 내림차순 정렬 검증
        for (var i = 0; i < topThree.length - 1; i++) {
          expect(
            topThree[i].confidencePercent >= topThree[i + 1].confidencePercent,
            isTrue,
            reason:
                '항목[$i](${topThree[i].confidencePercent}%)는 항목[${i + 1}](${topThree[i + 1].confidencePercent}%)보다 크거나 같아야 한다',
          );
        }
      },
    );
  });
}
