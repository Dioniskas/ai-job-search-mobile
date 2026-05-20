import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

// ── Screen 3: Form (multi-step, hh.ru-style) ─────────────────────────────────

// ── Data models ───────────────────────────────────────────────────────────────

class _WorkEntry {
  final companyCtrl = TextEditingController();
  final positionCtrl = TextEditingController();
  final dutiesCtrl = TextEditingController();
  DateTime? from;
  DateTime? to;
  bool isCurrent = false;

  void dispose() {
    companyCtrl.dispose();
    positionCtrl.dispose();
    dutiesCtrl.dispose();
  }
}

class _EduEntry {
  final institutionCtrl = TextEditingController();
  final specialityCtrl = TextEditingController();
  final yearCtrl = TextEditingController();

  void dispose() {
    institutionCtrl.dispose();
    specialityCtrl.dispose();
    yearCtrl.dispose();
  }
}

// ── Main screen ───────────────────────────────────────────────────────────────

class ResumeFormScreen extends StatefulWidget {
  const ResumeFormScreen({super.key});

  @override
  State<ResumeFormScreen> createState() => _ResumeFormScreenState();
}

class _ResumeFormScreenState extends State<ResumeFormScreen> {
  static const int _totalSteps = 6;
  final _pageCtrl = PageController();
  int _step = 0;

  // step 1
  File? _photo;
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  DateTime? _birthDate;
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // step 2
  final _positionCtrl = TextEditingController();
  final _salaryFromCtrl = TextEditingController();
  final _salaryToCtrl = TextEditingController();
  String _currency = 'сум';
  final _employmentTypes = <String>{};
  String? _workFormat;

  // step 3
  final _workEntries = <_WorkEntry>[_WorkEntry()];

  // step 4
  final _eduEntries = <_EduEntry>[_EduEntry()];

  // step 5
  final _skillInputCtrl = TextEditingController();
  final _skills = <String>[];
  final _languages = <Map<String, String>>[];

  // step 6
  final _aboutCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _positionCtrl.dispose();
    _salaryFromCtrl.dispose();
    _salaryToCtrl.dispose();
    _skillInputCtrl.dispose();
    _aboutCtrl.dispose();
    for (final e in _workEntries) {
      e.dispose();
    }
    for (final e in _eduEntries) {
      e.dispose();
    }
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (_firstNameCtrl.text.trim().isEmpty ||
            _lastNameCtrl.text.trim().isEmpty) {
          _showError('Заполните Имя и Фамилию');
          return false;
        }
      case 1:
        if (_positionCtrl.text.trim().isEmpty) {
          _showError('Укажите желаемую должность');
          return false;
        }
      case 2:
        for (final e in _workEntries) {
          if (e.companyCtrl.text.trim().isEmpty ||
              e.positionCtrl.text.trim().isEmpty) {
            _showError('Заполните Компанию и Должность для каждой записи');
            return false;
          }
        }
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = context.read<AuthProvider>().token!;

      final name =
          '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();

      String age = '';
      if (_birthDate != null) {
        final now = DateTime.now();
        int a = now.year - _birthDate!.year;
        if (now.month < _birthDate!.month ||
            (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
          a--;
        }
        age = a.toString();
      }

      final expParts = _workEntries.map((e) {
        final period = e.isCurrent
            ? '${_fmtDate(e.from)} — по настоящее время'
            : '${_fmtDate(e.from)} — ${_fmtDate(e.to)}';
        return '${e.companyCtrl.text.trim()}, ${e.positionCtrl.text.trim()} ($period). ${e.dutiesCtrl.text.trim()}';
      }).join('\n');

      final skillsList = _skills.join(', ');

      final resume = await ApiService.generateResumeFromText(token, {
        'name': name,
        if (age.isNotEmpty) 'age': age,
        'experience': expParts,
        'skills': skillsList,
        if (_aboutCtrl.text.trim().isNotEmpty) 'about': _aboutCtrl.text.trim(),
      });

      if (_photo != null && mounted) {
        final id = resume['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          final bytes = await _photo!.readAsBytes();
          final name = _photo!.path.split('/').last;
          await ApiService.uploadResumePhoto(token, id, bytes, name);
        }
      }

      if (mounted) _openDetail(context, resume);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(DateTime? d) =>
      d != null ? '${d.month.toString().padLeft(2, '0')}.${d.year}' : '—';

  // ── Photo picker ─────────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (picked == null) return;
    setState(() => _photo = File(picked.path));
  }

