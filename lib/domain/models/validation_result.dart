/// 이미지 유효성 검증 결과
sealed class ValidationResult {
  const ValidationResult();
}

/// 유효성 검증 성공
class ValidationSuccess extends ValidationResult {
  const ValidationSuccess();
}

/// 유효성 검증 실패
class ValidationFailure extends ValidationResult {
  final ValidationErrorType errorType;
  final String message;

  const ValidationFailure({required this.errorType, required this.message});
}

/// 유효성 검증 오류 유형
enum ValidationErrorType {
  unsupportedFormat, // 지원하지 않는 형식
  fileSizeExceeded, // 파일 크기 초과 (10MB)
  resolutionTooLow, // 해상도 미달 (50px 미만)
}
