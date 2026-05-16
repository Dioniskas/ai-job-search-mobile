import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _blue = Color(0xFF2563EB);
const _slate = Color(0xFF64748B);
const _bg = Color(0xFFF8FAFC);

const _employmentLabels = {
  'FULL_TIME': 'Полная занятость',
  'PART_TIME': 'Частичная занятость',
  'REMOTE': 'Удалённая работа',
  'CONTRACT': 'Контракт',
  'INTERNSHIP': 'Стажировка',
};

const _experienceLabels = {
  'NO_EXPERIENCE': 'Без опыта',
  '1-3': '1–3 года',
  '3-6': '3–6 лет',
  '6+': 'Более 6 лет',
};

Color _matchColor(int p) {
  if (p >= 70) return const Color(0xFF16A34A);
  if (p >= 40) return Colors.orange;
  return Colors.red;
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class VacancyDetailScreen extends StatefulWidget {
  const VacancyDetailScreen({super.key, required this.vacancyId});
  final String vacancyId;

  @override
  State<VacancyDetailScreen> createState() => _VacancyDetailScreenState();
}

class _VacancyDetailScreenState extends State<VacancyDetailScreen> {
  Map<String, dynamic>? _vacancy;
  Map<String, dynamic>? _employer;
  List<dynamic> _similar = [];
  bool _loading = true;
  String? _error;

  // AI match %
  int? _matchPercent;
  String? _matchExplanation;
  String? _matchResumeId;
  String? _matchResumeTitle;
  bool _matchLoading = false;

  // Save / favourite
  bool _isSaved = false;
  bool _saveLoading = false;

  // Report
  bool _reportLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  AuthProvider get _auth => context.read<AuthProvider>();
  String _token() => _auth.token ?? '';
  String? _role() => _auth.role;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _auth.withAuth((t) => ApiService.getVacancy(t, widget.vacancyId));
      if (mounted) {
        setState(() {
          _vacancy = data['vacancy'] as Map<String, dynamic>;
          _employer = _vacancy!['employer'] as Map<String, dynamic>?;
          _similar = data['similar'] as List<dynamic>;
          _loading = false;
        });
        if (_role() == 'SEEKER') {
          _loadMatchPercent();
          _loadSavedStatus();
          // Track history
          VacancyHistory.add(
            widget.vacancyId,
            _vacancy!['title'] as String? ?? '',
            (_vacancy!['employer'] as Map?)?['companyName'] as String? ?? '',
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadSavedStatus() async {
    try {
      final saved = await _auth.withAuth(
          (t) => ApiService.checkSavedVacancy(t, widget.vacancyId));
      if (mounted) setState(() => _isSaved = saved);
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    if (_saveLoading) return;
    setState(() => _saveLoading = true);
    try {
      if (_isSaved) {
        await _auth.withAuth((t) => ApiService.unsaveVacancy(t, widget.vacancyId));
      } else {
        await _auth.withAuth((t) => ApiService.saveVacancy(t, widget.vacancyId));
      }
      if (mounted) setState(() { _isSaved = !_isSaved; _saveLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _saveLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _showReportDialog() async {
    final reasons = [
      'Мошенничество или обман',
      'Неприемлемое содержание',
      'Недостоверная информация',
      'Спам',
      'Другое',
    ];
    String? selectedReason;

    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Пожаловаться на вакансию'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((r) => RadioListTile<String>(
              value: r,
              groupValue: selectedReason,
              title: Text(r, style: const TextStyle(fontSize: 14)),
              onChanged: (v) => setLocal(() => selectedReason = v),
              dense: true,
              contentPadding: EdgeInsets.zero,
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: selectedReason == null
                  ? null
                  : () => Navigator.pop(ctx, selectedReason),
              child: const Text('Отправить'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == null || !mounted) return;
    setState(() => _reportLoading = true);
    try {
      await _auth.withAuth((t) => ApiService.createReport(
        t, widget.vacancyId, 'vacancy', confirmed,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Жалоба отправлена. Спасибо!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  Future<void> _loadMatchPercent() async {
    setState(() => _matchLoading = true);
    try {
      final resumes = await _auth.withAuth((t) => ApiService.getResumes(t));
      if (resumes.isEmpty || !mounted) {
        setState(() => _matchLoading = false);
        return;
      }
      // Выбрать резюме с наивысшим баллом (или первое)
      final best = resumes.reduce((a, b) {
        final sa = (a['aiScore'] as num?)?.toInt() ?? 0;
        final sb = (b['aiScore'] as num?)?.toInt() ?? 0;
        return sa >= sb ? a : b;
      });
      final result = await _auth.withAuth((t) => ApiService.aiMatchPercent(
        t, best['id'] as String, widget.vacancyId,
      ));
      if (mounted) {
        setState(() {
          _matchPercent     = (result['percent'] as num?)?.toInt();
          _matchExplanation = result['explanation'] as String?;
          _matchResumeId    = best['id'] as String;
          _matchResumeTitle = best['title'] as String?;
          _matchLoading     = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _matchLoading = false);
    }
  }

  void _showApplySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ApplySheet(
        vacancyId:           widget.vacancyId,
        token:               _token(),
        preselectedResumeId: _matchResumeId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _vacancy == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Вакансия'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
        ),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error ?? 'Ошибка загрузки',
                style: const TextStyle(color: _slate),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Повторить')),
          ]),
        ),
      );
    }

    final v          = _vacancy!;
    final salaryMin  = v['salaryMin'] as int?;
    final salaryMax  = v['salaryMax'] as int?;
    final city       = v['city']       as String?;
    final empType    = v['employmentType'] as String?;
    final experience = v['experience']    as String?;
    final createdAt  = v['createdAt']     as String?;
    final description = v['description']  as String? ?? '';
    final isSeeker   = _role() == 'SEEKER';

    String salary = '';
    if (salaryMin != null && salaryMax != null) {
      salary = '${salaryMin ~/ 1000}–${salaryMax ~/ 1000} тыс. сум';
    } else if (salaryMin != null) {
      salary = 'от ${salaryMin ~/ 1000} тыс. сум';
    } else if (salaryMax != null) {
      salary = 'до ${salaryMax ~/ 1000} тыс. сум';
    }

    String dateStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) dateStr = '${dt.day} ${_monthName(dt.month)} ${dt.year}';
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Вакансия'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: isSeeker
            ? [
                _saveLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _blue),
                        ),
                      )
                    : IconButton(
                        onPressed: _toggleSave,
                        icon: Icon(
                          _isSaved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _isSaved ? Colors.red : null,
                        ),
                        tooltip: _isSaved ? 'Убрать из избранного' : 'В избранное',
                      ),
                _reportLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.red),
                        ),
                      )
                    : IconButton(
                        onPressed: _showReportDialog,
                        icon: const Icon(Icons.flag_outlined),
                        tooltip: 'Пожаловаться',
                        color: Colors.red.shade400,
                      ),
              ]
            : null,
      ),
      bottomNavigationBar: isSeeker
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _showApplySheet,
                  child: const Text('Откликнуться',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header ────────────────────────────────────────────────────────
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _logoAvatar(_employer?['logoUrl'] as String?),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v['title'] as String? ?? '',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A))),
                        const SizedBox(height: 4),
                        Text(_employer?['companyName'] as String? ?? '',
                            style: const TextStyle(
                                color: _slate, fontSize: 14)),
                      ]),
                ),
              ]),
              if (salary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(salary,
                    style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (city != null)
                  _infoChip(Icons.location_on_outlined, city),
                if (empType != null)
                  _infoChip(Icons.work_outline_rounded,
                      _employmentLabels[empType] ?? empType),
                if (experience != null)
                  _infoChip(Icons.timeline_outlined,
                      _experienceLabels[experience] ?? experience),
                if (dateStr.isNotEmpty)
                  _infoChip(Icons.calendar_today_outlined, dateStr),
              ]),
            ])),

            // ── % совпадения (только для соискателей) ────────────────────────
            if (isSeeker) _buildMatchCard(),

            // ── Description ───────────────────────────────────────────────────
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Описание вакансии',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 10),
              Text(description,
                  style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 14,
                      height: 1.6)),
            ])),

            // ── Похожие вакансии ──────────────────────────────────────────────
            if (_similar.isNotEmpty) ...[
              const SizedBox(height: 4),
              const Text('Похожие вакансии',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              ..._similar.map((s) => _SimilarCard(
                    vacancy: s,
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VacancyDetailScreen(
                            vacancyId: s['id'] as String),
                      ),
                    ),
                  )),
            ],

            const SizedBox(height: 80),
          ]),
        ),
      ),
    );
  }

  // ── Match % card ─────────────────────────────────────────────────────────────

  Widget _buildMatchCard() {
    if (_matchLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(children: [
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
          ),
          SizedBox(width: 10),
          Text('Рассчитываю совпадение...',
              style: TextStyle(color: _slate, fontSize: 13)),
        ]),
      );
    }

    if (_matchPercent == null) return const SizedBox.shrink();

    final p = _matchPercent!;
    final color = _matchColor(p);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome_rounded, size: 16, color: _blue),
          const SizedBox(width: 6),
          const Text('Совпадение с резюме',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF0F172A))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$p%',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ]),
        if (_matchResumeTitle != null) ...[
          const SizedBox(height: 4),
          Text('Резюме: $_matchResumeTitle',
              style: const TextStyle(color: _slate, fontSize: 12)),
        ],
        if (_matchExplanation != null &&
            _matchExplanation!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_matchExplanation!,
              style: const TextStyle(
                  color: Color(0xFF334155), fontSize: 13, height: 1.4)),
        ],
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Widget _card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: child,
  );

  Widget _logoAvatar(String? url) => CircleAvatar(
    radius: 24,
    backgroundColor: const Color(0xFFEFF6FF),
    backgroundImage: url != null ? NetworkImage(url) : null,
    child: url == null
        ? const Icon(Icons.business_rounded, color: _blue, size: 24)
        : null,
  );

  Widget _infoChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: _slate),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: _slate, fontSize: 13)),
    ]),
  );

  String _monthName(int m) => const [
    '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
  ][m];
}

