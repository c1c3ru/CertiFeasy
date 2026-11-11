import 'package:flutter/material.dart';

/// Aviso compacto sobre a finalidade do login e o fluxo de dados no envio.
/// Não bloqueia o usuário com modal nem implica consentimento automático.
class EmailPrivacyNotice extends StatefulWidget {
  const EmailPrivacyNotice({super.key});

  @override
  State<EmailPrivacyNotice> createState() => _EmailPrivacyNoticeState();
}

class _EmailPrivacyNoticeState extends State<EmailPrivacyNotice> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('email-privacy-notice'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF7A78FF).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF7A78FF).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: Color(0xFFAAA8FF),
                size: 17,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Por que pedimos seu e-mail?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'A conta institucional confirma sua autorização para '
                      'enviar certificados. O e-mail informado acima recebe '
                      'as respostas dos participantes.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('email-privacy-details-toggle'),
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFAAA8FF),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: Text(
                _expanded ? 'Mostrar menos' : 'Privacidade e LGPD',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          if (_expanded)
            const Padding(
              key: Key('email-privacy-details'),
              padding: EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                'O CertiFeasy não mantém cadastro de participantes nem '
                'cópias das planilhas e dos certificados em banco de dados '
                'da aplicação. Os campos ficam em memória durante a sessão '
                'e não são salvos nas preferências do navegador. '
                'Para realizar o envio, o endereço do destinatário, '
                'a mensagem e o PDF são transmitidos ao servidor e ao '
                'Gmail, que processa e pode conservar mensagens e registros '
                'do serviço. O login com Google só ocorre quando você '
                'escolher entrar. O tratamento é limitado à finalidade '
                'de emissão e envio dos certificados, observando os '
                'princípios de finalidade, necessidade e transparência '
                'da LGPD.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
