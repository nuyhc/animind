import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:animind/data/services/image_input_service_impl.dart';

/// 가짜 PermissionHandler 플랫폼 구현체
///
/// 권한 요청 결과를 테스트에서 제어할 수 있도록 한다.
class FakePermissionHandlerPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PermissionHandlerPlatform {
  /// 권한별 반환할 상태를 설정
  Map<Permission, PermissionStatus> permissionResults = {};

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async {
    return permissionResults[permission] ?? PermissionStatus.denied;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    final result = <Permission, PermissionStatus>{};
    for (final permission in permissions) {
      result[permission] =
          permissionResults[permission] ?? PermissionStatus.denied;
    }
    return result;
  }

  @override
  Future<bool> shouldShowRequestPermissionRationale(
    Permission permission,
  ) async {
    return false;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) async {
    return ServiceStatus.enabled;
  }
}

/// 가짜 ImagePicker 플랫폼 구현체
///
/// 이미지 선택/촬영 결과를 테스트에서 제어할 수 있도록 한다.
class FakeImagePickerPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements ImagePickerPlatform {
  /// pickImage 호출 시 반환할 파일 (null이면 취소)
  XFile? pickImageResult;

  /// 마지막 호출에 전달된 픽커 옵션 (해상도 제한 검증용)
  ImagePickerOptions? lastOptions;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    lastOptions = options;
    return pickImageResult;
  }

  // 레거시 메서드도 오버라이드
  @override
  Future<PickedFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    if (pickImageResult == null) return null;
    return PickedFile(pickImageResult!.path);
  }
}

