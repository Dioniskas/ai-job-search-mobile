import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ResumeEditScreen extends StatefulWidget {
  final Map<String, dynamic> resume;

  const ResumeEditScreen({super.key, required this.resume});

  @override
  State<ResumeEditScreen> createState() => _ResumeEditScreenState();
}

class _ResumeEditScreenState extends State<ResumeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _aiImproving = false;
  File? _newPhoto;
  String? _photoUrl;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _summaryCtrl;
  late final TextEditingController _experienceCtrl;
  late final TextEditingController _educationCtrl;
  late final TextEditingController _skillsCtrl;
  late final TextEditingController _languagesCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    final content = (widget.resume['content'] as Map<String, dynamic>?) ?? {};
    _photoUrl = widget.resume['photoUrl'] as String?;
    _titleCtrl      = TextEditingController(text: widget.resume['title'] as String? ?? '');
    _summaryCtrl    = TextEditingController(text: content['summary']    as String? ?? '');
    _experienceCtrl = TextEditingController(text: content['experience'] as String? ?? '');
    _educationCtrl  = TextEditingController(text: content['education']  as String? ?? '');
    _languagesCtrl  = TextEditingController(text: content['languages']  as String? ?? '');
    _phoneCtrl      = TextEditingController(text: content['phone']      as String? ?? '');
    _cityCtrl       = TextEditingController(text: content['city']       as String? ?? '');
    _emailCtrl      = TextEditingController(text: content['email']      as String? ?? '');
    final skills = (widget.resume['skills'] as List?)?.cast<String>() ?? [];
    _skillsCtrl = TextEditingController(text: skills.join(', '));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _experienceCtrl.dispose();
    _educationCtrl.dispose();
    _skillsCtrl.dispose();
    _languagesCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _newPhoto = File(picked.path));
    }
  }

  Future<void> _aiImprove() async {
    if (_experienceCtrl.text.trim().isEmpty) {
      _showSnack('Заполните опыт работы для ИИ улучшения');
      return;
    }
    setState(() => _aiImproving = true);
    try {
      final auth = context.read<AuthProvider>();
      final result = await auth.withAuth((t) => ApiService.aiImproveResumeText(
        t,
        title: _titleCtrl.text,
        summary: _summaryCtrl.text,
        experience: _experienceCtrl.text,
        education: _educationCtrl.text,
        skills: _skillsCtrl.text,
      ));
      if (!mounted) return;
      setState(() {
        if (result['summary']    != null) _summaryCtrl.text    = result['summary'];
        if (result['experience'] != null) _experienceCtrl.text = result['experience'];
        if (result['education']  != null) _educationCtrl.text  = result['education'];
        if (result['skills']     != null) _skillsCtrl.text     = (result['skills'] as List).join(', ');
      });
      _showSnack('✨ ИИ улучшил резюме!');
    } catch (e) {
      _showSnack('Ошибка ИИ: $e');
    } finally {
      if (mounted) setState(() => _aiImproving = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      final id = widget.resume['id'] as String;
      final skills = _skillsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final content = {
        'title':      _titleCtrl.text,
        'summary':    _summaryCtrl.text,
        'experience': _experienceCtrl.text,
        'education':  _educationCtrl.text,
        'languages':  _languagesCtrl.text,
        'phone':      _phoneCtrl.text,
        'city':       _cityCtrl.text,
        'email':      _emailCtrl.text,
        'skills':     skills,
      };

      await auth.withAuth((t) => ApiService.updateResume(t, id, {
        'title':      _titleCtrl.text,
        'content':    content,
        'skills':     skills,
        'experience': _experienceCtrl.text,
      }));

      // Upload photo if selected
      if (_newPhoto != null) {
        await auth.withAuth((t) => ApiService.uploadResumePhoto(t, id, _newPhoto!));
      }

      if (!mounted) return;
      _showSnack('Резюме сохранено!');
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Редактировать резюме'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        surfaceTintColor: cs.surface,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text('Сохранить', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Photo
            _buildPhotoSection(cs),
            const SizedBox(height: 20),

            // AI improve button
            _buildAiButton(cs),
            const SizedBox(height: 20),

            // Contacts section
            _buildSection(
              cs,
              title: 'Контакты',
              icon: Icons.contact_phone_rounded,
              children: [
                _field(_phoneCtrl, 'Телефон', Icons.phone_rounded, hint: '+998 90 123 45 67'),
                const SizedBox(height: 12),
                _field(_cityCtrl, 'Город', Icons.location_on_rounded, hint: 'Ташкент'),
                const SizedBox(height: 12),
                _field(_emailCtrl, 'Email', Icons.email_rounded, hint: 'example@mail.com'),
              ],
            ),
            const SizedBox(height: 16),

            // Main info
            _buildSection(
              cs,
              title: 'Основное',
              icon: Icons.description_rounded,
              children: [
                _field(_titleCtrl, 'Должность / Заголовок резюме', Icons.work_rounded,
                    validator: (v) => v!.isEmpty ? 'Обязательное поле' : null),
                const SizedBox(height: 12),
                _field(_summaryCtrl, 'О себе', Icons.person_rounded,
                    maxLines: 4, hint: 'Краткое описание себя как специалиста...'),
              ],
            ),
            const SizedBox(height: 16),

            // Experience
            _buildSection(
              cs,
              title: 'Опыт работы',
              icon: Icons.business_center_rounded,
              children: [
                _field(_experienceCtrl, 'Опыт работы', Icons.history_rounded,
                    maxLines: 6,
                    hint: 'Компания, должность, период работы, обязанности...'),
              ],
            ),
            const SizedBox(height: 16),

            // Education
            _buildSection(
              cs,
              title: 'Образование',
              icon: Icons.school_rounded,
              children: [
                _field(_educationCtrl, 'Образование', Icons.school_rounded,
                    maxLines: 3,
                    hint: 'Университет, специальность, год окончания...'),
              ],
            ),
            const SizedBox(height: 16),

            // Skills
            _buildSection(
              cs,
              title: 'Навыки',
              icon: Icons.psychology_rounded,
              children: [
                _field(_skillsCtrl, 'Навыки (через запятую)', Icons.star_rounded,
                    maxLines: 3,
                    hint: 'Flutter, Dart, Firebase, Git...'),
              ],
            ),
            const SizedBox(height: 16),

            // Languages
            _buildSection(
              cs,
              title: 'Языки',
              icon: Icons.language_rounded,
              children: [
                _field(_languagesCtrl, 'Знание языков', Icons.translate_rounded,
                    maxLines: 2,
                    hint: 'Русский — родной, Английский — B2, Узбекский — свободно'),
              ],
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(ColorScheme cs) {
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primaryContainer,
                border: Border.all(color: cs.primary, width: 2),
                image: _newPhoto != null
                    ? DecorationImage(image: FileImage(_newPhoto!), fit: BoxFit.cover)
                    : (_photoUrl != null
                        ? DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover)
                        : null),
              ),
              child: (_newPhoto == null && _photoUrl == null)
                  ? Icon(Icons.person_rounded, size: 48, color: cs.primary)
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 2),
                ),
                child: Icon(Icons.camera_alt_rounded, size: 16, color: cs.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiButton(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _aiImproving ? null : _aiImprove,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_aiImproving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                else
                  const Text('✨', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(
                  _aiImproving ? 'ИИ улучшает...' : 'Улучшить с помощью ИИ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(ColorScheme cs, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: maxLines == 1 ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        filled: true,
        fillColor: cs.surfaceContainerLowest,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 12 : 0,
        ),
      ),
    );
  }
}
