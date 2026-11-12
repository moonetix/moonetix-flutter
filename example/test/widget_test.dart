import 'package:flutter_test/flutter_test.dart';
import 'package:moonetix_offerwall_example/main.dart';

void main() {
  test('reads app and token from a demo link and from a route', () {
    const String app = 'eeee35416ef2e85e9b4d8203';
    final String token = 'sst_${'a' * 43}';
    for (final String text in <String>[
      'moonetix-flutter-demo://open?app=$app&token=$token',
      '/?app=$app&token=$token',
    ]) {
      final DemoLink? link = DemoLink.parse(text);
      expect(link?.appId, app);
      expect(link?.token, token);
    }
    expect(DemoLink.parse('/'), isNull);
    expect(DemoLink.parse('/?app=nope&token=nope'), isNull);
    expect(DemoLink.fromClipboard('token: $token')?.token, token);
  });

  testWidgets('shows the form', (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    expect(find.text('App ID'), findsOneWidget);
    expect(find.text('Session token'), findsOneWidget);
    expect(find.text('Open offerwall'), findsOneWidget);
  });
}
