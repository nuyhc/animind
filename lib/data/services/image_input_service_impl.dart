import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:animind/domain/models/models.dart';
import 'package:animind/domain/services/image_input_service.dart';
import 'package:animind/data/services/image_validator.dart';

/// 이미지 입력 서비스 구현체
///
/// image_picker 패키지를 통해 카메라/갤러리에서 이미지를 가져오고,
/// permission_handler 패키지로 권한을 관리한다.
class ImageInputServiceImpl implements ImageInputService {
  final ImagePicker _imagePicker;
  final ImageValidator _imageValidator;

  ImageInputServiceImpl({
    ImagePicker? imagePicker,
    ImageValidator? imageValidator,
  })  : _imagePicker = imagePicker ?? ImagePicker(),
        _imageValidator = imageValidator ?? ImageValidator();

  @override
  Future<ImageInputResult?> captureFromCamera() async {
    // 카메라 권한 요청
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      // 권한 거부 시 null 반환 (호출자가 UI 처리)
      return null;
    }

    // 카메라 촬영
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
    );

    // 사용자가 촬영을 취소한 경우 null 반환
    if (pickedFile == null) {
      return null;
    }

    final file = File(pickedFile.path);
    final metadata = await _buildMetadata(file);

    return ImageInputResult(imageFile: file, metadata: metadata);
  }

  @override
  Future<ImageInputResult?> pickFromGallery() async {
    // 갤러리(사진) 권한 요청
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      // 권한 거부 시 null 반환 (호출자가 UI 처리)
      return null;
    }

    // 갤러리에서 이미지 선택
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );

    // 사용자가 선택을 취소한 경우 null 반환
    if (pickedFile == null) {
      return null;
    }

    final file = File(pickedFile.path);
    final metadata = await _buildMetadata(file);

    return ImageInputResult(imageFile: file, metadata: metadata);
  }

  @override
  ValidationResult validateImage(File imageFile) {
    // ImageValidator에 위임
    return _imageValidator.validate(imageFile);
  }

  /// 이미지 파일로부터 메타데이터를 생성한다
  ///
  /// image 패키지를 사용하여 이미지 크기(너비, 높이)를 읽고,
  /// 파일 크기와 확장자 기반 형식을 추출한다.
  Future<ImageMetadata> _buildMetadata(File file) async {
    final bytes = await file.readAsBytes();
    final fileSizeBytes = bytes.length;

    // image 패키지로 이미지 디코딩하여 크기 정보 추출
    final decodedImage = img.decodeImage(bytes);
    final int width = decodedImage?.width ?? 0;
    final int height = decodedImage?.height ?? 0;

    // 확장자로부터 형식 감지
    final format = _detectFormat(file.path);

    return ImageMetadata(
      width: width,
      height: height,
      fileSizeBytes: fileSizeBytes,
      format: format,
      filePath: file.path,
    );
  }

  /// 파일 경로에서 이미지 형식을 감지한다
  ///
  /// 확장자를 기반으로 형식 문자열을 반환한다.
  String _detectFormat(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filePath.length - 1) {
      return 'unknown';
    }
    final extension = filePath.substring(lastDot + 1).toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'jpg';
      case 'png':
        return 'png';
      default:
        return extension;
    }
  }
}
