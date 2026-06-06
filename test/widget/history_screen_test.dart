import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animind/domain/models/analysis_history_entry.dart';
import 'package:animind/domain/models/cache_cleanup_result.dart';
import 'package:animind/domain/models/emotion_category.dart';
import 'package:animind/domain/services/history_manager.dart';
import 'package:animind/presentation/screens/history_screen.dart';

/// 테스트용 HistoryManager 구현
class MockHistoryManager implements HistoryManager {
  final List<AnalysisHistoryEntry> _entries;

  MockHistoryManager([List<AnalysisHistoryEntry>? entries])
      : _entries = entries ?? [];

  @override
  Future<List<AnalysisHistoryEntry>> getHistory() async => _entries;

  @override
  Future<void> saveResult(AnalysisHistoryEntry entry) async {}

  @override
  Future<void> deleteOldestHistory() async {}

  @override
  Future<CacheCleanupResult> clearOldestThumbnailCaches() async =>
      const CacheCleanupResult(deletedThumbnailCount: 0, freedBytes: 0);
}

void main() {
  // 테스트용 MaterialApp 래퍼
  Widget createTestApp({
    required HistoryManager historyManager,
    VoidCallback? onStartAnalysis,
  }) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: HistoryScreen(
        historyManager: historyManager,
        onStartAnalysis: onStartAnalysis,
      ),
    );
  }

  group('HistoryScreen - 빈 이력 상태', () {
    testWidgets('이력이 없을 때 빈 상태 메시지를 표시한다', (tester) async {
      await tester.pumpWidget(createTestApp(
        historyManager: MockHistoryManager(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('분석 이력이 없습니다'), findsOneWidget);
    });

    testWidgets('이력이 없을 때 분석 시작하기 버튼을 표시한다', (tester) async {
      await tester.pumpWidget(createTestApp(
        historyManager: MockHistoryManager(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('분석 시작하기'), findsOneWidget);
    });

    testWidgets('분석 시작하기 버튼을 누르면 콜백이 호출된다', (tester) async {
      var callbackCalled = false;

      await tester.pumpWidget(createTestApp(
        historyManager: MockHistoryManager(),
        onStartAnalysis: () => callbackCalled = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('분석 시작하기'));
      expect(callbackCalled, isTrue);
    });
  });

  group('HistoryScreen - 이력 목록 상태', () {
    final testEntries = [
      AnalysisHistoryEntry(
        id: 1,
        imageThumbnailPath: '/path/to/image1.jpg',
        thumbnailAvailable: true,
        predictedCategory: EmotionCategory.happy,
        confidencePercent: 92,
        analyzedAt: DateTime(2024, 1, 15, 14, 30),
      ),
      AnalysisHistoryEntry(
        id: 2,
        imageThumbnailPath: null,
        thumbnailAvailable: false,
        predictedCategory: EmotionCategory.angry,
        confidencePercent: 78,
        analyzedAt: DateTime(2024, 1, 14, 10, 5),
      ),
      AnalysisHistoryEntry(
        id: 3,
        imageThumbnailPath: '/path/to/deleted.jpg',
        thumbnailAvailable: false,
        predictedCategory: EmotionCategory.sad,
        confidencePercent: 65,
        analyzedAt: DateTime(2024, 1, 13, 8, 0),
      ),
    ];

    testWidgets('이력 항목에 감정 이모지가 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(
        historyManager: MockHistoryManager(testEntries),
      ));
      await tester.pumpAndSettle();

      // happy 이모지
      expect(find.text('😊'), findsOneWidget);
      // angry 이모지
      expect(find.text('😠'), findsOneWidget);
      // sad 이모지
      expect(find.text('😢'), findsOneWidget);
    });

    testWidgets('이력 항목에 한국어 카테고리명이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(
        historyManager: MockHistoryManager(testEntries),
      ));
      await tester.pumpAndSettle();

      expect(find.text('행복'), findsOneWidget);
      expect(find.text('화남'), findsOneWidget);
      expect(find.text('슬픔'), findsOneWidget);
    });

    testWidgets('이력 항목에 신뢰도 백분율이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(
        historyManager: MockHistoryManager(testEntries),
      ));
      await tester.pumpAndSettle();

      expect(find.text('92%'), findsOneWidget);
      expect(find.text('78%'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);
    });

    testWidgets('이력 항목에 한국식 날짜 형식이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(
        historyManager: MockHistoryManager(testEntries),
      ));
      await tester.pumpAndSettle();

      expect(find.text('2024.01.15 14:30'), findsOneWidget);
      expect(find.text('2024.01.14 10:05'), findsOneWidget);
      expect(find.text('2024.01.13 08:00'), findsOneWidget);
    });

    testWidgets('썸네일 사용 불가 시 대체 아이콘이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(
        historyManager: MockHistoryManager(testEntries),
      ));
      await tester.pumpAndSettle();

      // thumbnailAvailable == false 인 항목이 2개 있으므로 대체 아이콘 2개
      expect(find.byIcon(Icons.image_not_supported), findsNWidgets(2));
    });

    testWidgets('AppBar에 분석 이력 제목이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(
        historyManager: MockHistoryManager(testEntries),
      ));
      await tester.pumpAndSettle();

      expect(find.text('분석 이력'), findsOneWidget);
    });
  });

  group('HistoryScreen - 캐시 삭제된 이력', () {
    testWidgets('thumbnailAvailable이 false면 대체 썸네일을 표시한다',
        (tester) async {
      final entry = AnalysisHistoryEntry(
        id: 1,
        imageThumbnailPath: '/deleted/path.jpg',
        thumbnailAvailable: false,
        thumbnailDeletedAt: DateTime(2024, 1, 16),
        predictedCategory: EmotionCategory.other,
        confidencePercent: 45,
        analyzedAt: DateTime(2024, 1, 10, 9, 15),
      );

      await tester.pumpWidget(createTestApp(
        historyManager: MockHistoryManager([entry]),
      ));
      await tester.pumpAndSettle();

      // 대체 아이콘 표시
      expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
      // 카테고리/신뢰도/일시는 여전히 표시
      expect(find.text('🤔'), findsOneWidget);
      expect(find.text('기타'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget);
      expect(find.text('2024.01.10 09:15'), findsOneWidget);
    });
  });
}
