import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _blue = Color(0xFF2563EB);
const _slate = Color(0xFF64748B);

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

  void _showApplySheet({String? question}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ApplySheet(
        vacancyId:           widget.vacancyId,
        token:               _token(),
        preselectedResumeId: _matchResumeId,
        initialCoverText:    question,
      ),
    );
  }

  // ── Salary formatter ─────────────────────────────────────────────────────────

  static String _fmtNum(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _monthName(int m) => const [
    '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
  ][m];

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _vacancy == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Вакансия'),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
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

    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final v         = _vacancy!;
    final salaryMin = v['salaryMin'] as int?;
    final salaryMax = v['salaryMax'] as int?;
    final city      = v['city'] as String?;
    final empType   = v['employmentType'] as String?;
    final experience = v['experience'] as String?;
    final createdAt = v['createdAt'] as String?;
    final description = v['description'] as String? ?? '';
    final viewCount = v['viewCount'] as int?;
    final applicantCount = v['applicantCount'] as int?;
    final skills    = v['skills'] as List?;
    final isSeeker  = _role() == 'SEEKER';
    final isVerified = _employer?['isVerified'] as bool? ?? false;
    final logoUrl   = _employer?['logoUrl'] as String?;
    final companyName = _employer?['companyName'] as String? ?? '';

    String salary = '';
    if (salaryMin != null && salaryMax != null) {
      salary = '${_fmtNum(salaryMin)} – ${_fmtNum(salaryMax)} UZS';
    } else if (salaryMin != null) {
      salary = 'от ${_fmtNum(salaryMin)} UZS';
    } else if (salaryMax != null) {
      salary = 'до ${_fmtNum(salaryMax)} UZS';
    }

    String dateStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) dateStr = '${dt.day} ${_monthName(dt.month)} ${dt.year}';
    }

    final conditions = [
      if (empType != null) _employmentLabels[empType] ?? empType,
      if (experience != null) _experienceLabels[experience] ?? experience,
    ].join(' • ');

    final barColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final bgColor  = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,

      // ── AppBar ───────────────────────────────────────────────────────────────
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: barColor,
        foregroundColor: textColor,
        title: Text(
          v['title'] as String? ?? 'Вакансия',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        actions: [
          if (isSeeker)
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
                  ),
          IconButton(
            onPressed: () => _showMoreSheet(context, isDark),
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),

      // ── Bottom apply button ──────────────────────────────────────────────────
      bottomNavigationBar: isSeeker
          ? Container(
              decoration: BoxDecoration(
                color: barColor,
                border: Border(
                  top: BorderSide(color: borderColor),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _showApplySheet,
                    child: const Text('Откликнуться',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            )
          : null,

      // ── Body ─────────────────────────────────────────────────────────────────
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── 1. Title block ───────────────────────────────────────────────
              Text(
                v['title'] as String? ?? '',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              if (salary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  salary,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
              if (conditions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(conditions,
                    style: const TextStyle(
                        color: _slate, fontSize: 14)),
              ],
              if (city != null && city.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(city,
                    style: const TextStyle(
                        color: Color(0xFF9E9E9E), fontSize: 13)),
              ],
              const SizedBox(height: 16),

              // ── 2. Company card ──────────────────────────────────────────────
              _bordered(
                isDark: isDark,
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      image: logoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(logoUrl),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: logoUrl == null
                        ? const Icon(Icons.business_rounded,
                            color: _blue, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      companyName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (isVerified)
                    const Icon(Icons.verified_rounded,
                        size: 20, color: _blue),
                ]),
              ),
              const SizedBox(height: 12),

              // ── 3. Statistics ────────────────────────────────────────────────
              if (applicantCount != null || viewCount != null) ...[
                Row(children: [
                  if (applicantCount != null)
                    Expanded(
                      child: _statBox(
                        '$applicantCount человек уже откликнулось',
                        isDark,
                      ),
                    ),
                  if (applicantCount != null && viewCount != null)
                    const SizedBox(width: 8),
                  if (viewCount != null)
                    Expanded(
                      child: _statBox(
                        '$viewCount человек сейчас смотрят',
                        isDark,
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
              ],
              if (dateStr.isNotEmpty) ...[
                Text(dateStr,
                    style: const TextStyle(
                        color: Color(0xFF9E9E9E), fontSize: 12)),
                const SizedBox(height: 16),
              ],

              // ── 4. Description ───────────────────────────────────────────────
              Text('Описание',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              const SizedBox(height: 10),
              Text(description,
                  style: TextStyle(
                      color: isDark
                          ? Colors.white70
                          : const Color(0xFF3C3C43),
                      fontSize: 15,
                      height: 1.6)),
              const SizedBox(height: 20),

              // ── 5. Key skills ────────────────────────────────────────────────
              if (skills != null && skills.isNotEmpty) ...[
                Text('Ключевые навыки',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: skills.map<Widget>((s) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(s.toString(),
                        style: TextStyle(
                            fontSize: 13, color: textColor)),
                  )).toList(),
                ),
                const SizedBox(height: 20),
              ],

              // ── 6. AI Assistant ──────────────────────────────────────────────
              if (isSeeker) ...[
                _buildAssistantCard(isDark, textColor),
                const SizedBox(height: 20),
              ],

              // ── 7. Questions for employer ────────────────────────────────────
              if (isSeeker) ...[
                Text('Задайте вопросы работодателю',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor)),
                const SizedBox(height: 4),
                const Text(
                  'Он получит их с откликом на вакансию',
                  style: TextStyle(
                      color: Color(0xFF9E9E9E), fontSize: 13),
                ),
                const SizedBox(height: 12),
                ...[
                  'Где располагается место работы?',
                  'Какой график работы?',
                  'Какая оплата труда?',
                  'Как с вами связаться?',
                ].map((q) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showApplySheet(question: q),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        foregroundColor: textColor,
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      child: Text(q),
                    ),
                  ),
                )),
                const SizedBox(height: 20),
              ],

              // ── 8. Similar vacancies ─────────────────────────────────────────
              if (_similar.isNotEmpty) ...[
                Text('Рекомендованные вакансии',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _similar.length,
                    itemBuilder: (ctx, i) {
                      final s = _similar[i];
                      return _SimilarCard(
                        vacancy: s,
                        isDark: isDark,
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VacancyDetailScreen(
                                vacancyId: s['id'] as String),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── More sheet (три точки) ────────────────────────────────────────────────────

  void _showMoreSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF9E9E9E),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Поделиться вакансией'),
            onTap: () => Navigator.pop(ctx),
          ),
          if (_reportLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.red)),
            )
          else
            ListTile(
              leading: const Icon(Icons.flag_outlined,
                  color: Colors.red),
              title: const Text('Пожаловаться на вакансию',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog();
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── AI Assistant card ────────────────────────────────────────────────────────

  Widget _buildAssistantCard(bool isDark, Color textColor) {
    final bgColor = isDark
        ? const Color(0xFF1A2A4A)
        : const Color(0xFFEFF6FF);
    final borderColor = isDark
        ? const Color(0xFF2563EB).withValues(alpha: 0.4)
        : const Color(0xFFBFDBFE);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        const Row(children: [
          Text('✨', style: TextStyle(fontSize: 16)),
          SizedBox(width: 6),
          Text(
            'Совместимость с вашим резюме',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _blue,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (_matchLoading)
          const Row(children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _blue),
            ),
            SizedBox(width: 10),
            Text('Рассчитываю...',
                style: TextStyle(color: _slate, fontSize: 13)),
          ])
        else if (_matchPercent != null) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              '${_matchPercent!}%',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: _matchColor(_matchPercent!),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'совпадение',
                style: TextStyle(
                    color: _matchColor(_matchPercent!),
                    fontSize: 14),
              ),
            ),
          ]),
          if (_matchExplanation != null &&
              _matchExplanation!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_matchExplanation!,
                style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF3C3C43),
                    fontSize: 13,
                    height: 1.4)),
          ],
          if (_matchResumeTitle != null) ...[
            const SizedBox(height: 8),
            Text(
              'Резюме: $_matchResumeTitle',
              style: const TextStyle(
                  color: _slate, fontSize: 12),
            ),
          ],
        ] else
          const Text(
            'Создайте резюме, чтобы увидеть совместимость',
            style: TextStyle(color: _slate, fontSize: 13),
          ),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Widget _bordered({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFE5E5EA),
        ),
      ),
      child: child,
    );
  }

  Widget _statBox(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0A2A1A)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF16A34A),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Similar Card (horizontal) ──────────────────────────────────────────────────

