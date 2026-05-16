import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'ai_vacancies_screen.dart';
import 'vacancy_detail_screen.dart';

const _blue  = Color(0xFF2563EB);
const _slate = Color(0xFF64748B);
const _bg    = Color(0xFFF8FAFC);

class SeekerHomeScreen extends StatefulWidget {
  const SeekerHomeScreen({super.key});

  @override
  State<SeekerHomeScreen> createState() => _SeekerHomeScreenState();
}

class _SeekerHomeScreenState extends State<SeekerHomeScreen> {
  List<dynamic> _resumes = [];
  bool _initialized = false;
  int _unreadCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadResumes();
      _loadNotifications();
    }
  }

  AuthProvider get _auth => context.read<AuthProvider>();
  String _token() => _auth.token ?? '';

  Future<void> _loadResumes() async {
    try {
      final list = await _auth.withAuth((t) => ApiService.getResumes(t));
      if (mounted) setState(() => _resumes = list);
    } catch (_) {}
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await _auth.withAuth((t) => ApiService.getNotifications(t));
      if (mounted) {
        setState(() =>
            _unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {}
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _NotificationsSheet(
        token: _token(),
        onRead: () {
          if (mounted) setState(() => _unreadCount = 0);
        },
      ),
    );
  }

  Future<void> _startAiMatch() async {
    // Refresh list in case user created a resume in the Resume tab
    if (_resumes.isEmpty) {
      await _loadResumes();
      if (!mounted) return;
    }
    if (_resumes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Сначала создайте резюме в разделе «Резюме»')),
      );
      return;
    }
    if (_resumes.length == 1) {
      _navigateToMatch(_resumes[0]);
    } else {
      _showResumePicker();
    }
  }

  void _navigateToMatch(dynamic resume) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiVacanciesScreen(
          resumeId:    resume['id'] as String,
          resumeTitle: resume['title'] as String? ?? 'Резюме',
        ),
      ),
    );
  }

  void _showResumePicker() {
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
            const Text('Выберите резюме для подбора',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._resumes.map((r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_rounded,
                    color: _blue, size: 20),
              ),
              title: Text(
                r['title'] as String? ?? 'Резюме',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing:
                  const Icon(Icons.chevron_right_rounded, color: _slate),
              onTap: () {
                Navigator.pop(ctx);
                _navigateToMatch(r);
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = VacancyHistory.items;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Главная',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: _openNotifications,
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Уведомления',
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadResumes();
          await _loadNotifications();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── ИИ-подбор карточка ──────────────────────────────────────────
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
                    const Text('ИИ-подбор вакансий',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 10),
                  const Text(
                    'ИИ проанализирует ваше резюме и найдёт вакансии с наибольшим % совпадения',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.4),
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
                      onPressed: _startAiMatch,
                      child: const Text('Начать подбор',
                          style:
                              TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Предупреждение об отсутствии резюме ─────────────────────────
            if (_resumes.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Создайте резюме, чтобы ИИ подобрал подходящие вакансии',
                      style: TextStyle(
                          color: Colors.orange.shade800, fontSize: 13),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── История просмотров ───────────────────────────────────────────
            if (history.isNotEmpty) ...[
              const Text('Недавно просмотренные',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: history.length,
                  itemBuilder: (context, i) {
                    final v = history[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VacancyDetailScreen(vacancyId: v['id']!),
                        ),
                      ).then((_) => setState(() {})),
                      child: Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              v['title']!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (v['companyName']!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                v['companyName']!,
                                style: const TextStyle(
                                    color: _slate, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Возможности ──────────────────────────────────────────────────
            const Text('Возможности ИИ',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            _featureCard(
              icon: Icons.percent_rounded,
              title: '% совпадения',
              subtitle:
                  'Открывайте вакансии и узнавайте, насколько они подходят вашему резюме',
              color: const Color(0xFF16A34A),
            ),
            const SizedBox(height: 10),
            _featureCard(
              icon: Icons.edit_note_rounded,
              title: 'Сопроводительное письмо',
              subtitle:
                  'ИИ напишет персонализированное письмо при отклике на вакансию',
              color: Colors.purple,
            ),
            const SizedBox(height: 10),
            _featureCard(
              icon: Icons.payments_outlined,
              title: 'Рыночная зарплата',
              subtitle:
                  'Узнайте, сколько платят за вашу специализацию в Ташкенте',
              color: Colors.teal,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _featureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: _slate, fontSize: 12, height: 1.4)),
            ]),
          ),
        ]),
      );
}

// ── Notifications Bottom Sheet ─────────────────────────────────────────────────

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet({required this.token, required this.onRead});
  final String token;
  final VoidCallback onRead;

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
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
              ? const Center(
                  child: CircularProgressIndicator(color: _blue))
              : _notifications.isEmpty
                  ? const Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 56, color: _slate),
                        SizedBox(height: 12),
                        Text('Уведомлений нет',
                            style:
                                TextStyle(color: _slate, fontSize: 16)),
                      ]))
                  : ListView.separated(
                      controller: scroll,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _notifications.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final n      = _notifications[i];
                        final isRead = n['isRead']    as bool?   ?? false;
                        final text   = n['text']      as String? ?? '';
                        final type   = n['type']      as String? ?? '';
                        final createdAt = n['createdAt'] as String?;

                        String dateStr = '';
                        if (createdAt != null) {
                          final dt = DateTime.tryParse(createdAt);
                          if (dt != null) {
                            final local = dt.toLocal();
                            dateStr =
                                '${local.day}.${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
                          }
                        }

                        final icon  = _notifIcon(type);
                        final color = _notifColor(type);

                        return Container(
                          color: isRead
                              ? Colors.transparent
                              : _blue.withValues(alpha: 0.04),
                          child: ListTile(
                            leading: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color, size: 18),
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

  IconData _notifIcon(String type) {
    switch (type) {
      case 'NEW_APPLICATION':    return Icons.send_rounded;
      case 'APPLICATION_STATUS': return Icons.work_outline_rounded;
      default:                   return Icons.notifications_rounded;
    }
  }

  Color _notifColor(String type) {
    switch (type) {
      case 'NEW_APPLICATION':    return _blue;
      case 'APPLICATION_STATUS': return const Color(0xFF16A34A);
      default:                   return _slate;
    }
  }
}
