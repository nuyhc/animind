import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:animind/data/services/image_validator.dart';
import 'package:animind/domain/models/models.dart';

void main() {
  late ImageValidator validator;
  late Directory tempDir;

  setUp(() {
    validator = ImageValidator();
    tempDir = Directory.systemTemp.createTempSync('image_validator_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// 테스트용 PNG 이미지를 생성한다
  File createTestPng({
    required int width,
    required int height,
    String? fileName,
  }) {
    final image = img.Image(width: width, height: height);
    // 빨간색으로 채운다
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    final bytes = img.encodePng(image);
    final file = File('${tempDir.path}/${fileName ?? 'test.png'}');
    file.writeAsBytesSync(bytes);
    return file;
  }

  /// 테스트용 JPG 이미지를 생성한다
  File createTestJpg({
    required int width,
    required int height,
    String? fileName,
  }) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(0, 255, 0));
    final bytes = img.encodeJpg(image);
    final file = File('${tempDir.path}/${fileName ?? 'test.jpg'}');
    file.writeAsBytesSync(bytes);
    return file;
  }

  group('ImageValidator - 형식 검증', () {
    test('JPG 형식은 통과한다', () {
      final file = createTestJpg(width: 100, height: 100);
      final result = validator.validate(file);
      expect(result, isA<ValidationSuccess>());
    });

    test('JPEG 확장자도 통과한다', () {
      final file = createTestJpg(
        width: 100,
        height: 100,
        fileName: 'test.jpeg',
      );
      final result = validator.validate(file);
      expect(result, isA<ValidationSuccess>());
    });

    test('PNG 형식은 통과한다', () {
      final file = createTestPng(width: 100, height: 100);
      final result = validator.validate(file);
      expect(result, isA<ValidationSuccess>());
    });

    test('지원하지 않는 형식(GIF)은 unsupportedFormat 오류를 반환한다', () {
      // GIF 확장자 파일 생성 (내용은 PNG이지만 확장자로 판단)
      final image = img.Image(width: 100, height: 100);
      final bytes = img.encodePng(image);
      final file = File('${tempDir.path}/test.gif');
      file.writeAsBytesSync(bytes);

      final result = validator.validate(file);
      expect(result, isA<ValidationFailure>());
      final failure = result as ValidationFailure;
      expect(failure.errorType, ValidationErrorType.unsupportedFormat);
    });

    test('지원하지 않는 형식(BMP)은 unsupportedFormat 오류를 반환한다', () {
      final image = img.Image(width: 100, height: 100);
      final bytes = img.encodePng(image);
      final file = File('${tempDir.path}/test.bmp');
      file.writeAsBytesSync(bytes);

      final result = validator.validate(file);
      expect(result, isA<ValidationFailure>());
      final failure = result as ValidationFailure;
      expect(failure.errorType, ValidationErrorType.unsupportedFormat);
    });

    test('확장자가 없는 파일은 unsupportedFormat 오류를 반환한다', () {
      final image = img.Image(width: 100, height: 100);
      final bytes = img.encodePng(image);
      final file = File('${tempDir.path}/noextension');
      file.writeAsBytesSync(bytes);

      final result = validator.validate(file);
      expect(result, isA<ValidationFailure>());
      final failure = result as ValidationFailure;
      expect(failure.errorType, ValidationErrorType.unsupportedFormat);
    });

    test('대문자 확장자(JPG → jpg)도 통과한다', () {
      final file = createTestJpg(
        width: 100,
        height: 100,
        fileName: 'test.JPG',
      );
      final result = validator.validate(file);
      expect(result, isA<ValidationSuccess>());
    });
  });

  group('ImageValidator - 크기 검증', () {
    test('10MB 이하 파일은 통과한다', () {
      final file = createTestPng(width: 100, height: 100);
      final result = validator.validate(file);
      expect(result, isA<ValidationSuccess>());
    });

    test('10MB 초과 파일은 fileSizeExceeded 오류를 반환한다', () {
      // 10MB를 넘는 파일을 생성한다
      final file = File('${tempDir.path}/large.png');
      final largeBytes = Uint8List(11 * 1024 * 1024); // 11MB
      // PNG 헤더를 포함한 유효한 이미지를 만들기 어려우므로
      // 큰 이미지를 만들어 테스트한다
      final image = img.Image(width: 3000, height: 3000);
      img.fill(image, color: img.ColorRgb8(128, 128, 128));
      final bytes = img.encodePng(image, level: 0); // 무압축으로 크기 키움

      // 실제 10MB가 넘지 않을 수 있으므로 더미 데이터로 대체
      file.writeAsBytesSync(largeBytes);

      // 확장자가 png이므로 형식은 통과하지만 크기에서 실패한다
      final result = validator.validate(file);
      expect(result, isA<ValidationFailure>());
      final failure = result as ValidationFailure;
      expect(failure.errorType, ValidationErrorType.fileSizeExceeded);
    });
  });

  group('ImageValidator - 해상도 검증', () {
    test('50x50 이상 이미지는 통과한다', () {
      final file = createTestPng(width: 50, height: 50);
      final result = validator.validate(file);
      expect(result, isA<ValidationSuccess>());
    });

    test('가로 49px 이미지는 resolutionTooLow 오류를 반환한다', () {
      final file = createTestPng(width: 49, height: 100);
      final result = validator.validate(file);
      expect(result, isA<ValidationFailure>());
      final failure = result as ValidationFailure;
      expect(failure.errorType, ValidationErrorType.resolutionTooLow);
    });

    test('세로 49px 이미지는 resolutionTooLow 오류를 반환한다', () {
      final file = createTestPng(width: 100, height: 49);
      final result = validator.validate(file);
      expect(result, isA<ValidationFailure>());
      final failure = result as ValidationFailure;
      expect(failure.errorType, ValidationErrorType.resolutionTooLow);
    });

    test('1x1 이미지는 resolutionTooLow 오류를 반환한다', () {
      final file = createTestPng(width: 1, height: 1);
      final result = validator.validate(file);
      expect(result, isA<ValidationFailure>());
      final failure = result as ValidationFailure;
      expect(failure.errorType, ValidationErrorType.resolutionTooLow);
    });

    test('큰 해상도(1920x1080) 이미지는 통과한다', () {
      final file = createTestJpg(width: 1920, height: 1080);
      final result = validator.validate(file);
      expect(result, isA<ValidationSuccess>());
    });
  });

  group('ImageValidator - 검증 우선순위', () {
    test('형식이 잘못되면 크기/해상도와 관계없이 형식 오류를 반환한다', () {
      final image = img.Image(width: 10, height: 10);
      final bytes = img.encodePng(image);
      final file = File('${tempDir.path}/test.gif');
      file.writeAsBytesSync(bytes);

      final result = validator.validate(file);
      expect(result, isA<ValidationFailure>());
      final failure = result as ValidationFailure;
      expect(failure.errorType, ValidationErrorType.unsupportedFormat);
    });
  });

  group('ImageValidator - 의미 검증 미수행', () {
    test('동물이 없는 단색 이미지도 검증을 통과한다', () {
      // 동물이 포함되지 않은 단순 빨간색 이미지
      final file = createTestPng(width: 200, height: 200);
      final result = validator.validate(file);
      expect(result, isA<ValidationSuccess>());
    });
  });
}