// ── Similar Card ───────────────────────────────────────────────────────────────

class _SimilarCard extends StatelessWidget {
  const _SimilarCard({required this.vacancy, required this.onTap});
  final dynamic vacancy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final employer = vacancy['employer'] as Map<String, dynamic>?;
    final logoUrl  = employer?['logoUrl'] as String?;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEFF6FF),
          backgroundImage: logoUrl != null ? NetworkImage(logoUrl) : null,
          child: logoUrl == null
              ? const Icon(Icons.business_rounded, color: _blue, size: 18)
              : null,
        ),
        title: Text(vacancy['title'] as String? ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(employer?['companyName'] as String? ?? '',
            style: const TextStyle(color: _slate, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: _slate),
        onTap: onTap,
      ),
    );
  }
}

// ── Apply Bottom Sheet ─────────────────────────────────────────────────────────

class _ApplySheet extends StatefulWidget {
  const _ApplySheet({
    required this.vacancyId,
    required this.token,
    this.preselectedResumeId,
  });
  final String vacancyId;
  final String token;
  final String? preselectedResumeId;

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  List<dynamic> _resumes = [];
  bool _loadingResumes = true;
  String? _selectedResumeId;
  final _coverCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  bool _generatingCover = false;

  @override
  void initState() {
    super.initState();
    _selectedResumeId = widget.preselectedResumeId;
    _loadResumes();
  }

