import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  String? _filterStatus;

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

  List<dynamic> get _filteredApps {
    if (_filterStatus == null) return _apps;
    return _apps
        .where((a) => (a['status'] as String?) == _filterStatus)
        .toList();
  }

  static const _chips = [
    (null, 'Все'),
    ('VIEWED', 'Собеседование'),
    ('PENDING', 'Ожидание'),
    ('REJECTED', 'Отказ'),
    ('ACCEPTED', 'Архив'),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredApps;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text('Отклики',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1C1E))),
            ),
            // Filter chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _chips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (value, label) = _chips[i];
                  final active = _filterStatus == value;
                  return GestureDetector(
                    onTap: () => setState(() => _filterStatus = value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF1C1C1E)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? const Color(0xFF1C1C1E)
                              : const Color(0xFFD1D1D6),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: active
                              ? Colors.white
                              : const Color(0xFF1C1C1E),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Body
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _blue))
                  : _error != null
                      ? _errorView()
                      : filtered.isEmpty
                          ? _emptyView()
                          : RefreshIndicator(
                              onRefresh: () => _load(reset: true),
                              child: ListView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 16),
                                itemCount:
                                    filtered.length + (_loadingMore ? 1 : 0),
                                itemBuilder: (context, i) {
                                  if (i == filtered.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 16),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: _blue),
                                      ),
                                    );
                                  }
                                  final app = filtered[i];
                                  return _AppCard(
                                    app: app,
                                    onDeleted: () => setState(
                                        () => _apps.remove(app)),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: _slate),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: _load, child: const Text('Повторить')),
              ]),
        ),
      );

  Widget _emptyView() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Сейчас тут пусто',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E))),
                const SizedBox(height: 8),
                const Text(
                  'Загляните в подборку вакансий для вас — там есть на что посмотреть',
                  style: TextStyle(fontSize: 14, color: _slate),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go('/seeker'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Искать вакансии',
                      style: TextStyle(fontSize: 15)),
                ),
              ]),
        ),
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
    final app = widget.app;
    final status = app['status'] as String? ?? 'PENDING';
    final vacancy = app['vacancy'] as Map<String, dynamic>?;
    final employer = vacancy?['employer'] as Map<String, dynamic>?;
    final createdAt = app['createdAt'] as String?;
    final color = _statusColor(status);

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
      if (dt != null) {
        dateStr =
            '${dt.day} ${_monthShort(dt.month)}';
      }
    }

    final logoUrl = employer?['logoUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: vacancy == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VacancyDetailScreen(
                        vacancyId: vacancy['id'] as String),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Logo
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: logoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: logoUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: Icon(Icons.business_rounded,
                                  color: _slate, size: 20),
                            ),
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.business_rounded,
                                  color: _slate, size: 20),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.business_rounded,
                                color: _slate, size: 20),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Title + company
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vacancy?['title'] as String? ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF1C1C1E)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            employer?['companyName'] as String? ?? '',
                            style: const TextStyle(
                                color: _slate, fontSize: 13),
                          ),
                          if (salary.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(salary,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1C1C1E))),
                          ],
                        ]),
                  ),
                  const SizedBox(width: 8),
                  // Date + badge column
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (dateStr.isNotEmpty)
                          Text(dateStr,
                              style: const TextStyle(
                                  fontSize: 12, color: _slate)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_statusIcon(status),
                                size: 12, color: color),
                            const SizedBox(width: 3),
                            Text(
                              _statusLabel[status] ?? status,
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11),
                            ),
                          ]),
                        ),
                      ]),
                ]),

                // Cancel button for PENDING
                if (status == 'PENDING') ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFE5E5EA)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _deleting ? null : _confirmDelete,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 0, vertical: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _deleting
                          ? const Row(mainAxisSize: MainAxisSize.min, children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.red),
                              ),
                              SizedBox(width: 6),
                              Text('Отмена...'),
                            ])
                          : const Text('Отменить отклик'),
                    ),
                  ),
                ],
              ]),
        ),
      ),
    );
  }

  String _monthShort(int m) {
    const months = [
      '', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    return m >= 1 && m <= 12 ? months[m] : '';
  }
}
