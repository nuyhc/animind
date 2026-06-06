import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:animind/data/services/result_formatter_impl.dart';
import 'package:animind/domain/models/classification_result.dart';
import 'package:animind/domain/models/emotion_category.dart';
import 'package:animind/domain/models/emotion_mapping.dart';
import 'package:animind/domain/models/emotion_prediction.dart';

void main() {
  late ResultFormatterImpl formatter;

  setUp(() {
    // 시드 고정으로 결정적 테스트 보장
    formatter = ResultFormatterImpl(random: Random(42));
  });

  group('ResultFormatterImpl - 일반 결과', () {
    test('결과 문장이 "[template] 것 같아요" 형식이어야 한다', () {
      const result = ClassificationSuccess(
        topPrediction: EmotionPrediction(
          category: EmotionCategory.happy,
          confidence: 0.87,
        ),
        allPredictions: [
          EmotionPrediction(category: EmotionCategory.happy, confidence: 0.87),
          EmotionPrediction(category: EmotionCategory.sad, confidence: 0.08),
          EmotionPrediction(category: EmotionCategory.angry, confidence: 0.03),
          EmotionPrediction(category: EmotionCategory.other, confidence: 0.02),
        ],
        isUncertain: false,
      );

      final formatted = formatter.format(result);

      // "것 같아요"로 끝나야 함
      expect(formatted.sentence, endsWith('것 같아요'));
      // 템플릿 목록에 포함된 표현이어야 함
      final templates = EmotionMapping.expressionTemplates[EmotionCategory.happy]!;
      final usedTemplate = formatted.sentence.replaceAll(' 것 같아요', '');
      expect(templates, contains(usedTemplate));
    });

    test('모든 감정 카테고리에 대해 올바른 문장 구조를 생성해야 한다', () {
      for (final category in EmotionCategory.values) {
        final result = ClassificationSuccess(
          topPrediction: EmotionPrediction(
            category: category,
            confidence: 0.75,
          ),
          allPredictions: [
            EmotionPrediction(category: category, confidence: 0.75),
            const EmotionPrediction(
              category: EmotionCategory.happy,
              confidence: 0.15,
            ),
            const EmotionPrediction(
              category: EmotionCategory.sad,
              confidence: 0.07,
            ),
            const EmotionPrediction(
              category: EmotionCategory.other,
              confidence: 0.03,
            ),
          ],
          isUncertain: false,
        );

        final formatted = formatter.format(result);

        expect(formatted.sentence, endsWith('것 같아요'));
        expect(formatted.isUncertain, isFalse);
        expect(formatted.topThree, isNull);

        // 카테고리별 템플릿에서 선택된 표현인지 확인
        final templates = EmotionMapping.expressionTemplates[category]!;
        final usedTemplate = formatted.sentence.replaceAll(' 것 같아요', '');
        expect(
          templates.contains(usedTemplate),
          isTrue,
          reason: '$category 카테고리의 표현 "$usedTemplate"이 템플릿에 없음',
        );
      }
    });

    test('이모지가 카테고리 매핑과 일치해야 한다', () {
      for (final category in EmotionCategory.values) {
        final result = ClassificationSuccess(
          topPrediction: EmotionPrediction(
            category: category,
            confidence: 0.80,
          ),
          allPredictions: [
            EmotionPrediction(category: category, confidence: 0.80),
          ],
          isUncertain: false,
        );

        final formatted = formatter.format(result);

        expect(
          formatted.emoji,
          EmotionMapping.emojis[category],
          reason: '$category의 이모지가 매핑과 불일치',
        );
      }
    });

    test('신뢰도가 정수 백분율로 변환되어야 한다', () {
      const result = ClassificationSuccess(
        topPrediction: EmotionPrediction(
          category: EmotionCategory.angry,
          confidence: 0.873,
        ),
        allPredictions: [
          EmotionPrediction(category: EmotionCategory.angry, confidence: 0.873),
        ],
        isUncertain: false,
      );

      final formatted = formatter.format(result);

      // 0.873 * 100 = 87.3 → round() → 87
      expect(formatted.confidencePercent, 87);
    });

    test('신뢰도 반올림이 정확해야 한다', () {
      // 0.555 → 56% (반올림)
      const result = ClassificationSuccess(
        topPrediction: EmotionPrediction(
          category: EmotionCategory.sad,
          confidence: 0.555,
        ),
        allPredictions: [
          EmotionPrediction(category: EmotionCategory.sad, confidence: 0.555),
        ],
        isUncertain: false,
      );

      final formatted = formatter.format(result);

      expect(formatted.confidencePercent, 56);
    });

    test('카테고리가 올바르게 전달되어야 한다', () {
      const result = ClassificationSuccess(
        topPrediction: EmotionPrediction(
          category: EmotionCategory.other,
          confidence: 0.65,
        ),
        allPredictions: [
          EmotionPrediction(category: EmotionCategory.other, confidence: 0.65),
        ],
        isUncertain: false,
      );

      final formatted = formatter.format(result);

      expect(formatted.category, EmotionCategory.other);
    });
  });

  group('ResultFormatterImpl - 불확실 결과', () {
    test('불확실 결과는 "표정이 분명하지 않아요" 문구를 생성해야 한다', () {
      const result = ClassificationSuccess(
        topPrediction: EmotionPrediction(
          category: EmotionCategory.happy,
          confidence: 0.35,
        ),
        allPredictions: [
          EmotionPrediction(category: EmotionCategory.happy, confidence: 0.35),
          EmotionPrediction(category: EmotionCategory.sad, confidence: 0.30),
          EmotionPrediction(category: EmotionCategory.angry, confidence: 0.20),
          EmotionPrediction(category: EmotionCategory.other, confidence: 0.15),
        ],
        isUncertain: true,
      );

      final formatted = formatter.format(result);

      expect(formatted.sentence, '표정이 분명하지 않아요');
      expect(formatted.isUncertain, isTrue);
    });

    test('상위 3개 예측 목록이 포함되어야 한다', () {
      const result = ClassificationSuccess(
        topPrediction: EmotionPrediction(
          category: EmotionCategory.happy,
          confidence: 0.35,
        ),
        allPredictions: [
          EmotionPrediction(category: EmotionCategory.happy, confidence: 0.35),
          EmotionPrediction(category: EmotionCategory.sad, confidence: 0.30),
          EmotionPrediction(category: EmotionCategory.angry, confidence: 0.20),
          EmotionPrediction(category: EmotionCategory.other, confidence: 0.15),
        ],
        isUncertain: true,
      );

      final formatted = formatter.format(result);

      expect(formatted.topThree, isNotNull);
      expect(formatted.topThree!.length, 3);
    });

    test('상위 3개 항목에 올바른 이모지, 한국어명, 신뢰도가 포함되어야 한다', () {
      const result = ClassificationSuccess(
        topPrediction: EmotionPrediction(
          category: EmotionCategory.sad,
          confidence: 0.40,
        ),
        allPredictions: [
          EmotionPrediction(category: EmotionCategory.sad, confidence: 0.40),
          EmotionPrediction(category: EmotionCategory.angry, confidence: 0.30),
          EmotionPrediction(category: EmotionCategory.happy, confidence: 0.20),
          EmotionPrediction(category: EmotionCategory.other, confidence: 0.10),
        ],
        isUncertain: true,
      );

      final formatted = formatter.format(result);
      final topThree = formatted.topThree!;

      // 첫 번째: sad
      expect(topThree[0].emoji, '😢');
      expect(topThree[0].categoryName, '슬픔');
      expect(topThree[0].confidencePercent, 40);

      // 두 번째: angry
      expect(topThree[1].emoji, '😠');
      expect(topThree[1].categoryName, '화남');
      expect(topThree[1].confidencePercent, 30);

      // 세 번째: happy
      expect(topThree[2].emoji, '😊');
      expect(topThree[2].categoryName, '행복');
      expect(topThree[2].confidencePercent, 20);
    });

    test('불확실 결과의 이모지는 최상위 카테고리의 이모지여야 한다', () {
      const result = ClassificationSuccess(
        topPrediction: EmotionPrediction(
          category: EmotionCategory.other,
          confidence: 0.30,
        ),
        allPredictions: [
          EmotionPrediction(category: EmotionCategory.other, confidence: 0.30),
          EmotionPrediction(category: EmotionCategory.happy, confidence: 0.28),
          EmotionPrediction(category: EmotionCategory.sad, confidence: 0.22),
          EmotionPrediction(category: EmotionCategory.angry, confidence: 0.20),
        ],
        isUncertain: true,
      );

      final formatted = formatter.format(result);

      expect(formatted.emoji, '🤔'); // other 카테고리 이모지
    });
  });

  group('ResultFormatterImpl - 이모지 매핑 정확성', () {
    test('angry 카테고리 이모지는 😠이어야 한다', () {
      final result = _createSimpleResult(EmotionCategory.angry, 0.80);
      expect(formatter.format(result).emoji, '😠');
    });

    test('happy 카테고리 이모지는 😊이어야 한다', () {
      final result = _createSimpleResult(EmotionCategory.happy, 0.80);
      expect(formatter.format(result).emoji, '😊');
    });

    test('sad 카테고리 이모지는 😢이어야 한다', () {
      final result = _createSimpleResult(EmotionCategory.sad, 0.80);
      expect(formatter.format(result).emoji, '😢');
    });

    test('other 카테고리 이모지는 🤔이어야 한다', () {
      final result = _createSimpleResult(EmotionCategory.other, 0.80);
      expect(formatter.format(result).emoji, '🤔');
    });
  });
}

/// 테스트용 간단한 분류 결과 생성 헬퍼
ClassificationSuccess _createSimpleResult(
  EmotionCategory category,
  double confidence,
) {
  return ClassificationSuccess(
    topPrediction: EmotionPrediction(
      category: category,
      confidence: confidence,
    ),
    allPredictions: [
      EmotionPrediction(category: category, confidence: confidence),
    ],
    isUncertain: false,
  );
}
