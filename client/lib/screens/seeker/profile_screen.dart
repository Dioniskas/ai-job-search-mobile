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
        _photoUrl = p?['photoUrl'] as String?;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final percent = _completionPercent;
    final hint = _completionHint;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Профиль'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        surfaceTintColor: cs.surface,
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: cs.error),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Шапка: фото + имя + должность + прогресс ─────────────
                    _buildHeader(cs, percent, hint),
                    const SizedBox(height: 16),

                    // ── Мои резюме ─────────────────────────────────────────
                    _buildSection(
                      cs: cs,
                      title: 'Мои резюме',
                      children: [
                        if (_resumes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'У вас пока нет резюме',
                              style: TextStyle(color: cs.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ..._resumes.map((r) => _buildResumeRow(cs, r)),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ResumeCreateScreen()),
                            );
                            if (result == true || result == null) _loadAll();
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Создать новое резюме'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Статус поиска работы ──────────────────────────────
                    _buildSection(
                      cs: cs,
                      title: 'Статус поиска работы',
                      children: [
                        const SizedBox(height: 4),
                        _buildSearchStatus(cs),
                        const SizedBox(height: 4),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Настройки ─────────────────────────────────────────
                    _buildSection(
                      cs: cs,
                      title: 'Настройки',
                      children: [
                        _buildToggleRow(
                          cs: cs,
                          icon: Icons.visibility_outlined,
                          label: 'Видимость профиля',
                          subtitle: 'Работодатели видят ваш профиль',
                          value: _isVisible,
                          onChanged: (v) => setState(() => _isVisible = v),
                        ),
                        const Divider(height: 20),
                        _buildThemeRow(cs),
                        const Divider(height: 20),
                        _buildNavRow(
                          cs: cs,
                          icon: Icons.notifications_active_rounded,
                          label: 'Автопоиск — подписки на вакансии',
                          onTap: () => _navigate(const SubscriptionsScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Инструменты ───────────────────────────────────────
                    _buildSection(
                      cs: cs,
                      title: 'Инструменты',
                      children: [
                        _buildNavRow(
                          cs: cs,
                          icon: Icons.quiz_rounded,
                          label: 'Тесты навыков',
                          subtitle: 'Подтвердите экспертизу и получите бейдж',
                          color: cs.primary,
                          onTap: () => _navigate(const SkillTestsScreen()),
                        ),
                        const Divider(height: 20),
                        _buildNavRow(
                          cs: cs,
                          icon: Icons.psychology_rounded,
                          label: 'Подготовка к интервью',
                          subtitle: 'Ассистент задаст вопросы и оценит ответы',
                          color: const Color(0xFF7C3AED),
                          onTap: () => _navigate(const InterviewPrepScreen()),
                        ),
                        const Divider(height: 20),
                        _buildNavRow(
                          cs: cs,
                          icon: Icons.rocket_launch_rounded,
                          label: 'Поднять резюме в поиске',
                          subtitle: 'Платное продвижение от 1 990 сум',
                          color: const Color(0xFFD97706),
                          onTap: () => _navigate(const PlansScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── О приложении ──────────────────────────────────────
                    _buildSection(
                      cs: cs,
                      title: 'О приложении',
                      children: [
                        _buildNavRow(
                          cs: cs,
                          icon: Icons.privacy_tip_outlined,
                          label: 'Политика конфиденциальности',
                          onTap: () => _navigate(const PrivacyPolicyScreen()),
                        ),
                        const Divider(height: 20),
                        _buildNavRow(
                          cs: cs,
                          icon: Icons.description_outlined,
                          label: 'Пользовательское соглашение',
                          onTap: () => _navigate(const TermsOfServiceScreen()),
                        ),
                        const Divider(height: 20),
                        _buildNavRow(
                          cs: cs,
                          icon: Icons.support_agent_rounded,
                          label: 'Поддержка',
                          subtitle: 'support@aijobsearch.com',
                          onTap: () => _navigate(const SupportScreen()),
                        ),
                        const Divider(height: 20),
                        _buildNavRow(
                          cs: cs,
                          icon: Icons.info_outline_rounded,
                          label: 'О приложении',
                          subtitle: 'Версия 1.0.0',
                          onTap: () => _navigate(const AboutAppScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Сохранить ─────────────────────────────────────────
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Сохранить',
                              style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs, double percent, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        children: [
          // Фото
          Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: cs.surfaceContainerHighest,
                backgroundImage:
                    _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                child: _photoUrl == null
                    ? Icon(Icons.person_rounded,
                        size: 52, color: cs.onSurfaceVariant)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 2),
                    ),
                    child: _uploadingPhoto
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.camera_alt_rounded,
                            size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Имя
          Text(
            _displayName,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Должность из основного резюме
          Text(
            _jobTitle,
            style:
                TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Прогресс-бар
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Заполненность профиля',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
              Text('${(percent * 100).round()}%',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cs.primary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(hint,
                style:
                    TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  // ── Resume row ────────────────────────────────────────────────────────────

  Widget _buildResumeRow(ColorScheme cs, Map<String, dynamic> resume) {
    final isMain = resume['isMain'] == true;
    final id = resume['id'] as String;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMain
            ? cs.primary.withValues(alpha: 0.06)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMain ? cs.primary : cs.outlineVariant,
          width: isMain ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isMain ? cs.primaryContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.description_rounded,
                color: isMain ? cs.primary : cs.onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isMain)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('ОСНОВНОЕ',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    Flexible(
                      child: Text(
                        resume['title'] as String? ?? 'Резюме',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (!isMain)
                  TextButton(
                    onPressed: () => _setMain(id),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text('Сделать основным',
                        style: TextStyle(fontSize: 12, color: cs.primary)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.open_in_new_rounded,
                size: 18, color: cs.onSurfaceVariant),
            onPressed: () async {
              final deleted = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => ResumeDetailScreen(resume: resume)),
              );
              if (deleted == true) _loadAll();
            },
          ),
        ],
      ),
    );
  }

  // ── Section wrapper ───────────────────────────────────────────────────────

  Widget _buildSection({
    required ColorScheme cs,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // ── Toggle row ────────────────────────────────────────────────────────────

  Widget _buildToggleRow({
    required ColorScheme cs,
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(children: [
      Icon(icon, size: 20, color: cs.onSurfaceVariant),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: cs.onSurface)),
            if (subtitle != null)
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
      Switch(value: value, onChanged: onChanged),
    ]);
  }

  Widget _buildThemeRow(ColorScheme cs) {
    final themeProvider = context.watch<ThemeProvider>();
    return Row(children: [
      Icon(
        themeProvider.isDark
            ? Icons.dark_mode_rounded
            : Icons.light_mode_rounded,
        size: 20,
        color: cs.onSurfaceVariant,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тёмная тема',
                style: TextStyle(fontSize: 15, color: cs.onSurface)),
            Text(themeProvider.isDark ? 'Включена' : 'Выключена',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
      Switch(
        value: themeProvider.isDark,
        onChanged: (_) => themeProvider.toggle(),
      ),
    ]);
  }

  // ── Nav row ───────────────────────────────────────────────────────────────

  Widget _buildNavRow({
    required ColorScheme cs,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? subtitle,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 20, color: color ?? cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 15, color: cs.onSurface)),
                if (subtitle != null)
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        ]),
      ),
    );
  }

  // ── Search status ─────────────────────────────────────────────────────────

  Widget _buildSearchStatus(ColorScheme cs) {
    const statuses = [
      ('ACTIVE', 'Активно ищу', Color(0xFF16A34A)),
      ('OPEN', 'Рассматриваю', Color(0xFF2563EB)),
      ('NOT_LOOKING', 'Не ищу', Color(0xFF64748B)),
    ];
    return Row(
      children: statuses.map((s) {
        final (value, label, color) = s;
        final selected = _searchStatus == value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => setState(() => _searchStatus = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.12)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? color : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? color : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
