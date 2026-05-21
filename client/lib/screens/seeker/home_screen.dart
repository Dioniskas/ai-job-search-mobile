import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'ai_vacancies_screen.dart';
import 'interview_prep_screen.dart';
import 'vacancy_detail_screen.dart';

const _blue  = Color(0xFF2563EB);
const _slate = Color(0xFF64748B);

class SeekerHomeScreen extends StatefulWidget {
  const SeekerHomeScreen({super.key});

  @override
  State<SeekerHomeScreen> createState() => _SeekerHomeScreenState();
}

class _SeekerHomeScreenState extends State<SeekerHomeScreen> {
  List<dynamic> _resumes = [];
  bool _initialized = false;
  int _unreadCount = 0;
  int _applicationsCount = 0;
  int _pendingCount = 0;
  String _firstName = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadResumes();
      _loadNotifications();
      _loadApplicationStats();
      _loadProfile();
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

  Future<void> _loadProfile() async {
    try {
      final data = await _auth.withAuth((t) => ApiService.getSeekerProfile(t));
      if (mounted) setState(() => _firstName = data['firstName'] as String? ?? '');
    } catch (_) {}
  }

  Future<void> _loadApplicationStats() async {
    try {
      final list = await _auth.withAuth((t) => ApiService.getSeekerApplications(t));
      if (mounted) {
        setState(() {
          _applicationsCount = list.length;
          _pendingCount = list.where((a) => a['status'] == 'PENDING').length;
        });
      }
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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

  Map<String, dynamic>? get _mainResume {
    for (final r in _resumes) {
      if (r['isMain'] == true) return r;
    }
    return _resumes.isNotEmpty ? _resumes.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final main = _mainResume;
    final activity = (_pendingCount / 10).clamp(0.0, 1.0);
    final activityPct = (_pendingCount * 10).clamp(0, 100);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Карьера',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Color(0xFF1C1C1E))),
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadResumes();
          await _loadNotifications();
          await _loadApplicationStats();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── 1. Карьерные инструменты ─────────────────────────────
                const Text('Карьерные инструменты',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E))),
                const SizedBox(height: 12),

                // Большая карточка AI-подбора
                GestureDetector(
                  onTap: _startAiMatch,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: _blue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Подбор вакансий Ассистентом',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1C1C1E))),
                      ),
                      if (_resumes.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${_resumes.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFFC7C7CC)),
                    ]),
                  ),
                ),

                const SizedBox(height: 8),

                // Два блока рядом
                Row(children: [
                  Expanded(
                    child: _ToolTile(
                      icon: Icons.mic_outlined,
                      label: 'Подготовка к интервью',
                      color: const Color(0xFF7C3AED),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const InterviewPrepScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ToolTile(
                      icon: Icons.bar_chart_rounded,
                      label: 'Аналитика откликов',
                      color: const Color(0xFF16A34A),
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Скоро будет доступно')),
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 24),
                const Text('Быстрые действия',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E))),
                const SizedBox(height: 12),
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _QuickActionCard(
                          icon: Icons.phone_outlined,
                          label: 'Звонки через приложение',
                          color: const Color(0xFF2563EB)),
                      const SizedBox(width: 10),
                      _QuickActionCard(
                          icon: Icons.arrow_upward_rounded,
                          label: 'Поднять резюме в поиске',
                          color: const Color(0xFF16A34A)),
                      const SizedBox(width: 10),
                      _QuickActionCard(
                          icon: Icons.location_on_outlined,
                          label: 'Вакансии рядом с вами',
                          color: const Color(0xFFF97316)),
                      const SizedBox(width: 10),
                      _QuickActionCard(
                          icon: Icons.star_outline_rounded,
                          label: 'Оценить место работы',
                          color: const Color(0xFF7C3AED)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── 2. Моё резюме ────────────────────────────────────────
                if (main != null) ...[
                  const Text('Моё основное резюме',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1C1E))),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            main['title'] as String? ?? 'Резюме',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1C1C1E)),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            _ResumeStatBadge(
                                value: '$_applicationsCount',
                                label: 'откликов'),
                            const SizedBox(width: 8),
                            _ResumeStatBadge(
                                value: '$_pendingCount',
                                label: 'ожидают'),
                          ]),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _startAiMatch,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                              child: const Text(
                                  'Посмотреть подходящие вакансии'),
                            ),
                          ),
                        ]),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── 3. Активность ────────────────────────────────────────
                const Text('Ваша активность',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E))),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Активность',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF8E8E93))),
                              Text('$activityPct%',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1C1C1E))),
                            ]),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: activity,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFE5E5EA),
                            valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF007AFF)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Откликайтесь на вакансии чтобы повысить активность',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF8E8E93)),
                        ),
                      ]),
                ),
                const SizedBox(height: 24),

                // ── 4. Советы ────────────────────────────────────────────
                const Text('Полезные советы',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E))),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      _TipCard(title: 'Как составить резюме'),
                      SizedBox(width: 10),
                      _TipCard(title: 'Как пройти интервью'),
                      SizedBox(width: 10),
                      _TipCard(title: 'Как повысить зарплату'),
                    ],
                  ),
                ),
              ]),
        ),
      ),
    );
  }
}

// ── Tool Tile ─────────────────────────────────────────────────────────────────

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1C1C1E))),
          ],
        ),
      ),
    );
  }
}

// ── Resume Stat Badge ─────────────────────────────────────────────────────────

class _ResumeStatBadge extends StatelessWidget {
  const _ResumeStatBadge({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$value $label',
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF8E8E93))),
    );
  }
}

// ── Tip Card ──────────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  const _TipCard({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              color: Color(0xFF8E8E93), size: 20),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E))),
        ],
      ),
    );
  }
}

// ── Greeting Card ─────────────────────────────────────────────────────────────

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.firstName, required this.cs});
  final String firstName;
  final ColorScheme cs;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Доброе утро';
    if (h < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  @override
  Widget build(BuildContext context) {
    final name = firstName.isNotEmpty ? ', $firstName' : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2563EB).withValues(alpha: 0.08),
            const Color(0xFF1D4ED8).withValues(alpha: 0.04),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.waving_hand_rounded,
              color: Color(0xFF2563EB), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$_greeting$name!',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
            const SizedBox(height: 2),
            Text('Ваш поиск работы продолжается',
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
          ]),
        ),
      ]),
    );
  }
}

// ── Stat Chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.cs,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
        Text(label,
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
      ]),
    );
  }
}

// ── Quick Action Card ─────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Скоро будет доступно')),
      ),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF8E8E93))),
          ],
        ),
      ),
    );
  }
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
