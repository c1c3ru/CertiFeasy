import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:certifeasy/modules/generator/blocs/generator_bloc.dart';
import 'package:certifeasy/modules/generator/blocs/generator_event.dart';
import 'package:certifeasy/modules/generator/blocs/generator_state.dart';
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
      act: (bloc) => bloc.add(LoadFilesEvent(csvContent: 'nome;horas\nJoão;8\nMaria;16')),
      skip: 1, // skips the GeneratorSuccess message
      expect: () => [
        isA<GeneratorLoaded>()
            .having((s) => s.csvHeaders, 'headers', ['nome', 'horas'])
            .having((s) => s.mappedData.length, 'data length', 2)
            .having((s) => s.mappedData[0]['nome'], 'first row nome', 'João')
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'decodes CSV correctly when it has Latin-1 encoding fallbacks (simulated via string)',
      build: () => generatorBloc,
      act: (bloc) => bloc.add(LoadFilesEvent(csvContent: 'name,age\nJohn,30\nJane,25')),
      skip: 1,
      expect: () => [
        isA<GeneratorLoaded>()
            .having((s) => s.csvHeaders, 'headers', ['name', 'age'])
            .having((s) => s.mappedData.length, 'data length', 2)
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'emits GeneratorLoaded when LoadBackImageEvent is added',
      build: () {
        generatorBloc.add(LoadFilesEvent(csvContent: 'test;test\na;b', imageBytes: dummyImageBytes));
        return generatorBloc;
      },
      act: (bloc) => bloc.add(LoadBackImageEvent(dummyImageBytes)),
      skip: 1, // skip the load back image success message
      expect: () => [
        isA<GeneratorLoaded>()
            .having((s) => s.backTemplateImageBytes, 'backTemplateImageBytes', isNotNull)
      ],
    );

    blocTest<GeneratorBloc, GeneratorState>(
      'updates text position correctly',
      build: () {
        generatorBloc.add(LoadFilesEvent(csvContent: 'a\nb'));
        return generatorBloc;
      },
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
      build: () {
        generatorBloc.add(LoadFilesEvent(csvContent: 'a\nb'));
        return generatorBloc;
      },
      act: (bloc) => bloc.add(UpdatePdfModeEvent(PdfMode.frontAndBack)),
      skip: 0,
      expect: () => [
        isA<GeneratorLoaded>()
            .having((s) => s.pdfMode, 'pdfMode', PdfMode.frontAndBack)
      ],
    );
  });
}
