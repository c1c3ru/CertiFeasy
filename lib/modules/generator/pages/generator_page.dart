import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../blocs/generator_bloc.dart';
import '../blocs/generator_event.dart';
import '../blocs/generator_state.dart';
import '../../../core/utils/cert_generator.dart';

// ─── Paleta de cores disponíveis para o texto do certificado ───────────────
const _colorOptions = [
  Color(0xFF000000), // Preto
  Color(0xFFFFFFFF), // Branco
  Color(0xFF1A1A2E), // Azul muito escuro
  Color(0xFF2C3E50), // Azul petróleo
  Color(0xFF8E44AD), // Roxo
  Color(0xFF2980B9), // Azul
  Color(0xFF27AE60), // Verde
  Color(0xFFE74C3C), // Vermelho
  Color(0xFFE67E22), // Laranja
  Color(0xFFF1C40F), // Amarelo
  Color(0xFFBDC3C7), // Cinza claro
  Color(0xFF7F8C8D), // Cinza médio
];

// ─── Famílias de fontes disponíveis para o certificado ─────────────────────
const _fontOptions = [
  'Roboto',
  'Lato',
  'Montserrat',
  'Open Sans',
  'Playfair Display',
  'Merriweather',
  'Dancing Script',
  'Pacifico',
  'Oswald',
  'Raleway',
];

// ═══════════════════════════════════════════════════════════════════════════
class GeneratorPage extends StatefulWidget {
  const GeneratorPage({super.key});

