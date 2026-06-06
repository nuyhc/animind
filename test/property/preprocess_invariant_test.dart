// 전처리 출력 불변조건 속성 테스트
// Feature: animal-emotion-recognition, Property 1: 전처리 출력 불변조건
//
// 임의 크기/픽셀값 이미지에 대해 출력 224x224, 값 범위 [0.0, 1.0] 검증
// **Validates: Requirements 1.3**

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:animind/data/services/preprocessor_service_impl.dart';

void main() {
  late PreprocessorServiceImpl service;

  setUp(() {
    service = PreprocessorServiceImpl();
  });

  /// 임의 크기 및 픽셀값으로 테스트 이미지 생성 헬퍼
  Future<File> createRandomImage(int width, int height, Random rng) async {
    final image = img.Image(width: width, height: height);

    // 임의 픽셀값으로 채우기
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final r = rng.nextInt(256);
        final g = rng.nextInt(256);
        final b = rng.nextInt(256);
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    // 임시 파일로 저장 (PNG 형식)
    final tempDir = Directory.systemTemp;
    final tempFile = File(
      '${tempDir.path}/pbt_preprocess_${width}x${height}_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await tempFile.writeAsBytes(img.encodePng(image));

    return tempFile;
  }

  group(
    'Property 1: 전처리 출력 불변조건',
    () {
      // 속성 기반 테스트: 100회 이상 반복으로 불변조건 검증
      // 임의의 유효 이미지에 대해:
      // (a) 출력 텐서 형태는 항상 [1, 224, 224, 3]
      // (b) 모든 픽셀 값은 0.0 이상 1.0 이하
      test(
        '임의 크기/픽셀값 이미지에 대해 출력 224x224, 값 범위 [0.0, 1.0] 보장',
        () async {
          final rng = Random(42); // 재현 가능한 시드
          const iterations = 100;

          for (var i = 0; i < iterations; i++) {
            // 임의 이미지 크기 생성 (50~2000 범위)
            final width = 50 + rng.nextInt(1951); // 50 ~ 2000
            final height = 50 + rng.nextInt(1951); // 50 ~ 2000

            final imageFile = await createRandomImage(width, height, rng);

            try {
              final result = await service.preprocess(imageFile);

              // (a) 출력 텐서 형태 [1, 224, 224, 3] 검증
              expect(
                result.tensorData.length,
                1,
                reason:
                    '반복 $i (${width}x$height): 배치 차원이 1이어야 한다',
              );
              expect(
                result.tensorData[0].length,
                224,
                reason:
                    '반복 $i (${width}x$height): 높이가 224이어야 한다',
              );
              expect(
                result.tensorData[0][0].length,
                224,
                reason:
                    '반복 $i (${width}x$height): 너비가 224이어야 한다',
              );
              expect(
                result.tensorData[0][0][0].length,
                3,
                reason:
                    '반복 $i (${width}x$height): 채널 수가 3(RGB)이어야 한다',
              );

              // PreprocessedImage의 width/height 속성도 검증
              expect(
                result.width,
                224,
                reason: '반복 $i: width 속성이 224이어야 한다',
              );
              expect(
                result.height,
                224,
                reason: '반복 $i: height 속성이 224이어야 한다',
              );

              // (b) 모든 픽셀 값이 [0.0, 1.0] 범위 내인지 검증
              for (var row = 0; row < 224; row++) {
                for (var col = 0; col < 224; col++) {
                  for (var ch = 0; ch < 3; ch++) {
                    final value = result.tensorData[0][row][col][ch];
                    expect(
                      value,
                      greaterThanOrEqualTo(0.0),
                      reason:
                          '반복 $i (${width}x$height): '
                          '픽셀[$row][$col][$ch] = $value >= 0.0이어야 한다',
                    );
                    expect(
                      value,
                      lessThanOrEqualTo(1.0),
                      reason:
                          '반복 $i (${width}x$height): '
                          '픽셀[$row][$col][$ch] = $value <= 1.0이어야 한다',
                    );
                  }
                }
              }
            } finally {
              // 임시 파일 정리
              if (await imageFile.exists()) {
                await imageFile.delete();
              }
            }
          }
        },
        timeout: const Timeout(Duration(minutes: 10)),
      );
      // Tag: Feature: animal-emotion-recognition, Property 1: 전처리 출력 불변조건
    },
  );
}
