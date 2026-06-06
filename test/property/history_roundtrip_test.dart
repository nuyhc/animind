// 속성 기반 테스트: 이력 저장 라운드 트립
// Feature: animal-emotion-recognition, Property 7: 이력 저장 라운드 트립
//
// **Validates: Requirements 4.4**
//
// 임의의 유효한 분석 이력 항목(썸네일 경로 또는 null, 감정 카테고리, 신뢰도 0-100,
// 분석 일시)에 대해, 저장 후 조회하면 모든 필드가 원본과 동일하게 보존되어야 한다.

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

/// 임의의 문자열을 생성한다 (썸네일 경로 시뮬레이션)
String _randomString(Random rng, int maxLength) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789/_-.';
  final length = rng.nextInt(maxLength) + 1;
  return String.fromCharCodes(
    Iterable.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
  );
}

/// 임의의 DateTime을 생성한다 (2020~2025 범위)
DateTime _randomDateTime(Random rng) {
  // 2020-01-01 ~ 2025-12-31 범위의 임의 날짜/시간
  final year = 2020 + rng.nextInt(6);
  final month = 1 + rng.nextInt(12);
  final day = 1 + rng.nextInt(28); // 모든 월에서 안전한 범위
  final hour = rng.nextInt(24);
  final minute = rng.nextInt(60);
  final second = rng.nextInt(60);
  return DateTime(year, month, day, hour, minute, second);
}

/// 임의의 AnalysisHistoryEntry를 생성한다
AnalysisHistoryEntry _randomEntry(Random rng) {
  // 임의 감정 카테고리 (index 0-3)
  final category = EmotionCategory.values[rng.nextInt(4)];

  // 임의 신뢰도 (0-100)
  final confidence = rng.nextInt(101);

  // 임의 분석 일시
  final analyzedAt = _randomDateTime(rng);

  // 임의 썸네일 경로 (null 또는 랜덤 문자열)
  final hasThumb = rng.nextBool();
  final thumbnailPath = hasThumb ? '/thumbnails/${_randomString(rng, 20)}.jpg' : null;

  // 임의 썸네일 가용 상태
  final thumbnailAvailable = rng.nextBool();

  return AnalysisHistoryEntry(
    imageThumbnailPath: thumbnailPath,
    thumbnailAvailable: thumbnailAvailable,
    predictedCategory: category,
    confidencePercent: confidence,
    analyzedAt: analyzedAt,
  );
}

void main() {
  // FFI 초기화 (데스크톱 환경 SQLite 바인딩)
  sqfliteFfiInit();

  group(
    'Property 7: 이력 저장 라운드 트립',
    () {
      test(
        '임의 이력 항목 저장 후 조회 시 모든 필드가 동일 보존된다 (100회 반복)',
        () async {
          final rng = Random(42); // 재현 가능한 시드

          for (var i = 0; i < 100; i++) {
            // 매 반복마다 새로운 인메모리 DB 사용
            final db = await _createTestDatabase();
            final manager = HistoryManagerImpl(database: db);

            try {
              // 임의 이력 항목 생성
              final original = _randomEntry(rng);

              // 저장
              await manager.saveResult(original);

              // 조회
              final history = await manager.getHistory();

              // 정확히 1건 저장되었는지 확인
              expect(
                history.length,
                equals(1),
                reason: '반복 $i: 저장 후 이력은 1건이어야 한다',
              );

              final retrieved = history.first;

              // 모든 필드 비교 검증
              expect(
                retrieved.imageThumbnailPath,
                equals(original.imageThumbnailPath),
                reason:
                    '반복 $i: imageThumbnailPath 불일치 '
                    '(원본=${original.imageThumbnailPath}, 조회=${retrieved.imageThumbnailPath})',
              );

              expect(
                retrieved.thumbnailAvailable,
                equals(original.thumbnailAvailable),
                reason:
                    '반복 $i: thumbnailAvailable 불일치 '
                    '(원본=${original.thumbnailAvailable}, 조회=${retrieved.thumbnailAvailable})',
              );

              expect(
                retrieved.predictedCategory,
                equals(original.predictedCategory),
                reason:
                    '반복 $i: predictedCategory 불일치 '
                    '(원본=${original.predictedCategory}, 조회=${retrieved.predictedCategory})',
              );

              expect(
                retrieved.confidencePercent,
                equals(original.confidencePercent),
                reason:
                    '반복 $i: confidencePercent 불일치 '
                    '(원본=${original.confidencePercent}, 조회=${retrieved.confidencePercent})',
              );

              expect(
                retrieved.analyzedAt,
                equals(original.analyzedAt),
                reason:
                    '반복 $i: analyzedAt 불일치 '
                    '(원본=${original.analyzedAt}, 조회=${retrieved.analyzedAt})',
              );

              // id는 자동 생성되므로 null이 아닌지만 확인
              expect(
                retrieved.id,
                isNotNull,
                reason: '반복 $i: 저장된 항목에 id가 자동 할당되어야 한다',
              );
            } finally {
              await db.close();
            }
          }
        },
      );
    },
  );
}
