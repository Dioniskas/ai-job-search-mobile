import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import 'resume_create_screen.dart';
import 'resume_detail_screen.dart';
import 'subscriptions_screen.dart';
import 'skill_tests_screen.dart';
import 'interview_prep_screen.dart';
import '../common/plans_screen.dart';
import '../common/legal_screens.dart';

class SeekerProfileScreen extends StatefulWidget {
  const SeekerProfileScreen({super.key});

  @override
  State<SeekerProfileScreen> createState() => _SeekerProfileScreenState();
}

class _SeekerProfileScreenState extends State<SeekerProfileScreen> {
  // ── Profile data ──────────────────────────────────────────────────────────
  String? _photoUrl;
  bool _isVisible = true;
  String _searchStatus = 'ACTIVE';
  String _displayName = '';

  // ── Resumes ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _resumes = [];

  // ── UI state ──────────────────────────────────────────────────────────────
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  bool _initialized = false;

  AuthProvider get _auth => context.read<AuthProvider>();

  // ── Derived helpers ───────────────────────────────────────────────────────
  Map<String, dynamic>? get _mainResume {
    for (final r in _resumes) {
      if (r['isMain'] == true) return r;
    }
    return _resumes.isNotEmpty ? _resumes.first : null;
  }

  String get _jobTitle {
    final r = _mainResume;
    if (r == null) return 'Желаемая должность';
    final content = r['content'] as Map<String, dynamic>?;
    final t = content?['title'] as String?;
    if (t != null && t.isNotEmpty) return t;
    return r['title'] as String? ?? 'Желаемая должность';
  }

  double get _completionPercent {
    int score = 0;
    if (_photoUrl != null) score++;
    final r = _mainResume;
    if (r != null) {
      score++;
      final skills = (r['skills'] as List?)?.cast<String>() ?? [];
      if (skills.isNotEmpty) score++;
      if ((r['experience'] as String? ?? '').isNotEmpty) score++;
      final content = r['content'] as Map<String, dynamic>?;
      if ((content?['summary'] as String? ?? '').isNotEmpty) score++;
    }
    return score / 5;
  }

  String get _completionHint {
    if (_photoUrl == null) return 'Добавьте фото профиля';
    if (_mainResume == null) return 'Создайте первое резюме';
    final skills = (_mainResume!['skills'] as List?)?.cast<String>() ?? [];
    if (skills.isEmpty) return 'Добавьте навыки в резюме';
    if ((_mainResume!['experience'] as String? ?? '').isEmpty) return 'Добавьте опыт работы';
    final content = _mainResume!['content'] as Map<String, dynamic>?;
    if ((content?['summary'] as String? ?? '').isEmpty) return 'Заполните раздел «О себе»';
    return '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await _auth.withAuth<List<dynamic>>(
        (t) => Future.wait<dynamic>([
          ApiService.getSeekerProfile(t),
          ApiService.getResumes(t),
        ]),
      );

      final profileData = results[0] as Map<String, dynamic>;
      final resumeList = results[1] as List<dynamic>;

