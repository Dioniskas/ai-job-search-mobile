import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'resume_detail_screen.dart';

// ── Backwards-compat full-screen selector (used by profile_screen) ────────────

class ResumeCreateScreen extends StatelessWidget {
  const ResumeCreateScreen({super.key});

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Создать резюме'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        surfaceTintColor: cs.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('Как создать резюме?',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
          const SizedBox(height: 4),
          Text('Выберите удобный способ',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),
          _MethodTile(
            emoji: '📄',
            title: 'Загрузить PDF',
            subtitle: 'Уже есть готовое резюме',
            onTap: () => _push(context, const ResumeUploadPdfScreen(improve: false)),
          ),
          _MethodTile(
            emoji: '✨',
            title: 'PDF + Ассистент',
            subtitle: 'Загрузи PDF — Ассистент улучшит',
            onTap: () => _push(context, const ResumeUploadPdfScreen(improve: true)),
          ),
          _MethodTile(
            emoji: '📝',
            title: 'Заполнить форму',
            subtitle: 'Ассистент составит резюме',
            onTap: () => _push(context, const ResumeFormScreen()),
          ),
          _MethodTile(
            emoji: '🎤',
            title: 'Голосом',
            subtitle: 'Расскажи о себе — Ассистент оформит',
            onTap: () => _push(context, const ResumeVoiceScreen()),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MethodTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

void _openDetail(BuildContext context, Map<String, dynamic> resume) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => ResumeDetailScreen(resume: resume)),
  );
}

Widget _buildCard({required Widget child, required BuildContext context}) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

Widget _submitButton({
  required VoidCallback? onPressed,
  required bool loading,
  required String label,
  required IconData icon,
}) {
  return FilledButton.icon(
    onPressed: onPressed,
    icon: loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Icon(icon, size: 18),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF2563EB),
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// ── Screen 1 & 2: PDF upload ─────────────────────────────────────────────────

class ResumeUploadPdfScreen extends StatefulWidget {
  final bool improve;
  const ResumeUploadPdfScreen({super.key, required this.improve});

  @override
  State<ResumeUploadPdfScreen> createState() => _ResumeUploadPdfScreenState();
}

class _ResumeUploadPdfScreenState extends State<ResumeUploadPdfScreen> {
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
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(widget.improve ? 'PDF + Ассистент' : 'Загрузить PDF'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        surfaceTintColor: cs.surface,
      ),
      body: SingleChildScrollView(
        child: _buildCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                widget.improve
                    ? Icons.auto_awesome_rounded
                    : Icons.upload_file_rounded,
                size: 48,
                color: cs.primary,
              ),
              const SizedBox(height: 12),
              Text(
                widget.improve
                    ? 'Ассистент улучшит ваше резюме'
                    : 'Загрузите готовое резюме',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                widget.improve
                    ? 'Ассистент структурирует и улучшит текст вашего PDF-резюме'
                    : 'Загрузите PDF-файл резюме — он будет сохранён в системе',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? cs.surfaceContainerHighest
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _fileName != null ? cs.primary : cs.outlineVariant,
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
                        color:
                            _fileName != null ? cs.primary : cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _fileName ?? 'Нажмите, чтобы выбрать PDF',
                        style: TextStyle(
                          color: _fileName != null
                              ? cs.primary
                              : cs.onSurfaceVariant,
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
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: TextStyle(color: cs.error)),
                ),
              ],
              const SizedBox(height: 16),
              _submitButton(
                onPressed: (_filePath == null || _loading) ? null : _submit,
                loading: _loading,
                label: widget.improve
                    ? 'Улучшить с Ассистентом'
                    : 'Загрузить резюме',
                icon: widget.improve
                    ? Icons.auto_awesome_rounded
                    : Icons.upload_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Screen 3: Form ────────────────────────────────────────────────────────────

class ResumeFormScreen extends StatefulWidget {
  const ResumeFormScreen({super.key});

  @override
  State<ResumeFormScreen> createState() => _ResumeFormScreenState();
}

class _ResumeFormScreenState extends State<ResumeFormScreen> {
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
        if (_aboutCtrl.text.trim().isNotEmpty) 'about': _aboutCtrl.text.trim(),
      });
      if (mounted) _openDetail(context, resume);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Заполнить форму'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        surfaceTintColor: cs.surface,
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: _buildCard(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.edit_note_rounded, size: 40, color: cs.primary),
                const SizedBox(height: 8),
                Text(
                  'Ассистент составит резюме по вашим данным',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Заполните поля — Ассистент создаст профессиональное резюме',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _field(
                  context,
                  _nameCtrl,
                  'Имя и фамилия',
                  Icons.person_outline_rounded,
                  required: true,
                  hint: 'Например: Алексей Иванов',
                ),
                _field(
                  context,
                  _ageCtrl,
                  'Возраст',
                  Icons.cake_outlined,
                  keyboard: TextInputType.number,
                  hint: 'Например: 28',
                ),
                _field(
                  context,
                  _expCtrl,
                  'Опыт работы',
                  Icons.work_outline_rounded,
                  maxLines: 5,
                  required: true,
                  hint: 'Компания, должность, период, обязанности и достижения...',
                ),
                _field(
                  context,
                  _skillsCtrl,
                  'Навыки',
                  Icons.psychology_rounded,
                  maxLines: 2,
                  required: true,
                  hint: 'Flutter, Dart, Firebase, Git, REST API...',
                ),
                _field(
                  context,
                  _aboutCtrl,
                  'О себе',
                  Icons.notes_rounded,
                  maxLines: 3,
                  hint: 'Краткое описание вашего профессионального опыта...',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: TextStyle(color: cs.error)),
                  ),
                ],
                const SizedBox(height: 8),
                _submitButton(
                  onPressed: _loading ? null : _submit,
                  loading: _loading,
                  label: 'Создать с Ассистентом',
                  icon: Icons.auto_awesome_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    BuildContext context,
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    String? hint,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          helperText: required ? 'Обязательное поле' : null,
          prefixIcon: maxLines == 1 ? Icon(icon, size: 20) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: isDark
              ? cs.surfaceContainerHighest
              : const Color(0xFFF8FAFC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'Обязательное поле' : null
            : null,
      ),
    );
  }
}

