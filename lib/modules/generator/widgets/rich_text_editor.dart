import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/markup_editing.dart';
import '../../../core/utils/rich_text_markup.dart';

const _accent = Color(0xFF7A78FF);

/// Caixa de texto do certificado com barra de formatação.
///
/// O conteúdo continua sendo texto simples com uma marcação leve
/// (ver `rich_text_markup.dart`), então nada é executado nem há HTML.
class RichTextEditor extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  const RichTextEditor({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Digite o texto do certificado...',
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _BoldIntent extends Intent {
  const _BoldIntent();
}

class _ItalicIntent extends Intent {
  const _ItalicIntent();
}

class _UnderlineIntent extends Intent {
  const _UnderlineIntent();
}

class _RichTextEditorState extends State<RichTextEditor> {
  final _undoController = UndoHistoryController();
  final _focusNode = FocusNode();
  late FormattingState _format;

  @override
  void initState() {
    super.initState();
    _format = formattingAt(widget.controller.value);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _format = formattingAt(widget.controller.value);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _undoController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final next = formattingAt(widget.controller.value);
    if (next.bold != _format.bold ||
        next.italic != _format.italic ||
        next.underline != _format.underline ||
        next.strike != _format.strike ||
        next.align != _format.align ||
        next.prefix != _format.prefix) {
      setState(() => _format = next);
    }
  }

  void _apply(TextEditingValue Function(TextEditingValue) op) {
    final next = op(widget.controller.value);
    if (next.text.length > kMaxTemplateLength) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('O texto atingiu o limite de $kMaxTemplateLength caracteres.')),
      );
      return;
    }
    widget.controller.value = next;
    widget.onChanged(next.text);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(),
        const SizedBox(height: 8),
        Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.keyB, control: true): _BoldIntent(),
            SingleActivator(LogicalKeyboardKey.keyB, meta: true): _BoldIntent(),
            SingleActivator(LogicalKeyboardKey.keyI, control: true): _ItalicIntent(),
            SingleActivator(LogicalKeyboardKey.keyI, meta: true): _ItalicIntent(),
            SingleActivator(LogicalKeyboardKey.keyU, control: true): _UnderlineIntent(),
            SingleActivator(LogicalKeyboardKey.keyU, meta: true): _UnderlineIntent(),
          },
          child: Actions(
            actions: {
              _BoldIntent: CallbackAction<_BoldIntent>(
                onInvoke: (_) => _apply((v) => toggleInline(v, '**')),
              ),
              _ItalicIntent: CallbackAction<_ItalicIntent>(
                onInvoke: (_) => _apply((v) => toggleInline(v, '*')),
              ),
              _UnderlineIntent: CallbackAction<_UnderlineIntent>(
                onInvoke: (_) => _apply((v) => toggleInline(v, '__')),
              ),
            },
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              undoController: _undoController,
              minLines: 6,
              maxLines: 14,
              maxLength: kMaxTemplateLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF16192B),
                counterStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _accent, width: 1.5),
                ),
                hintText: widget.hintText,
                hintStyle: const TextStyle(color: Colors.white54),
                contentPadding: const EdgeInsets.all(14),
              ),
              onChanged: widget.onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF16192B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        runSpacing: 2,
        children: [
          ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _undoController,
            builder: (context, undo, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToolButton(
                  icon: Icons.undo_rounded,
                  label: 'Desfazer (Ctrl+Z)',
                  onPressed: undo.canUndo ? _undoController.undo : null,
                ),
                _ToolButton(
                  icon: Icons.redo_rounded,
                  label: 'Refazer (Ctrl+Shift+Z)',
                  onPressed: undo.canRedo ? _undoController.redo : null,
                ),
              ],
            ),
          ),
          const _ToolDivider(),
          _ToolButton(
            icon: Icons.format_bold_rounded,
            label: 'Negrito (Ctrl+B)',
            selected: _format.bold,
            onPressed: () => _apply((v) => toggleInline(v, '**')),
          ),
          _ToolButton(
            icon: Icons.format_italic_rounded,
            label: 'Itálico (Ctrl+I)',
            selected: _format.italic,
            onPressed: () => _apply((v) => toggleInline(v, '*')),
          ),
          _ToolButton(
            icon: Icons.format_underlined_rounded,
            label: 'Sublinhado (Ctrl+U)',
            selected: _format.underline,
            onPressed: () => _apply((v) => toggleInline(v, '__')),
          ),
          _ToolButton(
            icon: Icons.format_strikethrough_rounded,
            label: 'Tachado',
            selected: _format.strike,
            onPressed: () => _apply((v) => toggleInline(v, '~~')),
          ),
          const _ToolDivider(),
          _ToolButton(
            icon: Icons.title_rounded,
            label: 'Título',
            selected: _format.prefix == '# ',
            onPressed: () => _apply((v) => toggleLinePrefix(v, '# ')),
          ),
          _ToolButton(
            icon: Icons.text_fields_rounded,
            label: 'Subtítulo',
            selected: _format.prefix == '## ',
            onPressed: () => _apply((v) => toggleLinePrefix(v, '## ')),
          ),
          _ToolButton(
            icon: Icons.format_list_bulleted_rounded,
            label: 'Lista',
            selected: _format.prefix == '- ',
            onPressed: () => _apply((v) => toggleLinePrefix(v, '- ')),
          ),
          const _ToolDivider(),
          _ToolButton(
            icon: Icons.format_align_left_rounded,
            label: 'Alinhar à esquerda',
            selected: _format.align == MarkupAlign.left,
            onPressed: () => _apply((v) => setAlignment(v, MarkupAlign.left)),
          ),
          _ToolButton(
            icon: Icons.format_align_center_rounded,
            label: 'Centralizar',
            selected: _format.align == MarkupAlign.center,
            onPressed: () => _apply((v) => setAlignment(v, MarkupAlign.center)),
          ),
          _ToolButton(
            icon: Icons.format_align_right_rounded,
            label: 'Alinhar à direita',
            selected: _format.align == MarkupAlign.right,
            onPressed: () => _apply((v) => setAlignment(v, MarkupAlign.right)),
          ),
          _ToolButton(
            icon: Icons.format_align_justify_rounded,
            label: 'Justificar',
            selected: _format.align == MarkupAlign.justify,
            onPressed: () => _apply((v) => setAlignment(v, MarkupAlign.justify)),
          ),
          const _ToolDivider(),
          _ToolButton(
            icon: Icons.table_chart_outlined,
            label: 'Inserir tabela',
            onPressed: () => _apply((v) => insertTable(v)),
          ),
          _ToolButton(
            icon: Icons.format_clear_rounded,
            label: 'Limpar formatação',
            onPressed: () => _apply(clearFormatting),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: IconButton(
          icon: Icon(icon, size: 18),
          onPressed: onPressed,
          isSelected: selected,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          padding: EdgeInsets.zero,
          color: Colors.white70,
          disabledColor: Colors.white24,
          selectedIcon: Icon(icon, size: 18, color: _accent),
          style: IconButton.styleFrom(
            backgroundColor: selected ? _accent.withValues(alpha: 0.15) : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
    );
  }
}

class _ToolDivider extends StatelessWidget {
  const _ToolDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white12,
    );
  }
}