  @override
  void dispose() {
    _coverCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadResumes() async {
    try {
      final list = await ApiService.getResumes(widget.token);
      if (mounted) {
        setState(() { _resumes = list; _loadingResumes = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingResumes = false);
    }
  }

  Future<void> _generateCoverLetter() async {
    if (_selectedResumeId == null) return;
    setState(() => _generatingCover = true);
    try {
      final letter = await ApiService.aiCoverLetter(
        widget.token, _selectedResumeId!, widget.vacancyId,
      );
      if (mounted) {
        setState(() => _generatingCover = false);
        _coverCtrl.text = letter;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generatingCover = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedResumeId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Выберите резюме')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final cover = _coverCtrl.text.trim();
      await ApiService.applyToVacancy(
        widget.token,
        widget.vacancyId,
        _selectedResumeId!,
        coverLetter: cover.isEmpty ? null : cover,
      );
      if (mounted) setState(() { _submitted = true; _submitting = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _submitted ? _successView() : _formView(),
    );
  }

  Widget _successView() => Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.check_circle_rounded,
        size: 64, color: Color(0xFF16A34A)),
    const SizedBox(height: 12),
    const Text('Отклик отправлен!',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    const Text(
      'Работодатель рассмотрит вашу заявку и свяжется с вами',
      style: TextStyle(color: _slate),
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 20),
    FilledButton(
      style: FilledButton.styleFrom(
          backgroundColor: _blue,
          minimumSize: const Size(double.infinity, 48)),
      onPressed: () => Navigator.pop(context),
      child: const Text('Закрыть'),
    ),
  ]);

  Widget _formView() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Отклик на вакансию',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      const Text('Выберите резюме',
          style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (_loadingResumes)
        const Center(child: CircularProgressIndicator())
      else if (_resumes.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Нет резюме. Сначала создайте резюме в разделе «Резюме».',
            style: TextStyle(color: _slate),
          ),
        )
      else
        ..._resumes.map((r) {
          final id       = r['id'] as String;
          final title    = r['title'] as String? ?? 'Резюме';
          final selected = _selectedResumeId == id;
          return GestureDetector(
            onTap: () => setState(() => _selectedResumeId = id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? _blue : const Color(0xFFE2E8F0),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Icon(Icons.description_rounded,
                    color: selected ? _blue : _slate, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: selected
                              ? _blue
                              : const Color(0xFF0F172A))),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: _blue, size: 20),
              ]),
            ),
          );
        }),
      const SizedBox(height: 14),
      // Cover letter header with AI button
      Row(children: [
        const Text('Сопроводительное письмо',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const Spacer(),
        TextButton.icon(
          onPressed: (_selectedResumeId == null || _generatingCover)
              ? null
              : _generateCoverLetter,
          icon: _generatingCover
              ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome_rounded, size: 15),
          label: Text(
            _generatingCover ? 'Генерирую...' : '✨ ИИ письмо',
            style: const TextStyle(fontSize: 12),
          ),
          style: TextButton.styleFrom(
            foregroundColor: _blue,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ]),
      const SizedBox(height: 4),
      TextField(
        controller: _coverCtrl,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'Необязательно. Можно сгенерировать с помощью ИИ.',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _blue),
          ),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: _blue,
            minimumSize: const Size(double.infinity, 48)),
        onPressed: _submitting ? null : _submit,
        child: _submitting
            ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Text('Отправить отклик',
                style: TextStyle(fontSize: 16)),
      ),
    ],
  );
}

// ── Vacancy History ────────────────────────────────────────────────────────────
// Simple in-memory store of recently viewed vacancies (max 10).

class VacancyHistory {
  VacancyHistory._();

  static final List<Map<String, String>> _items = [];

  static void add(String id, String title, String companyName) {
    _items.removeWhere((v) => v['id'] == id);
    _items.insert(0, {
      'id':          id,
      'title':       title,
      'companyName': companyName,
    });
    if (_items.length > 10) _items.removeLast();
  }

  static List<Map<String, String>> get items => List.unmodifiable(_items);
}
