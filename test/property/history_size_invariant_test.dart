// 속성 기반 테스트: 이력 크기 불변조건
// Feature: animal-emotion-recognition, Property 8: 이력 크기 불변조건
//
// **Validates: Requirements 4.5**
//
// 임의 수(1~100)의 이력 추가 후 항상 20건 이하 유지 검증
// N > 20인 경우 가장 오래된 항목이 삭제되었는지 추가 검증

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:animind/data/services/history_manager_impl.dart';
import 'package:animind/domain/models/analysis_history_entry.dart';
import 'package:animind/domain/models/emotion_category.dart';

/// 테스트용 인메모리 데이터베이스 생성 헬퍼
Future<Database> _createTestDatabase() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE analysis_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_thumbnail_path TEXT,
            thumbnail_available INTEGER NOT NULL DEFAULT 1 CHECK(
              thumbnail_available IN (0, 1)
            ),
            thumbnail_deleted_at TEXT,
            predicted_category TEXT NOT NULL CHECK(
              predicted_category IN ('angry', 'happy', 'sad', 'other')
            ),
            confidence_percent INTEGER NOT NULL CHECK(
              confidence_percent >= 0 AND confidence_percent <= 100
            ),
            analyzed_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_history_analyzed_at
          ON analysis_history(analyzed_at DESC)
        ''');
      },
    ),
  );
  return db;
}

/// 임의 감정 카테고리 생성
EmotionCategory _randomCategory(Random rng) {
  return EmotionCategory.values[rng.nextInt(EmotionCategory.values.length)];
}

/// 임의 이력 항목 생성 (시간 순서를 보장하기 위해 인덱스 기반 시간 할당)
AnalysisHistoryEntry _createRandomEntry(Random rng, int index) {
  return AnalysisHistoryEntry(
    predictedCategory: _randomCategory(rng),
    confidencePercent: rng.nextInt(101), // 0~100
    analyzedAt: DateTime(2024, 1, 1).add(Duration(minutes: index)),
    imageThumbnailPath: null,
    thumbnailAvailable: false,
  );
}

void main() {
  // FFI 초기화 (데스크톱 환경 SQLite 바인딩)
  sqfliteFfiInit();

  group(
    'Property 8: 이력 크기 불변조건',
    () {
      test(
        '임의 수(1~100)의 이력 추가 후 항상 20건 이하 유지',
        () async {
          final rng = Random(42); // 재현 가능한 시드 사용
          const iterations = 100; // 최소 100회 반복

          for (int iter = 0; iter < iterations; iter++) {
            // 각 반복마다 새 인메모리 DB 생성
            final db = await _createTestDatabase();
            final manager = HistoryManagerImpl(database: db);

            // 1~100 사이의 임의 이력 수 결정
            final n = rng.nextInt(100) + 1;

            // N개의 임의 이력 항목 삽입
            for (int i = 0; i < n; i++) {
              final entry = _createRandomEntry(rng, i);
              await manager.saveResult(entry);
            }

            // 이력 조회
            final history = await manager.getHistory();

            // 핵심 불변조건: 이력 크기는 항상 20건 이하
            expect(
              history.length,
              lessThanOrEqualTo(20),
              reason:
                  'iteration=$iter, N=$n: '
                  '이력 크기(${history.length})가 20건 이하여야 한다',
            );

            // N <= 20이면 정확히 N건이어야 한다
            if (n <= 20) {
              expect(
                history.length,
                equals(n),
                reason:
                    'iteration=$iter, N=$n: '
                    'N <= 20이므로 이력 크기는 정확히 N이어야 한다',
              );
            }

            // N > 20이면 정확히 20건이어야 하며, 가장 오래된 항목이 삭제되었어야 한다
            if (n > 20) {
              expect(
                history.length,
                equals(20),
                reason:
                    'iteration=$iter, N=$n: '
                    'N > 20이므로 이력 크기는 정확히 20이어야 한다',
              );

              // 가장 오래된 항목이 삭제되었는지 확인:
              // 남아있는 항목들의 analyzedAt이 삭제된 범위에 해당하지 않아야 한다.
              // 삽입 순서대로 minute 0 ~ N-1 이며, 삭제된 것은 0 ~ (N-21)
              // 남아있는 것은 (N-20) ~ (N-1) 범위의 분 값을 가져야 한다
              final expectedOldestMinute = n - 20;
              final baseTime = DateTime(2024, 1, 1);

              for (final entry in history) {
                final minuteOffset =
                    entry.analyzedAt.difference(baseTime).inMinutes;
                expect(
                  minuteOffset,
                  greaterThanOrEqualTo(expectedOldestMinute),
                  reason:
                      'iteration=$iter, N=$n: '
                      '남은 항목의 시간 오프셋($minuteOffset분)은 '
                      '$expectedOldestMinute분 이상이어야 한다 (오래된 항목 삭제 확인)',
                );
              }
            }

            // 리소스 정리
            await db.close();
          }
        },
      );
    },
  );
}
