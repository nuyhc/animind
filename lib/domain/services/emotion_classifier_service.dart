import '../models/classification_result.dart';
import '../models/preprocessed_image.dart';

/// 감정 분류 추론을 수행하는 서비스
///
/// 별도의 동물 감지 또는 종 분류는 수행하지 않는다.
/// 형식/크기/해상도 검증을 통과한 모든 이미지는 동일한 4개 감정 분류 흐름으로 처리한다.
abstract class EmotionClassifierService {
  /// 모델을 초기화한다
  Future<void> initialize();

  /// 전처리된 이미지에 대해 감정 분류를 수행한다
  Future<ClassificationResult> classify(PreprocessedImage image);

  /// 모델 리소스를 해제한다
  void dispose();
}
