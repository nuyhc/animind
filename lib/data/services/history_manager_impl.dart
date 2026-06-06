import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:animind/domain/models/analysis_history_entry.dart';
import 'package:animind/domain/models/cache_cleanup_result.dart';
import 'package:animind/domain/services/history_manager.dart';

/// 이력 보존 한도
const int _maxHistoryCount = 20;

/// SQLite 기반 분석 이력 관리자 구현
class HistoryManagerImpl implements HistoryManager {
  Database? _database;

  /// 테스트용: 외부에서 Database 인스턴스를 주입할 수 있도록 허용
  HistoryManagerImpl({Database? database}) : _database = database;

  /// 데이터베이스 인스턴스를 반환한다. 최초 호출 시 초기화한다.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// SQLite 데이터베이스를 초기화한다
  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(directory.path, 'animind_history.db');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // 분석 이력 테이블 생성
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

        // 최신순 조회 인덱스 생성
        await db.execute('''
          CREATE INDEX idx_history_analyzed_at
          ON analysis_history(analyzed_at DESC)
        ''');
      },
    );
  }

  /// 분석 결과를 이력에 저장한다.
  /// 저장 후 20건 초과 시 가장 오래된 항목을 자동 삭제한다.
  @override
  Future<void> saveResult(AnalysisHistoryEntry entry) async {
    final db = await database;

    // id는 AUTOINCREMENT이므로 제외하여 삽입
    final map = entry.toMap();
    map.remove('id');

    await db.insert('analysis_history', map);

    // 20건 초과 시 가장 오래된 항목 삭제
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM analysis_history',
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;

    if (count > _maxHistoryCount) {
      await deleteOldestHistory();
    }
  }

  /// 저장된 이력 목록을 최신순으로 조회한다
  @override
  Future<List<AnalysisHistoryEntry>> getHistory() async {
    final db = await database;

    final results = await db.query(
      'analysis_history',
      orderBy: 'analyzed_at DESC',
    );

    return results.map((map) => AnalysisHistoryEntry.fromMap(map)).toList();
  }

  /// 가장 오래된 분석 이력 row를 삭제한다.
  /// 해당 항목에 썸네일 파일이 존재하면 디스크에서도 제거한다.
  @override
  Future<void> deleteOldestHistory() async {
    final db = await database;

    // 가장 오래된 항목 조회
    final oldest = await db.query(
      'analysis_history',
      orderBy: 'analyzed_at ASC',
      limit: 1,
    );

    if (oldest.isEmpty) return;

    final entry = AnalysisHistoryEntry.fromMap(oldest.first);

    // 썸네일 파일이 존재하면 디스크에서 삭제
    if (entry.imageThumbnailPath != null) {
      final file = File(entry.imageThumbnailPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // DB에서 행 삭제
    await db.delete(
      'analysis_history',
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// 오래된 썸네일 캐시 파일부터 정리한다.
  /// 분석 이력 row와 감정/신뢰도/분석 일시는 보존한다.
  /// 한 번 호출 시 가장 오래된 썸네일 1건을 처리한다.
  @override
  Future<CacheCleanupResult> clearOldestThumbnailCaches() async {
    final db = await database;

    // 썸네일이 사용 가능한 가장 오래된 항목 조회
    final candidates = await db.query(
      'analysis_history',
      where: 'thumbnail_available = 1 AND image_thumbnail_path IS NOT NULL',
      orderBy: 'analyzed_at ASC',
      limit: 1,
    );

    if (candidates.isEmpty) {
      return const CacheCleanupResult(
        deletedThumbnailCount: 0,
        freedBytes: 0,
      );
    }

    final entry = AnalysisHistoryEntry.fromMap(candidates.first);
    int freedBytes = 0;

    // 썸네일 파일 삭제 및 크기 측정
    if (entry.imageThumbnailPath != null) {
      final file = File(entry.imageThumbnailPath!);
      if (await file.exists()) {
        freedBytes = await file.length();
        await file.delete();
      }
    }

    // DB 행 업데이트: 썸네일 비가용으로 표시
    final now = DateTime.now().toIso8601String();
    await db.update(
      'analysis_history',
      {
        'thumbnail_available': 0,
        'thumbnail_deleted_at': now,
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );

    return CacheCleanupResult(
      deletedThumbnailCount: 1,
      freedBytes: freedBytes,
    );
  }
}
