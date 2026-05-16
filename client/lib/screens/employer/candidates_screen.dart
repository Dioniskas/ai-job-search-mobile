import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'ai_candidates_screen.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _blue  = Color(0xFF2563EB);
const _green = Color(0xFF16A34A);
const _slate = Color(0xFF64748B);
const _bg    = Color(0xFFF8FAFC);

const _searchStatusLabel = {
  'ACTIVE':      'Активно ищет',
  'OPEN':        'Рассматривает',
  'NOT_LOOKING': 'Не ищет',
};

Color _searchStatusColor(String s) {
  switch (s) {
    case 'ACTIVE': return _green;
    case 'OPEN':   return _blue;
    default:       return _slate;
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class EmployerCandidatesScreen extends StatefulWidget {
  const EmployerCandidatesScreen({super.key});

  @override
  State<EmployerCandidatesScreen> createState() =>
      _EmployerCandidatesScreenState();
}

class _EmployerCandidatesScreenState extends State<EmployerCandidatesScreen> {
  // Seeker profiles are loaded via vacancy-level AI matching.
  // This screen shows a prompt to pick a vacancy and use AI match.
  List<dynamic> _vacancies = [];
  bool _loading = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) { _initialized = true; _load(); }
  }

  AuthProvider get _auth => context.read<AuthProvider>();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _auth.withAuth((t) => ApiService.getEmployerVacancies(t));
      if (mounted) setState(() { _vacancies = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pickVacancyForAI() {
    if (_vacancies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Создайте вакансию, чтобы найти кандидатов')),
      );
      return;
    }

    if (_vacancies.length == 1) {
      _openAiScreen(_vacancies[0]);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Выберите вакансию',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._vacancies.map((v) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.work_outline_rounded,
                    color: _blue, size: 20),
              ),
              title: Text(
                v['title'] as String? ?? 'Вакансия',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing:
                  const Icon(Icons.chevron_right_rounded, color: _slate),
              onTap: () {
                Navigator.pop(ctx);
                _openAiScreen(v);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _openAiScreen(dynamic vacancy) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiCandidatesScreen(
          vacancyId:    vacancy['id'] as String,
          vacancyTitle: vacancy['title'] as String? ?? 'Вакансия',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Кандидаты',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  // AI Match card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _blue.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Text('ИИ-подбор кандидатов',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 10),
                        const Text(
                          'ИИ проанализирует вашу вакансию и найдёт наиболее подходящих кандидатов с % совпадения',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _blue,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _pickVacancyForAI,
                            child: const Text('Найти кандидатов',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Search status legend
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Статус поиска кандидатов',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 10),
                        ..._searchStatusLabel.entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _searchStatusColor(e.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(e.value,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF0F172A))),
                          ]),
                        )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_vacancies.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Мои вакансии (${_vacancies.length})',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._vacancies.map((v) => _VacancyTile(
                      vacancy: v,
                      onFindCandidates: () => _openAiScreen(v),
                    )),
                  ],
                ]),
              ),
            ),
    );
  }
}

// ── Vacancy Tile ───────────────────────────────────────────────────────────────

class _VacancyTile extends StatelessWidget {
  const _VacancyTile({
    required this.vacancy,
    required this.onFindCandidates,
  });
  final dynamic vacancy;
  final VoidCallback onFindCandidates;

  @override
  Widget build(BuildContext context) {
    final isActive  = vacancy['isActive'] as bool? ?? false;
    final countMap  = vacancy['_count'] as Map<String, dynamic>?;
    final appCount  = countMap?['applications'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFEFF6FF)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.work_outline_rounded,
              color: isActive ? _blue : _slate, size: 20),
        ),
        title: Text(
          vacancy['title'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text('$appCount откликов',
            style: const TextStyle(color: _slate, fontSize: 12)),
        trailing: TextButton.icon(
          onPressed: onFindCandidates,
          icon: const Icon(Icons.manage_search_rounded,
              size: 15, color: _blue),
          label: const Text('ИИ-подбор',
              style: TextStyle(color: _blue, fontSize: 11)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}
