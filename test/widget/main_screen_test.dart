import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animind/presentation/screens/main_screen.dart';

void main() {
  // 테스트용 MaterialApp 래퍼 (ProviderScope 포함)
  Widget createTestApp() {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const MainScreen(),
      ),
    );
  }

  group('MainScreen', () {
    testWidgets('카메라 촬영 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('카메라로 촬영하기'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('갤러리 선택 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('갤러리에서 선택하기'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library), findsOneWidget);
    });

    testWidgets('이력 진입 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      // AppBar의 이력 아이콘 버튼
      expect(find.byIcon(Icons.history), findsWidgets);
      // 본문의 텍스트 버튼
      expect(find.text('분석 이력 보기'), findsOneWidget);
    });

    testWidgets('지원 입력 조건 안내가 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('입력 조건 안내'), findsOneWidget);
      expect(find.textContaining('JPG, PNG'), findsOneWidget);
      expect(find.textContaining('10MB 이하'), findsOneWidget);
      expect(find.textContaining('50×50'), findsOneWidget);
      expect(find.textContaining('반려동물 표정'), findsOneWidget);
    });

    testWidgets('카메라 촬영 버튼의 터치 영역이 44dp 이상이다', (tester) async {
      await tester.pumpWidget(createTestApp());

      // FilledButton.icon의 SizedBox 높이가 56으로 설정됨 (>=44dp)
      final cameraButton = find.text('카메라로 촬영하기');
      expect(cameraButton, findsOneWidget);

      final buttonSize = tester.getSize(cameraButton.evaluate().first.widget is Text
          ? find.ancestor(of: cameraButton, matching: find.byType(SizedBox)).first
          : cameraButton);
      expect(buttonSize.height, greaterThanOrEqualTo(44));
    });

    testWidgets('갤러리 선택 버튼의 터치 영역이 44dp 이상이다', (tester) async {
      await tester.pumpWidget(createTestApp());

      final galleryButton = find.text('갤러리에서 선택하기');
      expect(galleryButton, findsOneWidget);

      final buttonSize = tester.getSize(find.ancestor(
        of: galleryButton,
        matching: find.byType(SizedBox),
      ).first);
      expect(buttonSize.height, greaterThanOrEqualTo(44));
    });

    testWidgets('이력 아이콘 버튼의 터치 영역이 44dp 이상이다', (tester) async {
      await tester.pumpWidget(createTestApp());

      // AppBar 내 IconButton
      final iconButtons = find.byType(IconButton);
      expect(iconButtons, findsWidgets);

      // 첫 번째 IconButton(이력 버튼)의 constraints 확인
      final iconButton = tester.widget<IconButton>(iconButtons.first);
      expect(iconButton.constraints?.minWidth, greaterThanOrEqualTo(44));
      expect(iconButton.constraints?.minHeight, greaterThanOrEqualTo(44));
    });

    testWidgets('앱 제목이 AppBar에 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('Animind'), findsOneWidget);
    });

    testWidgets('반려동물 감정 분석 소개 텍스트가 표시된다', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('반려동물 감정 분석'), findsOneWidget);
      expect(
        find.textContaining('사진을 촬영하거나 선택하여'),
        findsOneWidget,
      );
    });
  });
}
