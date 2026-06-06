import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animind/presentation/screens/permission_screen.dart';

void main() {
  // 테스트용 MaterialApp 래퍼
  Widget createTestApp({VoidCallback? onGoHome}) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: PermissionScreen(onGoHome: onGoHome),
    );
  }

  group('PermissionScreen', () {
    testWidgets('권한 필요 메시지가 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(
        find.textContaining('카메라/갤러리 사용을 위해'),
        findsOneWidget,
      );
      expect(
        find.textContaining('권한이 필요합니다'),
        findsOneWidget,
      );
    });

    testWidgets('권한 아이콘이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('설정 열기 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('설정 열기'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('메인으로 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('메인으로'), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    });

    testWidgets('메인으로 버튼을 누르면 onGoHome 콜백이 호출된다', (tester) async {
      var goHomeCalled = false;

      await tester.pumpWidget(createTestApp(
        onGoHome: () => goHomeCalled = true,
      ));

      await tester.tap(find.text('메인으로'));
      expect(goHomeCalled, isTrue);
    });

    testWidgets('설정 열기 버튼의 터치 영역이 44dp 이상이다', (tester) async {
      await tester.pumpWidget(createTestApp());

      final settingsButton = find.text('설정 열기');
      final sizedBox = find.ancestor(
        of: settingsButton,
        matching: find.byType(SizedBox),
      ).first;
      final size = tester.getSize(sizedBox);
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('메인으로 버튼의 터치 영역이 44dp 이상이다', (tester) async {
      await tester.pumpWidget(createTestApp());

      final homeButton = find.text('메인으로');
      final sizedBox = find.ancestor(
        of: homeButton,
        matching: find.byType(SizedBox),
      ).first;
      final size = tester.getSize(sizedBox);
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('AppBar에 권한 필요 제목이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('권한 필요'), findsOneWidget);
    });

    testWidgets('설정 안내 부가 설명이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(
        find.textContaining('설정에서 카메라 및 사진 접근 권한을'),
        findsOneWidget,
      );
    });
  });
}