void main() {
  late ImageInputServiceImpl service;
  late FakePermissionHandlerPlatform fakePermissionHandler;
  late FakeImagePickerPlatform fakeImagePicker;

  /// 테스트용 임시 이미지 파일 생성
  Future<File> createTestImage({
    int width = 100,
    int height = 100,
  }) async {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(128, 64, 32));

    final tempDir = Directory.systemTemp;
    final tempFile = File(
      '${tempDir.path}/test_input_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await tempFile.writeAsBytes(img.encodeJpg(image));
    return tempFile;
  }

  setUp(() {
    // 가짜 플랫폼 인터페이스 설정
    fakePermissionHandler = FakePermissionHandlerPlatform();
    PermissionHandlerPlatform.instance = fakePermissionHandler;

    fakeImagePicker = FakeImagePickerPlatform();
    ImagePickerPlatform.instance = fakeImagePicker;

    service = ImageInputServiceImpl();
  });

  group('ImageInputServiceImpl - 카메라 촬영', () {
    test('카메라 촬영 취소 시 null을 반환하고 오류가 발생하지 않아야 한다', () async {
      // 권한은 허용, 촬영은 취소
      fakePermissionHandler.permissionResults = {
        Permission.camera: PermissionStatus.granted,
      };
      fakeImagePicker.pickImageResult = null;

      final result = await service.captureFromCamera();

      // 취소 시 null 반환, 오류 없음 (Requirements 1.7)
      expect(result, isNull);
    });

    test('카메라 권한 거부 시 null을 반환해야 한다', () async {
      // 카메라 권한 거부
      fakePermissionHandler.permissionResults = {
        Permission.camera: PermissionStatus.denied,
      };

      final result = await service.captureFromCamera();

      // 권한 거부 시 null 반환 (Requirements 1.6)
      expect(result, isNull);
    });

    test('카메라 권한이 영구 거부 상태에서도 null을 반환해야 한다', () async {
      // 카메라 권한 영구 거부
      fakePermissionHandler.permissionResults = {
        Permission.camera: PermissionStatus.permanentlyDenied,
      };

      final result = await service.captureFromCamera();

      // 영구 거부도 null 반환 (Requirements 1.6)
      expect(result, isNull);
    });

    test('카메라 촬영 성공 시 유효한 ImageInputResult를 반환해야 한다', () async {
      // 테스트 이미지 준비
      final testImage = await createTestImage(width: 200, height: 150);

      try {
        // 권한 허용 + 이미지 촬영 성공
        fakePermissionHandler.permissionResults = {
          Permission.camera: PermissionStatus.granted,
        };
        fakeImagePicker.pickImageResult = XFile(testImage.path);

        final result = await service.captureFromCamera();

        // 유효한 결과 반환
        expect(result, isNotNull);
        expect(result!.imageFile.path, equals(testImage.path));
        expect(result.metadata.width, equals(200));
        expect(result.metadata.height, equals(150));
        expect(result.metadata.format, equals('jpg'));
        expect(result.metadata.fileSizeBytes, greaterThan(0));
        expect(result.metadata.filePath, equals(testImage.path));
      } finally {
        if (await testImage.exists()) {
          await testImage.delete();
        }
      }
    });

    test('카메라 촬영 시 픽커에 해상도 제한을 전달해야 한다', () async {
      final testImage = await createTestImage();

      try {
        fakePermissionHandler.permissionResults = {
          Permission.camera: PermissionStatus.granted,
        };
        fakeImagePicker.pickImageResult = XFile(testImage.path);

        await service.captureFromCamera();

        // 고해상도 원본 유입으로 인한 메모리 급증 방지 (회귀 방지)
        expect(
          fakeImagePicker.lastOptions?.maxWidth,
          equals(ImageInputServiceImpl.maxPickDimension),
        );
        expect(
          fakeImagePicker.lastOptions?.maxHeight,
          equals(ImageInputServiceImpl.maxPickDimension),
        );
      } finally {
        if (await testImage.exists()) {
          await testImage.delete();
        }
      }
    });
  });

  group('ImageInputServiceImpl - 갤러리 선택', () {
    test('갤러리 선택 취소 시 null을 반환하고 오류가 발생하지 않아야 한다', () async {
      // 권한은 허용, 선택은 취소
      fakePermissionHandler.permissionResults = {
        Permission.photos: PermissionStatus.granted,
      };
      fakeImagePicker.pickImageResult = null;

      final result = await service.pickFromGallery();

      // 취소 시 null 반환, 오류 없음 (Requirements 1.7)
      expect(result, isNull);
    });

    test('갤러리 선택 시 픽커에 해상도 제한을 전달해야 한다', () async {
      final testImage = await createTestImage();

      try {
        fakePermissionHandler.permissionResults = {
          Permission.photos: PermissionStatus.granted,
        };
        fakeImagePicker.pickImageResult = XFile(testImage.path);

        await service.pickFromGallery();

        // 고해상도 원본 유입으로 인한 메모리 급증 방지 (회귀 방지)
        expect(
          fakeImagePicker.lastOptions?.maxWidth,
          equals(ImageInputServiceImpl.maxPickDimension),
        );
        expect(
          fakeImagePicker.lastOptions?.maxHeight,
          equals(ImageInputServiceImpl.maxPickDimension),
        );
      } finally {
        if (await testImage.exists()) {
          await testImage.delete();
        }
      }
    });

    test('갤러리/사진 권한 거부 시 null을 반환해야 한다', () async {
      // 사진 접근 권한 거부
      fakePermissionHandler.permissionResults = {
        Permission.photos: PermissionStatus.denied,
      };

      final result = await service.pickFromGallery();

      // 권한 거부 시 null 반환 (Requirements 1.6)
      expect(result, isNull);
    });

    test('갤러리 권한이 영구 거부 상태에서도 null을 반환해야 한다', () async {
      // 사진 접근 권한 영구 거부
      fakePermissionHandler.permissionResults = {
        Permission.photos: PermissionStatus.permanentlyDenied,
      };

      final result = await service.pickFromGallery();

      // 영구 거부도 null 반환 (Requirements 1.6)
      expect(result, isNull);
    });

    test('갤러리 선택 성공 시 유효한 ImageInputResult를 반환해야 한다', () async {
      // 테스트 PNG 이미지 준비
      final image = img.Image(width: 300, height: 250);
      img.fill(image, color: img.ColorRgb8(0, 128, 255));

      final tempDir = Directory.systemTemp;
      final testImage = File(
        '${tempDir.path}/test_gallery_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await testImage.writeAsBytes(img.encodePng(image));

      try {
        // 권한 허용 + 이미지 선택 성공
        fakePermissionHandler.permissionResults = {
          Permission.photos: PermissionStatus.granted,
        };
        fakeImagePicker.pickImageResult = XFile(testImage.path);

        final result = await service.pickFromGallery();

        // 유효한 결과 반환
        expect(result, isNotNull);
        expect(result!.imageFile.path, equals(testImage.path));
        expect(result.metadata.width, equals(300));
        expect(result.metadata.height, equals(250));
        expect(result.metadata.format, equals('png'));
        expect(result.metadata.fileSizeBytes, greaterThan(0));
        expect(result.metadata.filePath, equals(testImage.path));
      } finally {
        if (await testImage.exists()) {
          await testImage.delete();
        }
      }
    });
  });
}
