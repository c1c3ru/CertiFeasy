import 'dart:convert';
import 'dart:typed_data';

/// Modelo de CSV oferecido em "Baixar modelo CSV".
///
/// Contém todas as colunas obrigatórias validadas pelo GeneratorBloc
/// (nome, evento, data, horas, email), para que o arquivo baixado possa ser
/// reenviado ao app sem erro.
const String kCsvTemplateContent =
    'nome;evento;data;horas;email;orientador;email_orientador;nome_trabalho\n'
    'João Silva;Seminário de Inovação;10/10/2026;8;joao.silva@exemplo.com;Prof. Carlos Lima;carlos.lima@exemplo.com;Inovação no Ensino\n'
    'Maria Santos;Workshop de Flutter;15/10/2026;16;maria.santos@exemplo.com;Profa. Ana Costa;ana.costa@exemplo.com;Aplicações de Flutter\n';

const String kCsvTemplateFileName = 'modelo_certificados.csv';

/// Bytes do modelo em UTF-8 com BOM, para o Excel exibir os acentos corretamente.
Uint8List csvTemplateBytes() =>
    Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(kCsvTemplateContent)]);
