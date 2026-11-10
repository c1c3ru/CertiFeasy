import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/email_service.dart';
import '../blocs/generator_state.dart';

/// Explica, por tipo de problema, quem não recebeu o certificado e o que
/// fazer: corrigir a planilha (erro de digitação) ou tentar de novo mais
/// tarde (problema técnico).
class EmailReportDialog extends StatelessWidget {
  final GeneratorEmailReport report;

  const EmailReportDialog({super.key, required this.report});

  static Future<void> show(BuildContext context, GeneratorEmailReport report) {
    return showDialog(context: context, builder: (_) => EmailReportDialog(report: report));
  }

  static const _sections = [
    (
      EmailFailureKind.invalidAddress,
      Icons.edit_note_rounded,
      Color(0xFFF1C40F),
      'E-mail digitado errado na planilha',
      'Corrija esses endereços na planilha e envie de novo só para essas pessoas.',
    ),
    (
      EmailFailureKind.technical,
      Icons.cloud_off_rounded,
      Color(0xFFE67E22),
      'Problema técnico (internet, Gmail ou servidor)',
      'Os endereços parecem certos. Espere alguns minutos e tente de novo só para essas pessoas.',
    ),
    (
      EmailFailureKind.rejectedContent,
      Icons.description_outlined,
      Color(0xFF9B59B6),
      'Certificado ou mensagem recusados',
      'Confira o assunto, a mensagem e o tamanho da arte do certificado.',
    ),
    (
      EmailFailureKind.unauthorized,
      Icons.lock_outline,
      Color(0xFFE74C3C),
      'Envio não autorizado',
      'Confira o login ou o código de acesso na aba E-mails. O envio parou aqui.',
    ),
  ];

  String _summary() {
    final failed = report.failures.where((f) => f.email.isNotEmpty || f.name.isNotEmpty).length;
    final parts = <String>['${report.sentCount} enviado(s)', '$failed com problema'];
    if (report.notAttemptedCount > 0) parts.add('${report.notAttemptedCount} não tentado(s)');
    return parts.join(' · ');
  }

  String _copyText() {
    final buffer = StringBuffer();
    for (final f in report.failures) {
      if (f.email.isEmpty && f.name.isEmpty) continue;
      buffer.writeln([f.name, f.email, f.detail, f.suggestion ?? ''].join('\t'));
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16192B),
      title: const Text('Alguns certificados não foram enviados', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_summary(), style: const TextStyle(color: Colors.white70)),
              if (report.notAttemptedCount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'O envio parou antes do fim: ${report.notAttemptedCount} pessoa(s) ainda não receberam.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
              for (final (kind, icon, color, title, advice) in _sections)
                if (report.ofKind(kind).isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$title (${report.ofKind(kind).length})',
                          style: TextStyle(color: color, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(advice, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  for (final f in report.ofKind(kind)) _FailureLine(failure: f),
                ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _copyText()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lista copiada. Cole numa planilha para corrigir.')),
            );
          },
          child: const Text('Copiar lista', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A78FF)),
          child: const Text('Entendi', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _FailureLine extends StatelessWidget {
  final EmailFailure failure;

  const _FailureLine({required this.failure});

  @override
  Widget build(BuildContext context) {
    final who = [
      if (failure.name.isNotEmpty) failure.name,
      if (failure.email.isNotEmpty) failure.email,
    ].join(' — ');
    return Padding(
      padding: const EdgeInsets.only(left: 28, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (who.isNotEmpty) SelectableText(who, style: const TextStyle(color: Colors.white, fontSize: 13)),
          Text(
            failure.suggestion == null
                ? failure.detail
                : '${failure.detail}. Você quis dizer ${failure.suggestion}?',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
