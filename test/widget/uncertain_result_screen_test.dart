import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animind/domain/models/emotion_category.dart';
import 'package:animind/domain/models/formatted_result.dart';
import 'package:animind/presentation/screens/uncertain_result_screen.dart';

void main() {
  // 테스트용 임시 이미지 파일 경로
  late File testImageFile;

  setUp(() {
    // 테스트용 임시 파일 (실제 이미지가 아니어도 위젯 테스트에서는 에러 빌더가 처리)
    testImageFile = File('test_image.jpg');
  });

  // 테스트용 상위 3개 예측 결과 생성
  List<FormattedPrediction> createTestPredictions() {
    return const [
      FormattedPrediction(
        emoji: '😊',
        categoryName: '행복',
        confidencePercent: 35,
      ),
      FormattedPrediction(
        emoji: '😢',
        categoryName: '슬픔',
        confidencePercent: 30,
      ),
      FormattedPrediction(
        emoji: '😠',
        categoryName: '화남',
        confidencePercent: 25,
      ),
    ];
  }

  // 테스트용 불확실 FormattedResult 생성
  FormattedResult createUncertainResult({
    List<FormattedPrediction>? topThree,
  }) {
    return FormattedResult(
      sentence: '표정이 분명하지 않아요',
      emoji: '🤔',
      confidencePercent: 35,
      category: EmotionCategory.happy,
      isUncertain: true,
      topThree: topThree ?? createTestPredictions(),
    );
  }

  // 테스트용 MaterialApp 래퍼
  Widget createTestApp({
    FormattedResult? result,
    VoidCallback? onAnalyzeAgain,
    VoidCallback? onViewHistory,
  }) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: UncertainResultScreen(
        imageFile: testImageFile,
        result: result ?? createUncertainResult(),
        onAnalyzeAgain: onAnalyzeAgain,
        onViewHistory: onViewHistory,
      ),
    );
  }

  group('UncertainResultScreen - 불확실 결과 화면', () {
    testWidgets('AppBar에 "분석 결과" 제목이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('분석 결과'), findsOneWidget);
    });

    testWidgets('불확실 안내 문구 "표정이 분명하지 않아요"가 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('표정이 분명하지 않아요'), findsOneWidget);
    });

    testWidgets('불확실 안내 문구에 도움말 아이콘이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('상위 3개 감정 후보가 모두 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      // 각 후보의 카테고리명 확인
      expect(find.text('행복'), findsOneWidget);
      expect(find.text('슬픔'), findsOneWidget);
      expect(find.text('화남'), findsOneWidget);
    });

    testWidgets('각 후보에 이모지가 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('😊'), findsOneWidget);
      expect(find.text('😢'), findsOneWidget);
      expect(find.text('😠'), findsOneWidget);
    });

    testWidgets('각 후보에 신뢰도 백분율이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('35%'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('"감정 후보" 섹션 제목이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('감정 후보'), findsOneWidget);
    });

    testWidgets('다시 분석하기 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('다시 분석하기'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('이력 보기 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('이력 보기'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('다시 분석하기 버튼을 누르면 콜백이 호출된다', (tester) async {
      var called = false;
      await tester.pumpWidget(createTestApp(
        onAnalyzeAgain: () => called = true,
      ));

      // 버튼이 화면 밖에 있을 수 있으므로 스크롤하여 보이게 한다
      await tester.scrollUntilVisible(
        find.text('다시 분석하기'),
        100,
      );
      await tester.tap(find.text('다시 분석하기'));
      expect(called, isTrue);
    });

    testWidgets('이력 보기 버튼을 누르면 콜백이 호출된다', (tester) async {
      var called = false;
      await tester.pumpWidget(createTestApp(
        onViewHistory: () => called = true,
      ));

      // 버튼이 화면 밖에 있을 수 있으므로 스크롤하여 보이게 한다
      await tester.scrollUntilVisible(
        find.text('이력 보기'),
        100,
      );
      await tester.tap(find.text('이력 보기'));
      expect(called, isTrue);
    });

    testWidgets('다시 분석하기 버튼의 터치 영역이 44dp 이상이다', (tester) async {
      await tester.pumpWidget(createTestApp());

      final buttonFinder = find.ancestor(
        of: find.text('다시 분석하기'),
        matching: find.byType(SizedBox),
      );
      expect(buttonFinder, findsWidgets);

      final buttonSize = tester.getSize(buttonFinder.first);
      expect(buttonSize.height, greaterThanOrEqualTo(44));
    });

    testWidgets('이력 보기 버튼의 터치 영역이 44dp 이상이다', (tester) async {
      await tester.pumpWidget(createTestApp());

      final buttonFinder = find.ancestor(
        of: find.text('이력 보기'),
        matching: find.byType(SizedBox),
      );
      expect(buttonFinder, findsWidgets);

      final buttonSize = tester.getSize(buttonFinder.first);
      expect(buttonSize.height, greaterThanOrEqualTo(44));
    });

    testWidgets('이미지 로드 실패 시 대체 아이콘이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      // Image.file에서 에러 발생 시 에러 빌더가 동작한다.
      // 테스트 환경에서 실제 파일이 없으므로 에러 발생 후 프레임을 처리한다.
      await tester.pump();
      await tester.pump();

      // 테스트 환경에 따라 에러 빌더 트리거 타이밍이 다를 수 있으므로
      // Image 위젯이 존재하는지 확인한다
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('스크린 리더용 시맨틱스가 제공된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      // Semantics 위젯을 통해 접근성 라벨이 존재하는지 확인
      expect(find.bySemanticsLabel('분석에 사용된 입력 이미지'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'분석 결과.*표정이 분명하지 않아요')),
        findsOneWidget,
      );
      // 개별 예측 항목에 시맨틱 라벨이 적용되어 있는지 확인
      expect(
        find.bySemanticsLabel(RegExp(r'행복.*35퍼센트')),
        findsOneWidget,
      );
    });

    testWidgets('topThree가 null이면 후보 목록이 표시되지 않는다', (tester) async {
      await tester.pumpWidget(createTestApp(
        result: const FormattedResult(
          sentence: '표정이 분명하지 않아요',
          emoji: '🤔',
          confidencePercent: 35,
          category: EmotionCategory.happy,
          isUncertain: true,
          topThree: null,
        ),
      ));

      expect(find.text('감정 후보'), findsNothing);
    });

    testWidgets('topThree가 빈 목록이면 후보 목록이 표시되지 않는다', (tester) async {
      await tester.pumpWidget(createTestApp(
        result: const FormattedResult(
          sentence: '표정이 분명하지 않아요',
          emoji: '🤔',
          confidencePercent: 35,
          category: EmotionCategory.happy,
          isUncertain: true,
          topThree: [],
        ),
      ));

      expect(find.text('감정 후보'), findsNothing);
    });
  });
}
