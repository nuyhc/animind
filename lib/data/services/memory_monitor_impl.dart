import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:animind/domain/models/memory_status.dart';
import 'package:animind/domain/services/memory_monitor.dart';

/// 앱의 메모리 압박 상태를 모니터링하는 구현 클래스
///
/// ProcessInfo.currentRss로 앱 RSS 메모리를 확인하고,
/// WidgetsBindingObserver를 통해 OS 메모리 경고 이벤트를 수신한다.
class MemoryMonitorImpl extends MemoryMonitor with WidgetsBindingObserver {
  /// 메모리 경고 이벤트를 브로드캐스트하는 스트림 컨트롤러
  final StreamController<void> _memoryWarningController =
      StreamController<void>.broadcast();

  /// OS 메모리 경고 수신 여부 플래그
  bool _receivedOsWarning = false;

  /// OS 메모리 경고 마지막 수신 시각
  DateTime? _lastWarningTime;

  /// OS 경고 유효 기간 (초). 경고 수신 후 이 시간이 지나면 경고 상태를 해제한다.
  static const int _warningValiditySeconds = 30;

  MemoryMonitorImpl() {
    // WidgetsBinding에 옵저버 등록하여 OS 메모리 경고를 수신
    _registerObserver();
  }

  /// WidgetsBinding 옵저버를 등록한다
  void _registerObserver() {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
  }

  /// iOS didReceiveMemoryWarning / Android onTrimMemory 콜백
  @override
  void didHaveMemoryPressure() {
    _receivedOsWarning = true;
    _lastWarningTime = DateTime.now();
    _memoryWarningController.add(null);
  }

  /// 현재 앱의 메모리 사용량(MB, RSS 기준)을 반환한다
  ///
  /// dart:io ProcessInfo.currentRss를 사용하여 현재 프로세스의
  /// RSS(Resident Set Size) 메모리를 바이트 단위로 조회 후 MB로 변환한다.
  @override
  Future<int> getAppMemoryUsageMB() async {
    final rssBytes = ProcessInfo.currentRss;
    // 바이트를 MB로 변환 (1MB = 1024 * 1024 bytes)
    return rssBytes ~/ (1024 * 1024);
  }

  /// 메모리 압박 여부를 확인한다
  ///
  /// 다음 조건 중 하나라도 충족되면 메모리 압박 상태로 판단한다:
  /// 1. 현재 RSS 사용량이 cacheCleanThresholdMB(180MB) 초과
  /// 2. OS 메모리 경고가 최근에 수신됨 (유효 기간 내)
  @override
  Future<bool> isUnderMemoryPressure() async {
    final currentUsageMB = await getAppMemoryUsageMB();

    // RSS 사용량이 임계치 초과
    if (currentUsageMB > MemoryMonitor.cacheCleanThresholdMB) {
      return true;
    }

    // OS 메모리 경고가 유효 기간 내에 수신됨
    if (_isOsWarningActive()) {
      return true;
    }

    return false;
  }

  /// OS 메모리 경고 이벤트 스트림
  ///
  /// iOS didReceiveMemoryWarning / Android onTrimMemory 이벤트가
  /// 수신될 때마다 이벤트를 방출한다.
  @override
  Stream<void> get onMemoryWarning => _memoryWarningController.stream;

  /// 분석 수행 가능 여부를 판단한다
  ///
  /// - 메모리 사용량이 임계치 이하이고 OS 경고 없음 → available
  /// - 메모리 사용량이 임계치 초과 또는 OS 경고 수신 → needsCacheClean
  /// - 호출자가 캐시 정리 후 재확인하여 여전히 압박 상태면 insufficient로 처리
  ///
  /// 간결한 구현: 압박 상태일 때 needsCacheClean을 반환하며,
  /// 호출자(비즈니스 로직)가 캐시 정리 후 재호출하여 상태를 재판단한다.
  @override
  Future<MemoryStatus> checkAnalysisAvailability() async {
    final isUnderPressure = await isUnderMemoryPressure();

    if (!isUnderPressure) {
      return MemoryStatus.available;
    }

    // 메모리 압박 상태: 캐시 정리 필요
    return MemoryStatus.needsCacheClean;
  }

  /// OS 경고가 유효 기간 내인지 확인한다
  bool _isOsWarningActive() {
    if (!_receivedOsWarning || _lastWarningTime == null) {
      return false;
    }

    final elapsed = DateTime.now().difference(_lastWarningTime!);
    if (elapsed.inSeconds > _warningValiditySeconds) {
      // 유효 기간 초과: 경고 상태 해제
      _receivedOsWarning = false;
      _lastWarningTime = null;
      return false;
    }

    return true;
  }

  /// 리소스 정리: 옵저버 해제 및 스트림 컨트롤러 닫기
  void dispose() {
    final binding = WidgetsBinding.instance;
    binding.removeObserver(this);
    _memoryWarningController.close();
  }
}
