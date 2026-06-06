import 'dart:math';

import 'package:animind/domain/models/classification_result.dart';
import 'package:animind/domain/models/emotion_category.dart';
import 'package:animind/domain/models/emotion_mapping.dart';
import 'package:animind/domain/models/formatted_result.dart';
import 'package:animind/domain/services/result_formatter.dart';

/// [ResultFormatter]의 구현체
///
/// 감정 분류 결과를 한국어 문장으로 변환한다.
/// - 일반 결과: "[감정 표현] 것 같아요" 형식
/// - 불확실 결과: "표정이 분명하지 않아요" + 상위 3개 목록
class ResultFormatterImpl implements ResultFormatter {
  final Random _random;

  /// [random]을 지정하면 테스트 시 결정적 동작을 보장할 수 있다.
  ResultFormatterImpl({Random? random}) : _random = random ?? Random();

  @override
  FormattedResult format(ClassificationSuccess result) {
    final category = result.topPrediction.category;
    final emoji = EmotionMapping.emojis[category]!;
    final confidencePercent = result.topPrediction.confidencePercent;

    if (result.isUncertain) {
      return _formatUncertain(result, emoji, confidencePercent, category);
    }

    return _formatNormal(category, emoji, confidencePercent);
  }

  /// 일반 결과 포맷팅
  ///
  /// 카테고리별 표현 템플릿에서 무작위로 하나를 선택하고
  /// "$template 것 같아요" 구조의 문장을 생성한다.
  FormattedResult _formatNormal(
    EmotionCategory category,
    String emoji,
    int confidencePercent,
  ) {
    final templates = EmotionMapping.expressionTemplates[category]!;
    final template = templates[_random.nextInt(templates.length)];
    final sentence = '$template 것 같아요';

    return FormattedResult(
      sentence: sentence,
      emoji: emoji,
      confidencePercent: confidencePercent,
      category: category,
      isUncertain: false,
    );
  }

  /// 불확실 결과 포맷팅
  ///
  /// 안내 문구와 함께 상위 3개 예측 결과 목록을 생성한다.
  FormattedResult _formatUncertain(
    ClassificationSuccess result,
    String emoji,
    int confidencePercent,
    EmotionCategory category,
  ) {
    const sentence = '표정이 분명하지 않아요';

    final topThree = result.topThreePredictions.map((prediction) {
      return FormattedPrediction(
        emoji: EmotionMapping.emojis[prediction.category]!,
        categoryName: EmotionMapping.koreanNames[prediction.category]!,
        confidencePercent: prediction.confidencePercent,
      );
    }).toList();

    return FormattedResult(
      sentence: sentence,
      emoji: emoji,
      confidencePercent: confidencePercent,
      category: category,
      isUncertain: true,
      topThree: topThree,
    );
  }
}
