import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'resume_edit_screen.dart';

class ResumeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> resume;

  const ResumeDetailScreen({super.key, required this.resume});

  @override
  State<ResumeDetailScreen> createState() => _ResumeDetailScreenState();
}

class _ResumeDetailScreenState extends State<ResumeDetailScreen> {
  late Map<String, dynamic> _resume;
  bool _deleting = false;
  bool _scoring = false;
  bool _settingMain = false;
  bool _downloadingPdf = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _resume = Map<String, dynamic>.from(widget.resume);
  }

  Future<void> _refresh() async {
    // Reload resume from server
    try {
      final auth = context.read<AuthProvider>();
      final list = await auth.withAuth((t) => ApiService.getResumes(t));
      final updated = (list as List).cast<Map<String, dynamic>>().firstWhere(
        (r) => r['id'] == _resume['id'],
        orElse: () => _resume,
      );
      if (mounted) setState(() => _resume = updated);
    } catch (_) {}
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить резюме?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.withAuth((t) => ApiService.deleteResume(t, _resume['id'] as String));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _score() async {
    setState(() => _scoring = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.withAuth((t) => ApiService.scoreResume(t, _resume['id'] as String));
      await _refresh();
      _showSnack('✅ Оценка обновлена!');
    } catch (e) {
      _showSnack('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _scoring = false);
    }
  }

  Future<void> _setMain() async {
    setState(() => _settingMain = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.withAuth((t) => ApiService.setMainResume(t, _resume['id'] as String));
      if (mounted) {
        setState(() => _resume['isMain'] = true);
        _showSnack('✅ Резюме установлено как основное');
      }
    } catch (e) {
      _showSnack('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _settingMain = false);
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ResumeEditScreen(resume: _resume)),
    );
    if (updated == true) await _refresh();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.withAuth((t) => ApiService.uploadResumePhoto(t, _resume['id'] as String, File(picked.path)));
      await _refresh();
      _showSnack('✅ Фото обновлено');
    } catch (e) {
      _showSnack('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _downloadingPdf = true);
    try {
      final auth = context.read<AuthProvider>();
      final bytes = await auth.withAuth(
        (t) => ApiService.downloadResumePdf(t, _resume['id'] as String),
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/resume_${_resume['id']}.pdf');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      _showSnack('Ошибка скачивания PDF: $e');
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = (_resume['content'] as Map<String, dynamic>?) ?? {};
    final skills = (_resume['skills'] as List?)?.cast<String>() ?? [];
    final isMain = _resume['isMain'] as bool? ?? false;
    final isAi = _resume['isAiGenerated'] as bool? ?? false;
    final photoUrl = _resume['photoUrl'] as String?;
    final score = content['aiScore'];

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            surfaceTintColor: cs.surface,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: _edit,
              ),
              IconButton(
                icon: _deleting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline_rounded, color: Colors.red),
                onPressed: _deleting ? null : _delete,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.primary.withValues(alpha: 0.15),
                      cs.surface,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // Photo
                    GestureDetector(
                      onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primaryContainer,
                              border: Border.all(color: cs.primary, width: 3),
                              image: photoUrl != null
                                  ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: photoUrl == null
                                ? Icon(Icons.person_rounded, size: 50, color: cs.primary)
                                : null,
                          ),
                          if (_uploadingPhoto)
                            const Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0x66000000),
                                ),
                                child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.primary,
                                border: Border.all(color: cs.surface, width: 2),
                              ),
                              child: Icon(Icons.camera_alt_rounded, size: 14, color: cs.onPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _resume['title'] as String? ?? 'Резюме',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isAi) _chip('✨ ИИ', cs.primary, cs.primaryContainer),
                        if (isMain) ...[
                          const SizedBox(width: 6),
                          _chip('⭐ Основное', const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
                        ],
                        if (score != null) ...[
                          const SizedBox(width: 6),
                          _chip('$score/100', _scoreColor(score), _scoreColor(score).withValues(alpha: 0.12)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Action buttons
                  Column(
                    children: [
                      if (!isMain) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _settingMain ? null : _setMain,
                            icon: _settingMain
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.star_rounded),
                            label: const Text('Сделать основным'),
                            style: FilledButton.styleFrom(backgroundColor: Colors.blue),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _downloadingPdf ? null : _downloadPdf,
                          icon: _downloadingPdf
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('Скачать PDF'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _scoring ? null : _score,
                          icon: _scoring
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Оценить резюме'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Contacts
                  if (_hasContacts(content)) ...[
                    _buildSection(
                      cs, isDark,
                      title: 'Контакты',
                      icon: Icons.contact_phone_rounded,
                      child: Column(
                        children: [
                          if (content['phone'] != null && (content['phone'] as String).isNotEmpty)
                            _infoRow(cs, Icons.phone_rounded, content['phone'] as String),
                          if (content['city'] != null && (content['city'] as String).isNotEmpty)
                            _infoRow(cs, Icons.location_on_rounded, content['city'] as String),
                          if (content['email'] != null && (content['email'] as String).isNotEmpty)
                            _infoRow(cs, Icons.email_rounded, content['email'] as String),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Summary
                  if (_notEmpty(content['summary']))
                    _buildTextSection(cs, isDark, 'О себе', Icons.person_rounded, content['summary'] as String),

                  // Skills
                  if (skills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildSection(
                      cs, isDark,
                      title: 'Навыки',
                      icon: Icons.psychology_rounded,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: skills.map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(s, style: TextStyle(fontSize: 13, color: cs.primary, fontWeight: FontWeight.w500)),
                        )).toList(),
                      ),
                    ),
                  ],

                  // Experience
                  if (_notEmpty(content['experience'])) ...[
                    const SizedBox(height: 12),
                    _buildTextSection(cs, isDark, 'Опыт работы', Icons.business_center_rounded, content['experience'] as String),
                  ],

                  // Education
                  if (_notEmpty(content['education'])) ...[
                    const SizedBox(height: 12),
                    _buildTextSection(cs, isDark, 'Образование', Icons.school_rounded, content['education'] as String),
                  ],

                  // Languages
                  if (_notEmpty(content['languages'])) ...[
                    const SizedBox(height: 12),
                    _buildTextSection(cs, isDark, 'Языки', Icons.language_rounded, content['languages'] as String),
                  ],

                  // AI Score details
                  if (content['aiScoreSummary'] != null) ...[
                    const SizedBox(height: 12),
                    _buildSection(
                      cs, isDark,
                      title: 'Оценка Ассистента',
                      icon: Icons.auto_awesome_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (content['aiScoreSummary'] != null)
                            Text(content['aiScoreSummary'] as String,
                                style: TextStyle(fontSize: 13, color: cs.onSurface)),
                          if (content['aiScoreStrengths'] != null) ...[
                            const SizedBox(height: 10),
                            Text('💪 Сильные стороны',
                                style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary)),
                            const SizedBox(height: 4),
                            ...(content['aiScoreStrengths'] as List).map((s) =>
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text('• $s', style: TextStyle(fontSize: 13, color: cs.onSurface)),
                              )
                            ),
                          ],
                          if (content['aiScoreImprovements'] != null) ...[
                            const SizedBox(height: 10),
                            Text('📈 Что улучшить',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
                            const SizedBox(height: 4),
                            ...(content['aiScoreImprovements'] as List).map((s) =>
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text('• $s', style: TextStyle(fontSize: 13, color: cs.onSurface)),
                              )
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _notEmpty(dynamic val) => val != null && (val as String).isNotEmpty;
  bool _hasContacts(Map<String, dynamic> content) {
    return _notEmpty(content['phone']) || _notEmpty(content['city']) || _notEmpty(content['email']);
  }

  Widget _buildSection(ColorScheme cs, bool isDark, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildTextSection(ColorScheme cs, bool isDark, String title, IconData icon, String text) {
    return _buildSection(cs, isDark, title: title, icon: icon,
      child: Text(text, style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.5)),
    );
  }

  Widget _infoRow(ColorScheme cs, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: cs.onSurface))),
        ],
      ),
    );
  }

  Widget _chip(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  Color _scoreColor(dynamic score) {
    final n = score is int ? score : int.tryParse('$score') ?? 0;
    if (n >= 80) return const Color(0xFF16A34A);
    if (n >= 60) return const Color(0xFF2563EB);
    if (n >= 40) return Colors.orange;
    return Colors.red;
  }
}
