import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_connectivity/omni_connectivity.dart';

void main() {
  testWidgets('Example app renders expected connectivity UI', (
    WidgetTester tester,
  ) async {
    await OmniConnectivity.init(
      options: [InternetCheckOption(customProbe: () async => true)],
    );

    await tester.pumpWidget(const MyApp());

    expect(find.text('OmniConnectivity example'), findsOneWidget);
    expect(find.text('Check now'), findsOneWidget);
    expect(find.textContaining('Status:'), findsOneWidget);
  });

  testWidgets('Check now updates status text', (WidgetTester tester) async {
    await OmniConnectivity.init(
      options: [InternetCheckOption(customProbe: () async => true)],
    );

    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Check now'));
    await tester.pump();

    expect(find.text('Status: connected'), findsOneWidget);
  });
}