  // ── Build ────────────────────────────────────────────────────────────────────

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: _ProgressBar(step: _step, total: _totalSteps),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1(
                  photo: _photo,
                  onPickPhoto: _pickPhoto,
                  firstNameCtrl: _firstNameCtrl,
                  lastNameCtrl: _lastNameCtrl,
                  middleNameCtrl: _middleNameCtrl,
                  birthDate: _birthDate,
                  onBirthDateChanged: (d) => setState(() => _birthDate = d),
                  cityCtrl: _cityCtrl,
                  phoneCtrl: _phoneCtrl,
                  emailCtrl: _emailCtrl,
                ),
                _Step2(
                  positionCtrl: _positionCtrl,
                  salaryFromCtrl: _salaryFromCtrl,
                  salaryToCtrl: _salaryToCtrl,
                  currency: _currency,
                  onCurrencyChanged: (v) => setState(() => _currency = v!),
                  employmentTypes: _employmentTypes,
                  onEmploymentToggle: (v) => setState(() {
                    if (_employmentTypes.contains(v)) {
                      _employmentTypes.remove(v);
                    } else {
                      _employmentTypes.add(v);
                    }
                  }),
                  workFormat: _workFormat,
                  onFormatChanged: (v) => setState(() => _workFormat = v),
                ),
                _Step3(
                  entries: _workEntries,
                  onAdd: () => setState(() => _workEntries.add(_WorkEntry())),
                  onRemove: (i) => setState(() {
                    _workEntries[i].dispose();
                    _workEntries.removeAt(i);
                  }),
                  onRebuild: () => setState(() {}),
                ),
                _Step4(
                  entries: _eduEntries,
                  onAdd: () => setState(() => _eduEntries.add(_EduEntry())),
                  onRemove: (i) => setState(() {
                    _eduEntries[i].dispose();
                    _eduEntries.removeAt(i);
                  }),
                ),
                _Step5(
                  skills: _skills,
                  skillInputCtrl: _skillInputCtrl,
                  onAddSkill: (s) => setState(() => _skills.add(s)),
                  onRemoveSkill: (i) => setState(() => _skills.removeAt(i)),
                  languages: _languages,
                  onAddLanguage: (l) => setState(() => _languages.add(l)),
                  onRemoveLanguage: (i) =>
                      setState(() => _languages.removeAt(i)),
                ),
                _Step6(
                  aboutCtrl: _aboutCtrl,
                  loading: _loading,
                  error: _error,
                  onSubmit: _loading ? null : _submit,
                ),
              ],
            ),
          ),
          _BottomNav(
            step: _step,
            total: _totalSteps,
            loading: _loading,
            onBack: _back,
            onNext: _next,
            onSubmit: _loading ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Шаг ${step + 1} из $total',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (step + 1) / total,
              minHeight: 4,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: const Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int step;
  final int total;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback? onSubmit;

  const _BottomNav({
    required this.step,
    required this.total,
    required this.loading,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLast = step == total - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          if (step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: loading ? null : onBack,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: cs.outline),
                ),
                child: const Text('Назад'),
              ),
            ),
          if (step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: isLast
                ? FilledButton.icon(
                    onPressed: onSubmit,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Создать резюме'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                : FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Далее'),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

InputDecoration _inputDeco(BuildContext context, String label,
    {String? hint, IconData? icon, bool required = false}) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return InputDecoration(
    labelText: required ? '$label *' : label,
    hintText: hint,
    prefixIcon: icon != null ? Icon(icon, size: 20) : null,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    filled: true,
    fillColor:
        isDark ? cs.surfaceContainerHighest : const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

Widget _stepTitle(BuildContext context, String title) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface)),
    );

