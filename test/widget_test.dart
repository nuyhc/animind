import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animind/main.dart';

void main() {
  testWidgets('앱이 정상적으로 빌드되어 메인 화면을 표시한다', (WidgetTester tester) async {
    // AnimindApp은 ProviderScope 하위에서 동작한다(MainScreen이 Riverpod 사용).
    await tester.pumpWidget(const ProviderScope(child: AnimindApp()));

    // 메인 화면의 핵심 진입 요소가 렌더링되는지 확인한다.
    expect(find.text('카메라로 촬영하기'), findsOneWidget);
    expect(find.text('갤러리에서 선택하기'), findsOneWidget);
  });
}
