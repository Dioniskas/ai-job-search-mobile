import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'vacancy_detail_screen.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _blue  = Color(0xFF2563EB);
const _green = Color(0xFF16A34A);
const _slate = Color(0xFF64748B);

// ── Screen ─────────────────────────────────────────────────────────────────────

class SavedVacanciesScreen extends StatefulWidget {
  const SavedVacanciesScreen({super.key});

  @override
  State<SavedVacanciesScreen> createState() => _SavedVacanciesScreenState();
}

class _SavedVacanciesScreenState extends State<SavedVacanciesScreen> {
  List<dynamic> _saved = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _token() => context.read<AuthProvider>().token ?? '';

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ApiService.getSavedVacancies(_token());
      if (mounted) setState(() { _saved = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _unsave(String vacancyId) async {
    try {
      await ApiService.unsaveVacancy(_token(), vacancyId);
      setState(() => _saved.removeWhere(
          (s) => (s['vacancy'] as Map?)?['id'] == vacancyId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Избранное',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : _error != null
              ? _errorView()
              : _saved.isEmpty
                  ? _emptyView()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _saved.length,
                        itemBuilder: (context, i) {
                          final vacancy = (_saved[i]['vacancy']
                              as Map<String, dynamic>?) ?? {};
                          return _SavedCard(
                            vacancy: vacancy,
                            onUnsave: () => _unsave(vacancy['id'] as String? ?? ''),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: _slate),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: _load, child: const Text('Повторить')),
      ]),
    ),
  );

  Widget _emptyView() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.favorite_border_rounded, size: 64, color: _slate),
      const SizedBox(height: 12),
      const Text('Нет избранных вакансий',
          style: TextStyle(fontSize: 17, color: _slate)),
      const SizedBox(height: 6),
      const Text(
        'Нажмите ❤ на карточке вакансии, чтобы сохранить',
        style: TextStyle(color: _slate, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    ]),
  );
}

// ── Saved Card ─────────────────────────────────────────────────────────────────

class _SavedCard extends StatelessWidget {
  const _SavedCard({required this.vacancy, required this.onUnsave});
  final Map<String, dynamic> vacancy;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final employer  = vacancy['employer'] as Map<String, dynamic>?;
    final logoUrl   = employer?['logoUrl'] as String?;
    final salaryMin = vacancy['salaryMin'] as int?;
    final salaryMax = vacancy['salaryMax'] as int?;
    final city      = vacancy['city'] as String?;

    String salary = '';
    if (salaryMin != null && salaryMax != null) {
      salary = '${salaryMin ~/ 1000}–${salaryMax ~/ 1000} тыс.';
    } else if (salaryMin != null) {
      salary = 'от ${salaryMin ~/ 1000} тыс.';
    } else if (salaryMax != null) {
      salary = 'до ${salaryMax ~/ 1000} тыс.';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: cs.surfaceContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                VacancyDetailScreen(vacancyId: vacancy['id'] as String),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFEFF6FF),
              backgroundImage:
                  logoUrl != null ? NetworkImage(logoUrl) : null,
              child: logoUrl == null
                  ? const Icon(Icons.business_rounded,
                      color: _blue, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  vacancy['title'] as String? ?? '',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: cs.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  employer?['companyName'] as String? ?? '',
                  style: const TextStyle(color: _slate, fontSize: 12),
                ),
                if (salary.isNotEmpty || city != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    if (salary.isNotEmpty) ...[
                      const Icon(Icons.payments_outlined,
                          size: 12, color: _green),
                      const SizedBox(width: 3),
                      Text(salary,
                          style: const TextStyle(
                              color: _green, fontSize: 11)),
                      const SizedBox(width: 8),
                    ],
                    if (city != null) ...[
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: _slate),
                      const SizedBox(width: 3),
                      Text(city,
                          style: const TextStyle(
                              color: _slate, fontSize: 11)),
                    ],
                  ]),
                ],
              ]),
            ),
            IconButton(
              onPressed: onUnsave,
              icon: const Icon(Icons.favorite_rounded,
                  color: Colors.red, size: 22),
              tooltip: 'Убрать из избранного',
            ),
          ]),
        ),
      ),
    );
  }
}
