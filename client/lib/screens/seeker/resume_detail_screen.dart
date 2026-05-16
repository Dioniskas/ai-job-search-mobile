import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ResumeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> resume;

  const ResumeDetailScreen({super.key, required this.resume});

  @override
  State<ResumeDetailScreen> createState() => _ResumeDetailScreenState();
}

class _ResumeDetailScreenState extends State<ResumeDetailScreen> {
  late Map<String, dynamic> _resume;
  bool _scoring = false;
  bool _downloading = false;
  bool _initialized = false;

  // Salary estimate state
  Map<String, dynamic>? _salary;
  bool _salaryLoading = false;

  // Profile photo
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _resume = widget.resume;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadProfilePhoto();
    }
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;
      final data = await ApiService.getSeekerProfile(token);
      final p = data['profile'] as Map<String, dynamic>?;
      if (mounted && p != null) {
        setState(() => _profilePhotoUrl = p['photoUrl'] as String?);
      }
    } catch (_) {}
  }

  Map<String, dynamic> get _content {
    final c = _resume['content'];
    if (c is Map<String, dynamic>) return c;
    return {};
  }

  Future<void> _getSalaryEstimate() async {
    setState(() => _salaryLoading = true);
    try {
      final token = context.read<AuthProvider>().token!;
      final result =
          await ApiService.aiSalaryEstimate(token, _resume['id'] as String);
      if (mounted) setState(() => _salary = result);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _salaryLoading = false);
    }
  }

  Future<void> _getScore() async {
    setState(() => _scoring = true);
    try {
      final token = context.read<AuthProvider>().token!;
      final updated =
          await ApiService.scoreResume(token, _resume['id'] as String);
      if (mounted) setState(() => _resume = updated);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _scoring = false);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _downloading = true);
    try {
      final token = context.read<AuthProvider>().token!;
      final bytes =
          await ApiService.downloadResumePdf(token, _resume['id'] as String);

      final dir = await getApplicationDocumentsDirectory();
      final safeTitle = (_resume['title'] as String? ?? 'resume')
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim()
          .replaceAll(' ', '_');
      final file =
          File('${dir.path}/${safeTitle}_${_resume['id']}.pdf');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить резюме?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final token = context.read<AuthProvider>().token!;
      await ApiService.deleteResume(token, _resume['id'] as String);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showError('Ошибка удаления: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg.replaceFirst('Exception: ', '')),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = _resume['aiScore'];
    final isAi = _resume['isAiGenerated'] as bool? ?? false;
    final skills = (_resume['skills'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          _resume['title'] as String? ?? 'Резюме',
          style: const TextStyle(fontSize: 17),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        surfaceTintColor: cs.surface,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: cs.error),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Seeker photo + badges ─────────────────────────────────────────
          _buildHeaderCard(cs, isAi, skills),
          const SizedBox(height: 12),

          // ── Score card ────────────────────────────────────────────────────
          _buildScoreCard(cs, score),
          const SizedBox(height: 12),

          // ── Salary estimate card ──────────────────────────────────────────
          _buildSalaryCard(cs),
          const SizedBox(height: 12),

          // ── PDF Download ──────────────────────────────────────────────────
          _buildPdfButton(cs),
          const SizedBox(height: 12),

          // ── Content sections ──────────────────────────────────────────────
          if ((_content['summary'] as String? ?? '').isNotEmpty) ...[
            _buildSection(cs,
                icon: Icons.person_outline_rounded,
                title: 'О себе',
                child: _text(cs, _content['summary'] as String)),
            const SizedBox(height: 12),
          ],

          if ((_content['experience'] as String? ?? '').isNotEmpty) ...[
            _buildSection(cs,
                icon: Icons.work_outline_rounded,
                title: 'Опыт работы',
                child: _text(cs, _content['experience'] as String)),
            const SizedBox(height: 12),
          ],

          if ((_content['education'] as String? ?? '').isNotEmpty) ...[
            _buildSection(cs,
                icon: Icons.school_outlined,
                title: 'Образование',
                child: _text(cs, _content['education'] as String)),
            const SizedBox(height: 12),
          ],

          if ((_content['languages'] as String? ?? '').isNotEmpty) ...[
            _buildSection(cs,
                icon: Icons.language_rounded,
                title: 'Языки',
                child: _text(cs, _content['languages'] as String)),
            const SizedBox(height: 12),
          ],

          if ((_content['additional'] as String? ?? '').isNotEmpty) ...[
            _buildSection(cs,
                icon: Icons.info_outline_rounded,
                title: 'Дополнительно',
                child: _text(cs, _content['additional'] as String)),
            const SizedBox(height: 12),
          ],

          if ((_content['rawText'] as String? ?? '').isNotEmpty &&
              (_content['summary'] as String? ?? '').isEmpty) ...[
            _buildSection(cs,
                icon: Icons.article_outlined,
                title: 'Текст резюме',
                child: _text(cs, _content['rawText'] as String)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  // ── Header card: photo + skills + badges ────────────────────────────────────

  Widget _buildHeaderCard(
      ColorScheme cs, bool isAi, List<String> skills) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Photo
          CircleAvatar(
            radius: 44,
            backgroundColor: cs.surfaceContainerHighest,
            backgroundImage: _profilePhotoUrl != null
                ? NetworkImage(_profilePhotoUrl!)
                : null,
            child: _profilePhotoUrl == null
                ? Icon(Icons.person_rounded,
                    size: 44, color: cs.onSurfaceVariant)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            _resume['title'] as String? ?? '',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface),
            textAlign: TextAlign.center,
          ),

          // Badges
          if (isAi || _resume['pdfUrl'] != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (isAi)
                  _badge(cs, '✨ ИИ-резюме', cs.primary,
                      cs.primaryContainer),
                if (_resume['pdfUrl'] != null)
                  _badge(cs, 'PDF', Colors.orange.shade700,
                      Colors.orange.shade50),
              ],
            ),
          ],

          // Skills
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: skills
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(s,
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onPrimaryContainer)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Score card ──────────────────────────────────────────────────────────────

  Widget _buildScoreCard(ColorScheme cs, dynamic score) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
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
              Icon(Icons.auto_awesome_rounded,
                  color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text('Оценка резюме от ИИ',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: cs.onSurface)),
              const Spacer(),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scoreColor(score).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$score / 100',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _scoreColor(score),
                        fontSize: 15),
                  ),
                ),
            ],
          ),
          // Strengths / Improvements from aiScoreDetails
          if (score != null) ...[
            _buildScoreDetails(cs),
          ],
          if (score == null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _scoring ? null : _getScore,
              icon: _scoring
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.stars_rounded, size: 18),
              label: Text(_scoring ? 'Анализирую...' : 'Получить оценку'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreDetails(ColorScheme cs) {
    final content = _resume['content'];
    if (content is! Map<String, dynamic>) return const SizedBox.shrink();

    final summary = content['aiScoreSummary'] as String?;
    final strengths =
        (content['aiScoreStrengths'] as List?)?.cast<String>() ?? [];
    final improvements =
        (content['aiScoreImprovements'] as List?)?.cast<String>() ?? [];

    if (summary == null && strengths.isEmpty && improvements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary != null && summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(summary,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ],
        if (strengths.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Сильные стороны:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF16A34A))),
          ...strengths.map((s) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline,
                      size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(s,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF16A34A)))),
                ]),
              )),
        ],
        if (improvements.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Что улучшить:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.error)),
          ...improvements.map((s) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  Icon(Icons.arrow_circle_up_outlined,
                      size: 14, color: cs.error),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(s,
                          style: TextStyle(
                              fontSize: 12, color: cs.error))),
                ]),
              )),
        ],
      ],
    );
  }

  // ── Salary card ─────────────────────────────────────────────────────────────

  Widget _buildSalaryCard(ColorScheme cs) {
    const teal = Color(0xFF0D9488);
    final salaryMin = _salary?['min'] as int?;
    final salaryMax = _salary?['max'] as int?;
    final currency = _salary?['currency'] as String? ?? 'UZS';
    final explanation = _salary?['explanation'] as String?;

    String rangeText = '';
    if (salaryMin != null && salaryMax != null) {
      rangeText =
          '${salaryMin ~/ 1000000}–${salaryMax ~/ 1000000} млн $currency';
    } else if (salaryMin != null) {
      rangeText = 'от ${salaryMin ~/ 1000000} млн $currency';
    } else if (salaryMax != null) {
      rangeText = 'до ${salaryMax ~/ 1000000} млн $currency';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.payments_outlined, color: teal, size: 20),
            const SizedBox(width: 8),
            Text('Рыночная зарплата',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: cs.onSurface)),
            const Spacer(),
            if (rangeText.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(rangeText,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: teal,
                        fontSize: 13)),
              ),
          ]),
          if (explanation != null && explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(explanation,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ],
          if (_salary == null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _salaryLoading ? null : _getSalaryEstimate,
              icon: _salaryLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.query_stats_rounded, size: 18),
              label: Text(_salaryLoading
                  ? 'Анализирую рынок...'
                  : 'Узнать рыночную зарплату'),
              style: FilledButton.styleFrom(
                backgroundColor: teal,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── PDF download button ──────────────────────────────────────────────────────

  Widget _buildPdfButton(ColorScheme cs) {
    return OutlinedButton.icon(
      onPressed: _downloading ? null : _downloadPdf,
      icon: _downloading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: cs.primary))
          : const Icon(Icons.picture_as_pdf_rounded),
      label: Text(
          _downloading ? 'Генерирую PDF...' : 'Скачать PDF',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: cs.primary),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _buildSection(ColorScheme cs,
      {required IconData icon,
      required String title,
      required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _text(ColorScheme cs, String value) => Text(
        value,
        style: TextStyle(
            fontSize: 14, color: cs.onSurface, height: 1.5),
      );

  Widget _badge(
      ColorScheme cs, String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor)),
    );
  }

  Color _scoreColor(dynamic score) {
    final n = score is int ? score : int.tryParse('$score') ?? 0;
    if (n >= 80) return const Color(0xFF16A34A);
    if (n >= 60) return Theme.of(context).colorScheme.primary;
    if (n >= 40) return Colors.orange;
    return Theme.of(context).colorScheme.error;
  }
}
