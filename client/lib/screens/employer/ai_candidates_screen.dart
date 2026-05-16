import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _blue = Color(0xFF2563EB);
const _slate = Color(0xFF64748B);
const _bg = Color(0xFFF8FAFC);

Color _percentColor(int p) {
  if (p >= 70) return const Color(0xFF16A34A);
  if (p >= 40) return Colors.orange;
  return Colors.red;
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class AiCandidatesScreen extends StatefulWidget {
  const AiCandidatesScreen({
    super.key,
    required this.vacancyId,
    required this.vacancyTitle,
  });
  final String vacancyId;
  final String vacancyTitle;

  @override
  State<AiCandidatesScreen> createState() => _AiCandidatesScreenState();
}

class _AiCandidatesScreenState extends State<AiCandidatesScreen> {
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
      final list = await ApiService.aiMatchResumes(_token(), widget.vacancyId);
      if (mounted) setState(() { _matches = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Подходящие кандидаты',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            const Icon(Icons.work_outline_rounded, size: 14, color: _slate),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Вакансия: ${widget.vacancyTitle}',
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
                                _CandidateCard(match: _matches[index]),
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
      const Text('ИИ ищет подходящих кандидатов...',
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
      const Icon(Icons.people_outline_rounded, size: 64, color: _slate),
      const SizedBox(height: 12),
      const Text('Подходящих кандидатов не найдено',
          style: TextStyle(fontSize: 16, color: _slate)),
      const SizedBox(height: 6),
      const Text(
        'В системе пока нет резюме с достаточным % совпадения',
        style: TextStyle(color: _slate, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    ]),
  );
}

// ── Candidate Card ─────────────────────────────────────────────────────────────

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.match});
  final dynamic match;

  @override
  Widget build(BuildContext context) {
    final percent = (match['percent'] as num?)?.toInt() ?? 0;
    final reason  = match['reason']  as String? ?? '';
    final resume  = match['resume']  as Map<String, dynamic>?;
    final seeker  = resume?['seeker'] as Map<String, dynamic>?;
    final color   = _percentColor(percent);

    final firstName = seeker?['firstName'] as String? ?? '';
    final lastName  = seeker?['lastName']  as String? ?? '';
    final city      = seeker?['city']      as String?;
    final photoUrl  = seeker?['photoUrl']  as String?;
    final fullName  = '$firstName $lastName'.trim();
    final jobTitle  = resume?['title'] as String? ?? '';
    final skills    = (resume?['skills'] as List?)?.cast<String>() ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFEFF6FF),
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? 'Кандидат' : fullName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF0F172A)),
                    ),
                    if (jobTitle.isNotEmpty)
                      Text(jobTitle,
                          style: const TextStyle(color: _slate, fontSize: 12)),
                  ]),
            ),
            // % badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

          if (city != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 13, color: _slate),
              const SizedBox(width: 4),
              Text(city, style: const TextStyle(color: _slate, fontSize: 12)),
            ]),
          ],

          if (skills.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: skills.take(5).map((s) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(s,
                    style: const TextStyle(
                        color: _slate, fontSize: 11)),
              )).toList(),
            ),
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
    );
  }
}
