import '../models/analysis_history_entry.dart';
import '../models/cache_cleanup_result.dart';

/// 분석 이력을 관리하는 서비스
abstract class HistoryManager {
  /// 분석 결과를 이력에 저장한다
  Future<void> saveResult(AnalysisHistoryEntry entry);

  /// 저장된 이력 목록을 조회한다 (최신순)
  Future<List<AnalysisHistoryEntry>> getHistory();

  /// 이력 보존 한도(20건)를 초과했을 때 가장 오래된 분석 이력 row를 삭제한다
  Future<void> deleteOldestHistory();

  /// 메모리 압박 시 오래된 썸네일 캐시 파일부터 정리한다.
  /// 분석 이력 row와 감정/신뢰도/분석 일시는 보존한다.
  Future<CacheCleanupResult> clearOldestThumbnailCaches();
}