class _SimilarCard extends StatelessWidget {
  const _SimilarCard({
    required this.vacancy,
    required this.onTap,
    required this.isDark,
  });
  final dynamic vacancy;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final employer = vacancy['employer'] as Map<String, dynamic>?;
    final logoUrl  = employer?['logoUrl'] as String?;
    final title    = vacancy['title'] as String? ?? '';
    final company  = employer?['companyName'] as String? ?? '';
    final salaryMin = vacancy['salaryMin'] as int?;

    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final textColor = isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  image: logoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(logoUrl),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: logoUrl == null
                    ? const Icon(Icons.business_rounded,
                        color: _blue, size: 18)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  company,
                  style: const TextStyle(
                      color: _slate, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (salaryMin != null) ...[
              const Spacer(),
              Text(
                'от ${(salaryMin ~/ 1000 * 1000)} UZS',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF16A34A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
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
    this.initialCoverText,
  });
  final String vacancyId;
  final String token;
  final String? preselectedResumeId;
  final String? initialCoverText;

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
    if (widget.initialCoverText != null) {
      _coverCtrl.text = widget.initialCoverText!;
    }
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

  Widget _formView() {
    final cs = Theme.of(context).colorScheme;
    return Column(
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
                            color: selected ? _blue : cs.onSurface)),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle_rounded,
                        color: _blue, size: 20),
                ]),
              ),
            );
          }),
        const SizedBox(height: 14),
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
              _generatingCover ? 'Генерирую...' : '✨ Ассистент',
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
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
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
}

// ── Vacancy History ────────────────────────────────────────────────────────────

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
