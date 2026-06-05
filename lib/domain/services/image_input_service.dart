import 'dart:io';

import '../models/image_input_result.dart';
import '../models/validation_result.dart';

/// 이미지 입력 처리를 담당하는 서비스
abstract class ImageInputService {
  /// 카메라로부터 이미지를 캡처한다
  /// [ImageInputResult]를 반환하며, 취소 시 null을 반환
  Future<ImageInputResult?> captureFromCamera();

  /// 갤러리에서 이미지를 선택한다
  /// [ImageInputResult]를 반환하며, 취소 시 null을 반환
  Future<ImageInputResult?> pickFromGallery();

  /// 이미지 유효성을 검증한다
  /// 형식, 크기, 해상도 검증 수행
  ValidationResult validateImage(File imageFile);
}