// ── Step 1 — Photo & personal ─────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final File? photo;
  final VoidCallback onPickPhoto;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController middleNameCtrl;
  final DateTime? birthDate;
  final ValueChanged<DateTime> onBirthDateChanged;
  final TextEditingController cityCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;

  const _Step1({
    required this.photo,
    required this.onPickPhoto,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.middleNameCtrl,
    required this.birthDate,
    required this.onBirthDateChanged,
    required this.cityCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepTitle(context, 'Фото и личные данные'),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: cs.surfaceContainerHighest,
                  backgroundImage:
                      photo != null ? FileImage(photo!) : null,
                  child: photo == null
                      ? Icon(Icons.person_rounded,
                          size: 50, color: cs.onSurfaceVariant)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: onPickPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: firstNameCtrl,
            decoration:
                _inputDeco(context, 'Имя', required: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: lastNameCtrl,
            decoration:
                _inputDeco(context, 'Фамилия', required: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: middleNameCtrl,
            decoration: _inputDeco(context, 'Отчество'),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: birthDate ??
                    DateTime.now().subtract(const Duration(days: 365 * 25)),
                firstDate: DateTime(1950),
                lastDate: DateTime.now().subtract(const Duration(days: 365 * 14)),
                locale: const Locale('ru'),
              );
              if (picked != null) onBirthDateChanged(picked);
            },
            child: InputDecorator(
              decoration: _inputDeco(context, 'Дата рождения',
                  icon: Icons.cake_outlined),
              child: Text(
                birthDate != null
                    ? '${birthDate!.day.toString().padLeft(2, '0')}.${birthDate!.month.toString().padLeft(2, '0')}.${birthDate!.year}'
                    : 'Выберите дату',
                style: TextStyle(
                    color: birthDate != null
                        ? cs.onSurface
                        : cs.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cityCtrl,
            decoration:
                _inputDeco(context, 'Город', icon: Icons.location_on_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration:
                _inputDeco(context, 'Телефон', icon: Icons.phone_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration:
                _inputDeco(context, 'Email', icon: Icons.email_outlined),
          ),
        ],
      ),
    );
  }
}

// ── Step 2 — Desired position ─────────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  final TextEditingController positionCtrl;
  final TextEditingController salaryFromCtrl;
  final TextEditingController salaryToCtrl;
  final String currency;
  final ValueChanged<String?> onCurrencyChanged;
  final Set<String> employmentTypes;
  final ValueChanged<String> onEmploymentToggle;
  final String? workFormat;
  final ValueChanged<String?> onFormatChanged;

  const _Step2({
    required this.positionCtrl,
    required this.salaryFromCtrl,
    required this.salaryToCtrl,
    required this.currency,
    required this.onCurrencyChanged,
    required this.employmentTypes,
    required this.onEmploymentToggle,
    required this.workFormat,
    required this.onFormatChanged,
  });

  static const _empTypes = ['Полная', 'Частичная', 'Удалённая', 'Проектная'];
  static const _formats = ['На месте', 'Удалённо', 'Гибрид'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepTitle(context, 'Желаемая должность'),
          TextField(
            controller: positionCtrl,
            decoration: _inputDeco(context, 'Должность',
                icon: Icons.work_outline_rounded, required: true),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: salaryFromCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      _inputDeco(context, 'Зарплата от'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: salaryToCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco(context, 'до'),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: currency,
                onChanged: onCurrencyChanged,
                items: ['сум', 'USD']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                underline: const SizedBox(),
                style: TextStyle(color: cs.onSurface, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Тип занятости',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _empTypes.map((t) {
              final selected = employmentTypes.contains(t);
              return FilterChip(
                label: Text(t),
                selected: selected,
                onSelected: (_) => onEmploymentToggle(t),
                selectedColor:
                    const Color(0xFF2563EB).withValues(alpha: 0.15),
                checkmarkColor: const Color(0xFF2563EB),
                labelStyle: TextStyle(
                    color:
                        selected ? const Color(0xFF2563EB) : cs.onSurface),
                side: BorderSide(
                    color: selected
                        ? const Color(0xFF2563EB)
                        : cs.outlineVariant),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text('Формат работы',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _formats.map((f) {
              final selected = workFormat == f;
              return ChoiceChip(
                label: Text(f),
                selected: selected,
                onSelected: (_) => onFormatChanged(selected ? null : f),
                selectedColor:
                    const Color(0xFF2563EB).withValues(alpha: 0.15),
                checkmarkColor: const Color(0xFF2563EB),
                labelStyle: TextStyle(
                    color:
                        selected ? const Color(0xFF2563EB) : cs.onSurface),
                side: BorderSide(
                    color: selected
                        ? const Color(0xFF2563EB)
                        : cs.outlineVariant),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Step 3 — Work experience ──────────────────────────────────────────────────

class _Step3 extends StatelessWidget {
  final List<_WorkEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onRebuild;

  const _Step3({
    required this.entries,
    required this.onAdd,
    required this.onRemove,
    required this.onRebuild,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepTitle(context, 'Опыт работы'),
          ...List.generate(entries.length, (i) {
            final e = entries[i];
            return _WorkEntryCard(
              index: i,
              entry: e,
              onRemove: entries.length > 1 ? () => onRemove(i) : null,
              onRebuild: onRebuild,
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить место работы'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB)),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkEntryCard extends StatefulWidget {
  final int index;
  final _WorkEntry entry;
  final VoidCallback? onRemove;
  final VoidCallback onRebuild;

  const _WorkEntryCard({
    required this.index,
    required this.entry,
    required this.onRemove,
    required this.onRebuild,
  });

  @override
  State<_WorkEntryCard> createState() => _WorkEntryCardState();
}

class _WorkEntryCardState extends State<_WorkEntryCard> {
  Future<void> _pickDate(bool isFrom) async {
    final e = widget.entry;
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? e.from : e.to) ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        e.from = picked;
      } else {
        e.to = picked;
      }
    });
    widget.onRebuild();
  }

  String _fmtDate(DateTime? d) =>
      d != null ? '${d.month.toString().padLeft(2, '0')}.${d.year}' : 'Не указано';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = widget.entry;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Место ${widget.index + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: cs.onSurface)),
                const Spacer(),
                if (widget.onRemove != null)
                  IconButton(
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: cs.error,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: e.companyCtrl,
              decoration:
                  _inputDeco(context, 'Компания', required: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: e.positionCtrl,
              decoration:
                  _inputDeco(context, 'Должность', required: true),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(true),
                    child: InputDecorator(
                      decoration: _inputDeco(context, 'С'),
                      child: Text(_fmtDate(e.from),
                          style: TextStyle(
                              color: e.from != null
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                              fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!e.isCurrent)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(false),
                      child: InputDecorator(
                        decoration: _inputDeco(context, 'По'),
                        child: Text(_fmtDate(e.to),
                            style: TextStyle(
                                color: e.to != null
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant,
                                fontSize: 14)),
                      ),
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                Checkbox(
                  value: e.isCurrent,
                  onChanged: (v) => setState(() => e.isCurrent = v!),
                  activeColor: const Color(0xFF2563EB),
                ),
                const Text('По настоящее время'),
              ],
            ),
            TextField(
              controller: e.dutiesCtrl,
              maxLines: 3,
              decoration: _inputDeco(context, 'Обязанности',
                  hint: 'Что вы делали на этой должности...'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 4 — Education ────────────────────────────────────────────────────────

class _Step4 extends StatelessWidget {
  final List<_EduEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _Step4({
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepTitle(context, 'Образование'),
          ...List.generate(entries.length, (i) {
            final e = entries[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('Образование ${i + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (entries.length > 1)
                          IconButton(
                            onPressed: () => onRemove(i),
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: Theme.of(context).colorScheme.error,
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: e.institutionCtrl,
                      decoration:
                          _inputDeco(context, 'Учебное заведение'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: e.specialityCtrl,
                      decoration:
                          _inputDeco(context, 'Специальность'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: e.yearCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          _inputDeco(context, 'Год окончания'),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить образование'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB)),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 5 — Skills & Languages ───────────────────────────────────────────────

class _Step5 extends StatelessWidget {
  final List<String> skills;
  final TextEditingController skillInputCtrl;
  final ValueChanged<String> onAddSkill;
  final ValueChanged<int> onRemoveSkill;
  final List<Map<String, String>> languages;
  final ValueChanged<Map<String, String>> onAddLanguage;
  final ValueChanged<int> onRemoveLanguage;

  const _Step5({
    required this.skills,
    required this.skillInputCtrl,
    required this.onAddSkill,
    required this.onRemoveSkill,
    required this.languages,
    required this.onAddLanguage,
    required this.onRemoveLanguage,
  });

  static const _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'Родной'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepTitle(context, 'Навыки и языки'),
          Text('Навыки',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: skillInputCtrl,
                  decoration: _inputDeco(context, 'Добавить навык',
                      hint: 'Flutter, SQL, ...'),
                  onSubmitted: (v) {
                    final t = v.trim();
                    if (t.isNotEmpty) {
                      onAddSkill(t);
                      skillInputCtrl.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final t = skillInputCtrl.text.trim();
                  if (t.isNotEmpty) {
                    onAddSkill(t);
                    skillInputCtrl.clear();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ],
          ),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(skills.length, (i) {
                return Chip(
                  label: Text(skills[i]),
                  onDeleted: () => onRemoveSkill(i),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  backgroundColor:
                      const Color(0xFF2563EB).withValues(alpha: 0.1),
                  labelStyle:
                      const TextStyle(color: Color(0xFF2563EB), fontSize: 13),
                  side: const BorderSide(color: Color(0xFF2563EB), width: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                );
              }),
            ),
          ],
          const SizedBox(height: 24),
          Text('Языки',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 8),
          _AddLanguageRow(
            levels: _levels,
            onAdd: onAddLanguage,
          ),
          if (languages.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...List.generate(languages.length, (i) {
              final l = languages[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  dense: true,
                  title: Text(l['lang'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(l['level'] ?? '',
                            style: const TextStyle(
                                color: Color(0xFF2563EB), fontSize: 12)),
                      ),
                      IconButton(
                        onPressed: () => onRemoveLanguage(i),
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: cs.onSurfaceVariant),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _AddLanguageRow extends StatefulWidget {
  final List<String> levels;
  final ValueChanged<Map<String, String>> onAdd;

  const _AddLanguageRow({required this.levels, required this.onAdd});

  @override
  State<_AddLanguageRow> createState() => _AddLanguageRowState();
}

class _AddLanguageRowState extends State<_AddLanguageRow> {
  final _langCtrl = TextEditingController();
  String _level = 'B1';

  @override
  void dispose() {
    _langCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _langCtrl,
            decoration:
                _inputDeco(context, 'Язык', hint: 'Русский, English...'),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _level,
          onChanged: (v) => setState(() => _level = v!),
          items: widget.levels
              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
              .toList(),
          underline: const SizedBox(),
          style: TextStyle(color: cs.onSurface, fontSize: 14),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            final t = _langCtrl.text.trim();
            if (t.isNotEmpty) {
              widget.onAdd({'lang': t, 'level': _level});
              _langCtrl.clear();
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: EdgeInsets.zero,
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ],
    );
  }
}

// ── Step 6 — About ────────────────────────────────────────────────────────────

class _Step6 extends StatelessWidget {
  final TextEditingController aboutCtrl;
  final bool loading;
  final String? error;
  final VoidCallback? onSubmit;

  const _Step6({
    required this.aboutCtrl,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepTitle(context, 'О себе'),
          TextField(
            controller: aboutCtrl,
            maxLines: 8,
            decoration: _inputDeco(context, 'Расскажите о себе и своих достижениях',
                hint:
                    'Опишите свои сильные стороны, ключевые достижения, профессиональные цели...'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              final text =
                  'Составь профессиональное резюме раздел "О себе" на основе введённых данных.';
              aboutCtrl.text = text;
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Создать с Ассистентом'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB)),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(error!, style: TextStyle(color: cs.error)),
            ),
          ],
        ],
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
    // Запрашиваем разрешение на микрофон
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        setState(() => _error =
            'Нет доступа к микрофону. Разрешите доступ в настройках телефона.');
        if (status.isPermanentlyDenied) {
          openAppSettings();
        }
      }
      return;
    }

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
    } catch (e) {
      await rec.closeRecorder();
      if (mounted) {
        setState(() => _error = 'Ошибка инициализации микрофона: $e');
      }
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
