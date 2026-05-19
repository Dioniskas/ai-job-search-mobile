import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'vacancy_detail_screen.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _blue = Color(0xFF2563EB);
const _slate = Color(0xFF64748B);

// ── Status helpers ─────────────────────────────────────────────────────────────

const _statusLabel = {
  'PENDING':  'Ожидает',
  'VIEWED':   'Просмотрено',
  'ACCEPTED': 'Принято',
  'REJECTED': 'Отказ',
};

Color _statusColor(String s) {
  switch (s) {
    case 'ACCEPTED': return const Color(0xFF16A34A);
    case 'REJECTED': return Colors.red;
    case 'VIEWED':   return _blue;
    default:         return _slate;
  }
}

IconData _statusIcon(String s) {
  switch (s) {
    case 'ACCEPTED': return Icons.check_circle_rounded;
    case 'REJECTED': return Icons.cancel_rounded;
    case 'VIEWED':   return Icons.visibility_rounded;
    default:         return Icons.schedule_rounded;
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class SeekerApplicationsScreen extends StatefulWidget {
  const SeekerApplicationsScreen({super.key});

  @override
  State<SeekerApplicationsScreen> createState() =>
      _SeekerApplicationsScreenState();
}

class _SeekerApplicationsScreenState extends State<SeekerApplicationsScreen> {
  List<dynamic> _apps = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _initialized = false;
  int _page = 1;
  int _totalPages = 1;

  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) { _initialized = true; _load(reset: true); }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  AuthProvider get _auth => context.read<AuthProvider>();

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      setState(() { _loading = true; _error = null; });
    }
    try {
      final result = await _auth.withAuth(
          (t) => ApiService.getSeekerApplicationsPage(t, page: _page));
      final list = result['data'] as List<dynamic>;
      final totalPages = (result['totalPages'] as num?)?.toInt() ?? 1;
      if (mounted) {
        setState(() {
          if (reset || _page == 1) {
            _apps = list;
          } else {
            _apps = [..._apps, ...list];
          }
          _totalPages = totalPages;
          _loading = false;
          _loadingMore = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_apps.isEmpty) {
            _error = e is Exception
                ? e.toString().replaceFirst('Exception: ', '')
                : e.toString();
          }
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _totalPages) return;
    _page++;
    setState(() => _loadingMore = true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Мои отклики',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : _error != null
              ? _errorView()
              : _apps.isEmpty
                  ? _emptyView()
                  : RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(12),
                        itemCount: _apps.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _apps.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _blue),
                              ),
                            );
                          }
                          return _AppCard(
                            app: _apps[i],
                            onDeleted: () => setState(() => _apps.removeAt(i)),
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
      const Icon(Icons.send_outlined, size: 64, color: _slate),
      const SizedBox(height: 12),
      const Text('Откликов пока нет',
          style: TextStyle(fontSize: 17, color: _slate)),
      const SizedBox(height: 6),
      const Text('Откликнитесь на вакансии в разделе «Поиск»',
          style: TextStyle(color: _slate, fontSize: 13),
          textAlign: TextAlign.center),
    ]),
  );
}

// ── Application Card ───────────────────────────────────────────────────────────

class _AppCard extends StatefulWidget {
  const _AppCard({required this.app, required this.onDeleted});
  final dynamic app;
  final VoidCallback onDeleted;

  @override
  State<_AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<_AppCard> {
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить отклик?'),
        content: const Text('Отклик будет удалён. Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Нет'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Отменить отклик'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.withAuth((t) =>
          ApiService.deleteApplication(t, widget.app['id'] as String));
      if (mounted) widget.onDeleted();
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final app    = widget.app;
    final status   = app['status'] as String? ?? 'PENDING';
    final vacancy  = app['vacancy'] as Map<String, dynamic>?;
    final employer = vacancy?['employer'] as Map<String, dynamic>?;
    final resume   = app['resume']  as Map<String, dynamic>?;
    final createdAt = app['createdAt'] as String?;
    final color    = _statusColor(status);

    final salaryMin = vacancy?['salaryMin'] as int?;
    final salaryMax = vacancy?['salaryMax'] as int?;
    String salary = '';
    if (salaryMin != null && salaryMax != null) {
      salary = '${salaryMin ~/ 1000}–${salaryMax ~/ 1000} тыс.';
    } else if (salaryMin != null) {
      salary = 'от ${salaryMin ~/ 1000} тыс.';
    }

    String dateStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) dateStr = '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    }

    final logoUrl = employer?['logoUrl'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      color: cs.surfaceContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: vacancy == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        VacancyDetailScreen(vacancyId: vacancy['id'] as String),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFEFF6FF),
                child: logoUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: logoUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SizedBox(
                            width: 40, height: 40,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.business_rounded, color: _blue, size: 18),
                        ),
                      )
                    : const Icon(Icons.business_rounded, color: _blue, size: 18),
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
                      Text(
                        employer?['companyName'] as String? ?? '',
                        style:
                            const TextStyle(color: _slate, fontSize: 12),
                      ),
                    ]),
              ),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_statusIcon(status), size: 13, color: color),
                  const SizedBox(width: 4),
                  Text(
                    _statusLabel[status] ?? status,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ]),
              ),
            ]),

            if (salary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.payments_outlined,
                    size: 13, color: Color(0xFF16A34A)),
                const SizedBox(width: 4),
                Text(salary,
                    style: const TextStyle(
                        color: Color(0xFF16A34A), fontSize: 12)),
              ]),
            ],

            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.description_outlined, size: 13, color: _slate),
              const SizedBox(width: 4),
              Text(
                resume?['title'] as String? ?? 'Резюме',
                style: const TextStyle(color: _slate, fontSize: 12),
              ),
              const Spacer(),
              if (dateStr.isNotEmpty)
                Text(dateStr,
                    style: const TextStyle(color: _slate, fontSize: 11)),
            ]),

            if (status == 'PENDING') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _deleting ? null : _confirmDelete,
                  icon: _deleting
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.close_rounded, size: 16),
                  label: Text(_deleting ? 'Отмена...' : 'Отменить отклик'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],

            // Status explanation
            if (status == 'VIEWED') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.visibility_outlined, size: 13, color: _blue),
                  SizedBox(width: 6),
                  Text('Работодатель просмотрел ваш отклик',
                      style: TextStyle(color: _blue, fontSize: 12)),
                ]),
              ),
            ] else if (status == 'ACCEPTED') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.celebration_rounded,
                      size: 13, color: Color(0xFF16A34A)),
                  SizedBox(width: 6),
                  Text('Поздравляем! Ждите приглашения',
                      style: TextStyle(
                          color: Color(0xFF16A34A), fontSize: 12)),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
