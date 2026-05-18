import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'resume_create_screen.dart';
import 'resume_detail_screen.dart';


class SeekerResumeScreen extends StatefulWidget {
  const SeekerResumeScreen({super.key});

  @override
  State<SeekerResumeScreen> createState() => _SeekerResumeScreenState();
}

class _SeekerResumeScreenState extends State<SeekerResumeScreen> {
  List<Map<String, dynamic>> _resumes = [];
  bool _loading = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<AuthProvider>().withAuth(
          (t) => ApiService.getResumes(t));
      if (mounted) {
        setState(() => _resumes = list.cast<Map<String, dynamic>>());
      }
    } catch (_) {
      // Показываем пустой список
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(Map<String, dynamic> resume) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (ctx) => ResumeDetailScreen(resume: resume)),
    );
    if (deleted == true) _load();
  }

  Future<void> _pushScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  void _showCreateSheet() {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Создать резюме',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ),
            _SheetOption(
              emoji: '📄',
              title: 'Загрузить PDF',
              subtitle: 'Уже есть готовое резюме',
              onTap: () {
                Navigator.pop(ctx);
                _pushScreen(const ResumeUploadPdfScreen(improve: false));
              },
            ),
            _SheetOption(
              emoji: '✨',
              title: 'PDF + Ассистент',
              subtitle: 'Загрузи PDF — Ассистент улучшит',
              onTap: () {
                Navigator.pop(ctx);
                _pushScreen(const ResumeUploadPdfScreen(improve: true));
              },
            ),
            _SheetOption(
              emoji: '📝',
              title: 'Заполнить форму',
              subtitle: 'Ассистент составит резюме',
              onTap: () {
                Navigator.pop(ctx);
                _pushScreen(const ResumeFormScreen());
              },
            ),
            _SheetOption(
              emoji: '🎤',
              title: 'Голосом',
              subtitle: 'Расскажи о себе — Ассистент оформит',
              onTap: () {
                Navigator.pop(ctx);
                _pushScreen(const ResumeVoiceScreen());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Мои резюме'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        surfaceTintColor: cs.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: cs.primary,
        icon: Icon(Icons.add_rounded, color: cs.onPrimary),
        label: Text('+ Создать', style: TextStyle(color: cs.onPrimary)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _resumes.isEmpty
              ? _buildEmpty(cs)
              : RefreshIndicator(
                  color: cs.primary,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _resumes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, i) => _ResumeCard(
                      resume: _resumes[i],
                      onTap: () => _openDetail(_resumes[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined,
              size: 72, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'Резюме пока нет',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Создайте резюме одним из 4 способов',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showCreateSheet,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Создать резюме'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet option row ───────────────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetOption({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── Resume card ───────────────────────────────────────────────────────────────

class _ResumeCard extends StatelessWidget {
  final Map<String, dynamic> resume;
  final VoidCallback onTap;

  const _ResumeCard({required this.resume, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAi = resume['isAiGenerated'] as bool? ?? false;
    final score = resume['aiScore'];
    final skills = (resume['skills'] as List?)?.cast<String>() ?? [];
    final updatedAt = resume['updatedAt'] as String? ?? '';
    final date = _formatDate(updatedAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.description_rounded,
                      color: cs.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resume['title'] as String? ?? 'Резюме',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(date,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (score != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          _scoreColor(score, cs).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$score/100',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _scoreColor(score, cs)),
                    ),
                  ),
              ],
            ),
            if (skills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: skills
                    .take(4)
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                            border:
                                Border.all(color: cs.outlineVariant),
                          ),
                          child: Text(s,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (isAi) _chip('✨ ИИ', cs.primary, cs.primaryContainer),
                if (resume['pdfUrl'] != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _chip('PDF', Colors.orange.shade700,
                        Colors.orange.shade50),
                  ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor)),
    );
  }

  Color _scoreColor(dynamic score, ColorScheme cs) {
    final n = score is int ? score : int.tryParse('$score') ?? 0;
    if (n >= 80) return const Color(0xFF16A34A);
    if (n >= 60) return cs.primary;
    if (n >= 40) return Colors.orange;
    return cs.error;
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
