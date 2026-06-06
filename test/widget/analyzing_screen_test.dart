import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animind/presentation/screens/analyzing_screen.dart';

void main() {
  group('AnalyzingScreen', () {
    late File testImageFile;

    setUp(() {
      // 테스트용 임시 이미지 파일 경로 (실제 파일 존재 여부와 무관하게 위젯 구조 테스트)
      testImageFile = File('test/fixtures/test_image.jpg');
    });

    Widget createTestWidget({File? imageFile}) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: AnalyzingScreen(imageFile: imageFile ?? testImageFile),
      );
    }

    testWidgets('로딩 인디케이터가 표시되어야 한다', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // CircularProgressIndicator 존재 확인
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('진행 중 문구가 표시되어야 한다', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // 주요 진행 중 문구 확인
      expect(find.text('감정을 분석하고 있어요...'), findsOneWidget);
    });

    testWidgets('보조 안내 문구가 표시되어야 한다', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // 보조 문구 확인
      expect(find.text('잠시만 기다려 주세요'), findsOneWidget);
    });

    testWidgets('이미지 미리보기 영역이 존재해야 한다', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Image.file 위젯 존재 확인 (이미지 로딩 실패 시 errorBuilder 동작)
      // 실제 파일이 없으므로 errorBuilder에 의해 대체 아이콘이 표시됨
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('이미지 미리보기에 ClipRRect으로 둥근 모서리가 적용되어야 한다', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // ClipRRect 위젯 존재 확인
      expect(find.byType(ClipRRect), findsOneWidget);

      // 둥근 모서리 적용 확인
      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, BorderRadius.circular(16.0));
    });

    testWidgets('스크린 리더를 위한 접근성 레이블이 존재해야 한다', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Semantics 위젯에서 접근성 레이블 확인
      expect(
        find.bySemanticsLabel('분석 중인 이미지 미리보기'),
        findsOneWidget,
      );
    });

    testWidgets('Material Design 3 테마가 적용되어야 한다', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Scaffold 배경색이 surface 색상인지 확인
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      );
      expect(scaffold.backgroundColor, theme.colorScheme.surface);
    });
  });
}
