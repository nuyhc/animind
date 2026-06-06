import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animind/domain/models/models.dart';
import 'package:animind/presentation/providers/memory_warning_provider.dart';
import 'package:animind/presentation/providers/service_providers.dart';

/// 분석 상태를 나타내는 sealed class
///
/// 각 상태는 UI에서 구분하여 표시한다.
sealed class AnalysisState {
  const AnalysisState();
}

/// 초기 대기 상태
class AnalysisIdle extends AnalysisState {
  const AnalysisIdle();
}

/// 분석 진행 중 상태
class AnalysisAnalyzing extends AnalysisState {
  /// 입력 이미지 미리보기용 파일
  final File? imageFile;

  const AnalysisAnalyzing({this.imageFile});
}

/// 분석 성공 상태 (신뢰도 50% 이상)
class AnalysisSuccess extends AnalysisState {
  final FormattedResult result;
  final File imageFile;

  const AnalysisSuccess({required this.result, required this.imageFile});
}

/// 불확실 결과 상태 (신뢰도 50% 미만)
class AnalysisUncertain extends AnalysisState {
  final FormattedResult result;
  final File imageFile;

  const AnalysisUncertain({required this.result, required this.imageFile});
}

/// 오류 상태
class AnalysisError extends AnalysisState {
  final String message;

  /// 재시도를 위한 입력 이미지 보존
  final File? imageFile;

  const AnalysisError({required this.message, this.imageFile});
}

/// 권한 거부 상태
class AnalysisPermissionDenied extends AnalysisState {
  final String message;

  const AnalysisPermissionDenied({
    this.message = '카메라/갤러리 사용을 위해 권한이 필요합니다',
  });
}

/// 메모리 부족 상태
class AnalysisMemoryInsufficient extends AnalysisState {
  final String message;

  const AnalysisMemoryInsufficient({
    this.message = '메모리 부족으로 분석을 수행할 수 없습니다',
  });
}

/// 분석 흐름을 관리하는 Notifier
///
/// 이미지 입력 → 검증 → 메모리 확인 → 전처리 → 분류 → 포맷 → 결과 표시 → 이력 저장
/// 각 단계에서 실패 시 적절한 오류 상태로 전환하며, 재시도를 지원한다.
class AnalysisNotifier extends Notifier<AnalysisState> {
  @override
  AnalysisState build() => const AnalysisIdle();

  /// 카메라 촬영을 통한 분석 시작
  Future<void> analyzeFromCamera() async {
    final imageInputService = ref.read(imageInputServiceProvider);

    // 카메라 이미지 캡처
    final inputResult = await imageInputService.captureFromCamera();

    // null인 경우: 권한 거부 또는 사용자 취소 → idle 유지
    if (inputResult == null) {
      return;
    }

    await _runAnalysisFlow(inputResult.imageFile);
  }

  /// 갤러리 선택을 통한 분석 시작
  Future<void> analyzeFromGallery() async {
    final imageInputService = ref.read(imageInputServiceProvider);

    // 갤러리에서 이미지 선택
    final inputResult = await imageInputService.pickFromGallery();

    // null인 경우: 권한 거부 또는 사용자 취소 → idle 유지
    if (inputResult == null) {
      return;
    }

    await _runAnalysisFlow(inputResult.imageFile);
  }

  /// 오류 발생 후 동일 이미지로 분석을 재시도한다
  ///
  /// 오류 상태에서 보존한 입력 이미지를 다시 분석 흐름에 투입한다.
  Future<void> retry(File imageFile) async {
    await _runAnalysisFlow(imageFile);
  }

  /// 분석 상태를 idle로 초기화한다
  void reset() {
    state = const AnalysisIdle();
  }

  /// 전체 분석 흐름을 실행한다
  ///
  /// 흐름: 검증 → 메모리 확인 → 전처리 → 분류 → 포맷 → 이력 저장 → 결과 반환
  Future<void> _runAnalysisFlow(File imageFile) async {
    // 분석 중 상태로 전환 (이미지 미리보기 포함)
    state = AnalysisAnalyzing(imageFile: imageFile);

    try {
      // 1. 이미지 유효성 검증
      final validationResult =
          ref.read(imageValidatorProvider).validate(imageFile);

      if (validationResult is ValidationFailure) {
        state = AnalysisError(
          message: validationResult.message,
          imageFile: imageFile,
        );
        return;
      }

      // 2. 메모리 상태 확인
      final memoryMonitor = ref.read(memoryMonitorProvider);
      var memoryStatus = await memoryMonitor.checkAnalysisAvailability();

      if (memoryStatus == MemoryStatus.needsCacheClean) {
        // 캐시 정리 수행
        final historyManager = ref.read(historyManagerProvider);
        await historyManager.clearOldestThumbnailCaches();

        // 캐시 정리 알림 전달
        ref.read(memoryWarningProvider.notifier).notifyCacheCleared();

        // 재확인
        memoryStatus = await memoryMonitor.checkAnalysisAvailability();
      }

      if (memoryStatus == MemoryStatus.needsCacheClean ||
          memoryStatus == MemoryStatus.insufficient) {
        // 캐시 정리 후에도 메모리 부족
        state = const AnalysisMemoryInsufficient();
        return;
      }

      // 3. 이미지 전처리
      final preprocessor = ref.read(preprocessorServiceProvider);
      final preprocessedImage = await preprocessor.preprocess(imageFile);

      // 4. 감정 분류 (모델 초기화 완료를 보장하기 위해 future를 await)
      final classifier =
          await ref.read(emotionClassifierServiceProvider.future);
      final classificationResult = await classifier.classify(preprocessedImage);

      // 추론 실패 처리
      if (classificationResult is InferenceError) {
        state = AnalysisError(
          message: classificationResult.errorMessage,
          imageFile: imageFile,
        );
        return;
      }

      // 5. 결과 포맷팅
      final success = classificationResult as ClassificationSuccess;
      final formatter = ref.read(resultFormatterProvider);
      final formattedResult = formatter.format(success);

      // 6. 이력 저장
      final historyManager = ref.read(historyManagerProvider);
      final historyEntry = AnalysisHistoryEntry(
        imageThumbnailPath: imageFile.path,
        predictedCategory: success.topPrediction.category,
        confidencePercent: success.topPrediction.confidencePercent,
        analyzedAt: DateTime.now(),
      );
      await historyManager.saveResult(historyEntry);

      // 7. 결과 상태 반환 (불확실 여부에 따라 분기)
      if (success.isUncertain) {
        state = AnalysisUncertain(
          result: formattedResult,
          imageFile: imageFile,
        );
      } else {
        state = AnalysisSuccess(
          result: formattedResult,
          imageFile: imageFile,
        );
      }
    } catch (e) {
      // 예상치 못한 오류 처리
      state = AnalysisError(
        message: '감정 분석 중 오류가 발생했습니다: $e',
        imageFile: imageFile,
      );
    }
  }
}

/// 분석 상태 관리 Provider
///
/// UI에서 이 provider를 watch하여 상태에 따라 화면을 전환한다.
final analysisProvider =
    NotifierProvider<AnalysisNotifier, AnalysisState>(AnalysisNotifier.new);
