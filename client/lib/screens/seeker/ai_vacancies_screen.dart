import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'vacancy_detail_screen.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _blue = Color(0xFF2563EB);
const _slate = Color(0xFF64748B);

Color _percentColor(int p) {
  if (p >= 70) return const Color(0xFF16A34A);
  if (p >= 40) return Colors.orange;
  return Colors.red;
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class AiVacanciesScreen extends StatefulWidget {
  const AiVacanciesScreen({
    super.key,
    required this.resumeId,
    required this.resumeTitle,
  });
  final String resumeId;
  final String resumeTitle;

  @override
  State<AiVacanciesScreen> createState() => _AiVacanciesScreenState();
}

class _AiVacanciesScreenState extends State<AiVacanciesScreen> {
  List<dynamic> _matches = [];
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
      final list = await ApiService.aiMatchVacancies(_token(), widget.resumeId);
      if (mounted) setState(() { _matches = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('ИИ-подбор',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: Column(children: [
        // Subtitle bar
        Container(
          color: cs.surface,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            const Icon(Icons.description_rounded, size: 14, color: _slate),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Резюме: ${widget.resumeTitle}',
                style: const TextStyle(color: _slate, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? _loadingView()
              : _error != null
                  ? _errorView()
                  : _matches.isEmpty
                      ? _emptyView()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _matches.length,
                            itemBuilder: (context, index) =>
                                _MatchCard(match: _matches[index]),
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _loadingView() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(color: _blue),
      const SizedBox(height: 16),
      const Text('ИИ анализирует ваш профиль...',
          style: TextStyle(color: _slate, fontSize: 15)),
      const SizedBox(height: 6),
      const Text('Это может занять 10–20 секунд',
          style: TextStyle(color: _slate, fontSize: 12)),
    ]),
  );

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
      const Icon(Icons.search_off_rounded, size: 64, color: _slate),
      const SizedBox(height: 12),
      const Text('Подходящих вакансий не найдено',
          style: TextStyle(fontSize: 16, color: _slate)),
      const SizedBox(height: 6),
      const Text('Попробуйте обновить резюме или добавить больше навыков',
          style: TextStyle(color: _slate, fontSize: 13),
          textAlign: TextAlign.center),
    ]),
  );
}

// ── Match Card ─────────────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});
  final dynamic match;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final percent  = (match['percent'] as num?)?.toInt() ?? 0;
    final reason   = match['reason']  as String? ?? '';
    final vacancy  = match['vacancy'] as Map<String, dynamic>?;
    final employer = vacancy?['employer'] as Map<String, dynamic>?;
    final salaryMin = vacancy?['salaryMin'] as int?;
    final salaryMax = vacancy?['salaryMax'] as int?;
    final city      = vacancy?['city']  as String?;
    final logoUrl   = employer?['logoUrl'] as String?;
    final color     = _percentColor(percent);

    String salary = '';
    if (salaryMin != null && salaryMax != null) {
      salary = '${salaryMin ~/ 1000}–${salaryMax ~/ 1000} тыс.';
    } else if (salaryMin != null) {
      salary = 'от ${salaryMin ~/ 1000} тыс.';
    } else if (salaryMax != null) {
      salary = 'до ${salaryMax ~/ 1000} тыс.';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: cs.surfaceContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: vacancy == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VacancyDetailScreen(
                        vacancyId: vacancy['id'] as String),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Logo
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
                        vacancy?['title'] as String? ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: cs.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        employer?['companyName'] as String? ?? '',
                        style: const TextStyle(color: _slate, fontSize: 12),
                      ),
                    ]),
              ),
              const SizedBox(width: 8),
              // % Badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ]),

            if (salary.isNotEmpty || city != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                if (salary.isNotEmpty) ...[
                  const Icon(Icons.payments_outlined,
                      size: 13, color: Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Text(salary,
                      style: const TextStyle(
                          color: Color(0xFF16A34A), fontSize: 12)),
                  const SizedBox(width: 12),
                ],
                if (city != null) ...[
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: _slate),
                  const SizedBox(width: 4),
                  Text(city,
                      style: const TextStyle(color: _slate, fontSize: 12)),
                ],
              ]),
            ],

            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(reason,
                        style: TextStyle(
                            color: color.withValues(alpha: 0.85),
                            fontSize: 12,
                            height: 1.4)),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
