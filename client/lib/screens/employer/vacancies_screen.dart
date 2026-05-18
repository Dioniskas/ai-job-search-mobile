import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'vacancy_create_screen.dart';
import 'ai_candidates_screen.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _blue = Color(0xFF2563EB);
const _slate = Color(0xFF64748B);

// ── Screen ─────────────────────────────────────────────────────────────────────

class EmployerVacanciesScreen extends StatefulWidget {
  const EmployerVacanciesScreen({super.key});

  @override
  State<EmployerVacanciesScreen> createState() =>
      _EmployerVacanciesScreenState();
}

class _EmployerVacanciesScreenState extends State<EmployerVacanciesScreen> {
  List<dynamic> _vacancies = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  AuthProvider get _auth => context.read<AuthProvider>();

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _auth.withAuth((t) => ApiService.getEmployerVacancies(t));
      if (mounted) setState(() { _vacancies = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleActive(String id, bool current) async {
    try {
      await _auth.withAuth((t) => ApiService.updateVacancy(t, id, {'isActive': !current}));
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _delete(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить вакансию?'),
        content: Text('«$title» будет удалена без возможности восстановления.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _auth.withAuth((t) => ApiService.deleteVacancy(t, id));
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (context) => const EmployerVacancyCreateScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Мои вакансии',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Создать вакансию'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _vacancies.isEmpty
                  ? _emptyView()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(12, 12, 12, 100),
                        itemCount: _vacancies.length,
                        itemBuilder: (context, index) {
                          final v = _vacancies[index];
                          return _VacancyItem(
                            vacancy: v,
                            onToggle: () => _toggleActive(
                              v['id'] as String,
                              v['isActive'] as bool? ?? false,
                            ),
                            onDelete: () => _delete(
                              v['id'] as String,
                              v['title'] as String? ?? '',
                            ),
                            onFindCandidates: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AiCandidatesScreen(
                                  vacancyId: v['id'] as String,
                                  vacancyTitle:
                                      v['title'] as String? ?? 'Вакансия',
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _errorView() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
      const SizedBox(height: 12),
      Text(_error!,
          style: const TextStyle(color: _slate),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FilledButton(onPressed: _load, child: const Text('Повторить')),
    ]),
  );

  Widget _emptyView() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.work_off_outlined, size: 64, color: _slate),
      const SizedBox(height: 12),
      const Text('Нет активных вакансий',
          style: TextStyle(fontSize: 17, color: _slate)),
      const SizedBox(height: 8),
      const Text('Нажмите «Создать вакансию», чтобы начать',
          style: TextStyle(color: _slate, fontSize: 13)),
    ]),
  );
}

// ── Vacancy Item Card ──────────────────────────────────────────────────────────

class _VacancyItem extends StatelessWidget {
  const _VacancyItem({
    required this.vacancy,
    required this.onToggle,
    required this.onDelete,
    required this.onFindCandidates,
  });
  final dynamic vacancy;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onFindCandidates;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = vacancy['isActive'] as bool? ?? false;
    final countMap = vacancy['_count'] as Map<String, dynamic>?;
    final appCount = countMap?['applications'] as int? ?? 0;
    final createdAt = vacancy['createdAt'] as String?;

    String dateStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        dateStr =
            '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: cs.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                vacancy['title'] as String? ?? '',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface),
              ),
            ),
            Switch(
              value: isActive,
              onChanged: (_) => onToggle(),
              activeThumbColor: Colors.white,
              activeTrackColor: _blue,
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            _badge(
              isActive ? 'Активна' : 'Скрыта',
              isActive ? const Color(0xFF16A34A) : _slate,
            ),
            const SizedBox(width: 8),
            _badge('$appCount откликов', _blue),
            const Spacer(),
            if (dateStr.isNotEmpty)
              Text(dateStr,
                  style: const TextStyle(color: _slate, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onFindCandidates,
                icon: const Icon(Icons.manage_search_rounded,
                    size: 16, color: _blue),
                label: const Text('Кандидаты',
                    style: TextStyle(color: _blue, fontSize: 12)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: Colors.red),
                label: const Text('Удалить',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}
