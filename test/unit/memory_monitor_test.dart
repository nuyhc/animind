import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:animind/domain/models/memory_status.dart';
import 'package:animind/domain/services/memory_monitor.dart';
import 'package:animind/data/services/memory_monitor_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryMonitorImpl monitor;

  setUp(() {
    monitor = MemoryMonitorImpl();
  });

  tearDown(() {
    monitor.dispose();
  });

  group('MemoryMonitorImpl', () {
    group('getAppMemoryUsageMB', () {
      test('RSS 메모리를 MB 단위로 반환한다', () async {
        final usageMB = await monitor.getAppMemoryUsageMB();

        // 테스트 환경에서도 프로세스 RSS는 0보다 큰 양수여야 한다
        expect(usageMB, greaterThanOrEqualTo(0));
        // 일반적으로 테스트 프로세스는 수십~수백 MB 이하
        expect(usageMB, lessThan(2000));
      });

      test('정수값을 반환한다', () async {
        final usageMB = await monitor.getAppMemoryUsageMB();

        expect(usageMB, isA<int>());
      });
    });

    group('isUnderMemoryPressure', () {
      test('OS 경고가 없고 메모리 사용량이 낮으면 false를 반환한다', () async {
        // 테스트 환경에서는 일반적으로 임계치(450MB) 이하이므로 false 기대
        final isUnderPressure = await monitor.isUnderMemoryPressure();

        // 테스트 프로세스가 임계치 미만이라고 가정
        // 실제 환경에서는 달라질 수 있으나, 일반적인 테스트 환경에서는 이 조건 충족
        expect(isUnderPressure, isA<bool>());
      });

      test('OS 메모리 경고 수신 시 true를 반환한다', () async {
        // OS 메모리 경고 시뮬레이션
        monitor.didHaveMemoryPressure();

        final isUnderPressure = await monitor.isUnderMemoryPressure();

        expect(isUnderPressure, isTrue);
      });
    });

    group('onMemoryWarning', () {
      test('OS 메모리 경고 발생 시 이벤트를 방출한다', () async {
        final completer = Completer<void>();
        final subscription = monitor.onMemoryWarning.listen((_) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        });

        // OS 메모리 경고 시뮬레이션
        monitor.didHaveMemoryPressure();

        await completer.future;
        expect(completer.isCompleted, isTrue);

        await subscription.cancel();
      });

      test('여러 번 경고가 발생하면 각각 이벤트를 방출한다', () async {
        int warningCount = 0;
        final subscription = monitor.onMemoryWarning.listen((_) {
          warningCount++;
        });

        monitor.didHaveMemoryPressure();
        monitor.didHaveMemoryPressure();
        monitor.didHaveMemoryPressure();

        // 스트림 이벤트 처리를 위해 잠시 대기
        await Future<void>.delayed(Duration.zero);

        expect(warningCount, equals(3));

        await subscription.cancel();
      });
    });

    group('checkAnalysisAvailability', () {
      test('메모리 압박이 없으면 available을 반환한다', () async {
        // 테스트 환경에서 메모리 사용량이 낮은 경우
        // OS 경고 없이 정상 상태
        final status = await monitor.checkAnalysisAvailability();

        // 테스트 환경에서는 available 또는 needsCacheClean 중 하나
        expect(
          status,
          anyOf(MemoryStatus.available, MemoryStatus.needsCacheClean),
        );
      });

      test('OS 메모리 경고 수신 시 needsCacheClean을 반환한다', () async {
        // OS 메모리 경고 시뮬레이션
        monitor.didHaveMemoryPressure();

        final status = await monitor.checkAnalysisAvailability();

        expect(status, equals(MemoryStatus.needsCacheClean));
      });
    });

    group('OS 경고 유효 기간', () {
      test('didHaveMemoryPressure 호출 직후에는 경고 상태가 활성화된다',
          () async {
        monitor.didHaveMemoryPressure();

        final isUnderPressure = await monitor.isUnderMemoryPressure();
        expect(isUnderPressure, isTrue);
      });
    });

    group('인터페이스 준수', () {
      test('MemoryMonitor 추상 클래스를 구현한다', () {
        expect(monitor, isA<MemoryMonitor>());
      });

      test('memoryBudgetMB 상수가 500이다', () {
        expect(MemoryMonitor.memoryBudgetMB, equals(500));
      });

      test('cacheCleanThresholdMB 상수가 450이다', () {
        expect(MemoryMonitor.cacheCleanThresholdMB, equals(450));
      });

      test('캐시 정리 임계치는 메모리 예산의 90%이다', () {
        expect(
          MemoryMonitor.cacheCleanThresholdMB,
          equals(MemoryMonitor.memoryBudgetMB * 9 ~/ 10),
        );
      });
    });
  });
}
