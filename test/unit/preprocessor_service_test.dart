import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:animind/data/services/preprocessor_service_impl.dart';

void main() {
  late PreprocessorServiceImpl service;

  setUp(() {
    service = PreprocessorServiceImpl();
  });

  group('PreprocessorServiceImpl', () {
    /// 테스트용 임시 이미지 파일 생성 헬퍼
    Future<File> createTestImage({
      int width = 100,
      int height = 100,
      img.Color? fillColor,
    }) async {
      final image = img.Image(width: width, height: height);

      // 지정된 색상으로 채우기 (기본: 빨간색)
      final color = fillColor ?? img.ColorRgb8(255, 0, 0);
      img.fill(image, color: color);

      // 임시 파일로 저장
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/test_image_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(img.encodePng(image));

      return tempFile;
    }

    test('출력 텐서 크기가 [1, 224, 224, 3]이어야 한다', () async {
      final imageFile = await createTestImage(width: 300, height: 200);

      try {
        final result = await service.preprocess(imageFile);

        // 배치 차원
        expect(result.tensorData.length, 1);
        // 높이
        expect(result.tensorData[0].length, 224);
        // 너비
        expect(result.tensorData[0][0].length, 224);
        // 채널 (RGB)
        expect(result.tensorData[0][0][0].length, 3);
      } finally {
        await imageFile.delete();
      }
    });

    test('출력 이미지 크기가 224x224이어야 한다', () async {
      final imageFile = await createTestImage(width: 640, height: 480);

      try {
        final result = await service.preprocess(imageFile);

        expect(result.width, 224);
        expect(result.height, 224);
      } finally {
        await imageFile.delete();
      }
    });

    test('픽셀값이 0.0~1.0 범위로 정규화되어야 한다', () async {
      // 흰색 이미지 (모든 픽셀 255)
      final imageFile = await createTestImage(
        fillColor: img.ColorRgb8(255, 255, 255),
      );

      try {
        final result = await service.preprocess(imageFile);

        // 모든 픽셀 확인
        for (final row in result.tensorData[0]) {
          for (final pixel in row) {
            for (final channel in pixel) {
              expect(channel, greaterThanOrEqualTo(0.0));
              expect(channel, lessThanOrEqualTo(1.0));
            }
          }
        }
      } finally {
        await imageFile.delete();
      }
    });

    test('흰색 이미지의 모든 채널값이 1.0이어야 한다', () async {
      final imageFile = await createTestImage(
        fillColor: img.ColorRgb8(255, 255, 255),
      );

      try {
        final result = await service.preprocess(imageFile);

        final pixel = result.tensorData[0][0][0];
        expect(pixel[0], closeTo(1.0, 0.01)); // R
        expect(pixel[1], closeTo(1.0, 0.01)); // G
        expect(pixel[2], closeTo(1.0, 0.01)); // B
      } finally {
        await imageFile.delete();
      }
    });

    test('검은색 이미지의 모든 채널값이 0.0이어야 한다', () async {
      final imageFile = await createTestImage(
        fillColor: img.ColorRgb8(0, 0, 0),
      );

      try {
        final result = await service.preprocess(imageFile);

        final pixel = result.tensorData[0][0][0];
        expect(pixel[0], closeTo(0.0, 0.01)); // R
        expect(pixel[1], closeTo(0.0, 0.01)); // G
        expect(pixel[2], closeTo(0.0, 0.01)); // B
      } finally {
        await imageFile.delete();
      }
    });

    test('RGB 색상이 올바르게 정규화되어야 한다', () async {
      // 빨간색 이미지 (R=255, G=0, B=0)
      final imageFile = await createTestImage(
        fillColor: img.ColorRgb8(255, 0, 0),
      );

      try {
        final result = await service.preprocess(imageFile);

        final pixel = result.tensorData[0][112][112]; // 중앙 픽셀
        expect(pixel[0], closeTo(1.0, 0.01)); // R = 1.0
        expect(pixel[1], closeTo(0.0, 0.01)); // G = 0.0
        expect(pixel[2], closeTo(0.0, 0.01)); // B = 0.0
      } finally {
        await imageFile.delete();
      }
    });

    test('작은 이미지도 224x224로 확대되어야 한다', () async {
      final imageFile = await createTestImage(width: 50, height: 50);

      try {
        final result = await service.preprocess(imageFile);

        expect(result.tensorData[0].length, 224);
        expect(result.tensorData[0][0].length, 224);
      } finally {
        await imageFile.delete();
      }
    });

    test('큰 이미지도 224x224로 축소되어야 한다', () async {
      final imageFile = await createTestImage(width: 1920, height: 1080);

      try {
        final result = await service.preprocess(imageFile);

        expect(result.tensorData[0].length, 224);
        expect(result.tensorData[0][0].length, 224);
      } finally {
        await imageFile.delete();
      }
    });

    test('JPG 형식 이미지도 처리할 수 있어야 한다', () async {
      final image = img.Image(width: 100, height: 100);
      img.fill(image, color: img.ColorRgb8(128, 64, 192));

      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/test_image_jpg_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(img.encodeJpg(image));

      try {
        final result = await service.preprocess(tempFile);

        expect(result.tensorData.length, 1);
        expect(result.tensorData[0].length, 224);
        expect(result.width, 224);
        expect(result.height, 224);
      } finally {
        await tempFile.delete();
      }
    });

    test('디코딩 불가능한 파일은 예외를 던져야 한다', () async {
      final tempDir = Directory.systemTemp;
      final invalidFile = File(
        '${tempDir.path}/invalid_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await invalidFile.writeAsBytes([0, 1, 2, 3, 4, 5]);

      await expectLater(
        () => service.preprocess(invalidFile),
        throwsException,
      );

      // cleanup - 파일 잠금이 풀린 후 삭제 시도
      try {
        if (await invalidFile.exists()) {
          await invalidFile.delete();
        }
      } catch (_) {
        // 파일 삭제 실패는 무시 (OS 잠금)
      }
    });
  });
}
