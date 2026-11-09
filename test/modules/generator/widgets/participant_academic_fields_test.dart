import 'package:certifeasy/modules/generator/widgets/participant_academic_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('permite preencher campos acadêmicos e trocar participante',
      (tester) async {
    final rows = <Map<String, dynamic>>[
      {
        'nome': 'Ana',
        'orientador': 'Prof. Carlos',
        'email_orientador': 'carlos@instituicao.edu.br',
        'nome_trabalho': 'Trabalho A',
      },
      {
        'nome': 'Bia',
        'orientador': 'Profa. Beatriz',
        'email_orientador': '',
        'nome_trabalho': 'Trabalho B',
      },
    ];
    var selectedIndex = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: ParticipantAcademicFields(
              rowIndex: selectedIndex,
              participantCount: rows.length,
              rowData: rows[selectedIndex],
              enabled: true,
              onSelectRow: (value) =>
                  setState(() => selectedIndex = value),
              onChanged: (field, value) => setState(() {
                rows[selectedIndex] = {
                  ...rows[selectedIndex],
                  field.column: value,
                };
              }),
            ),
          ),
        ),
      ),
    ));

    TextFormField field(String key) =>
        tester.widget<TextFormField>(find.byKey(Key(key)));

    expect(field('academic-orientador').controller!.text, 'Prof. Carlos');
    expect(field('academic-email-orientador').controller!.text,
        'carlos@instituicao.edu.br');
    expect(field('academic-nome-trabalho').controller!.text, 'Trabalho A');

    await tester.ensureVisible(find.byKey(const Key('academic-orientador')));
    await tester.enterText(
      find.byKey(const Key('academic-orientador')),
      'Prof. Carlos Atualizado',
    );
    await tester.pump();
    expect(rows[0]['orientador'], 'Prof. Carlos Atualizado');

    await tester.tap(find.byKey(const Key('academic-next-participant')));
    await tester.pump();
    expect(field('academic-orientador').controller!.text, 'Profa. Beatriz');
    expect(field('academic-nome-trabalho').controller!.text, 'Trabalho B');
    expect(rows[0]['orientador'], 'Prof. Carlos Atualizado');

    await tester.tap(find.byKey(const Key('academic-previous-participant')));
    await tester.pump();
    expect(field('academic-orientador').controller!.text,
        'Prof. Carlos Atualizado');
  });

  testWidgets('desabilita edição e navegação durante exportação',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ParticipantAcademicFields(
          rowIndex: 0,
          participantCount: 2,
          rowData: const {'nome': 'Ana'},
          enabled: false,
          onSelectRow: (_) => fail('Não deve navegar'),
          onChanged: (_, _) => fail('Não deve editar'),
        ),
      ),
    ));
    expect(
      tester.widget<TextFormField>(
        find.byKey(const Key('academic-nome-trabalho')),
      ).enabled,
      false,
    );
    expect(
      tester.widget<IconButton>(
        find.byKey(const Key('academic-next-participant')),
      ).onPressed,
      isNull,
    );
  });
}
