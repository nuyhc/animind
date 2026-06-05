import 'emotion_category.dart';

/// 분석 이력 엔트리 (SQLite 저장)
class AnalysisHistoryEntry {
  final int? id;

  /// 썸네일 경로. 캐시 삭제 시 null 가능
  final String? imageThumbnailPath;

  /// 썸네일 파일 사용 가능 여부
  final bool thumbnailAvailable;

  /// 썸네일 캐시 삭제 일시
  final DateTime? thumbnailDeletedAt;

  final EmotionCategory predictedCategory;

  /// 정수 백분율
  final int confidencePercent;

  /// 분석 일시
  final DateTime analyzedAt;

  const AnalysisHistoryEntry({
    this.id,
    this.imageThumbnailPath,
    this.thumbnailAvailable = true,
    this.thumbnailDeletedAt,
    required this.predictedCategory,
    required this.confidencePercent,
    required this.analyzedAt,
  });

  /// SQLite Map 변환
  Map<String, dynamic> toMap() => {
    'id': id,
    'image_thumbnail_path': imageThumbnailPath,
    'thumbnail_available': thumbnailAvailable ? 1 : 0,
    'thumbnail_deleted_at': thumbnailDeletedAt?.toIso8601String(),
    'predicted_category': predictedCategory.name,
    'confidence_percent': confidencePercent,
    'analyzed_at': analyzedAt.toIso8601String(),
  };

  /// SQLite Map으로부터 생성
  factory AnalysisHistoryEntry.fromMap(Map<String, dynamic> map) =>
      AnalysisHistoryEntry(
        id: map['id'] as int?,
        imageThumbnailPath: map['image_thumbnail_path'] as String?,
        thumbnailAvailable: (map['thumbnail_available'] as int) == 1,
        thumbnailDeletedAt: map['thumbnail_deleted_at'] == null
            ? null
            : DateTime.parse(map['thumbnail_deleted_at'] as String),
        predictedCategory: EmotionCategory.values.byName(
          map['predicted_category'] as String,
        ),
        confidencePercent: map['confidence_percent'] as int,
        analyzedAt: DateTime.parse(map['analyzed_at'] as String),
      );
}
