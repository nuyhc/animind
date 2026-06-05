/// 입력 이미지의 메타데이터
class ImageMetadata {
  /// 원본 너비 (픽셀)
  final int width;

  /// 원본 높이 (픽셀)
  final int height;

  /// 파일 크기 (바이트)
  final int fileSizeBytes;

  /// 파일 형식 (jpg, png)
  final String format;

  /// 파일 경로
  final String filePath;

  const ImageMetadata({
    required this.width,
    required this.height,
    required this.fileSizeBytes,
    required this.format,
    required this.filePath,
  });

  /// 파일 크기를 MB 단위로 반환
  double get fileSizeMB => fileSizeBytes / (1024 * 1024);
}
