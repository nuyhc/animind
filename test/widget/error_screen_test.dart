import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animind/presentation/screens/error_screen.dart';

void main() {
  // 테스트용 MaterialApp 래퍼
  Widget createTestApp({
    required String errorMessage,
    VoidCallback? onRetry,
    VoidCallback? onGoHome,
  }) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: ErrorScreen(
        errorMessage: errorMessage,
        onRetry: onRetry,
        onGoHome: onGoHome,
      ),
    );
  }

  group('ErrorScreen', () {
    testWidgets('오류 메시지가 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(
        errorMessage: '감정 분석 중 오류가 발생했습니다',
      ));

      expect(find.text('감정 분석 중 오류가 발생했습니다'), findsOneWidget);
    });

    testWidgets('오류 아이콘이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(
        errorMessage: '오류 발생',
      ));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('재시도 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(
        errorMessage: '오류 발생',
      ));

      expect(find.text('재시도'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('메인으로 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(
        errorMessage: '오류 발생',
      ));

      expect(find.text('메인으로'), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    });

    testWidgets('재시도 버튼을 누르면 onRetry 콜백이 호출된다', (tester) async {
      var retryCalled = false;

      await tester.pumpWidget(createTestApp(
        errorMessage: '오류 발생',
        onRetry: () => retryCalled = true,
      ));

      await tester.tap(find.text('재시도'));
      expect(retryCalled, isTrue);
    });

    testWidgets('메인으로 버튼을 누르면 onGoHome 콜백이 호출된다', (tester) async {
      var goHomeCalled = false;

      await tester.pumpWidget(createTestApp(
        errorMessage: '오류 발생',
        onGoHome: () => goHomeCalled = true,
      ));

      await tester.tap(find.text('메인으로'));
      expect(goHomeCalled, isTrue);
    });

    testWidgets('재시도 버튼의 터치 영역이 44dp 이상이다', (tester) async {
      await tester.pumpWidget(createTestApp(
        errorMessage: '오류 발생',
      ));

      final retryButton = find.text('재시도');
      final sizedBox = find.ancestor(
        of: retryButton,
        matching: find.byType(SizedBox),
      ).first;
      final size = tester.getSize(sizedBox);
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('메인으로 버튼의 터치 영역이 44dp 이상이다', (tester) async {
      await tester.pumpWidget(createTestApp(
        errorMessage: '오류 발생',
      ));

      final homeButton = find.text('메인으로');
      final sizedBox = find.ancestor(
        of: homeButton,
        matching: find.byType(SizedBox),
      ).first;
      final size = tester.getSize(sizedBox);
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('다양한 오류 메시지를 전달받아 표시할 수 있다', (tester) async {
      await tester.pumpWidget(createTestApp(
        errorMessage: '메모리 부족으로 분석을 수행할 수 없습니다',
      ));

      expect(
        find.text('메모리 부족으로 분석을 수행할 수 없습니다'),
        findsOneWidget,
      );
    });

    testWidgets('AppBar에 오류 제목이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp(
        errorMessage: '오류 발생',
      ));

      expect(find.text('오류'), findsOneWidget);
    });
  });
}
