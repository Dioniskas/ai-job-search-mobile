import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

const _blue  = Color(0xFF2563EB);
const _green = Color(0xFF16A34A);
const _slate = Color(0xFF64748B);

class EmployerHomeScreen extends StatefulWidget {
  const EmployerHomeScreen({super.key});

  @override
  State<EmployerHomeScreen> createState() => _EmployerHomeScreenState();
}

class _EmployerHomeScreenState extends State<EmployerHomeScreen> {
  bool _initialized = false;
  int _unreadCount = 0;
  int _vacancyCount = 0;
  int _appCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) { _initialized = true; _load(); }
  }

  AuthProvider get _auth => context.read<AuthProvider>();
  String _token() => _auth.token ?? '';

  Future<void> _load() async {
    try {
      final results = await _auth.withAuth<List<dynamic>>(
        (t) => Future.wait<dynamic>([
          ApiService.getNotifications(t),
          ApiService.getEmployerVacancies(t),
          ApiService.getEmployerApplications(t),
        ]),
      );
      if (!mounted) return;
      final notifData = results[0] as Map<String, dynamic>;
      final vacancies = results[1] as List<dynamic>;
      final apps      = results[2] as List<dynamic>;
      setState(() {
        _unreadCount  = (notifData['unreadCount'] as num?)?.toInt() ?? 0;
        _vacancyCount = vacancies.length;
        _appCount     = apps.length;
      });
    } catch (_) {}
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EmployerNotifSheet(
        token: _token(),
        onRead: () { if (mounted) setState(() => _unreadCount = 0); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Главная',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        actions: [
          Stack(children: [
            IconButton(
              onPressed: _openNotifications,
              icon: const Icon(Icons.notifications_outlined),
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    _unreadCount > 9 ? '9+' : '$_unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ]),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Stats
            Row(children: [
              Expanded(
                child: _statCard(
                  icon: Icons.work_rounded,
                  label: 'Вакансии',
                  value: '$_vacancyCount',
                  color: _blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  icon: Icons.send_rounded,
                  label: 'Отклики',
                  value: '$_appCount',
                  color: _green,
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // Tips card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Text('Советы',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const SizedBox(height: 10),
                  ...[
                    '• Используйте ИИ-подбор для поиска кандидатов по вакансии',
                    '• Отвечайте на отклики быстро — кандидаты ценят скорость',
                    '• Добавляйте зарплату — вакансии с зарплатой получают больше откликов',
                    '• Укажите адрес, чтобы вакансия отображалась на карте',
                  ].map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(t,
                        style: const TextStyle(
                            color: _slate, fontSize: 13, height: 1.4)),
                  )),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: const TextStyle(color: _slate, fontSize: 12)),
          ]),
        ]),
      );
}

// ── Employer Notifications Sheet ──────────────────────────────────────────────

class _EmployerNotifSheet extends StatefulWidget {
  const _EmployerNotifSheet({required this.token, required this.onRead});
  final String token;
  final VoidCallback onRead;

  @override
  State<_EmployerNotifSheet> createState() => _EmployerNotifSheetState();
}

class _EmployerNotifSheetState extends State<_EmployerNotifSheet> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getNotifications(widget.token);
      final list = data['notifications'] as List<dynamic>? ?? [];
      if (mounted) setState(() { _notifications = list; _loading = false; });
      await ApiService.markNotificationsRead(widget.token);
      widget.onRead();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => Column(children: [
        const SizedBox(height: 12),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Icon(Icons.notifications_rounded, color: _blue, size: 22),
            SizedBox(width: 8),
            Text('Уведомления',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _blue))
              : _notifications.isEmpty
                  ? const Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 56, color: _slate),
                        SizedBox(height: 12),
                        Text('Уведомлений нет',
                            style: TextStyle(color: _slate, fontSize: 16)),
                      ]))
                  : ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _notifications.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final n      = _notifications[i];
                        final isRead = n['isRead'] as bool?   ?? false;
                        final text   = n['text']   as String? ?? '';
                        final createdAt = n['createdAt'] as String?;

                        String dateStr = '';
                        if (createdAt != null) {
                          final dt = DateTime.tryParse(createdAt);
                          if (dt != null) {
                            final local = dt.toLocal();
                            dateStr = '${local.day}.${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
                          }
                        }

                        return Container(
                          color: isRead
                              ? Colors.transparent
                              : _blue.withValues(alpha: 0.04),
                          child: ListTile(
                            leading: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: _blue.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.send_rounded,
                                  color: _blue, size: 18),
                            ),
                            title: Text(text,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isRead
                                        ? FontWeight.normal
                                        : FontWeight.w600)),
                            subtitle: dateStr.isNotEmpty
                                ? Text(dateStr,
                                    style: const TextStyle(
                                        fontSize: 11, color: _slate))
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
