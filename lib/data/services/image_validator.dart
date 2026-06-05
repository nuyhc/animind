import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:animind/domain/models/models.dart';

/// 이미지 유효성 검증기
///
/// 형식, 크기, 해상도를 검증한다.
/// 의미 검증(동물 포함 여부)은 수행하지 않는다.
class ImageValidator {
  /// 최대 파일 크기 (10MB)
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  /// 최소 해상도 (가로/세로 50px)
  static const int minResolution = 50;

  /// 지원 형식 목록
  static const List<String> supportedExtensions = ['jpg', 'jpeg', 'png'];

  /// 이미지 파일의 유효성을 검증한다
  ///
  /// 검증 순서: 형식 → 크기 → 해상도
  /// 첫 번째 실패한 조건에서 즉시 [ValidationFailure]를 반환한다.
  /// 모든 조건을 통과하면 [ValidationSuccess]를 반환한다.
  ValidationResult validate(File imageFile) {
    // 1. 형식 검증
    final formatResult = _validateFormat(imageFile.path);
    if (formatResult != null) return formatResult;

    // 2. 크기 검증
    final sizeResult = _validateFileSize(imageFile);
    if (sizeResult != null) return sizeResult;

    // 3. 해상도 검증
    final resolutionResult = _validateResolution(imageFile);
    if (resolutionResult != null) return resolutionResult;

    return const ValidationSuccess();
  }

  /// 파일 확장자 기반 형식 검증
  ///
  /// JPG, JPEG, PNG만 허용한다.
  ValidationFailure? _validateFormat(String filePath) {
    final extension = _getFileExtension(filePath);
    if (!supportedExtensions.contains(extension)) {
      return const ValidationFailure(
        errorType: ValidationErrorType.unsupportedFormat,
        message: '지원되는 형식은 JPG, PNG입니다',
      );
    }
    return null;
  }

  /// 파일 크기 검증
  ///
  /// 10MB 초과 시 실패를 반환한다.
  ValidationFailure? _validateFileSize(File imageFile) {
    final fileSizeBytes = imageFile.lengthSync();
    if (fileSizeBytes > maxFileSizeBytes) {
      return const ValidationFailure(
        errorType: ValidationErrorType.fileSizeExceeded,
        message: '이미지 크기는 10MB 이하만 가능합니다',
      );
    }
    return null;
  }

  /// 해상도 검증
  ///
  /// 가로 또는 세로가 50px 미만이면 실패를 반환한다.
  ValidationFailure? _validateResolution(File imageFile) {
    final bytes = imageFile.readAsBytesSync();
    final image = img.decodeImage(bytes);

    if (image == null) {
      return const ValidationFailure(
        errorType: ValidationErrorType.unsupportedFormat,
        message: '이미지를 읽을 수 없습니다',
      );
    }

    if (image.width < minResolution || image.height < minResolution) {
      return const ValidationFailure(
        errorType: ValidationErrorType.resolutionTooLow,
        message: '이미지 해상도가 너무 낮습니다 (최소 50×50)',
      );
    }
    return null;
  }

  /// 파일 경로에서 확장자를 소문자로 추출한다
  String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filePath.length - 1) {
      return '';
    }
    return filePath.substring(lastDot + 1).toLowerCase();
  }
}
