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
        csvData: const [['nome'], ['Ana']],
        csvHeaders: const ['nome'],
        mappedData: const [{'nome': 'Ana'}],
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
            .having((s) => s.csvHeaders, 'headers', ['nome', 'evento', 'data', 'horas', 'email'])
            .having((s) => s.mappedData.length, 'data length', 2)
            .having((s) => s.mappedData[0]['nome'], 'first row nome', 'João Silva'),
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
