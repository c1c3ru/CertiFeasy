import 'package:certifeasy/modules/generator/widgets/email_privacy_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app() => const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 350,
            child: SingleChildScrollView(child: EmailPrivacyNotice()),
          ),
        ),
      );

  testWidgets('mostra apenas explicação curta ao abrir', (tester) async {
    await tester.pumpWidget(app());

    expect(find.byKey(const Key('email-privacy-notice')), findsOneWidget);
    expect(find.text('Por que pedimos seu e-mail?'), findsOneWidget);
    expect(
      find.textContaining('confirma sua autorização'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('email-privacy-details')), findsNothing);
  });

  testWidgets('expande informações LGPD sem modal invasivo', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.byKey(const Key('email-privacy-details-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('email-privacy-details')), findsOneWidget);
    expect(find.textContaining('Gmail'), findsOneWidget);
    expect(find.textContaining('LGPD'), findsOneWidget);

    await tester.tap(find.byKey(const Key('email-privacy-details-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('email-privacy-details')), findsNothing);
  });
}
