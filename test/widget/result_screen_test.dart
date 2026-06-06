import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animind/domain/models/emotion_category.dart';
import 'package:animind/domain/models/formatted_result.dart';
import 'package:animind/presentation/screens/result_screen.dart';

void main() {
  // 테스트용 임시 이미지 파일 경로
  late File testImageFile;

  setUp(() {
    // 테스트용 임시 파일 (실제 이미지가 아니어도 위젯 테스트에서는 에러 빌더가 처리)
    testImageFile = File('test_image.jpg');
  });

  // 테스트용 FormattedResult 생성
  FormattedResult createTestResult({
    String sentence = '행복해하는 것 같아요',
    String emoji = '😊',
    int confidencePercent = 87,
    EmotionCategory category = EmotionCategory.happy,
    bool isUncertain = false,
  }) {
    return FormattedResult(
      sentence: sentence,
      emoji: emoji,
      confidencePercent: confidencePercent,
      category: category,
      isUncertain: isUncertain,
    );
  }

  // 테스트용 MaterialApp 래퍼
  Widget createTestApp({
    required FormattedResult result,
    VoidCallback? onAnalyzeAgain,
    VoidCallback? onViewHistory,
  }) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: ResultScreen(
        imageFile: testImageFile,
        result: result,
        onAnalyzeAgain: onAnalyzeAgain,
        onViewHistory: onViewHistory,
      ),
    );
  }

  group('ResultScreen - 일반 결과 화면', () {
    testWidgets('AppBar에 "분석 결과" 제목이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(result: createTestResult()));

      expect(find.text('분석 결과'), findsOneWidget);
    });

    testWidgets('감정 이모지가 크게 표시된다', (tester) async {
      final result = createTestResult(emoji: '😊');
      await tester.pumpWidget(createTestApp(result: result));

      final emojiText = find.text('😊');
      expect(emojiText, findsOneWidget);

      // 이모지의 폰트 크기가 64로 설정되어 있는지 확인
      final textWidget = tester.widget<Text>(emojiText);
      expect(textWidget.style?.fontSize, equals(64));
    });

    testWidgets('한국어 결과 문장이 표시된다', (tester) async {
      final result = createTestResult(sentence: '화가 난 것 같아요');
      await tester.pumpWidget(createTestApp(result: result));

      expect(find.text('화가 난 것 같아요'), findsOneWidget);
    });

    testWidgets('감정 카테고리명이 한국어로 표시된다', (tester) async {
      final result = createTestResult(category: EmotionCategory.happy);
      await tester.pumpWidget(createTestApp(result: result));

      expect(find.text('행복'), findsOneWidget);
    });

    testWidgets('신뢰도가 정수 백분율로 표시된다', (tester) async {
      final result = createTestResult(confidencePercent: 92);
      await tester.pumpWidget(createTestApp(result: result));

      expect(find.text('92%'), findsOneWidget);
    });

    testWidgets('다시 분석하기 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(result: createTestResult()));

      expect(find.text('다시 분석하기'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('이력 보기 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(result: createTestResult()));

      expect(find.text('이력 보기'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('다시 분석하기 버튼을 누르면 콜백이 호출된다', (tester) async {
      var called = false;
      await tester.pumpWidget(createTestApp(
        result: createTestResult(),
        onAnalyzeAgain: () => called = true,
      ));

      await tester.tap(find.text('다시 분석하기'));
      expect(called, isTrue);
    });

    testWidgets('이력 보기 버튼을 누르면 콜백이 호출된다', (tester) async {
      var called = false;
      await tester.pumpWidget(createTestApp(
        result: createTestResult(),
        onViewHistory: () => called = true,
      ));

      // 버튼이 화면 밖에 있을 수 있으므로 스크롤 후 탭
      await tester.scrollUntilVisible(find.text('이력 보기'), 100);
      await tester.tap(find.text('이력 보기'));
      expect(called, isTrue);
    });

    testWidgets('다시 분석하기 버튼의 터치 영역이 44dp 이상이다', (tester) async {
      await tester.pumpWidget(createTestApp(result: createTestResult()));

      final buttonFinder = find.ancestor(
        of: find.text('다시 분석하기'),
        matching: find.byType(SizedBox),
      );
      expect(buttonFinder, findsWidgets);

      final buttonSize = tester.getSize(buttonFinder.first);
      expect(buttonSize.height, greaterThanOrEqualTo(44));
    });

    testWidgets('이력 보기 버튼의 터치 영역이 44dp 이상이다', (tester) async {
      await tester.pumpWidget(createTestApp(result: createTestResult()));

      final buttonFinder = find.ancestor(
        of: find.text('이력 보기'),
        matching: find.byType(SizedBox),
      );
      expect(buttonFinder, findsWidgets);

      final buttonSize = tester.getSize(buttonFinder.first);
      expect(buttonSize.height, greaterThanOrEqualTo(44));
    });

    testWidgets('화남 카테고리의 결과가 올바르게 표시된다', (tester) async {
      final result = createTestResult(
        sentence: '짜증이 난 것 같아요',
        emoji: '😠',
        confidencePercent: 75,
        category: EmotionCategory.angry,
      );
      await tester.pumpWidget(createTestApp(result: result));

      expect(find.text('😠'), findsOneWidget);
      expect(find.text('짜증이 난 것 같아요'), findsOneWidget);
      expect(find.text('화남'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('슬픔 카테고리의 결과가 올바르게 표시된다', (tester) async {
      final result = createTestResult(
        sentence: '슬퍼하는 것 같아요',
        emoji: '😢',
        confidencePercent: 63,
        category: EmotionCategory.sad,
      );
      await tester.pumpWidget(createTestApp(result: result));

      expect(find.text('😢'), findsOneWidget);
      expect(find.text('슬퍼하는 것 같아요'), findsOneWidget);
      expect(find.text('슬픔'), findsOneWidget);
      expect(find.text('63%'), findsOneWidget);
    });

    testWidgets('기타 카테고리의 결과가 올바르게 표시된다', (tester) async {
      final result = createTestResult(
        sentence: '독특한 표정의 것 같아요',
        emoji: '🤔',
        confidencePercent: 55,
        category: EmotionCategory.other,
      );
      await tester.pumpWidget(createTestApp(result: result));

      expect(find.text('🤔'), findsOneWidget);
      expect(find.text('독특한 표정의 것 같아요'), findsOneWidget);
      expect(find.text('기타'), findsOneWidget);
      expect(find.text('55%'), findsOneWidget);
    });

    testWidgets('이미지 위젯이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(result: createTestResult()));
      await tester.pumpAndSettle();

      // Image.file 위젯 또는 에러 시 대체 Container가 존재하는지 확인
      // 테스트 환경에서는 파일이 존재하지 않으므로 에러 빌더 또는 Image 위젯이 표시됨
      final imageWidget = find.byType(Image);
      final containerWidget = find.byIcon(Icons.image_not_supported);
      expect(
        imageWidget.evaluate().isNotEmpty ||
            containerWidget.evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('스크린 리더용 시맨틱스가 제공된다', (tester) async {
      final result = createTestResult(
        sentence: '행복해하는 것 같아요',
        emoji: '😊',
      );
      await tester.pumpWidget(createTestApp(result: result));

      // Semantics 위젯이 존재하는지 확인
      final semanticsWidgets = find.byType(Semantics);
      expect(semanticsWidgets, findsWidgets);

      // Semantics 위젯 중 적절한 label이 설정된 것이 있는지 확인
      final allSemantics = tester.widgetList<Semantics>(semanticsWidgets);
      final labels = allSemantics
          .where((s) => s.properties.label != null)
          .map((s) => s.properties.label!)
          .toList();

      expect(labels.any((l) => l.contains('입력 이미지')), isTrue);
      expect(labels.any((l) => l.contains('이모지')), isTrue);
      expect(labels.any((l) => l.contains('분석 결과')), isTrue);
    });
  });
}
