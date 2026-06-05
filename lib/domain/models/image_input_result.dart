import 'dart:io';

import 'image_metadata.dart';

/// 이미지 입력 결과
class ImageInputResult {
  final File imageFile;
  final ImageMetadata metadata;

  const ImageInputResult({required this.imageFile, required this.metadata});
}
