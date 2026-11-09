import 'package:flutter/material.dart';

import '../blocs/generator_event.dart';

/// Campos acadêmicos editáveis para a linha selecionada do CSV.
/// Mantém os controladores enquanto o BLoC emite atualizações, preservando
/// o cursor durante a digitação.
class ParticipantAcademicFields extends StatefulWidget {
  const ParticipantAcademicFields({
    super.key,
    required this.rowIndex,
    required this.participantCount,
    required this.rowData,
    required this.enabled,
    required this.onSelectRow,
    required this.onChanged,
  });

  final int rowIndex;
  final int participantCount;
  final Map<String, dynamic> rowData;
  final bool enabled;
  final ValueChanged<int> onSelectRow;
  final void Function(AcademicField field, String value) onChanged;

  @override
  State<ParticipantAcademicFields> createState() =>
      _ParticipantAcademicFieldsState();
}

class _ParticipantAcademicFieldsState extends State<ParticipantAcademicFields> {
  final _orientadorController = TextEditingController();
  final _emailOrientadorController = TextEditingController();
  final _nomeTrabalhoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncFields();
  }

  @override
  void didUpdateWidget(covariant ParticipantAcademicFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rowIndex != widget.rowIndex ||
        !identical(oldWidget.rowData, widget.rowData)) {
      _syncFields();
    }
  }

  void _sync(TextEditingController controller, String column) {
    final text = widget.rowData[column]?.toString() ?? '';
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _syncFields() {
    _sync(_orientadorController, AcademicField.orientador.column);
    _sync(_emailOrientadorController, AcademicField.emailOrientador.column);
    _sync(_nomeTrabalhoController, AcademicField.nomeTrabalho.column);
  }

  @override
  void dispose() {
    _orientadorController.dispose();
    _emailOrientadorController.dispose();
    _nomeTrabalhoController.dispose();
    super.dispose();
  }

  Widget _field({
    required String label,
    required String hint,
    required String fieldKey,
    required TextEditingController controller,
    required AcademicField field,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextFormField(
        key: Key(fieldKey),
        controller: controller,
        enabled: widget.enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: const Color(0xFF7A78FF)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFF7A78FF)),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        onChanged: (value) => widget.onChanged(field, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rowName = widget.rowData['nome']?.toString().trim();
    final participantLabel = rowName == null || rowName.isEmpty
        ? 'Participante ${widget.rowIndex + 1}'
        : rowName;

    return Container(
      key: const Key('academic-info-editor'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16192B),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dados de orientação e trabalho',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Edite os dados de cada participante. As alterações entram '
            'na prévia, no PDF, no ZIP e nas variáveis dos e-mails. '
            'O arquivo CSV original não é modificado.',
            style: TextStyle(color: Colors.white60, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.rowIndex + 1} de ${widget.participantCount} — $participantLabel',
                  key: const Key('academic-selected-participant'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              IconButton(
                key: const Key('academic-previous-participant'),
                tooltip: 'Participante anterior',
                onPressed: widget.enabled && widget.rowIndex > 0
                    ? () => widget.onSelectRow(widget.rowIndex - 1)
                    : null,
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
              ),
              IconButton(
                key: const Key('academic-next-participant'),
                tooltip: 'Próximo participante',
                onPressed: widget.enabled &&
                        widget.rowIndex + 1 < widget.participantCount
                    ? () => widget.onSelectRow(widget.rowIndex + 1)
                    : null,
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
              ),
            ],
          ),
          _field(
            fieldKey: 'academic-orientador',
            label: 'Nome do orientador',
            hint: 'Ex.: Profa. Ana Silva',
            controller: _orientadorController,
            field: AcademicField.orientador,
            icon: Icons.school_outlined,
          ),
          _field(
            fieldKey: 'academic-email-orientador',
            label: 'E-mail do orientador',
            hint: 'Ex.: ana@instituicao.edu.br',
            controller: _emailOrientadorController,
            field: AcademicField.emailOrientador,
            keyboardType: TextInputType.emailAddress,
            icon: Icons.alternate_email,
          ),
          _field(
            fieldKey: 'academic-nome-trabalho',
            label: 'Nome do trabalho',
            hint: 'Ex.: Aplicações de IA na Educação',
            controller: _nomeTrabalhoController,
            field: AcademicField.nomeTrabalho,
            icon: Icons.article_outlined,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
