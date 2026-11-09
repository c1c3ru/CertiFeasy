import 'package:certifeasy/modules/generator/widgets/email_recipient_column_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('não apresenta fallback visual para a primeira coluna', (tester) async {
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmailRecipientColumnSelector(
            headers: const ['nome', 'email', 'email_orientador'],
            selectedColumn: 'email_csv_antigo',
            onChanged: (column) => chosen = column,
          ),
        ),
      ),
    );

    final dropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const Key('recipient-column-dropdown')),
    );
    expect(dropdown.value, isNull);
    expect(find.text('Selecione uma coluna'), findsOneWidget);
    expect(find.byKey(const Key('missing-recipient-column-warning')), findsOneWidget);

    await tester.tap(find.byKey(const Key('recipient-column-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('email').last);
    await tester.pumpAndSettle();
    expect(chosen, 'email');
  });

  testWidgets('exibe a seleção quando o CSV contém a coluna', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmailRecipientColumnSelector(
            headers: const ['nome', 'email'],
            selectedColumn: 'email',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(
      tester.widget<DropdownButton<String>>(
        find.byKey(const Key('recipient-column-dropdown')),
      ).value,
      'email',
    );
    expect(find.byKey(const Key('missing-recipient-column-warning')), findsNothing);
  });
}
