import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:animind/domain/models/models.dart';
import 'package:animind/domain/services/preprocessor_service.dart';

/// [PreprocessorService]의 구현체
///
/// 이미지 파일을 모델 추론용으로 전처리한다:
/// 1. 이미지 디코딩
/// 2. 224x224 리사이즈 (바이리니어 보간법)
/// 3. 픽셀값 0.0~1.0 정규화
/// 4. 텐서 데이터 [1, 224, 224, 3] 형태로 변환
class PreprocessorServiceImpl implements PreprocessorService {
  /// 모델 입력 이미지 크기
  static const int targetSize = 224;

  @override
  Future<PreprocessedImage> preprocess(File imageFile) async {
    // 이미지 파일 바이트 읽기
    final bytes = await imageFile.readAsBytes();

    // 이미지 디코딩
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      throw Exception('이미지를 디코딩할 수 없습니다: ${imageFile.path}');
    }

    // 224x224로 리사이즈 (바이리니어 보간법)
    final resizedImage = img.copyResize(
      decodedImage,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.linear,
    );

    // 텐서 데이터 생성: [1, 224, 224, 3] (배치, 높이, 너비, 채널 RGB)
    final tensorData = _imageToTensor(resizedImage);

    return PreprocessedImage(tensorData: tensorData);
  }

  /// 리사이즈된 이미지를 [1, 224, 224, 3] 텐서로 변환한다
  ///
  /// 각 픽셀의 RGB 값을 0~255에서 0.0~1.0으로 정규화한다
  List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    // 높이 x 너비 x 채널(RGB) 3차원 배열 생성
    final batch = List.generate(targetSize, (y) {
      return List.generate(targetSize, (x) {
        final pixel = image.getPixel(x, y);

        // RGB 값을 0.0~1.0으로 정규화
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        return [r, g, b];
      });
    });

    // 배치 차원 추가: [1, 224, 224, 3]
    return [batch];
  }
}
