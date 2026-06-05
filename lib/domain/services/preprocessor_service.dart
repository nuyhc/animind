import 'dart:io';

import '../models/preprocessed_image.dart';

/// 이미지 전처리를 담당하는 서비스
abstract class PreprocessorService {
  /// 입력 이미지를 모델 추론용으로 전처리한다
  /// - 224x224 리사이즈
  /// - 0.0~1.0 정규화
  Future<PreprocessedImage> preprocess(File imageFile);
}
