import 'dart:io';

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

/// 테스트용 이력 항목 생성 헬퍼
AnalysisHistoryEntry createTestEntry({
  EmotionCategory category = EmotionCategory.happy,
  int confidence = 85,
  DateTime? analyzedAt,
  String? thumbnailPath,
  bool thumbnailAvailable = true,
}) {
  return AnalysisHistoryEntry(
    predictedCategory: category,
    confidencePercent: confidence,
    analyzedAt: analyzedAt ?? DateTime.now(),
    imageThumbnailPath: thumbnailPath,
    thumbnailAvailable: thumbnailAvailable,
  );
}

void main() {
  // FFI 초기화 (데스크톱 환경 SQLite 바인딩)
  sqfliteFfiInit();

  late Database db;
  late HistoryManagerImpl manager;

  setUp(() async {
    db = await createTestDatabase();
    manager = HistoryManagerImpl(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('HistoryManagerImpl - saveResult', () {
    test('분석 결과를 이력에 저장할 수 있어야 한다', () async {
      final entry = createTestEntry(
        category: EmotionCategory.happy,
        confidence: 92,
      );

      await manager.saveResult(entry);

      final history = await manager.getHistory();
      expect(history.length, 1);
      expect(history.first.predictedCategory, EmotionCategory.happy);
      expect(history.first.confidencePercent, 92);
    });

    test('저장된 항목에 자동 생성된 id가 있어야 한다', () async {
      final entry = createTestEntry();

      await manager.saveResult(entry);

      final history = await manager.getHistory();
      expect(history.first.id, isNotNull);
      expect(history.first.id, greaterThan(0));
    });

    test('20건 초과 시 가장 오래된 항목이 자동 삭제되어야 한다', () async {
      // 21건 삽입 (시간순으로 오래된 것부터)
      for (int i = 0; i < 21; i++) {
        final entry = createTestEntry(
          analyzedAt: DateTime(2024, 1, 1, 0, i),
          confidence: i + 1,
        );
        await manager.saveResult(entry);
      }

      final history = await manager.getHistory();
      expect(history.length, 20);

      // 가장 오래된 항목(confidence=1)이 삭제되었는지 확인
      final confidences = history.map((e) => e.confidencePercent).toList();
      expect(confidences.contains(1), isFalse);
    });
  });

  group('HistoryManagerImpl - getHistory', () {
    test('빈 이력을 조회하면 빈 목록을 반환해야 한다', () async {
      final history = await manager.getHistory();
      expect(history, isEmpty);
    });

    test('이력을 최신순으로 정렬하여 반환해야 한다', () async {
      await manager.saveResult(createTestEntry(
        analyzedAt: DateTime(2024, 1, 1),
        confidence: 10,
      ));
      await manager.saveResult(createTestEntry(
        analyzedAt: DateTime(2024, 1, 3),
        confidence: 30,
      ));
      await manager.saveResult(createTestEntry(
        analyzedAt: DateTime(2024, 1, 2),
        confidence: 20,
      ));

      final history = await manager.getHistory();

      expect(history.length, 3);
      // 최신순 정렬 확인
      expect(history[0].confidencePercent, 30); // 1월 3일
      expect(history[1].confidencePercent, 20); // 1월 2일
      expect(history[2].confidencePercent, 10); // 1월 1일
    });

    test('모든 필드가 정확하게 라운드 트립되어야 한다', () async {
      final analyzedAt = DateTime(2024, 6, 15, 14, 30, 0);
      final entry = AnalysisHistoryEntry(
        imageThumbnailPath: '/path/to/thumb.jpg',
        thumbnailAvailable: true,
        predictedCategory: EmotionCategory.sad,
        confidencePercent: 73,
        analyzedAt: analyzedAt,
      );

      await manager.saveResult(entry);

      final history = await manager.getHistory();
      final saved = history.first;

      expect(saved.imageThumbnailPath, '/path/to/thumb.jpg');
      expect(saved.thumbnailAvailable, true);
      expect(saved.thumbnailDeletedAt, isNull);
      expect(saved.predictedCategory, EmotionCategory.sad);
      expect(saved.confidencePercent, 73);
      expect(saved.analyzedAt, analyzedAt);
    });
  });

  group('HistoryManagerImpl - deleteOldestHistory', () {
    test('가장 오래된 이력 항목을 삭제해야 한다', () async {
      await manager.saveResult(createTestEntry(
        analyzedAt: DateTime(2024, 1, 1),
        confidence: 10,
      ));
      await manager.saveResult(createTestEntry(
        analyzedAt: DateTime(2024, 1, 2),
        confidence: 20,
      ));
      await manager.saveResult(createTestEntry(
        analyzedAt: DateTime(2024, 1, 3),
        confidence: 30,
      ));

      await manager.deleteOldestHistory();

      final history = await manager.getHistory();
      expect(history.length, 2);
      // 가장 오래된 항목(confidence=10)이 삭제되었는지 확인
      expect(history.every((e) => e.confidencePercent != 10), isTrue);
    });

    test('이력이 비어있으면 아무 동작도 하지 않아야 한다', () async {
      // 예외가 발생하지 않아야 한다
      await manager.deleteOldestHistory();

      final history = await manager.getHistory();
      expect(history, isEmpty);
    });

    test('썸네일 파일이 존재하면 디스크에서도 삭제해야 한다', () async {
      // 임시 썸네일 파일 생성
      final tempDir = Directory.systemTemp;
      final thumbFile = File(
        '${tempDir.path}/test_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await thumbFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);

      await manager.saveResult(createTestEntry(
        analyzedAt: DateTime(2024, 1, 1),
        thumbnailPath: thumbFile.path,
      ));

      expect(await thumbFile.exists(), isTrue);

      await manager.deleteOldestHistory();

      // 썸네일 파일이 디스크에서 삭제되었는지 확인
      expect(await thumbFile.exists(), isFalse);
    });
  });

  group('HistoryManagerImpl - clearOldestThumbnailCaches', () {
    test('썸네일이 사용 가능한 가장 오래된 항목의 캐시를 정리해야 한다',
        () async {
      // 임시 썸네일 파일 생성
      final tempDir = Directory.systemTemp;
      final thumbFile = File(
        '${tempDir.path}/test_cache_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await thumbFile.writeAsBytes(List.filled(1024, 0xFF)); // 1KB

      await manager.saveResult(createTestEntry(
        analyzedAt: DateTime(2024, 1, 1),
        thumbnailPath: thumbFile.path,
      ));

      final result = await manager.clearOldestThumbnailCaches();

      expect(result.deletedThumbnailCount, 1);
      expect(result.freedBytes, 1024);
      // 썸네일 파일이 삭제되었는지 확인
      expect(await thumbFile.exists(), isFalse);
    });

    test('캐시 정리 후 이력 row는 보존되어야 한다', () async {
      final tempDir = Directory.systemTemp;
      final thumbFile = File(
        '${tempDir.path}/test_cache2_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await thumbFile.writeAsBytes(List.filled(512, 0xAA));

      await manager.saveResult(createTestEntry(
        analyzedAt: DateTime(2024, 3, 15),
        category: EmotionCategory.angry,
        confidence: 67,
        thumbnailPath: thumbFile.path,
      ));

      await manager.clearOldestThumbnailCaches();

      // 이력 row가 보존되었는지 확인
      final history = await manager.getHistory();
      expect(history.length, 1);
      expect(history.first.predictedCategory, EmotionCategory.angry);
      expect(history.first.confidencePercent, 67);
      // 썸네일 비가용 상태로 업데이트되었는지 확인
      expect(history.first.thumbnailAvailable, false);
      expect(history.first.thumbnailDeletedAt, isNotNull);
    });

    test('정리할 썸네일이 없으면 빈 결과를 반환해야 한다', () async {
      // 썸네일 없는 항목만 존재
      await manager.saveResult(createTestEntry(
        thumbnailPath: null,
        thumbnailAvailable: false,
      ));

      final result = await manager.clearOldestThumbnailCaches();

      expect(result.deletedThumbnailCount, 0);
      expect(result.freedBytes, 0);
    });

    test('한 번 호출 시 1건만 처리해야 한다', () async {
      final tempDir = Directory.systemTemp;
      final thumbFile1 = File(
        '${tempDir.path}/test_multi1_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final thumbFile2 = File(
        '${tempDir.path}/test_multi2_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await thumbFile1.writeAsBytes(List.filled(100, 0x01));
      await thumbFile2.writeAsBytes(List.filled(200, 0x02));

      await manager.saveResult(createTestEntry(
        analyzedAt: DateTime(2024, 1, 1),
        thumbnailPath: thumbFile1.path,
      ));
      await manager.saveResult(createTestEntry(
        analyzedAt: DateTime(2024, 1, 2),
        thumbnailPath: thumbFile2.path,
      ));

      final result = await manager.clearOldestThumbnailCaches();

      expect(result.deletedThumbnailCount, 1);
      // 오래된 것(thumbFile1)이 먼저 삭제됨
      expect(await thumbFile1.exists(), isFalse);
      expect(await thumbFile2.exists(), isTrue);

      // 정리
      await thumbFile2.delete();
    });
  });

  group('HistoryManagerImpl - 4개 감정 카테고리', () {
    test('모든 감정 카테고리를 저장/조회할 수 있어야 한다', () async {
      for (final category in EmotionCategory.values) {
        await manager.saveResult(createTestEntry(category: category));
      }

      final history = await manager.getHistory();
      expect(history.length, 4);

      final categories = history.map((e) => e.predictedCategory).toSet();
      expect(categories, containsAll(EmotionCategory.values));
    });
  });
}
