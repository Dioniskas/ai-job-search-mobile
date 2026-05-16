import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'resume_detail_screen.dart';

const _blue = Color(0xFF2563EB);
const _bg = Color(0xFFF8FAFC);
const _textPrimary = Color(0xFF0F172A);
const _textSecondary = Color(0xFF64748B);

class ResumeCreateScreen extends StatefulWidget {
  const ResumeCreateScreen({super.key});

  @override
  State<ResumeCreateScreen> createState() => _ResumeCreateScreenState();
}

class _ResumeCreateScreenState extends State<ResumeCreateScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Создать резюме'),
        backgroundColor: Colors.white,
        foregroundColor: _textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: _blue,
          unselectedLabelColor: _textSecondary,
          indicatorColor: _blue,
          tabs: const [
            Tab(text: '📄 Загрузить PDF'),
            Tab(text: '✨ PDF + ИИ'),
            Tab(text: '📝 Из формы'),
            Tab(text: '🎤 Из голоса'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _UploadPdfTab(improve: false),
          _UploadPdfTab(improve: true),
          _FormTab(),
          _VoiceTab(),
        ],
      ),
    );
  }
}

// ── Helper ──────────────────────────────────────────────────────────────────

void _openDetail(BuildContext context, Map<String, dynamic> resume) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => ResumeDetailScreen(resume: resume),
    ),
  );
}

Widget _buildCard({required Widget child}) {
  return Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

Widget _submitButton(
    {required VoidCallback? onPressed,
    required bool loading,
    required String label,
    required IconData icon}) {
  return FilledButton.icon(
    onPressed: onPressed,
    icon: loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
        : Icon(icon, size: 18),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: _blue,
      minimumSize: const Size.fromHeight(52),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// ── Tab 1 & 2: PDF upload ───────────────────────────────────────────────────

class _UploadPdfTab extends StatefulWidget {
  final bool improve;
  const _UploadPdfTab({required this.improve});

  @override
  State<_UploadPdfTab> createState() => _UploadPdfTabState();
}

class _UploadPdfTabState extends State<_UploadPdfTab> {
  String? _filePath;
  String? _fileName;
  bool _loading = false;
  String? _error;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null) return;
    setState(() {
      _filePath = result.files.single.path;
      _fileName = result.files.single.name;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_filePath == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = context.read<AuthProvider>().token!;
      final resume = widget.improve
          ? await ApiService.improveResumePdf(token, _filePath!)
          : await ApiService.uploadResumePdf(token, _filePath!);
      if (mounted) _openDetail(context, resume);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  widget.improve
                      ? Icons.auto_awesome_rounded
                      : Icons.upload_file_rounded,
                  size: 48,
                  color: _blue,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.improve
                      ? 'ИИ улучшит ваше резюме'
                      : 'Загрузите готовое резюме',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.improve
                      ? 'Искусственный интеллект структурирует и улучшит текст вашего PDF-резюме'
                      : 'Загрузите PDF-файл резюме — он будет сохранён в системе',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _pickFile,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _fileName != null
                            ? _blue
                            : const Color(0xFFE2E8F0),
                        width: _fileName != null ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _fileName != null
                              ? Icons.picture_as_pdf_rounded
                              : Icons.cloud_upload_outlined,
                          size: 40,
                          color: _fileName != null
                              ? _blue
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _fileName ?? 'Нажмите, чтобы выбрать PDF',
                          style: TextStyle(
                            color: _fileName != null
                                ? _blue
                                : _textSecondary,
                            fontWeight: _fileName != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!,
                        style:
                            const TextStyle(color: Color(0xFFDC2626))),
                  ),
                ],
                const SizedBox(height: 16),
                _submitButton(
                  onPressed: (_filePath == null || _loading) ? null : _submit,
                  loading: _loading,
                  label: widget.improve
                      ? 'Улучшить с ИИ'
                      : 'Загрузить резюме',
                  icon: widget.improve
                      ? Icons.auto_awesome_rounded
                      : Icons.upload_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 3: Form ──────────────────────────────────────────────────────────────

class _FormTab extends StatefulWidget {
  const _FormTab();

  @override
  State<_FormTab> createState() => _FormTabState();
}

class _FormTabState extends State<_FormTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _expCtrl.dispose();
    _skillsCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = context.read<AuthProvider>().token!;
      final resume = await ApiService.generateResumeFromText(token, {
        'name': _nameCtrl.text.trim(),
        if (_ageCtrl.text.trim().isNotEmpty) 'age': _ageCtrl.text.trim(),
        'experience': _expCtrl.text.trim(),
        'skills': _skillsCtrl.text.trim(),
        if (_aboutCtrl.text.trim().isNotEmpty)
          'about': _aboutCtrl.text.trim(),
      });
      if (mounted) _openDetail(context, resume);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.edit_note_rounded,
                  size: 40, color: _blue),
              const SizedBox(height: 8),
              const Text(
                'ИИ составит резюме по вашим данным',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _field(_nameCtrl, 'Имя и фамилия *',
                  Icons.person_outline_rounded,
                  required: true),
              _field(_ageCtrl, 'Возраст',
                  Icons.cake_outlined,
                  keyboard: TextInputType.number),
              _field(_expCtrl, 'Опыт работы *',
                  Icons.work_outline_rounded,
                  maxLines: 4,
                  hint: 'Опишите ваш опыт работы: компании, должности, достижения',
                  required: true),
              _field(_skillsCtrl, 'Навыки *',
                  Icons.psychology_rounded,
                  maxLines: 2,
                  hint: 'Перечислите через запятую: Python, SQL, управление командой...',
                  required: true),
              _field(_aboutCtrl, 'О себе',
                  Icons.notes_rounded,
                  maxLines: 3,
                  hint: 'Дополнительная информация о вас'),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style:
                          const TextStyle(color: Color(0xFFDC2626))),
                ),
              ],
              const SizedBox(height: 8),
              _submitButton(
                onPressed: _loading ? null : _submit,
                loading: _loading,
                label: 'Создать с ИИ',
                icon: Icons.auto_awesome_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: _bg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        validator: required
            ? (v) => v == null || v.trim().isEmpty
                ? 'Обязательное поле'
                : null
            : null,
      ),
    );
  }
}

