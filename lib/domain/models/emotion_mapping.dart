import 'emotion_category.dart';

/// 감정 카테고리별 한국어 표현 및 이모지 매핑 (4개 카테고리)
///
/// 각 감정 카테고리에 대응하는 이모지, 한국어 카테고리명,
/// 결과 문장에 사용할 표현 템플릿을 정의한다.
class EmotionMapping {
  EmotionMapping._();

  /// 감정 카테고리별 이모지
  static const Map<EmotionCategory, String> emojis = {
    EmotionCategory.angry: '😠',
    EmotionCategory.happy: '😊',
    EmotionCategory.sad: '😢',
    EmotionCategory.other: '🤔',
  };

  /// 감정 카테고리별 한국어 이름
  static const Map<EmotionCategory, String> koreanNames = {
    EmotionCategory.angry: '화남',
    EmotionCategory.happy: '행복',
    EmotionCategory.sad: '슬픔',
    EmotionCategory.other: '기타',
  };

  /// 각 카테고리별 최소 3개의 한국어 표현 변형
  static const Map<EmotionCategory, List<String>> expressionTemplates = {
    EmotionCategory.angry: [
      '화가 난',
      '짜증이 난',
      '기분이 나쁜',
    ],
    EmotionCategory.happy: [
      '행복해하는',
      '기분이 좋은',
      '즐거워하는',
    ],
    EmotionCategory.sad: [
      '슬퍼하는',
      '우울해하는',
      '기운이 없는',
    ],
    EmotionCategory.other: [
      '알 수 없는 표정의',
      '독특한 표정의',
      '묘한 표정의',
    ],
  };
}
