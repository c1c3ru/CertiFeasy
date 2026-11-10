import 'package:certifeasy/core/utils/certificate_file_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserva cada participante quando nomes colidem', () {
    final names = CertificateFileNames.uniqueBaseNames(
      [
        {'nome': 'Ana Silva'},
        {'nome': 'Ana/Silva'},
        {'nome': 'ANA SILVA'},
        {'nome': 'Ana_Silva_2'},
      ],
      ['nome'],
    );
    expect(names, [
      'Ana_Silva',
      'Ana_Silva_2',
      'ANA_SILVA_3',
      'Ana_Silva_2_2',
    ]);
    expect(names.map((value) => value.toLowerCase()).toSet().length, 4);
  });

  test('gera nomes seguros para dados vazios e caracteres de caminho', () {
    final names = CertificateFileNames.uniqueBaseNames(
      [
        {'nome': '../'},
        {'nome': ''},
        {'nome': 'João\\Maria'},
      ],
      ['nome'],
    );
    expect(names[0], 'certificado_1');
    expect(names[1], 'certificado_2');
    expect(names[2], 'João_Maria');
  });

  test('limita comprimento e resolve colisão após truncamento', () {
    final raw = List.filled(90, 'A').join();
    final names = CertificateFileNames.uniqueBaseNames(
      [{'nome': raw}, {'nome': raw}],
      ['nome'],
    );
    expect(names.first.length, 80);
    expect(names.last, '${raw.substring(0, 80)}_2');
  });

  test('usa nome padrão quando não existe cabeçalho', () {
    expect(
      CertificateFileNames.uniqueBaseNames([{}, {}], []),
      ['certificado_1', 'certificado_2'],
    );
  });

  test('usa a coluna "nome" mesmo quando ela não é a primeira', () {
    expect(
      CertificateFileNames.uniqueBaseNames(
        [{'email': 'ana@x.com', 'nome': 'Ana Silva'}],
        ['email', 'nome'],
      ),
      ['Ana_Silva'],
    );
  });
}
