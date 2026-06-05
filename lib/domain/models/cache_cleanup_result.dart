/// 썸네일 캐시 정리 결과
class CacheCleanupResult {
  /// 삭제된 썸네일 수
  final int deletedThumbnailCount;

  /// 해제된 바이트 수
  final int freedBytes;

  const CacheCleanupResult({
    required this.deletedThumbnailCount,
    required this.freedBytes,
  });
}
