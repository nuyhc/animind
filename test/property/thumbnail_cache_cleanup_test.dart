// 속성 기반 테스트: 캐시 삭제 순서
// Feature: animal-emotion-recognition, Property 14: 캐시 삭제 순서
//
// **Validates: Requirements 4.11, 7.4**
//
// 임의의 분석 이력 목록(썸네일 포함, 랜덤 타임스탬프)에서:
// clearOldestThumbnailCaches()를 반복 호출할 때:
// (a) 썸네일은 analyzed_at 기준 가장 오래된 항목부터 순차적으로 삭제된다
// (b) 썸네일 삭제 후에도 이력 row(카테고리, 신뢰도, 분석 일시)는 보존된다
// (c) 썸네일 삭제 후 thumbnail_available이 false로 업데이트된다

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:animind/data/services/history_manager_impl.dart';
import 'package:animind/domain/models/analysis_history_entry.dart';
import 'package:animind/domain/models/emotion_category.dart';

/// 테스트용 인메모리 데이터베이스 생성 헬퍼
Future<Database> createTestDatabase() async {
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

/// 랜덤 감정 카테고리 생성
EmotionCategory randomCategory(Random rng) {
  return EmotionCategory.values[rng.nextInt(EmotionCategory.values.length)];
}

/// 랜덤 신뢰도(0~100) 생성
int randomConfidence(Random rng) {
  return rng.nextInt(101);
}

/// 랜덤 타임스탬프 생성 (2020~2024 범위)
DateTime randomTimestamp(Random rng) {
  // 초 단위로 계산하여 nextInt 범위 제한(2^32) 내로 유지
  final baseSeconds = DateTime(2020, 1, 1).millisecondsSinceEpoch ~/ 1000;
  final endSeconds = DateTime(2025, 1, 1).millisecondsSinceEpoch ~/ 1000;
  final rangeSeconds = endSeconds - baseSeconds; // 약 1.58억 초 → int 범위 내
  final randomSeconds = baseSeconds + rng.nextInt(rangeSeconds);
  return DateTime.fromMillisecondsSinceEpoch(randomSeconds * 1000);
}

void main() {
  // FFI 초기화 (데스크톱 환경 SQLite 바인딩)
  sqfliteFfiInit();

  group(
    'Property 14: 캐시 삭제 순서',
    () {
      // loop-based 속성 테스트: async 작업(DB, 파일 I/O) 포함
      // 최소 50 iterations (파일 I/O 포함이므로)
      test(
        '(a) 썸네일은 analyzed_at 기준 가장 오래된 항목부터 순차 삭제된다',
        () async {
          const iterations = 50;
          final rng = Random(42); // 재현 가능한 시드

          for (int iter = 0; iter < iterations; iter++) {
            // 랜덤 엔트리 수 (3~10)
            final entryCount = 3 + rng.nextInt(8);
            final tempDir = await Directory.systemTemp.createTemp(
              'prop14_order_$iter',
            );

            try {
              final db = await createTestDatabase();
              final manager = HistoryManagerImpl(database: db);

              // 랜덤 타임스탬프 목록 생성
              final timestamps = List.generate(
                entryCount,
                (_) => randomTimestamp(rng),
              );

              // 썸네일 파일 생성 및 이력 저장
              final thumbFiles = <File>[];
              for (int i = 0; i < entryCount; i++) {
                final thumbFile = File(
                  '${tempDir.path}/thumb_${iter}_$i.jpg',
                );
                // 랜덤 크기(100~2000 bytes)의 더미 썸네일 생성
                await thumbFile.writeAsBytes(
                  List.filled(100 + rng.nextInt(1901), rng.nextInt(256)),
                );
                thumbFiles.add(thumbFile);

                final entry = AnalysisHistoryEntry(
                  predictedCategory: randomCategory(rng),
                  confidencePercent: randomConfidence(rng),
                  analyzedAt: timestamps[i],
                  imageThumbnailPath: thumbFile.path,
                  thumbnailAvailable: true,
                );
                await manager.saveResult(entry);
              }

              // 타임스탬프를 오름차순 정렬 → 예상 삭제 순서
              final sortedTimestamps = List<DateTime>.from(timestamps)..sort();

              // clearOldestThumbnailCaches()를 반복 호출하며 삭제 순서 검증
              final deletedTimestamps = <DateTime>[];
              for (int call = 0; call < entryCount; call++) {
                final result = await manager.clearOldestThumbnailCaches();
                if (result.deletedThumbnailCount == 0) break;

                // 삭제된 항목의 타임스탬프를 찾기 위해
                // thumbnail_available == false인 항목 중 가장 최근 변경된 것
                final history = await manager.getHistory();
                final cleaned = history.where(
                  (e) => !e.thumbnailAvailable && e.thumbnailDeletedAt != null,
                );

                // 지금까지 정리된 항목 중 마지막으로 추가된 것의 타임스탬프
                if (cleaned.length > deletedTimestamps.length) {
                  // analyzed_at 기준으로 정리된 항목들을 오름차순 정렬
                  final cleanedSorted = cleaned.toList()
                    ..sort((a, b) => a.analyzedAt.compareTo(b.analyzedAt));
                  deletedTimestamps.clear();
                  for (final c in cleanedSorted) {
                    deletedTimestamps.add(c.analyzedAt);
                  }
                }
              }

              // 삭제된 순서가 타임스탬프 오름차순과 일치하는지 검증
              for (int i = 0; i < deletedTimestamps.length; i++) {
                expect(
                  deletedTimestamps[i],
                  equals(sortedTimestamps[i]),
                  reason:
                      'iter=$iter: 삭제 순서[$i]=${deletedTimestamps[i]}가 '
                      '예상 순서(${sortedTimestamps[i]})와 일치해야 한다',
                );
              }

              await db.close();
            } finally {
              // 임시 디렉토리 정리
              if (await tempDir.exists()) {
                await tempDir.delete(recursive: true);
              }
            }
          }
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );

      test(
        '(b) 썸네일 삭제 후 이력 row(카테고리, 신뢰도, 분석 일시)는 보존된다',
        () async {
          const iterations = 50;
          final rng = Random(123); // 재현 가능한 시드

          for (int iter = 0; iter < iterations; iter++) {
            final entryCount = 3 + rng.nextInt(8);
            final tempDir = await Directory.systemTemp.createTemp(
              'prop14_preserve_$iter',
            );

            try {
              final db = await createTestDatabase();
              final manager = HistoryManagerImpl(database: db);

              // 원본 데이터 기록용
              final originalEntries = <AnalysisHistoryEntry>[];

              for (int i = 0; i < entryCount; i++) {
                final thumbFile = File(
                  '${tempDir.path}/thumb_${iter}_$i.jpg',
                );
                await thumbFile.writeAsBytes(
                  List.filled(100 + rng.nextInt(1901), rng.nextInt(256)),
                );

                final entry = AnalysisHistoryEntry(
                  predictedCategory: randomCategory(rng),
                  confidencePercent: randomConfidence(rng),
                  analyzedAt: randomTimestamp(rng),
                  imageThumbnailPath: thumbFile.path,
                  thumbnailAvailable: true,
                );
                originalEntries.add(entry);
                await manager.saveResult(entry);
              }

              // 일부 항목의 캐시를 정리 (1~entryCount 사이 랜덤 횟수)
              final cleanCount = 1 + rng.nextInt(entryCount);
              for (int call = 0; call < cleanCount; call++) {
                await manager.clearOldestThumbnailCaches();
              }

              // 모든 이력 row가 보존되었는지 검증
              final history = await manager.getHistory();
              expect(
                history.length,
                equals(entryCount),
                reason:
                    'iter=$iter: 캐시 정리 후에도 이력 건수($entryCount)가 '
                    '보존되어야 한다 (실제: ${history.length})',
              );

              // 각 원본 항목의 카테고리, 신뢰도, 분석 일시가 보존되는지 검증
              for (final original in originalEntries) {
                final matching = history.where(
                  (h) =>
                      h.analyzedAt == original.analyzedAt &&
                      h.predictedCategory == original.predictedCategory &&
                      h.confidencePercent == original.confidencePercent,
                );
                expect(
                  matching.isNotEmpty,
                  isTrue,
                  reason:
                      'iter=$iter: 원본 항목(카테고리=${original.predictedCategory}, '
                      '신뢰도=${original.confidencePercent}, '
                      '분석일시=${original.analyzedAt})이 이력에 보존되어야 한다',
                );
              }

              await db.close();
            } finally {
              if (await tempDir.exists()) {
                await tempDir.delete(recursive: true);
              }
            }
          }
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );

      test(
        '(c) 썸네일 삭제 후 thumbnail_available이 false로 업데이트된다',
        () async {
          const iterations = 50;
          final rng = Random(777); // 재현 가능한 시드

          for (int iter = 0; iter < iterations; iter++) {
            final entryCount = 3 + rng.nextInt(8);
            final tempDir = await Directory.systemTemp.createTemp(
              'prop14_flag_$iter',
            );

            try {
              final db = await createTestDatabase();
              final manager = HistoryManagerImpl(database: db);

              // 엔트리별 타임스탬프 기록
              final timestamps = <DateTime>[];

              for (int i = 0; i < entryCount; i++) {
                final thumbFile = File(
                  '${tempDir.path}/thumb_${iter}_$i.jpg',
                );
                await thumbFile.writeAsBytes(
                  List.filled(100 + rng.nextInt(1901), rng.nextInt(256)),
                );

                final ts = randomTimestamp(rng);
                timestamps.add(ts);

                final entry = AnalysisHistoryEntry(
                  predictedCategory: randomCategory(rng),
                  confidencePercent: randomConfidence(rng),
                  analyzedAt: ts,
                  imageThumbnailPath: thumbFile.path,
                  thumbnailAvailable: true,
                );
                await manager.saveResult(entry);
              }

              // 정리할 횟수 (1~entryCount)
              final cleanCount = 1 + rng.nextInt(entryCount);

              // 예상되는 정리 대상: 타임스탬프 오름차순 기준 첫 cleanCount개
              final sortedTimestamps = List<DateTime>.from(timestamps)..sort();
              final expectedCleaned = sortedTimestamps.take(cleanCount).toSet();

              for (int call = 0; call < cleanCount; call++) {
                await manager.clearOldestThumbnailCaches();
              }

              // 결과 검증
              final history = await manager.getHistory();
              for (final entry in history) {
                final wasCleaned = expectedCleaned.contains(entry.analyzedAt);
                if (wasCleaned) {
                  expect(
                    entry.thumbnailAvailable,
                    isFalse,
                    reason:
                        'iter=$iter: 정리된 항목(analyzedAt=${entry.analyzedAt})의 '
                        'thumbnailAvailable은 false여야 한다',
                  );
                  expect(
                    entry.thumbnailDeletedAt,
                    isNotNull,
                    reason:
                        'iter=$iter: 정리된 항목(analyzedAt=${entry.analyzedAt})의 '
                        'thumbnailDeletedAt은 null이 아니어야 한다',
                  );
                } else {
                  expect(
                    entry.thumbnailAvailable,
                    isTrue,
                    reason:
                        'iter=$iter: 미정리 항목(analyzedAt=${entry.analyzedAt})의 '
                        'thumbnailAvailable은 true여야 한다',
                  );
                }
              }

              await db.close();
            } finally {
              if (await tempDir.exists()) {
                await tempDir.delete(recursive: true);
              }
            }
          }
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );

      // Tag: Feature: animal-emotion-recognition, Property 14: 캐시 삭제 순서
    },
  );
}
