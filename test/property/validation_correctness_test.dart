// 속성 기반 테스트: 이미지 유효성 검증 정확성
// Feature: animal-emotion-recognition, Property 2: 이미지 유효성 검증 정확성
//
// **Validates: Requirements 1.4, 1.5, 1.8**
//
// 임의 형식/크기/해상도 조합에 대해:
// (a) 형식이 JPG/PNG가 아니면 unsupportedFormat으로 거부
// (b) 파일 크기 > 10MB → fileSizeExceeded로 거부
// (c) 가로 또는 세로 < 50px → resolutionTooLow로 거부
// (d) 세 조건 모두 만족 시에만 유효로 판정

import 'dart:io';
import 'dart:typed_data';

import 'package:glados/glados.dart';
import 'package:image/image.dart' as img;
import 'package:animind/data/services/image_validator.dart';
import 'package:animind/domain/models/models.dart';

void main() {
  late ImageValidator validator;
  late Directory tempDir;

  setUp(() {
    validator = ImageValidator();
    tempDir = Directory.systemTemp.createTempSync('pbt_validation_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // 비지원 형식 목록 (테스트용)
  const unsupportedExtensions = [
    'gif',
    'bmp',
    'tiff',
    'webp',
    'svg',
    'heic',
    'raw',
    'ico',
    'tga',
    'psd',
  ];

  /// 유효한 PNG 이미지 바이트를 생성한다
  Uint8List createValidPngBytes(int width, int height) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(128, 128, 128));
    return Uint8List.fromList(img.encodePng(image));
  }

  /// 유효한 JPG 이미지 바이트를 생성한다
  Uint8List createValidJpgBytes(int width, int height) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(128, 128, 128));
    return Uint8List.fromList(img.encodeJpg(image));
  }

  group('Property 2: 이미지 유효성 검증 정확성', () {
    // (a) 형식이 JPG 또는 PNG가 아니면 unsupportedFormat으로 거부
    Glados(any.intInRange(0, unsupportedExtensions.length - 1),
            ExploreConfig(numRuns: 100))
        .test(
      '(a) 비지원 형식은 항상 unsupportedFormat으로 거부된다',
      (extIndex) {
        final ext = unsupportedExtensions[extIndex];
        // 유효한 이미지 내용으로 파일을 생성하되 확장자만 비지원으로 설정
        final bytes = createValidPngBytes(100, 100);
        final file = File('${tempDir.path}/test_${extIndex}_$ext.$ext');
        file.writeAsBytesSync(bytes);

        final result = validator.validate(file);

        expect(result, isA<ValidationFailure>());
        final failure = result as ValidationFailure;
        expect(failure.errorType, ValidationErrorType.unsupportedFormat);

        // 정리
        if (file.existsSync()) file.deleteSync();
      },
    );

    // (b) 파일 크기 > 10MB → fileSizeExceeded로 거부
    // 10MB 초과 ~ 15MB 사이의 임의 크기를 생성하여 테스트
    Glados(any.intInRange(
      ImageValidator.maxFileSizeBytes + 1,
      ImageValidator.maxFileSizeBytes + (5 * 1024 * 1024), // +5MB
    ), ExploreConfig(numRuns: 100))
        .test(
      '(b) 10MB 초과 파일은 항상 fileSizeExceeded로 거부된다',
      (fileSize) {
        // 지원 형식(png)으로 큰 파일을 생성
        final bytes = Uint8List(fileSize);
        final file = File('${tempDir.path}/large_$fileSize.png');
        file.writeAsBytesSync(bytes);

        final result = validator.validate(file);

        expect(result, isA<ValidationFailure>());
        final failure = result as ValidationFailure;
        expect(failure.errorType, ValidationErrorType.fileSizeExceeded);

        // 정리
        if (file.existsSync()) file.deleteSync();
      },
    );

    // (c) 가로 또는 세로 < 50px → resolutionTooLow로 거부
    // 1~49px 범위의 가로 또는 세로를 생성하여 테스트
    Glados2(
      any.intInRange(1, 49), // 낮은 해상도 차원 (1~49)
      any.intInRange(50, 500), // 정상 해상도 차원 (50~500)
      ExploreConfig(numRuns: 100),
    ).test(
      '(c) 가로가 50px 미만이면 resolutionTooLow로 거부된다',
      (lowDim, normalDim) {
        // 가로가 낮은 이미지 생성
        final bytes = createValidPngBytes(lowDim, normalDim);
        final file = File('${tempDir.path}/low_w_${lowDim}_$normalDim.png');
        file.writeAsBytesSync(bytes);

        final result = validator.validate(file);

        expect(result, isA<ValidationFailure>());
        final failure = result as ValidationFailure;
        expect(failure.errorType, ValidationErrorType.resolutionTooLow);

        // 정리
        if (file.existsSync()) file.deleteSync();
      },
    );

    Glados2(
      any.intInRange(50, 500), // 정상 가로 (50~500)
      any.intInRange(1, 49), // 낮은 세로 (1~49)
      ExploreConfig(numRuns: 100),
    ).test(
      '(c) 세로가 50px 미만이면 resolutionTooLow로 거부된다',
      (normalDim, lowDim) {
        // 세로가 낮은 이미지 생성
        final bytes = createValidPngBytes(normalDim, lowDim);
        final file = File('${tempDir.path}/low_h_${normalDim}_$lowDim.png');
        file.writeAsBytesSync(bytes);

        final result = validator.validate(file);

        expect(result, isA<ValidationFailure>());
        final failure = result as ValidationFailure;
        expect(failure.errorType, ValidationErrorType.resolutionTooLow);

        // 정리
        if (file.existsSync()) file.deleteSync();
      },
    );

    // (d) 세 조건 모두 만족하면 유효로 판정
    // 지원 형식 + 10MB 이하 + 50px 이상의 조합
    Glados2(
      any.intInRange(50, 300), // 가로 (50~300)
      any.intInRange(50, 300), // 세로 (50~300)
      ExploreConfig(numRuns: 100),
    ).test(
      '(d) 지원 형식이고 크기/해상도 조건을 만족하면 유효로 판정된다',
      (width, height) {
        // PNG 형식으로 유효한 이미지 생성
        final bytes = createValidPngBytes(width, height);
        final file = File('${tempDir.path}/valid_${width}_$height.png');
        file.writeAsBytesSync(bytes);

        // 파일 크기가 10MB 이하인지 확인 (이 범위의 이미지는 항상 이하임)
        expect(file.lengthSync() <= ImageValidator.maxFileSizeBytes, isTrue);

        final result = validator.validate(file);
        expect(result, isA<ValidationSuccess>());

        // 정리
        if (file.existsSync()) file.deleteSync();
      },
    );

    // (d) JPG 형식으로도 유효 판정 확인
    Glados2(
      any.intInRange(50, 300), // 가로 (50~300)
      any.intInRange(50, 300), // 세로 (50~300)
      ExploreConfig(numRuns: 100),
    ).test(
      '(d) JPG 형식이고 크기/해상도 조건을 만족하면 유효로 판정된다',
      (width, height) {
        // JPG 형식으로 유효한 이미지 생성
        final bytes = createValidJpgBytes(width, height);
        final file = File('${tempDir.path}/valid_${width}_$height.jpg');
        file.writeAsBytesSync(bytes);

        // 파일 크기가 10MB 이하인지 확인
        expect(file.lengthSync() <= ImageValidator.maxFileSizeBytes, isTrue);

        final result = validator.validate(file);
        expect(result, isA<ValidationSuccess>());

        // 정리
        if (file.existsSync()) file.deleteSync();
      },
    );
  });
}
