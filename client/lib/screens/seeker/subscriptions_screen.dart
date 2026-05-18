import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _blue  = Color(0xFF2563EB);
const _slate = Color(0xFF64748B);

const _empTypes = [
  ('FULL_TIME',   'Полная занятость'),
  ('PART_TIME',   'Частичная'),
  ('REMOTE',      'Удалённо'),
  ('CONTRACT',    'Контракт'),
  ('INTERNSHIP',  'Стажировка'),
];

// ── Screen ─────────────────────────────────────────────────────────────────────

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  List<dynamic> _subs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _token() => context.read<AuthProvider>().token ?? '';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getSubscriptions(_token());
      if (mounted) setState(() { _subs = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await ApiService.deleteSubscription(_token(), id);
      setState(() => _subs.removeWhere((s) => s['id'] == id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showAddDialog() {
    final queryCtrl = TextEditingController();
    final cityCtrl  = TextEditingController();
    final salaryCtrl = TextEditingController();
    String? selectedEmp;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Новая подписка'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: queryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ключевое слово (необяз.)',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Город (необяз.)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: salaryCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Зарплата от (UZS, необяз.)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedEmp,
                decoration: const InputDecoration(
                  labelText: 'Тип занятости (необяз.)',
                ),
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('Любой')),
                  ..._empTypes.map((e) => DropdownMenuItem(
                      value: e.$1, child: Text(e.$2))),
                ],
                onChanged: (v) => setDlg(() => selectedEmp = v),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final q        = queryCtrl.text.trim();
                  final c        = cityCtrl.text.trim();
                  final salaryInt = salaryCtrl.text.trim().isEmpty
                      ? null
                      : int.tryParse(salaryCtrl.text.trim());
                  final body = <String, dynamic>{};
                  if (q.isNotEmpty)          body['query']          = q;
                  if (c.isNotEmpty)          body['city']           = c;
                  if (salaryInt != null)     body['salaryMin']      = salaryInt;
                  if (selectedEmp != null)   body['employmentType'] = selectedEmp;
                  await ApiService.createSubscription(_token(), body);
                  _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('Создать'),
            ),
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
        title: const Text('Автопоиск',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Добавить подписку',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : Column(children: [
              Container(
                color: cs.surface,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: const Text(
                  'Вы будете получать уведомления о новых вакансиях по заданным параметрам',
                  style: TextStyle(color: _slate, fontSize: 13),
                ),
              ),
              Expanded(
                child: _subs.isEmpty
                    ? _emptyView()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _subs.length,
                        itemBuilder: (context, i) =>
                            _SubCard(sub: _subs[i],
                                onDelete: () =>
                                    _delete(_subs[i]['id'] as String)),
                      ),
              ),
            ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.notifications_active_rounded),
        label: const Text('Добавить подписку'),
      ),
    );
  }

  Widget _emptyView() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.notifications_none_rounded, size: 64, color: _slate),
      const SizedBox(height: 12),
      const Text('Нет подписок',
          style: TextStyle(fontSize: 17, color: _slate)),
      const SizedBox(height: 6),
      const Text('Создайте подписку, чтобы получать новые вакансии',
          style: TextStyle(color: _slate, fontSize: 13),
          textAlign: TextAlign.center),
    ]),
  );
}

// ── Subscription Card ──────────────────────────────────────────────────────────

class _SubCard extends StatelessWidget {
  const _SubCard({required this.sub, required this.onDelete});
  final dynamic sub;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query   = sub['query']          as String?;
    final city    = sub['city']           as String?;
    final salary  = sub['salaryMin']      as int?;
    final empType = sub['employmentType'] as String?;

    final chips = <String>[];
    if (query   != null && query.isNotEmpty)   chips.add('🔍 $query');
    if (city    != null && city.isNotEmpty)    chips.add('📍 $city');
    if (salary  != null)                       chips.add('💰 от ${salary ~/ 1000} тыс.');
    if (empType != null && empType.isNotEmpty) {
      const labels = {
        'FULL_TIME':  'Полная занятость',
        'PART_TIME':  'Частичная',
        'REMOTE':     'Удалённо',
        'CONTRACT':   'Контракт',
        'INTERNSHIP': 'Стажировка',
      };
      chips.add('💼 ${labels[empType] ?? empType}');
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
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_active_rounded,
                color: _blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: chips.isEmpty
                ? const Text('Все вакансии',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14))
                : Wrap(
                    spacing: 6, runSpacing: 4,
                    children: chips.map((c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(c,
                          style: const TextStyle(
                              fontSize: 12, color: _blue)),
                    )).toList(),
                  ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.red, size: 20),
            tooltip: 'Удалить',
          ),
        ]),
      ),
    );
  }
}