// ── Screen 4: Voice ───────────────────────────────────────────────────────────

class ResumeVoiceScreen extends StatefulWidget {
  const ResumeVoiceScreen({super.key});

  @override
  State<ResumeVoiceScreen> createState() => _ResumeVoiceScreenState();
}

class _ResumeVoiceScreenState extends State<ResumeVoiceScreen> {
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
    await _recorder!.startRecorder(toFile: path, codec: Codec.aacMP4);
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
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Создать голосом'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        surfaceTintColor: cs.surface,
      ),
      body: SingleChildScrollView(
        child: _buildCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.mic_rounded, size: 48, color: cs.primary),
              const SizedBox(height: 8),
              Text(
                'Расскажите о себе голосом',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Ассистент транскрибирует речь и составит профессиональное резюме',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Расскажите о:',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    ...[
                      'Имени и желаемой должности',
                      'Опыте работы (компании, должности, достижения)',
                      'Ключевых навыках и технологиях',
                      'Образовании и курсах',
                    ].map((tip) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 14, color: cs.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(tip,
                                  style: TextStyle(
                                      fontSize: 12, color: cs.onSurface)),
                            ),
                          ]),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTap: _loading ? null : _toggleRecording,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.red.withValues(alpha: 0.12)
                          : cs.primaryContainer.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isRecording ? Colors.red : cs.primary,
                        width: 2.5,
                      ),
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 46,
                      color: _isRecording ? Colors.red : cs.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  _isRecording
                      ? '● Запись: ${_fmt(_duration)}'
                      : _audioPath != null
                          ? 'Запись готова — ${_fmt(_duration)}'
                          : 'Нажмите, чтобы начать запись',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        _isRecording ? FontWeight.w600 : FontWeight.normal,
                    color: _isRecording ? Colors.red : cs.onSurfaceVariant,
                  ),
                ),
              ),
              if (_loading) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: cs.primary),
                      ),
                      const SizedBox(width: 10),
                      Text('Ассистент обрабатывает запись...',
                          style: TextStyle(
                              color: cs.primary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: TextStyle(color: cs.error)),
                ),
              ],
              const SizedBox(height: 20),
              _submitButton(
                onPressed:
                    (_audioPath == null || _isRecording || _loading)
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
                  style:
                      TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