// ── Tab 4: Voice ─────────────────────────────────────────────────────────────

class _VoiceTab extends StatefulWidget {
  const _VoiceTab();

  @override
  State<_VoiceTab> createState() => _VoiceTabState();
}

class _VoiceTabState extends State<_VoiceTab> {
  FlutterSoundRecorder? _recorder;
  bool _isRecorderReady = false;
  bool _isRecording = false;
  String? _audioPath;
  Duration _duration = Duration.zero;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    final rec = FlutterSoundRecorder();
    try {
      await rec.openRecorder();
      await rec.setSubscriptionDuration(const Duration(milliseconds: 200));
      rec.onProgress?.listen((e) {
        if (mounted && _isRecording) {
          setState(() => _duration = e.duration);
        }
      });
      _recorder = rec;
      if (mounted) setState(() => _isRecorderReady = true);
    } catch (_) {
      await rec.closeRecorder();
    }
  }

  @override
  void dispose() {
    if (_isRecording) _recorder?.stopRecorder();
    _recorder?.closeRecorder();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _recorder!.stopRecorder();
      setState(() => _isRecording = false);
      return;
    }

    if (!_isRecorderReady) {
      await _initRecorder();
      if (!_isRecorderReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Нет доступа к микрофону'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder!.startRecorder(
      toFile: path,
      codec: Codec.aacMP4,
    );

    setState(() {
      _isRecording = true;
      _audioPath = path;
      _duration = Duration.zero;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_audioPath == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = context.read<AuthProvider>().token!;
      final resume =
          await ApiService.generateResumeFromVoice(token, _audioPath!);
      if (mounted) _openDetail(context, resume);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mic_rounded, size: 48, color: _blue),
            const SizedBox(height: 8),
            const Text(
              'Расскажите о себе голосом',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'ИИ транскрибирует речь и составит профессиональное резюме',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 32),

            // Recording button
            Center(
              child: GestureDetector(
                onTap: _toggleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? Colors.red.withValues(alpha: 0.1)
                        : const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isRecording ? Colors.red : _blue,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 44,
                    color: _isRecording ? Colors.red : _blue,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Timer / status
            Center(
              child: Text(
                _isRecording
                    ? '⏺ ${_formatDuration(_duration)}'
                    : _audioPath != null
                        ? '✅ Запись готова (${_formatDuration(_duration)})'
                        : 'Нажмите, чтобы начать запись',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: _isRecording
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: _isRecording ? Colors.red : _textSecondary,
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Расскажите: имя, опыт работы (компании и должности), ключевые навыки, образование',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _textSecondary),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style:
                        const TextStyle(color: Color(0xFFDC2626))),
              ),
            ],

            const SizedBox(height: 20),
            _submitButton(
              onPressed: (_audioPath == null || _isRecording || _loading)
                  ? null
                  : _submit,
              loading: _loading,
              label: 'Создать резюме из записи',
              icon: Icons.auto_awesome_rounded,
            ),

            if (_audioPath != null && !_loading) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() {
                  _audioPath = null;
                  _duration = Duration.zero;
                }),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Записать заново'),
                style: TextButton.styleFrom(foregroundColor: _textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