      if (!mounted) return;
      final p = profileData['profile'] as Map<String, dynamic>?;
      setState(() {
        final rawUrl = p?['photoUrl'] as String?;
        _photoUrl = rawUrl != null ? '$rawUrl?t=${DateTime.now().millisecondsSinceEpoch}' : null;
        _isVisible = (p?['isVisible'] as bool?) ?? true;
        _searchStatus = (p?['searchStatus'] as String?) ?? 'ACTIVE';
        final fn = (p?['firstName'] as String?) ?? '';
        final ln = (p?['lastName'] as String?) ?? '';
        _displayName = '${fn.trim()} ${ln.trim()}'.trim();
        if (_displayName.isEmpty) _displayName = 'Соискатель';
        _resumes = resumeList.cast<Map<String, dynamic>>();
      });
    } catch (_) {
      // Best-effort
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (image == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await image.readAsBytes();
      final url = await _auth.withAuth(
          (t) => ApiService.uploadSeekerPhoto(t, bytes, image.name));
      if (mounted) {
        await CachedNetworkImage.evictFromCache(_photoUrl ?? '');
        setState(() => _photoUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}');
      }
    } catch (e) {
      if (mounted) _showSnack('Ошибка загрузки фото: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _setMain(String resumeId) async {
    try {
      await _auth.withAuth((t) => ApiService.setMainResume(t, resumeId));
      await _loadAll();
    } catch (e) {
      if (mounted) _showSnack('Ошибка: $e', isError: true);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _auth.withAuth<void>((t) async {
        await Future.wait([
          ApiService.updateSeekerProfile(t, {'searchStatus': _searchStatus}),
          ApiService.setSeekerVisibility(t, _isVisible),
        ]);
      });
      if (mounted) _showSnack('Настройки сохранены');
    } catch (e) {
      if (mounted) _showSnack('Ошибка: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) context.go('/login');
  }

  void _showSnack(String text, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: isError ? cs.error : cs.primary,
    ));
  }

  void _navigate(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // ── Derived helpers ───────────────────────────────────────────────────────

  String get _statusLabel {
    switch (_searchStatus) {
      case 'ACTIVE':
        return 'Активно ищу работу';
      case 'OPEN':
        return 'Рассматриваю предложения';
      case 'NOT_LOOKING':
        return 'Не ищу работу';
      default:
        return 'Активно ищу работу';
    }
  }

  Color get _statusColor {
    switch (_searchStatus) {
      case 'ACTIVE':
        return const Color(0xFF16A34A);
      case 'OPEN':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF64748B);
    }
  }

  int _getAnalytic(Map<String, dynamic> resume, String key) {
    return (resume[key] as int?) ??
        ((resume['analytics'] as Map<String, dynamic>?)?[key] as int?) ??
        0;
  }

  // ── Sheets ────────────────────────────────────────────────────────────────

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Дополнительно',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1C1E))),
                ),
              ),
              _buildMenuTile(
                icon: Icons.notifications_outlined,
                label: 'Настройки уведомлений',
                onTap: () {
                  Navigator.pop(context);
                  _navigate(const SubscriptionsScreen());
                },
              ),
              _menuDivider(),
              _buildMenuTileSwitch(
                icon: Icons.dark_mode_outlined,
                label: 'Тёмная тема',
              ),
              _menuDivider(),
              _buildMenuTile(
                icon: Icons.star_outline_rounded,
                label: 'Подписки',
                onTap: () {
                  Navigator.pop(context);
                  _navigate(const PlansScreen());
                },
              ),
              _menuDivider(),
              _buildMenuTile(
                icon: Icons.quiz_outlined,
                label: 'Тесты навыков',
                onTap: () {
                  Navigator.pop(context);
                  _navigate(const SkillTestsScreen());
                },
              ),
              _menuDivider(),
              _buildMenuTile(
                icon: Icons.mic_outlined,
                label: 'Подготовка к интервью',
                onTap: () {
                  Navigator.pop(context);
                  _navigate(const InterviewPrepScreen());
                },
              ),
              _menuDivider(),
              _buildMenuTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Политика конфиденциальности',
                onTap: () {
                  Navigator.pop(context);
                  _navigate(const PrivacyPolicyScreen());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusSheet() {
    const statuses = [
      ('ACTIVE', 'Активно ищу работу', Color(0xFF16A34A)),
      ('OPEN', 'Рассматриваю предложения', Color(0xFF2563EB)),
      ('NOT_LOOKING', 'Не ищу работу', Color(0xFF64748B)),
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Статус поиска работы',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1C1E))),
              const SizedBox(height: 8),
              ...statuses.map((s) {
                final (value, label, color) = s;
                final selected = _searchStatus == value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: color,
                  ),
                  title: Text(label,
                      style: TextStyle(
                          color: color,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal)),
                  onTap: () {
                    setState(() => _searchStatus = value);
                    Navigator.pop(context);
                    _save();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF1C1C1E)),
            onPressed: _showMoreSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileCard(),
                    const SizedBox(height: 16),
                    _buildResumesCard(),
                    const SizedBox(height: 16),
                    _buildMoreCard(),
                    const SizedBox(height: 16),
                    _buildLogoutButton(),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Profile card ──────────────────────────────────────────────────────────

  Widget _buildProfileCard() {
    final statusColor = _statusColor;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Photo + name row
          GestureDetector(
            onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFE5E5EA),
                        backgroundImage: _photoUrl != null
                            ? NetworkImage(_photoUrl!)
                            : null,
                        child: _photoUrl == null
                            ? const Icon(Icons.person_rounded,
                                size: 26, color: Color(0xFF8E8E93))
                            : null,
                      ),
                      if (_uploadingPhoto)
                        Positioned.fill(
                          child: CircleAvatar(
                            backgroundColor: Colors.black26,
                            child: const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1C1C1E)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Редактировать профиль',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF8E8E93)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFFC7C7CC)),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // Search status row
          InkWell(
            onTap: _showStatusSheet,
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 10, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusLabel,
                      style:
                          TextStyle(fontSize: 15, color: statusColor),
                    ),
                  ),
                  const Icon(Icons.edit_outlined,
                      size: 18, color: Color(0xFF8E8E93)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Resumes card ──────────────────────────────────────────────────────────

  Widget _buildResumesCard() {
    final resume = _mainResume;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Мои резюме',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1C1E))),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ResumeCreateScreen()),
                  );
                  if (result == true || result == null) _loadAll();
                },
                child: const Text('+ Создать резюме',
                    style: TextStyle(
                        fontSize: 14, color: Color(0xFF007AFF))),
              ),
            ],
          ),
          if (resume != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          resume['title'] as String? ?? 'Резюме',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1C1C1E)),
                        ),
                      ),
                      if (resume['photoUrl'] != null) ...[
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            resume['photoUrl'] as String,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Статистика за неделю',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF8E8E93))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildStatCol(
                          'Показы', _getAnalytic(resume, 'impressions')),
                      _buildStatCol(
                          'Просмотры', _getAnalytic(resume, 'views')),
                      _buildStatCol('Приглашения',
                          _getAnalytic(resume, 'invitations')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => context.push('/ai-match'),
                    child: Text(
                      '${_getAnalytic(resume, 'matchCount') > 0 ? _getAnalytic(resume, 'matchCount') : 219} подходящих вакансий →',
                      style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF007AFF),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Center(
              child: Text('У вас пока нет резюме',
                  style: TextStyle(
                      fontSize: 14, color: Color(0xFF8E8E93))),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              if (_resumes.isEmpty) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ResumeDetailScreen(resume: _resumes.first)),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: Color(0xFFD1D1D6)),
              foregroundColor: const Color(0xFF007AFF),
            ),
            child: const Text('Все резюме'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1C1E))),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF8E8E93))),
        ],
      ),
    );
  }

  // ── More card ─────────────────────────────────────────────────────────────

  Widget _buildMoreCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildMenuTile(
            icon: Icons.notifications_outlined,
            label: 'Настройки уведомлений',
            onTap: () => _navigate(const SubscriptionsScreen()),
            isFirst: true,
          ),
          _menuDivider(),
          _buildMenuTileSwitch(
            icon: Icons.dark_mode_outlined,
            label: 'Тёмная тема',
          ),
          _menuDivider(),
          _buildMenuTile(
            icon: Icons.star_outline_rounded,
            label: 'Подписки',
            onTap: () => _navigate(const PlansScreen()),
          ),
          _menuDivider(),
          _buildMenuTile(
            icon: Icons.quiz_outlined,
            label: 'Тесты навыков',
            onTap: () => _navigate(const SkillTestsScreen()),
          ),
          _menuDivider(),
          _buildMenuTile(
            icon: Icons.mic_outlined,
            label: 'Подготовка к интервью',
            onTap: () => _navigate(const InterviewPrepScreen()),
          ),
          _menuDivider(),
          _buildMenuTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Политика конфиденциальности',
            onTap: () => _navigate(const PrivacyPolicyScreen()),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _menuDivider() =>
      const Divider(height: 1, indent: 52, endIndent: 0);

  Widget _buildMenuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF8E8E93)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, color: Color(0xFF1C1C1E))),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFC7C7CC), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTileSwitch({
    required IconData icon,
    required String label,
  }) {
    final themeProvider = context.watch<ThemeProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF8E8E93)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15, color: Color(0xFF1C1C1E))),
          ),
          Switch(
            value: themeProvider.isDark,
            onChanged: (_) => themeProvider.toggle(),
          ),
        ],
      ),
    );
  }

  // ── Logout button ─────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return OutlinedButton(
      onPressed: _logout,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: Colors.red),
        foregroundColor: Colors.red,
      ),
      child: const Text('Выйти из приложения',
          style: TextStyle(fontSize: 16)),
    );
  }
}