  @override
  State<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> with TickerProviderStateMixin {
  late final GeneratorBloc _bloc;
  int _currentTab = 0;
  late final AnimationController _panelAnimController;
  late Animation<double> _panelFade;

  final _textTemplateController =
      TextEditingController(text: 'Certificamos que {nome} participou por {horas} horas.');
  final _backTextTemplateController =
      TextEditingController(text: 'Informações adicionais do verso...');
      
  bool _isEditingBack = false;

  @override
  void initState() {
    super.initState();
    _bloc = BlocProvider.of<GeneratorBloc>(context);
    _bloc.add(LoadFilesEvent());
    _panelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _panelFade = CurvedAnimation(parent: _panelAnimController, curve: Curves.easeOut);
    _panelAnimController.forward();
  }

  @override
  void dispose() {
    _textTemplateController.dispose();
    _backTextTemplateController.dispose();
    _panelAnimController.dispose();
    super.dispose();
  }

  // ─── Navegação entre abas ─────────────────────────────────────────────
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.first.bytes != null) {
      _bloc.add(LoadFilesEvent(imageBytes: result.files.first.bytes));
    }
  }

  Future<void> _pickCSV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result != null && result.files.first.bytes != null) {
      String csvString;
      try {
        csvString = utf8.decode(result.files.first.bytes!);
      } catch (e) {
        csvString = latin1.decode(result.files.first.bytes!);
      }
      _bloc.add(LoadFilesEvent(csvContent: csvString));
    }
  }

  Future<void> _pickBackImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.first.bytes != null) {
      _bloc.add(LoadBackImageEvent(result.files.first.bytes!));
    }
  }

  /// Gera e salva um modelo CSV com as colunas padrão
  Future<void> _downloadCsvTemplate() async {
    const csvContent = 'nome;horas;evento\nJoão Silva;8;Seminário de Inovação\nMaria Santos;16;Workshop de Flutter';
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // No mobile, geramos um arquivo temporário e abrimos a janela de compartilhamento nativa
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/modelo_certificados.csv');
        await file.writeAsString(csvContent);
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(file.path)], text: 'Modelo de CSV para o CertiFeasy');
      } else {
        // No Desktop (Linux/Win/Mac), abrimos a janela clássica de 'Salvar como...'
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Salvar Modelo CSV',
          fileName: 'modelo_certificados.csv',
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsString(csvContent);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Modelo CSV salvo com sucesso!'), backgroundColor: Colors.green),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar modelo: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _onTabTapped(int index, GeneratorLoaded state) {
    if (index > 0) {
      if (state.templateImageBytes == null || state.mappedData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Faça o upload do CSV e da Imagem antes de prosseguir.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    if (_currentTab != index) {
      _panelAnimController.forward(from: 0);
      setState(() => _currentTab = index);
    }
  }

  // ─── BUILD PRINCIPAL ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GeneratorBloc, GeneratorState>(
      bloc: _bloc,
      buildWhen: (previous, current) => current is GeneratorLoaded || current is GeneratorInitial,
      listener: (context, state) {
        if (state is GeneratorError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ));
        } else if (state is GeneratorSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      builder: (context, state) {
        if (state is GeneratorInitial || state is GeneratorLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (state is GeneratorLoaded) {
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return _buildLargeScreenLayout(state);
              } else {
                return _buildSmallScreenLayout(state);
              }
            }
          );
        }
        return const Scaffold(body: Center(child: Text('Estado desconhecido')));
      },
    );
  }

  Widget _buildLargeScreenLayout(GeneratorLoaded state) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(state),
          Container(width: 1, color: Colors.white10),
          _buildOptionsPanel(state, width: 360),
          Container(width: 1, color: Colors.white10),
          Expanded(child: _buildPreviewArea(state)),
        ],
      ),
    );
  }

  Widget _buildSmallScreenLayout(GeneratorLoaded state) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CertifEasy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF16192B),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(flex: 2, child: _buildPreviewArea(state)),
          Container(height: 1, color: Colors.white10),
          Expanded(flex: 3, child: _buildOptionsPanel(state, width: double.infinity)),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF16192B),
        selectedItemColor: const Color(0xFF7A78FF),
        unselectedItemColor: Colors.white54,
        currentIndex: _currentTab,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index != _currentTab) {
            _panelAnimController.forward(from: 0);
            setState(() => _currentTab = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.upload_file), label: 'Upload'),
          BottomNavigationBarItem(icon: Icon(Icons.text_fields), label: 'Texto'),
          BottomNavigationBarItem(icon: Icon(Icons.color_lens), label: 'Aparência'),
          BottomNavigationBarItem(icon: Icon(Icons.email), label: 'E-mails'),
        ],
      ),
    );
  }

  // ─── SIDEBAR ──────────────────────────────────────────────────────────
  Widget _buildSidebar(GeneratorLoaded state) {
    return Container(
      width: 250,
      color: const Color(0xFF16192B),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7A78FF), Color(0xFF4A8BFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7A78FF).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.verified_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'CertifEasy',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _buildSidebarItem(0, 'Upload', Icons.upload_file_rounded, state),
          _buildSidebarItem(1, 'Texto & Variáveis', Icons.text_fields_rounded, state),
          _buildSidebarItem(2, 'Aparência', Icons.palette_rounded, state),
          _buildSidebarItem(3, 'E-mails', Icons.email_rounded, state),
          const Spacer(),
          // ── Botão: Gerar ZIP (PNGs) ──────────────────────────────────
          _buildSidebarActionButton(
            label: state.isGenerating ? 'Gerando...' : 'Gerar ZIP (PNGs)',
            icon: Icons.folder_zip_rounded,
            enabled: !state.isGenerating && state.canGenerateZip,
            gradient: const LinearGradient(
              colors: [Color(0xFF7A78FF), Color(0xFF4A8BFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            glowColor: const Color(0xFF7A78FF),
            onTap: () => _bloc.add(GenerateBatchEvent()),
          ),
          const SizedBox(height: 8),
          // ── Botão: Gerar PDF ─────────────────────────────────────────
          _buildSidebarActionButton(
            label: state.isGenerating ? 'Gerando...' : 'Gerar PDF',
            icon: Icons.picture_as_pdf_rounded,
            enabled: !state.isGenerating && state.canGeneratePdf,
            gradient: const LinearGradient(
              colors: [Color(0xFFE8973A), Color(0xFFD4622A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            glowColor: const Color(0xFFE8973A),
            onTap: () => _bloc.add(GeneratePdfBatchEvent()),
          ),
          if (state.isGenerating) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.progress > 0 ? state.progress : null,
                backgroundColor: const Color(0xFF2E334F),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF7A78FF)),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(state.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Color(0xFF7A78FF), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white38, size: 18),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF7A78FF)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildSidebarActionButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required Gradient gradient,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1.0 : 0.4,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: enabled ? gradient : null,
          color: enabled ? null : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? [BoxShadow(color: glowColor.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int index, String title, IconData icon, GeneratorLoaded state) {
    final isSelected = _currentTab == index;
    // As abas dependem do upload do CSV + Imagem Frente
    final isDisabled = index > 0 && (state.templateImageBytes == null || state.mappedData.isEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isDisabled) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Faça o upload do CSV e da Imagem base para desbloquear esta aba.'),
                  backgroundColor: Color(0xFFE8973A),
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            if (!isSelected) {
              _onTabTapped(index, state);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withValues(alpha: 0.04) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF7A78FF) : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isDisabled
                        ? Colors.white24
                        : isSelected
                            ? Colors.white
                            : Colors.white54,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDisabled ? Colors.white24 : isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── PAINEL DE OPÇÕES ─────────────────────────────────────────────────
  Widget _buildOptionsPanel(GeneratorLoaded state, {double width = 360}) {
    final titles = ['Upload de Arquivos', 'Texto e Variáveis', 'Aparência do Texto', 'Configurar E-mails'];
    return Container(
      width: width,
      color: const Color(0xFF111322),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titles[_currentTab.clamp(0, 3)],
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FadeTransition(
              opacity: _panelFade,
              child: SingleChildScrollView(
                child: _buildPanelContent(state),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelContent(GeneratorLoaded state) {
    switch (_currentTab) {
      case 0: return _buildUploadContent(state);
      case 1: return _buildTextContent(state);
      case 2: return _buildAppearanceContent(state);
      case 3: return _buildEmailContent(state);
      default: return const SizedBox();
    }
  }

  // ─── TAB 3: EMAIL ───────────────────────────────────────────────────────
  Widget _buildEmailContent(GeneratorLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Configurações Resend'),
        const SizedBox(height: 12),
        
        
        TextFormField(
          initialValue: state.senderEmail,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('E-mail do Remetente', Icons.alternate_email),
          onChanged: (val) => _bloc.add(UpdateEmailConfigEvent(senderEmail: val)),
        ),
        const SizedBox(height: 24),

        _buildSectionLabel('Mensagem'),
        const SizedBox(height: 12),
        
        TextFormField(
          initialValue: state.emailSubject,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Assunto', Icons.title),
          onChanged: (val) => _bloc.add(UpdateEmailConfigEvent(emailSubject: val)),
        ),
        const SizedBox(height: 12),

        TextFormField(
          initialValue: state.emailBody,
          style: const TextStyle(color: Colors.white),
          maxLines: 4,
          decoration: _inputDecoration('Corpo do E-mail', Icons.notes),
          onChanged: (val) => _bloc.add(UpdateEmailConfigEvent(emailBody: val)),
        ),
        const SizedBox(height: 24),

        _buildSectionLabel('Coluna de E-mail (Destinatários)'),
        const SizedBox(height: 12),
        
        if (state.csvHeaders.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.csvHeaders.contains(state.emailColumn) 
                  ? state.emailColumn 
                  : state.csvHeaders.first,
                isExpanded: true,
                dropdownColor: const Color(0xFF16192B),
                style: const TextStyle(color: Colors.white),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                items: state.csvHeaders.map((header) {
                  return DropdownMenuItem(
                    value: header,
                    child: Text(header),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    _bloc.add(UpdateEmailConfigEvent(emailColumn: val));
                  }
                },
              ),
            ),
          )
        else
          const Text('Carregue um CSV primeiro.', style: TextStyle(color: Colors.white54, fontSize: 12)),
          
        const SizedBox(height: 40),
        
        // Progresso
        if (state.isSendingEmails)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enviando... ${state.emailsSentCount} / ${state.emailsTotalCount}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: state.emailsTotalCount > 0 
                      ? state.emailsSentCount / state.emailsTotalCount 
                      : 0,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF7A78FF)),
                  minHeight: 6,
                ),
              ),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.canSendEmails 
                ? () {
                    // Confirmação simples
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF16192B),
                        title: const Text('Confirmar Envio', style: TextStyle(color: Colors.white)),
                        content: const Text(
                          'Deseja gerar e enviar os certificados por e-mail para todos os contatos válidos no CSV?',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _bloc.add(SendEmailsBatchEvent());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7A78FF),
                            ),
                            child: const Text('Sim, Enviar', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  } 
                : null,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Enviar Certificados'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A78FF),
                disabledBackgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
      ],
    );
  }

  // ─── TAB 0: UPLOAD ────────────────────────────────────────────────────
  Widget _buildUploadContent(GeneratorLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── 1. Template Frente ───────────────────────────────────────────────
        _buildSectionLabel('Templates'),
        const SizedBox(height: 12),
        _buildDropBox(
          title: 'Template Frente',
          subtitle: state.templateImageBytes != null ? 'Imagem carregada ✓' : 'JPG ou PNG — arte da frente',
          icon: Icons.image_outlined,
          isLoaded: state.templateImageBytes != null,
          onTap: _pickImage,
          onDrop: (details) async {
            final file = details.files.first;
            final path = file.name.toLowerCase();
            if (path.endsWith('.png') || path.endsWith('.jpg') || path.endsWith('.jpeg')) {
              final bytes = await file.readAsBytes();
              _bloc.add(LoadFilesEvent(imageBytes: bytes));
            }
          },
        ),
        const SizedBox(height: 12),

        // ── 2. Template Verso (sempre visível) ───────────────────────────────
        _buildDropBox(
          title: 'Template Verso',
          subtitle: state.backTemplateImageBytes != null
              ? 'Verso carregado ✓'
              : 'JPG ou PNG — arte do verso (opcional)',
          icon: Icons.flip_rounded,
          isLoaded: state.backTemplateImageBytes != null,
          accentColor: const Color(0xFFE8973A),
          onTap: _pickBackImage,
          onDrop: (details) async {
            final file = details.files.first;
            final path = file.name.toLowerCase();
            if (path.endsWith('.png') || path.endsWith('.jpg') || path.endsWith('.jpeg')) {
              final bytes = await file.readAsBytes();
              _bloc.add(LoadBackImageEvent(bytes));
            }
          },
        ),
        const SizedBox(height: 24),
        const Divider(color: Colors.white10),
        const SizedBox(height: 20),

        // ── 3. CSV ───────────────────────────────────────────────────────────
        _buildSectionLabel('Dados dos Participantes'),
        const SizedBox(height: 12),
        _buildDropBox(
          title: 'Arquivo CSV',
          subtitle: state.mappedData.isNotEmpty
              ? '${state.mappedData.length} registro${state.mappedData.length > 1 ? 's' : ''} carregado${state.mappedData.length > 1 ? 's' : ''} ✓'
              : 'Arraste ou clique para selecionar',
          icon: Icons.description_outlined,
          isLoaded: state.mappedData.isNotEmpty,
          onTap: _pickCSV,
          onDrop: (details) async {
            final file = details.files.first;
            if (file.name.toLowerCase().endsWith('.csv')) {
              final bytes = await file.readAsBytes();
              String csvString;
              try {
                csvString = utf8.decode(bytes);
              } catch (e) {
                csvString = latin1.decode(bytes);
              }
              _bloc.add(LoadFilesEvent(csvContent: csvString));
            }
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _downloadCsvTemplate,
            icon: const Icon(Icons.download_outlined, size: 14, color: Color(0xFF7A78FF)),
            label: const Text('Baixar modelo CSV', style: TextStyle(color: Color(0xFF7A78FF), fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),

        // Chips de colunas detectadas
        if (state.csvHeaders.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF16192B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Colunas detectadas:', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.csvHeaders.map((h) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A78FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF7A78FF).withValues(alpha: 0.4)),
                    ),
                    child: Text('{$h}', style: const TextStyle(color: Color(0xFF7A78FF), fontSize: 12)),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        const Divider(color: Colors.white10),
        const SizedBox(height: 20),

        // ── 4. Seletor de Modo PDF ───────────────────────────────────────────
        _buildSectionLabel('Modo de Saída PDF'),
        const SizedBox(height: 4),
        const Text(
          'Escolha quais lados do certificado serão incluídos no PDF.',
          style: TextStyle(color: Colors.white38, fontSize: 11.5),
        ),
        const SizedBox(height: 14),
        _buildPdfModeSelector(state),
        const SizedBox(height: 16),

        // Info contextual por modo
        if (state.pdfMode == PdfMode.backOnly)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8973A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8973A).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFE8973A)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Somente Verso: o PDF terá apenas o template do verso, sem texto dinâmico.',
                    style: TextStyle(color: Color(0xFFE8973A), fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        if (state.pdfMode == PdfMode.frontAndBack && state.backTemplateImageBytes == null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8973A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8973A).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFE8973A)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Carregue o Template Verso para habilitar o modo Frente + Verso.',
                    style: TextStyle(color: Color(0xFFE8973A), fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPdfModeSelector(GeneratorLoaded state) {

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16192B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _buildPdfModeOption(
            mode: PdfMode.frontOnly,
            current: state.pdfMode,
            icon: Icons.looks_one_rounded,
            label: 'Somente Frente',
            description: '1 página por certificado',
            color: const Color(0xFF7A78FF),
          ),
          const Divider(height: 1, color: Colors.white10),
          _buildPdfModeOption(
            mode: PdfMode.backOnly,
            current: state.pdfMode,
            icon: Icons.flip_rounded,
            label: 'Somente Verso',
            description: '1 página — arte do verso',
            color: const Color(0xFFE8973A),
          ),
          const Divider(height: 1, color: Colors.white10),
          _buildPdfModeOption(
            mode: PdfMode.frontAndBack,
            current: state.pdfMode,
            icon: Icons.looks_two_rounded,
            label: 'Frente + Verso',
            description: '2 × N páginas (pronto para impressão)',
            color: const Color(0xFF27AE60),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfModeOption({
    required PdfMode mode,
    required PdfMode current,
    required IconData icon,
    required String label,
    required String description,
    required Color color,
  }) {
    final isSelected = current == mode;
    return InkWell(
      onTap: () => _bloc.add(UpdatePdfModeEvent(mode)),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 18, color: isSelected ? color : Colors.white38),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(description, style: TextStyle(color: isSelected ? color.withValues(alpha: 0.8) : Colors.white24, fontSize: 11)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? color : Colors.white24, width: isSelected ? 2 : 1),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildDropBox({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isLoaded,
    required VoidCallback onTap,
    required Function(DropDoneDetails) onDrop,
    Color? accentColor,
  }) {
    final accent = accentColor ?? const Color(0xFF7A78FF);
    return DropTarget(
      onDragDone: onDrop,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
          decoration: BoxDecoration(
            color: isLoaded
                ? accent.withValues(alpha: 0.06)
                : const Color(0xFF16192B).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: isLoaded
                ? Border.all(color: accent.withValues(alpha: 0.6), width: 1.5)
                : Border.all(color: Colors.white12, width: 1),
          ),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  isLoaded ? Icons.check_circle_rounded : icon,
                  key: ValueKey(isLoaded),
                  size: 40,
                  color: isLoaded ? accent : Colors.white38,
                ),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15)),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: isLoaded ? accent : Colors.white38,
                  fontSize: 12.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ─── TAB 1: TEXTO & VARIÁVEIS ─────────────────────────────────────────
  Widget _buildTextContent(GeneratorLoaded state) {
    final controller = _isEditingBack ? _backTextTemplateController : _textTemplateController;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.pdfMode != PdfMode.frontOnly) ...[
          _buildFaceToggle(),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF16192B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF7A78FF).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF7A78FF)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Use {nome_da_coluna} para valores dinâmicos. Ex: {nome}, {horas}.\n'
                  'Dica: Crie tabelas estilo Markdown (ex: | Coluna 1 | Coluna 2 |) para organizar o conteúdo do verso!',
                  style: TextStyle(color: Colors.white60, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (state.csvHeaders.isNotEmpty) ...[
          const Text('Variáveis disponíveis:', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: state.csvHeaders.map((h) => InkWell(
              onTap: () {
                final text = controller.text;
                final selection = controller.selection;
                final tag = '{$h}';
                final newText = text.replaceRange(
                  selection.start < 0 ? text.length : selection.start,
                  selection.end < 0 ? text.length : selection.end,
                  tag,
                );
                controller.text = newText;
                _bloc.add(UpdateTemplateEvent(
                  textTemplate: newText,
                  isBack: _isEditingBack,
                ));
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF7A78FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF7A78FF).withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('{$h}', style: const TextStyle(color: Color(0xFF7A78FF), fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.add_rounded, size: 12, color: Color(0xFF7A78FF)),
                  ],
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),
        ],
        TextField(
          controller: controller,
          maxLines: 6,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF16192B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF7A78FF), width: 1.5),
            ),
            hintText: 'Digite o texto do certificado...',
            hintStyle: const TextStyle(color: Colors.white24),
            contentPadding: const EdgeInsets.all(14),
          ),
          onChanged: (val) => _bloc.add(UpdateTemplateEvent(textTemplate: val, isBack: _isEditingBack)),
        ),
      ],
    );
  }

  // ─── TAB 2: APARÊNCIA ─────────────────────────────────────────────────
  Widget _buildAppearanceContent(GeneratorLoaded state) {
    final currentFontSize = _isEditingBack ? state.backFontSize : state.fontSize;
    final currentFontFamily = _isEditingBack ? state.backFontFamily : state.fontFamily;
    final currentFontColor = _isEditingBack ? state.backFontColorValue : state.fontColorValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.pdfMode != PdfMode.frontOnly) ...[
          _buildFaceToggle(),
          const SizedBox(height: 16),
        ],
        // ── Tamanho da Fonte ──
        _buildSectionLabel('Tamanho da Fonte'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF7A78FF),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFF7A78FF),
                  overlayColor: const Color(0xFF7A78FF).withValues(alpha: 0.2),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: currentFontSize,
                  min: 10,
                  max: 200,
                  onChanged: (val) => _bloc.add(UpdateTemplateEvent(fontSize: val, isBack: _isEditingBack)),
                ),
              ),
            ),
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF16192B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                currentFontSize.toStringAsFixed(0),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF7A78FF), fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Família de Fonte ──
        _buildSectionLabel('Fonte do Texto'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF16192B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButton<String>(
            value: _fontOptions.contains(currentFontFamily) ? currentFontFamily : _fontOptions.first,
            isExpanded: true,
            dropdownColor: const Color(0xFF16192B),
            underline: const SizedBox(),
            icon: const Icon(Icons.expand_more_rounded, color: Colors.white54),
            items: _fontOptions.map((f) => DropdownMenuItem(
              value: f,
              child: Text(f, style: const TextStyle(color: Colors.white, fontSize: 14)),
            )).toList(),
            onChanged: (val) {
              if (val != null) _bloc.add(UpdateTemplateEvent(fontFamily: val));
            },
          ),
        ),
        const SizedBox(height: 20),

        // ── Cor do Texto ──
        _buildSectionLabel('Cor do Texto'),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: _colorOptions.map((color) {
            final isSelected = state.fontColorValue == color.toARGB32();
            return GestureDetector(
              onTap: () => _bloc.add(UpdateTemplateEvent(fontColorValue: color.toARGB32())),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF7A78FF) : Colors.white24,
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: const Color(0xFF7A78FF).withValues(alpha: 0.5), blurRadius: 8)]
                      : [],
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded, size: 16, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // ── Posição do Texto ──
        _buildSectionLabel('Posição do Texto'),
        const SizedBox(height: 4),
        const Text(
          'Ajusta onde o texto é posicionado no certificado.',
          style: TextStyle(color: Colors.white38, fontSize: 11.5),
        ),
        const SizedBox(height: 12),

        // Posição X
        Row(
          children: [
            const SizedBox(width: 12),
            const Text('← Esq', style: TextStyle(color: Colors.white38, fontSize: 11)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF7A78FF),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFF7A78FF),
                  overlayColor: const Color(0xFF7A78FF).withValues(alpha: 0.2),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _isEditingBack ? state.backTextPositionX : state.textPositionX,
                  min: 0.05,
                  max: 0.95,
                  onChanged: (val) => _bloc.add(UpdateTextPositionEvent(dx: val, isBack: _isEditingBack)),
                ),
              ),
            ),
            const Text('Dir →', style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(width: 12),
          ],
        ),

        // Posição Y
        Row(
          children: [
            const SizedBox(width: 12),
            const Text('↑ Cima', style: TextStyle(color: Colors.white38, fontSize: 11)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF4A8BFF),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFF4A8BFF),
                  overlayColor: const Color(0xFF4A8BFF).withValues(alpha: 0.2),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _isEditingBack ? state.backTextPositionY : state.textPositionY,
                  min: 0.05,
                  max: 0.95,
                  onChanged: (val) => _bloc.add(UpdateTextPositionEvent(dy: val, isBack: _isEditingBack)),
                ),
              ),
            ),
            const Text('Baixo ↓', style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(width: 12),
          ],
        ),

        const SizedBox(height: 6),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: () {
              _bloc.add(UpdateTextPositionEvent(dx: 0.5, dy: 0.5, isBack: _isEditingBack));
            },
            icon: const Icon(Icons.center_focus_strong_rounded, size: 14, color: Colors.white38),
            label: const Text('Centralizar', style: TextStyle(color: Colors.white38, fontSize: 12)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildFaceToggle() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF16192B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isEditingBack = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_isEditingBack ? const Color(0xFF7A78FF).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Frente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isEditingBack ? const Color(0xFF7A78FF) : Colors.white54,
                    fontWeight: !_isEditingBack ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isEditingBack = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _isEditingBack ? const Color(0xFF7A78FF).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Verso',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isEditingBack ? const Color(0xFF7A78FF) : Colors.white54,
                    fontWeight: _isEditingBack ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ÁREA DE PREVIEW ──────────────────────────────────────────────────
  Widget _buildPreviewArea(GeneratorLoaded state) {
    return Container(
      color: const Color(0xFF0D1020),
      child: Column(
        children: [
          // Topbar do preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Visualização em Tempo Real',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (state.mappedData.isNotEmpty) _buildPreviewNav(state),
              ],
            ),
          ),
          // Área do certificado
          Expanded(
            child: (!_isEditingBack && state.templateImageBytes == null) || (_isEditingBack && state.backTemplateImageBytes == null)
                ? _buildEmptyPreview()
                : _buildCheckerboard(_buildInteractivePreview(state)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewNav(GeneratorLoaded state) {
    final idx = state.selectedCsvRowIndex;
    final total = state.mappedData.length;
    final rowName = state.mappedData[idx].values.firstOrNull?.toString() ?? 'Linha ${idx + 1}';

    return Row(
      children: [
        Text(
          rowName,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 8),
        Text(
          '${idx + 1} / $total',
          style: const TextStyle(color: Color(0xFF7A78FF), fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        _navBtn(Icons.chevron_left_rounded, idx > 0 ? () => _bloc.add(SelectPreviewRowEvent(idx - 1)) : null),
        const SizedBox(width: 4),
        _navBtn(Icons.chevron_right_rounded, idx < total - 1 ? () => _bloc.add(SelectPreviewRowEvent(idx + 1)) : null),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: onTap != null ? const Color(0xFF16192B) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? Colors.white70 : Colors.white24,
        ),
      ),
    );
  }

  Widget _buildEmptyPreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 64, color: Colors.white12),
          const SizedBox(height: 16),
          const Text(
            'Carregue um template para visualizar',
            style: TextStyle(color: Colors.white24, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vá até a aba Upload e selecione uma imagem',
            style: TextStyle(color: Colors.white12, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckerboard(Widget child) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: CheckerboardPainter())),
        child,
      ],
    );
  }


  Widget _buildInteractivePreview(GeneratorLoaded state) {
    final idx = state.selectedCsvRowIndex.clamp(0, state.mappedData.isEmpty ? 0 : state.mappedData.length - 1);
    final rowData = state.mappedData.isEmpty ? <String, dynamic>{} : state.mappedData[idx];

    final currentTemplate = _isEditingBack ? state.backTextTemplate : state.textTemplate;
    String previewText = currentTemplate;
    rowData.forEach((key, value) {
      previewText = previewText.replaceAll('{$key}', value.toString());
    });

    final currentImageBytes = _isEditingBack ? state.backTemplateImageBytes : state.templateImageBytes;
    final currentPosX = _isEditingBack ? state.backTextPositionX : state.textPositionX;
    final currentPosY = _isEditingBack ? state.backTextPositionY : state.textPositionY;
    final currentFontFamily = _isEditingBack ? state.backFontFamily : state.fontFamily;
    final currentFontSize = _isEditingBack ? state.backFontSize : state.fontSize;
    final currentFontColor = _isEditingBack ? state.backFontColorValue : state.fontColorValue;

    return InteractiveViewer(
      minScale: 0.1,
      maxScale: 4.0,
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Image.memory(currentImageBytes!, fit: BoxFit.contain),
                Positioned.fill(
                  child: CustomPaint(
                    painter: CertPreviewPainter(
                      parsedText: previewText,
                      fontSize: currentFontSize,
                      fontFamily: currentFontFamily,
                      fontColor: Color(currentFontColor),
                      textPositionX: currentPosX,
                      textPositionY: currentPosY,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Checkerboard Painter ────────────────────────────────────────────────────
class CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = const Color(0xFF14172A);
    final paint2 = Paint()..color = const Color(0xFF1A1E35);

    const double squareSize = 20.0;

    for (int y = 0; y < (size.height / squareSize).ceil(); y++) {
      for (int x = 0; x < (size.width / squareSize).ceil(); x++) {
        final rect = Rect.fromLTWH(x * squareSize, y * squareSize, squareSize, squareSize);
        canvas.drawRect(rect, (x + y) % 2 == 0 ? paint1 : paint2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CertPreviewPainter extends CustomPainter {
  final String parsedText;
  final double fontSize;
  final String fontFamily;
  final Color fontColor;
  final double textPositionX;
  final double textPositionY;

  CertPreviewPainter({
    required this.parsedText,
    required this.fontSize,
    required this.fontFamily,
    required this.fontColor,
    required this.textPositionX,
    required this.textPositionY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    CertGenerator.drawCertificateContent(
      canvas,
      size,
      parsedText,
      fontSize,
      fontFamily,
      fontColor,
      textPositionX: textPositionX,
      textPositionY: textPositionY,
    );
  }

  @override
  bool shouldRepaint(covariant CertPreviewPainter oldDelegate) {
    return oldDelegate.parsedText != parsedText ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.fontFamily != fontFamily ||
        oldDelegate.fontColor != fontColor ||
        oldDelegate.textPositionX != textPositionX ||
        oldDelegate.textPositionY != textPositionY;
  }
}
