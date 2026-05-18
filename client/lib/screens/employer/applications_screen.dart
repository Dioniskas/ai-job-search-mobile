import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _blue  = Color(0xFF2563EB);
const _green = Color(0xFF16A34A);
const _slate = Color(0xFF64748B);

const _statusLabels = {
  'PENDING':  'Ожидает',
  'VIEWED':   'Просмотрено',
  'ACCEPTED': 'Принят',
  'REJECTED': 'Отказ',
};

Color _statusColor(String s) {
  switch (s) {
    case 'ACCEPTED': return _green;
    case 'REJECTED': return Colors.red;
    case 'VIEWED':   return _blue;
    default:         return _slate;
  }
}

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

class EmployerApplicationsScreen extends StatefulWidget {
  const EmployerApplicationsScreen({super.key});

  @override
  State<EmployerApplicationsScreen> createState() =>
      _EmployerApplicationsScreenState();
}

class _EmployerApplicationsScreenState
    extends State<EmployerApplicationsScreen> {
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
          (t) => ApiService.getEmployerApplicationsPage(t, page: _page));
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

  Future<void> _changeStatus(String appId, String newStatus) async {
    try {
      await _auth.withAuth((t) => ApiService.updateApplicationStatus(t, appId, newStatus));
      _load(reset: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Отклики',
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
                            onChangeStatus: (s) =>
                                _changeStatus(_apps[i]['id'] as String, s),
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
      const Icon(Icons.inbox_outlined, size: 64, color: _slate),
      const SizedBox(height: 12),
      const Text('Откликов пока нет',
          style: TextStyle(fontSize: 17, color: _slate)),
      const SizedBox(height: 6),
      const Text('Соискатели ещё не откликались на ваши вакансии',
          style: TextStyle(color: _slate, fontSize: 13),
          textAlign: TextAlign.center),
    ]),
  );
}

// ── Application Card ───────────────────────────────────────────────────────────

class _AppCard extends StatelessWidget {
  const _AppCard({required this.app, required this.onChangeStatus});
  final dynamic app;
  final void Function(String) onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status   = app['status']  as String? ?? 'PENDING';
    final vacancy  = app['vacancy'] as Map<String, dynamic>?;
    final resume   = app['resume']  as Map<String, dynamic>?;
    final seeker   = resume?['seeker'] as Map<String, dynamic>?;
    final color    = _statusColor(status);
    final coverLetter = app['coverLetter'] as String?;
    final createdAt   = app['createdAt']  as String?;

    final firstName    = seeker?['firstName'] as String? ?? '';
    final lastName     = seeker?['lastName']  as String? ?? '';
    final city         = seeker?['city']      as String?;
    final photoUrl     = seeker?['photoUrl']  as String?;
    final searchStatus = seeker?['searchStatus'] as String? ?? 'ACTIVE';
    final fullName     = '$firstName $lastName'.trim();

    String dateStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) dateStr = '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: cs.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header: seeker info + status badge
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFEFF6FF),
              child: photoUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(
                          width: 44, height: 44,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                        errorWidget: (_, __, ___) => Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: _blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                    )
                  : Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? 'Кандидат' : fullName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: cs.onSurface),
                    ),
                    Row(children: [
                      Text(
                        resume?['title'] as String? ?? 'Резюме',
                        style: const TextStyle(color: _slate, fontSize: 12),
                      ),
                      if (city != null) ...[
                        const Text(' · ',
                            style: TextStyle(color: _slate, fontSize: 12)),
                        Text(city,
                            style:
                                const TextStyle(color: _slate, fontSize: 12)),
                      ],
                    ]),
                  ]),
            ),
            // Status badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabels[status] ?? status,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ]),

          const SizedBox(height: 8),

          // Vacancy + search status
          Row(children: [
            const Icon(Icons.work_outline_rounded, size: 13, color: _slate),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                vacancy?['title'] as String? ?? '',
                style: const TextStyle(color: _slate, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _searchStatusColor(searchStatus).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _searchStatusLabel[searchStatus] ?? searchStatus,
                style: TextStyle(
                    color: _searchStatusColor(searchStatus),
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),

          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Дата отклика: $dateStr',
                style: const TextStyle(color: _slate, fontSize: 11)),
          ],

          // Cover letter preview
          if (coverLetter != null && coverLetter.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Сопроводительное письмо',
                    style: TextStyle(
                        fontSize: 11,
                        color: _slate,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  coverLetter.length > 200
                      ? '${coverLetter.substring(0, 200)}...'
                      : coverLetter,
                  style:
                      TextStyle(color: cs.onSurface, fontSize: 12),
                ),
              ]),
            ),
          ],

          // Action buttons
          if (status == 'PENDING' || status == 'VIEWED') ...[
            const SizedBox(height: 10),
            Row(children: [
              if (status == 'PENDING')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onChangeStatus('VIEWED'),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('Просмотрено', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: _blue),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              if (status == 'PENDING') const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onChangeStatus('ACCEPTED'),
                  icon: const Icon(Icons.check_rounded, size: 15),
                  label: const Text('Принять', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onChangeStatus('REJECTED'),
                  icon: const Icon(Icons.close_rounded, size: 15),
                  label: const Text('Отказать', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
