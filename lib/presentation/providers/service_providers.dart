import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animind/data/services/emotion_classifier_service_impl.dart';
import 'package:animind/data/services/history_manager_impl.dart';
import 'package:animind/data/services/image_input_service_impl.dart';
import 'package:animind/data/services/image_validator.dart';
import 'package:animind/data/services/memory_monitor_impl.dart';
import 'package:animind/data/services/preprocessor_service_impl.dart';
import 'package:animind/data/services/result_formatter_impl.dart';
import 'package:animind/domain/services/emotion_classifier_service.dart';
import 'package:animind/domain/services/history_manager.dart';
import 'package:animind/domain/services/image_input_service.dart';
import 'package:animind/domain/services/memory_monitor.dart';
import 'package:animind/domain/services/preprocessor_service.dart';
import 'package:animind/domain/services/result_formatter.dart';

/// 이미지 입력 서비스 Provider
///
/// 카메라 촬영 및 갤러리 선택 기능을 제공한다.
final imageInputServiceProvider = Provider<ImageInputService>((ref) {
  return ImageInputServiceImpl();
});

/// 이미지 유효성 검증기 Provider
///
/// 형식, 크기, 해상도 검증을 수행한다.
final imageValidatorProvider = Provider<ImageValidator>((ref) {
  return ImageValidator();
});

/// 이미지 전처리 서비스 Provider
///
/// 224x224 리사이즈 및 정규화를 수행한다.
final preprocessorServiceProvider = Provider<PreprocessorService>((ref) {
  return PreprocessorServiceImpl();
});

/// 감정 분류 서비스 Provider
///
/// TFLite 모델을 사용한 감정 분류 추론을 수행한다.
/// 모델 자산 로딩(`initialize`)이 비동기이므로 [FutureProvider]로 노출하며,
/// 최초 사용 시 모델을 1회 로딩한 뒤 준비된 인스턴스를 반환한다.
/// dispose 시 모델 리소스를 해제한다.
final emotionClassifierServiceProvider =
    FutureProvider<EmotionClassifierService>((ref) async {
  final classifier = EmotionClassifierServiceImpl();
  await classifier.initialize();
  ref.onDispose(classifier.dispose);
  return classifier;
});

/// 결과 포매터 Provider
///
/// 분류 결과를 한국어 문장으로 변환한다.
final resultFormatterProvider = Provider<ResultFormatter>((ref) {
  return ResultFormatterImpl();
});

/// 이력 관리자 Provider
///
/// SQLite 기반 분석 이력 저장/조회/삭제를 담당한다.
final historyManagerProvider = Provider<HistoryManager>((ref) {
  return HistoryManagerImpl();
});

/// 메모리 모니터 Provider
///
/// 앱 메모리 사용량 모니터링 및 압박 상태 판단을 담당한다.
/// dispose 시 옵저버를 해제한다.
final memoryMonitorProvider = Provider<MemoryMonitor>((ref) {
  final monitor = MemoryMonitorImpl();
  ref.onDispose(() => monitor.dispose());
  return monitor;
});
