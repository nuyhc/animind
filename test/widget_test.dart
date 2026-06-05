import 'package:flutter_test/flutter_test.dart';
import 'package:animind/main.dart';

void main() {
  testWidgets('앱이 정상적으로 빌드되는지 확인', (WidgetTester tester) async {
    await tester.pumpWidget(const AnimindApp());
    expect(find.text('Animind - 동물 감정 인식'), findsOneWidget);
  });
}
