import 'package:certifeasy/core/utils/participant_table_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const academicSpreadsheet =
      'Nome\tOrientador(a)\tTítulo do trabalho\tEvento\tData\tE-mail\tE-mail do orientador\n'
      'OLIVEIRA, Maria Exemplo\tRODRIGUES, Docente Exemplo\t'
      'ANÁLISE DE VIDEOAULAS DE QUÍMICA NO YOUTUBE\t'
      'II Mostra Científica do IFCE Campus Maracanaú\t9-out.\t'
      'maria@example.com\tdocente@ifce.example\n'
      'ARAÚJO, Pessoa Exemplo\tROCHA, Professora Exemplo\t'
      'AVALIAÇÃO DE LEITO FILTRANTE\t'
      'II Mostra Científica do IFCE Campus Maracanaú\t9-out.\t'
      'pessoa@example.com\tProfa. Rocha <rocha@ifce.example>';

  group('ParticipantTableParser', () {
    test('importa planilha TSV acadêmica sem horas e normaliza cabeçalhos', () {
      final result = ParticipantTableParser.parse(academicSpreadsheet);

      expect(result.headers, [
        'nome',
        'orientador',
        'nome_trabalho',
        'evento',
        'data',
        'email',
        'email_orientador',
        'horas',
      ]);
      expect(result.mappedData, hasLength(2));
      expect(result.mappedData.first['nome'], 'OLIVEIRA, Maria Exemplo');
      expect(result.mappedData.first['orientador'],
          'RODRIGUES, Docente Exemplo');
      expect(result.mappedData.first['nome_trabalho'],
          'ANÁLISE DE VIDEOAULAS DE QUÍMICA NO YOUTUBE');
      expect(result.mappedData.first['data'], '9-out.');
      expect(result.mappedData.first['email'], 'maria@example.com');
      expect(result.mappedData.first['horas'], '');
      expect(result.mappedData.last['email_orientador'], 'rocha@ifce.example');
      expect(result.csvData.first, result.headers);
      expect(result.csvData.last.last, '');
    });

    test('mantém horas obrigatórias no CSV tradicional', () {
      final result = ParticipantTableParser.parse(
        'nome;evento;data;horas;email\n'
        'Ana;Curso;09/11/2026;12;ana@example.com',
      );

      expect(result.headers, ['nome', 'evento', 'data', 'horas', 'email']);
      expect(result.mappedData.single['horas'], 12);
    });

    test('rejeita CSV tradicional quando faltam horas', () {
      expect(
        () => ParticipantTableParser.parse(
          'nome;evento;data;email\nAna;Curso;09/11;ana@example.com',
        ),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'mensagem',
          contains('horas'),
        )),
      );
    });

    test('rejeita ausência de horas se só orientador estiver presente', () {
      expect(
        () => ParticipantTableParser.parse(
          'Nome;Orientador(a);Evento;Data;E-mail\n'
          'Ana;Prof. Carlos;Curso;09/11;ana@example.com',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('permite horas preenchidas até em apresentação de trabalhos', () {
      final result = ParticipantTableParser.parse(
        'Nome;Orientador(a);Título do trabalho;Evento;Data;E-mail;Horas\n'
        'Ana;Prof. Carlos;Pesquisa;Mostra;9-out.;ana@example.com;3',
      );
      expect(result.mappedData.single['horas'], 3);
      expect(result.headers.where((h) => h == 'horas'), hasLength(1));
    });

    test('lê CSV separado por vírgula sem perder cabeçalhos legados', () {
      final result = ParticipantTableParser.parse(
        'nome,evento,data,horas,email,nome_trabalho\n'
        '"SILVA, Ana",Mostra,10/10,4,ana@example.com,Pesquisa',
      );
      expect(result.mappedData.single['nome'], 'SILVA, Ana');
      expect(result.mappedData.single['nome_trabalho'], 'Pesquisa');
    });

    test('lê CSV com BOM e acentos nos cabeçalhos', () {
      final result = ParticipantTableParser.parse(
        '\ufeffNome;Título do trabalho;Orientador(a);Evento;Data;E-mail\n'
        'Ana;Pesquisa;Profa. Rita;Mostra;9-out.;ana@example.com',
      );
      expect(result.headers, containsAll(['nome_trabalho', 'orientador']));
      expect(result.mappedData.single['nome_trabalho'], 'Pesquisa');
    });

    test('recusa colunas duplicadas depois de normalizar aliases', () {
      expect(
        () => ParticipantTableParser.parse(
          'nome;evento;data;horas;email;E-mail\n'
          'Ana;Curso;10/10;4;ana@example.com;outra@example.com',
        ),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'coluna',
          contains('email'),
        )),
      );
    });

    test('mantém colunas extras de certificados personalizados', () {
      final result = ParticipantTableParser.parse(
        'nome;evento;data;horas;email;tipo_de_participacao\n'
        'Ana;Evento;10/10;8;ana@example.com;Palestrante',
      );
      expect(result.headers, contains('tipo_de_participacao'));
      expect(result.mappedData.single['tipo_de_participacao'], 'Palestrante');
    });
  });
}
