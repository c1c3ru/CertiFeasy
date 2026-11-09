import 'package:flutter/material.dart';

/// Seleção explícita da coluna de destinatários.
/// Não exibe a primeira coluna como se estivesse selecionada quando o CSV muda.
class EmailRecipientColumnSelector extends StatelessWidget {
  const EmailRecipientColumnSelector({
    super.key,
    required this.headers,
    required this.selectedColumn,
    required this.onChanged,
  });

  final List<String> headers;
  final String selectedColumn;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (headers.isEmpty) {
      return const Text(
        'Carregue um CSV primeiro.',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      );
    }

    final selectionExists = headers.contains(selectedColumn);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('recipient-column-dropdown'),
              value: selectionExists ? selectedColumn : null,
              hint: const Text(
                'Selecione uma coluna',
                style: TextStyle(color: Colors.white70),
              ),
              isExpanded: true,
              dropdownColor: const Color(0xFF16192B),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
              items: headers.map((header) {
                return DropdownMenuItem(
                  value: header,
                  child: Text(header),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ),
        if (!selectionExists) ...[
          const SizedBox(height: 8),
          Text(
            'A coluna de destinatários "$selectedColumn" não existe neste CSV. '
            'Selecione uma coluna válida antes de enviar.',
            key: const Key('missing-recipient-column-warning'),
            style: const TextStyle(color: Color(0xFFFFB86B), fontSize: 12),
          ),
        ],
      ],
    );
  }
}
