import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/models/analysis_history_entry.dart';
import '../../domain/models/emotion_mapping.dart';
import '../../domain/services/history_manager.dart';

/// 분석 이력 화면
///
/// 최신순으로 분석 이력 목록을 표시하며,
/// 이력이 없는 경우 빈 상태 메시지와 분석 시작 버튼을 표시한다.
/// 캐시 삭제된 이력에 대해서는 대체 썸네일(아이콘)을 표시한다.
///
/// 접근성 준수 사항:
/// - 이력 항목에 스크린 리더용 Semantics 라벨 제공
/// - Material Design 3 ColorScheme으로 WCAG AA 명도 대비 보장
/// - theme.textTheme 사용으로 시스템 글자 크기 확대 대응
/// - 텍스트에 softWrap/overflow 처리 적용
class HistoryScreen extends StatefulWidget {
  final HistoryManager historyManager;

  /// 분석 시작하기 버튼을 눌렀을 때의 콜백
  final VoidCallback? onStartAnalysis;

  const HistoryScreen({
    super.key,
    required this.historyManager,
    this.onStartAnalysis,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<AnalysisHistoryEntry>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = widget.historyManager.getHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('분석 이력'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<AnalysisHistoryEntry>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          // 로딩 상태
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // 오류 상태
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '이력을 불러오는 중 오류가 발생했습니다',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          final history = snapshot.data ?? [];

          // 빈 이력 상태
          if (history.isEmpty) {
            return _buildEmptyState(context);
          }

          // 이력 목록 상태
          return _buildHistoryList(context, history);
        },
      ),
    );
  }

  /// 빈 이력 상태 UI
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
            semanticLabel: '이력 없음',
          ),
          const SizedBox(height: 16),
          Text(
            '분석 이력이 없습니다',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            overflow: TextOverflow.visible,
            softWrap: true,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: widget.onStartAnalysis,
            icon: const Icon(Icons.camera_alt),
            label: const Text('분석 시작하기'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(200, 48),
            ),
          ),
        ],
      ),
    );
  }

  /// 이력 목록 UI
  Widget _buildHistoryList(
    BuildContext context,
    List<AnalysisHistoryEntry> history,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: history.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = history[index];
        return _HistoryListItem(entry: entry);
      },
    );
  }
}

/// 개별 이력 항목 위젯
class _HistoryListItem extends StatelessWidget {
  final AnalysisHistoryEntry entry;

  const _HistoryListItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final emoji = EmotionMapping.emojis[entry.predictedCategory] ?? '🤔';
    final name =
        EmotionMapping.koreanNames[entry.predictedCategory] ?? '기타';

    return Semantics(
      label: '$name ${entry.confidencePercent}퍼센트, '
          '${_formatDate(entry.analyzedAt)}에 분석됨',
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildThumbnail(context),
        title: _buildCategoryRow(context, emoji, name),
        subtitle: _buildSubtitle(context),
        minVerticalPadding: 8,
      ),
    );
  }

  /// 썸네일 또는 대체 아이콘 표시
  Widget _buildThumbnail(BuildContext context) {
    // 썸네일 사용 불가 시 대체 아이콘 표시
    if (!entry.thumbnailAvailable || entry.imageThumbnailPath == null) {
      return Semantics(
        label: '썸네일 사용 불가',
        excludeSemantics: true,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.image_not_supported,
            color: Theme.of(context).colorScheme.outline,
            size: 28,
          ),
        ),
      );
    }

    // 썸네일 이미지 표시
    return Semantics(
      label: '분석 이미지 썸네일',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(entry.imageThumbnailPath!),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 파일 로드 실패 시에도 대체 아이콘 표시
            return Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.image_not_supported,
                color: Theme.of(context).colorScheme.outline,
                size: 28,
              ),
            );
          },
        ),
      ),
    );
  }

  /// 카테고리 이모지 + 한국어 이름 행
  Widget _buildCategoryRow(BuildContext context, String emoji, String name) {
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            style: Theme.of(context).textTheme.titleSmall,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${entry.confidencePercent}%',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  /// 분석 일시 표시
  Widget _buildSubtitle(BuildContext context) {
    return Text(
      _formatDate(entry.analyzedAt),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }

  /// 날짜를 한국식 형식으로 포맷 (2024.01.15 14:30)
  String _formatDate(DateTime dateTime) {
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$year.$month.$day $hour:$minute';
  }
}
