/// 메모리 상태
enum MemoryStatus {
  available, // 분석 가능
  needsCacheClean, // 캐시 정리 필요
  insufficient, // 메모리 부족으로 분석 불가
}
