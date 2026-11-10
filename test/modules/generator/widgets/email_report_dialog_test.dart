import 'package:certifeasy/core/services/email_service.dart';
import 'package:certifeasy/modules/generator/blocs/generator_state.dart';
import 'package:certifeasy/modules/generator/widgets/email_report_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('separa erro de digitação de problema técnico', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EmailReportDialog(
          report: GeneratorEmailReport(
            sentCount: 17,
            failures: const [
              EmailFailure(
                name: 'Ana',
                email: 'ana@gmial.com',
                kind: EmailFailureKind.invalidAddress,
                detail: 'domínio "gmial.com" parece digitado errado',
                suggestion: 'ana@gmail.com',
              ),
              EmailFailure(
                name: 'Bruno',
                email: 'bruno@ifce.edu.br',
                kind: EmailFailureKind.technical,
                detail: 'sem conexão com o servidor (confira a internet)',
              ),
            ],
          ),
        ),
      ),
    ));

    expect(find.text('17 enviado(s) · 2 com problema'), findsOneWidget);
    expect(find.text('E-mail digitado errado na planilha (1)'), findsOneWidget);
    expect(find.textContaining('Você quis dizer ana@gmail.com?'), findsOneWidget);
    expect(find.text('Problema técnico (internet, Gmail ou servidor) (1)'), findsOneWidget);
    expect(find.text('Bruno — bruno@ifce.edu.br'), findsOneWidget);
    expect(find.textContaining('Envio não autorizado'), findsNothing);
  });
}
