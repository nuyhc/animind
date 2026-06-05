import '../models/memory_status.dart';

/// 앱의 메모리 압박 상태를 모니터링하는 서비스
///
/// 기기 전체의 가용 메모리는 플랫폼(특히 iOS)에서 신뢰성 있게 노출되지 않으므로,
/// 앱 자체 사용량(RSS)과 OS 메모리 경고 이벤트를 기준으로 판단한다.
abstract class MemoryMonitor {
  /// 메모리 예산 (200MB)
  static const int memoryBudgetMB = 200;

  /// 캐시 정리 임계치 (메모리 예산의 90% = 180MB)
  static const int cacheCleanThresholdMB = 180;

  /// 현재 앱의 메모리 사용량(MB, RSS 기준)을 반환한다
  Future<int> getAppMemoryUsageMB();

  /// 메모리 압박 여부를 확인한다 (사용량이 임계치 초과 또는 OS 경고 수신)
  Future<bool> isUnderMemoryPressure();

  /// OS 메모리 경고 이벤트 스트림
  /// (iOS didReceiveMemoryWarning / Android onTrimMemory)
  Stream<void> get onMemoryWarning;

  /// 분석 수행 가능 여부를 판단한다
  Future<MemoryStatus> checkAnalysisAvailability();
}
