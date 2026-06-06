import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animind/presentation/providers/service_providers.dart';

/// 메모리 경고 이벤트 상태
///
/// 메모리 경고 수신 시 캐시 정리를 수행하고 결과를 알린다.
sealed class MemoryWarningState {
  const MemoryWarningState();
}

/// 대기 상태 (메모리 경고 없음)
class MemoryWarningIdle extends MemoryWarningState {
  const MemoryWarningIdle();
}

/// 캐시 정리 완료 상태
class MemoryWarningCacheCleared extends MemoryWarningState {
  /// 정리된 썸네일 수
  final int clearedCount;

  const MemoryWarningCacheCleared({required this.clearedCount});
}

/// 캐시 정리 후에도 메모리 부족 상태
class MemoryWarningInsufficient extends MemoryWarningState {
  const MemoryWarningInsufficient();
}

/// 메모리 경고를 감지하고 캐시 정리를 수행하는 Notifier
///
/// MemoryMonitor의 onMemoryWarning 스트림을 구독하여
/// OS 메모리 경고 수신 시 가장 오래된 썸네일 캐시를 정리하고
/// UI에 알림을 전달한다.
///
/// Requirements: 7.3, 7.4, 7.5
class MemoryWarningNotifier extends Notifier<MemoryWarningState> {
  StreamSubscription<void>? _subscription;

  @override
  MemoryWarningState build() {
    final memoryMonitor = ref.watch(memoryMonitorProvider);

    // 이전 구독 해제
    _subscription?.cancel();

    // OS 메모리 경고 스트림 구독
    _subscription = memoryMonitor.onMemoryWarning.listen((_) {
      _handleMemoryWarning();
    });

    // Notifier 해제 시 구독도 해제
    ref.onDispose(() {
      _subscription?.cancel();
    });

    return const MemoryWarningIdle();
  }

  /// 메모리 경고 수신 시 캐시 정리를 수행한다
  ///
  /// 1. 메모리 상태 확인
  /// 2. 캐시 정리 필요 시 오래된 썸네일부터 순차 삭제
  /// 3. 정리 후 재확인
  /// 4. 결과에 따라 상태 전환
  Future<void> _handleMemoryWarning() async {
    final memoryMonitor = ref.read(memoryMonitorProvider);
    final historyManager = ref.read(historyManagerProvider);

    // 메모리 압박 상태 확인
    final isUnderPressure = await memoryMonitor.isUnderMemoryPressure();
    if (!isUnderPressure) return;

    // 캐시 정리 수행
    final cleanupResult = await historyManager.clearOldestThumbnailCaches();

    // 정리 후 재확인
    final stillUnderPressure = await memoryMonitor.isUnderMemoryPressure();

    if (stillUnderPressure && cleanupResult.deletedThumbnailCount == 0) {
      // 정리할 캐시가 없고 여전히 메모리 부족
      state = const MemoryWarningInsufficient();
    } else {
      // 캐시 정리 완료 알림
      state = MemoryWarningCacheCleared(
        clearedCount: cleanupResult.deletedThumbnailCount,
      );
    }
  }

  /// 알림 확인 후 상태를 초기화한다
  void acknowledge() {
    state = const MemoryWarningIdle();
  }

  /// 분석 흐름에서 캐시 정리가 수행되었음을 알린다
  ///
  /// AnalysisNotifier에서 분석 전 메모리 확인 후 캐시를 정리했을 때 호출된다.
  void notifyCacheCleared() {
    state = const MemoryWarningCacheCleared(clearedCount: 1);
  }
}

/// 메모리 경고 상태 관리 Provider
///
/// UI에서 이 provider를 watch하여 캐시 정리 알림 SnackBar를 표시한다.
final memoryWarningProvider =
    NotifierProvider<MemoryWarningNotifier, MemoryWarningState>(
  MemoryWarningNotifier.new,
);
