import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:certifeasy/modules/generator/blocs/generator_bloc.dart';
import 'package:certifeasy/modules/generator/blocs/generator_event.dart';
import 'package:certifeasy/modules/generator/blocs/generator_state.dart';
import 'package:certifeasy/core/utils/csv_template.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GeneratorBloc', () {
    late GeneratorBloc generatorBloc;
    
    // Um PNG 1x1 transparente
    final Uint8List dummyImageBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      generatorBloc = GeneratorBloc();
    });

    tearDown(() {
      generatorBloc.close();
    });

    test('initial state is GeneratorInitial', () {
      expect(generatorBloc.state, isA<GeneratorInitial>());
    });

    blocTest<GeneratorBloc, GeneratorState>(
      'emits GeneratorLoaded when LoadFilesEvent is added with CSV',
      build: () => generatorBloc,
      act: (bloc) => bloc.add(LoadFilesEvent(csvContent: 'nome;evento;data;horas;email\nJoão;Tech;2023;8;a@b.com')),
      skip: 1, // skips the GeneratorSuccess message
      expect: () => [
        isA<GeneratorLoaded>()
            .having((s) => s.csvHeaders, 'headers', ['nome', 'evento', 'data', 'horas', 'email'])
            .having((s) => s.mappedData.length, 'data length', 1)
            .having((s) => s.mappedData[0]['nome'], 'first row nome', 'João')
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'decodes CSV correctly when it has Latin-1 encoding fallbacks (simulated via string)',
      build: () => generatorBloc,
      act: (bloc) => bloc.add(LoadFilesEvent(csvContent: 'nome,evento,data,horas,email\nJohn,E,D,30,j@b.com')),
      skip: 1,
      expect: () => [
        isA<GeneratorLoaded>()
            .having((s) => s.csvHeaders, 'headers', ['nome', 'evento', 'data', 'horas', 'email'])
            .having((s) => s.mappedData.length, 'data length', 1)
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'importa linhas Excel usando a mesma validação de CSV/TSV',
      build: () => generatorBloc,
      act: (bloc) => bloc.add(LoadFilesEvent(tableRows: [
        ['Nome', 'Orientador(a)', 'Título do trabalho',
         'Evento', 'Data', 'E-mail', 'E-mail do orientador'],
        ['OLIVEIRA, Ana', 'Profa. Marta', 'Educação em Química',
         'Mostra Científica', '9-out.', 'ana@example.com',
         'marta@ifce.example'],
      ])),
      expect: () => [
        isA<GeneratorSuccess>(),
        isA<GeneratorLoaded>()
            .having((s) => s.mappedData.length, 'linhas', 1)
            .having((s) => s.mappedData.single['nome'], 'nome', 'OLIVEIRA, Ana')
            .having((s) => s.mappedData.single['nome_trabalho'],
                'título', 'Educação em Química')
            .having((s) => s.mappedData.single['horas'],
                'horas não informadas', '')
            .having((s) => s.emailColumn,
                'destinatário continua email', 'email'),
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'rejeita linhas Excel tradicionais sem horas e preserva estado',
      seed: () => GeneratorLoaded(
        csvData: const [
          ['nome', 'evento', 'data', 'horas', 'email'],
          ['Ana', 'Curso', '10/10/2026', '4', 'ana@example.com'],
        ],
        csvHeaders: const ['nome', 'evento', 'data', 'horas', 'email'],
        mappedData: const [
          {'nome': 'Ana', 'evento': 'Curso', 'data': '10/10/2026',
           'horas': '4', 'email': 'ana@example.com'},
        ],
        templateImageBytes: dummyImageBytes,
      ),
      build: () => generatorBloc,
      act: (bloc) => bloc.add(LoadFilesEvent(tableRows: [
        ['nome', 'evento', 'data', 'email'],
        ['Bia', 'Curso', '10/10/2026', 'bia@example.com'],
      ])),
      expect: () => [
        isA<GeneratorError>().having(
          (error) => error.message, 'erro', contains('horas')),
        isA<GeneratorLoaded>()
            .having((s) => s.mappedData.single['nome'],
                'mantém estado anterior', 'Ana'),
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'emits GeneratorLoaded when LoadBackImageEvent is added',
      seed: () => GeneratorLoaded(
        csvData: const [['test1', 'test2'], ['a', 'b']],
        csvHeaders: const ['test1', 'test2'],
        mappedData: const [{'test1': 'a', 'test2': 'b'}],
      ),
      build: () => generatorBloc,
      act: (bloc) => bloc.add(LoadBackImageEvent(dummyImageBytes)),
      skip: 1, // skip the load back image success message
      expect: () => [
        isA<GeneratorLoaded>()
            .having((s) => s.backTemplateImageBytes, 'backTemplateImageBytes', isNotNull)
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'updates text position correctly',
      seed: () => GeneratorLoaded(
        csvData: const [['a'], ['b']],
        csvHeaders: const ['a'],
        mappedData: const [{'a': 'b'}],
      ),
      build: () => generatorBloc,
      act: (bloc) => bloc.add(UpdateTextPositionEvent(dx: 0.2, dy: 0.8)),
      skip: 0,
      expect: () => [
        isA<GeneratorLoaded>()
            .having((s) => s.textPositionX, 'x', 0.2)
            .having((s) => s.textPositionY, 'y', 0.8)
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'updates PDF mode correctly',
      seed: () => GeneratorLoaded(
        csvData: const [['a'], ['b']],
        csvHeaders: const ['a'],
        mappedData: const [{'a': 'b'}],
      ),
      build: () => generatorBloc,
      act: (bloc) => bloc.add(UpdatePdfModeEvent(PdfMode.frontAndBack)),
      skip: 0,
      expect: () => [
        isA<GeneratorLoaded>()
            .having((s) => s.pdfMode, 'pdfMode', PdfMode.frontAndBack)
      ],
    );

    test('canSendEmails requires the access code', () {
      final base = GeneratorLoaded(
        csvData: const [['nome', 'email'], ['Ana', 'ana@exemplo.com']],
        csvHeaders: const ['nome', 'email'],
        mappedData: const [{'nome': 'Ana', 'email': 'ana@exemplo.com'}],
        templateImageBytes: dummyImageBytes,
        senderEmail: 'contato@exemplo.com',
      );
      expect(base.canSendEmails, isFalse);
      expect(base.copyWith(emailAccessCode: 'segredo').canSendEmails, isTrue);
    });

    blocTest<GeneratorBloc, GeneratorState>(
      'rejects an invalid reply-to e-mail before sending anything',
      seed: () => GeneratorLoaded(
        csvData: const [['nome', 'email'], ['Ana', 'ana@exemplo.com']],
        csvHeaders: const ['nome', 'email'],
        mappedData: const [{'nome': 'Ana', 'email': 'ana@exemplo.com'}],
        templateImageBytes: dummyImageBytes,
        senderEmail: 'sem-arroba',
        emailAccessCode: 'segredo',
      ),
      build: () => generatorBloc,
      act: (bloc) => bloc.add(SendEmailsBatchEvent()),
      expect: () => [
        isA<GeneratorError>(),
        isA<GeneratorLoaded>().having((s) => s.isSendingEmails, 'isSendingEmails', false),
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'accepts the downloadable CSV template (with UTF-8 BOM) without errors',
      build: () => generatorBloc,
      act: (bloc) => bloc.add(LoadFilesEvent(csvContent: utf8.decode(csvTemplateBytes()))),
      expect: () => [
        isA<GeneratorSuccess>(),
        isA<GeneratorLoaded>()
            .having((s) => s.csvHeaders, 'headers', [
              'nome', 'evento', 'data', 'horas', 'email',
              'orientador', 'email_orientador', 'nome_trabalho',
            ])
            .having((s) => s.mappedData.length, 'data length', 2)
            .having((s) => s.mappedData[0]['nome'], 'first row nome', 'João Silva')
            .having((s) => s.mappedData[0]['orientador'], 'orientador', 'Prof. Carlos Lima')
            .having((s) => s.mappedData[0]['nome_trabalho'], 'nome do trabalho', 'Inovação no Ensino')
            .having((s) => s.mappedData[1]['email_orientador'], 'email orientador', 'ana.costa@exemplo.com'),
      ],
    );

    test('bloqueia envio quando a coluna salva não pertence ao CSV atual', () {
      final state = GeneratorLoaded(
        csvData: const [
          ['nome', 'email', 'email_orientador'],
          ['Ana', 'ana@exemplo.com', 'prof@exemplo.com'],
        ],
        csvHeaders: const ['nome', 'email', 'email_orientador'],
        mappedData: const [
          {'nome': 'Ana', 'email': 'ana@exemplo.com',
           'email_orientador': 'prof@exemplo.com'},
        ],
        templateImageBytes: dummyImageBytes,
        senderEmail: 'contato@exemplo.com',
        emailAccessCode: 'segredo',
        emailColumn: 'email_antigo',
      );
      expect(state.hasValidEmailColumn, isFalse);
      expect(state.canSendEmails, isFalse);
      expect(state.copyWith(emailColumn: 'email').canSendEmails, isTrue);
      // Uma seleção deliberada pode usar outra coluna, mas nunca é automática.
      expect(state.copyWith(emailColumn: 'email_orientador').canSendEmails, isTrue);
    });

    blocTest<GeneratorBloc, GeneratorState>(
      'rejeita coluna ausente antes de gerar ou enviar qualquer e-mail',
      seed: () => GeneratorLoaded(
        csvData: const [['nome', 'email'], ['Ana', 'ana@exemplo.com']],
        csvHeaders: const ['nome', 'email'],
        mappedData: const [{'nome': 'Ana', 'email': 'ana@exemplo.com'}],
        templateImageBytes: dummyImageBytes,
        senderEmail: 'contato@exemplo.com',
        emailAccessCode: 'segredo',
        emailColumn: 'email_antigo',
      ),
      build: () => generatorBloc,
      act: (bloc) => bloc.add(SendEmailsBatchEvent()),
      expect: () => [
        isA<GeneratorError>().having(
          (s) => s.message,
          'erro explicativo',
          contains('email_antigo'),
        ),
        isA<GeneratorLoaded>().having(
          (s) => s.isSendingEmails,
          'não inicia envio',
          false,
        ),
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'aceita CSV antigo sem campos de orientador',
      build: () => generatorBloc,
      act: (bloc) => bloc.add(LoadFilesEvent(
        csvContent: 'nome;evento;data;horas;email\nAna;Feira;2026;4;ana@exemplo.com',
      )),
      expect: () => [
        isA<GeneratorSuccess>(),
        isA<GeneratorLoaded>()
            .having((s) => s.csvHeaders.length, 'colunas antigas', 5)
            .having((s) => s.mappedData.single['nome'], 'nome', 'Ana'),
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'mantém campos opcionais mesmo com valores vazios',
      build: () => generatorBloc,
      act: (bloc) => bloc.add(LoadFilesEvent(
        csvContent: 'nome;evento;data;horas;email;orientador;email_orientador;nome_trabalho\n'
            'Ana;Feira;2026;4;ana@exemplo.com;;;Pesquisa Aplicada',
      )),
      expect: () => [
        isA<GeneratorSuccess>(),
        isA<GeneratorLoaded>()
            .having((s) => s.mappedData.single['nome_trabalho'], 'trabalho', 'Pesquisa Aplicada')
            .having((s) => s.mappedData.single['orientador'], 'orientador vazio', ''),
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'importa mostra científica TSV sem carga horária, preservando destinatários',
      build: () => generatorBloc,
      act: (bloc) => bloc.add(LoadFilesEvent(
        csvContent: 'Nome\tOrientador(a)\tTítulo do trabalho\tEvento\tData\tE-mail\tE-mail do orientador\n'
            'SILVA, Ana\tProfa. Marta\tEstudo de Química\tII Mostra Científica\t9-out.\t'
            'ana@example.com\tProfa. Marta <marta@ifce.example>',
      )),
      expect: () => [
        isA<GeneratorSuccess>(),
        isA<GeneratorLoaded>()
            .having((s) => s.mappedData.length, 'participantes', 1)
            .having((s) => s.mappedData.single['nome'], 'nome', 'SILVA, Ana')
            .having((s) => s.mappedData.single['nome_trabalho'], 'título', 'Estudo de Química')
            .having((s) => s.mappedData.single['orientador'], 'orientador', 'Profa. Marta')
            .having((s) => s.mappedData.single['email'], 'destinatário', 'ana@example.com')
            .having((s) => s.mappedData.single['email_orientador'], 'email professor', 'marta@ifce.example')
            .having((s) => s.mappedData.single['horas'], 'horas não informadas', '')
            .having((s) => s.emailColumn, 'coluna de envio preservada', 'email'),
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'não aceita CSV tradicional sem horas',
      seed: () => GeneratorLoaded(
        csvData: const [
          ['nome', 'evento', 'data', 'horas', 'email'],
          ['Ana', 'Curso', '11/09', '8', 'ana@example.com'],
        ],
        csvHeaders: const ['nome', 'evento', 'data', 'horas', 'email'],
        mappedData: const [
          {'nome': 'Ana', 'evento': 'Curso', 'data': '11/09',
           'horas': '8', 'email': 'ana@example.com'},
        ],
        templateImageBytes: dummyImageBytes,
      ),
      build: () => generatorBloc,
      act: (bloc) => bloc.add(LoadFilesEvent(
        csvContent: 'nome;evento;data;email\nBia;Curso;10/10;bia@example.com',
      )),
      expect: () => [
        isA<GeneratorError>().having(
          (e) => e.message,
          'coluna obrigatória',
          contains('horas'),
        ),
        isA<GeneratorLoaded>()
            .having((s) => s.mappedData.single['nome'], 'não perdeu os dados', 'Ana')
            .having((s) => s.templateImageBytes, 'não perdeu arte', isNotNull),
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'keeps previously loaded data when an invalid CSV is uploaded',
      seed: () => GeneratorLoaded(
        csvData: const [['nome'], ['Ana']],
        csvHeaders: const ['nome'],
        mappedData: const [{'nome': 'Ana'}],
        templateImageBytes: dummyImageBytes,
      ),
      build: () => generatorBloc,
      act: (bloc) => bloc.add(LoadFilesEvent(csvContent: 'nome;horas\nJoão;8')),
      expect: () => [
        isA<GeneratorError>(),
        isA<GeneratorLoaded>()
            .having((s) => s.templateImageBytes, 'templateImageBytes', isNotNull)
            .having((s) => s.mappedData.length, 'data length', 1),
      ],
    );

    test('keeps a CSV loaded while e-mail settings are being saved', () async {
      const csvA = 'nome;evento;data;horas;email\nTeste;Exemplo;01/01;1;t@x.com';
      const csvB = 'nome;evento;data;horas;email\nAna Real;Evento Real;02/02;2;ana@x.com';
      generatorBloc.add(LoadFilesEvent(csvContent: csvA, imageBytes: dummyImageBytes));
      await Future<void>.delayed(Duration.zero);

      generatorBloc.add(UpdateEmailConfigEvent(emailSubject: 'Seu certificado'));
      generatorBloc.add(LoadFilesEvent(csvContent: csvB));
      generatorBloc.add(UpdateTemplateEvent(textTemplate: 'Meu texto {nome}'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final s = generatorBloc.state as GeneratorLoaded;
      expect(s.mappedData.single['nome'], 'Ana Real');
      expect(s.textTemplate, 'Meu texto {nome}');
      expect(s.emailSubject, 'Seu certificado');
    });

    test('a message state in between does not reset the loaded data', () async {
      generatorBloc.add(LoadFilesEvent(
        csvContent: 'nome;evento;data;horas;email\nAna;E;D;1;a@x.com',
        imageBytes: dummyImageBytes,
      ));
      await Future<void>.delayed(Duration.zero);
      generatorBloc.add(UpdateTemplateEvent(textTemplate: 'Texto do usuário'));
      // Um CSV inválido gera uma mensagem de erro e não pode apagar o resto.
      generatorBloc.add(LoadFilesEvent(csvContent: 'a;b\n1;2'));
      final newImage = Uint8List.fromList([...dummyImageBytes]);
      generatorBloc.add(LoadFilesEvent(imageBytes: newImage));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final s = generatorBloc.state as GeneratorLoaded;
      expect(s.textTemplate, 'Texto do usuário');
      expect(s.mappedData.single['nome'], 'Ana');
      expect(identical(s.templateImageBytes, newImage), isTrue);
    });
  });
}
