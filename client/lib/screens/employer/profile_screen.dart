import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../common/plans_screen.dart';
import '../common/legal_screens.dart';

class EmployerProfileScreen extends StatefulWidget {
  const EmployerProfileScreen({super.key});

  @override
  State<EmployerProfileScreen> createState() => _EmployerProfileScreenState();
}

class _EmployerProfileScreenState extends State<EmployerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  String? _logoUrl;
  bool _isVerified = false;
  bool _loadingProfile = true;
  bool _savingProfile = false;
  bool _uploadingLogo = false;
  String? _error;
  String? _successMessage;
  bool _initialized = false;

  AuthProvider get _auth => context.read<AuthProvider>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _descriptionCtrl.dispose();
    _websiteCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _auth.withAuth((t) => ApiService.getEmployerProfile(t));
      final p = data['profile'] as Map<String, dynamic>?;
      if (p != null && mounted) {
        _companyNameCtrl.text = (p['companyName'] as String?) ?? '';
        _descriptionCtrl.text = (p['description'] as String?) ?? '';
        _websiteCtrl.text = (p['website'] as String?) ?? '';
        _cityCtrl.text = (p['city'] as String?) ?? '';
        setState(() {
          _logoUrl = p['logoUrl'] as String?;
          _isVerified = p['isVerified'] as bool? ?? false;
        });
      }
    } catch (_) {
      // Profile not yet created — show empty form
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (image == null || !mounted) return;

    setState(() => _uploadingLogo = true);
    try {
      final bytes = await image.readAsBytes();
      final url = await _auth.withAuth(
          (t) => ApiService.uploadEmployerLogo(t, bytes, image.name));
      if (mounted) setState(() => _logoUrl = url);
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка загрузки логотипа: ${_msg(e)}'),
          backgroundColor: cs.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _savingProfile = true;
      _error = null;
      _successMessage = null;
    });
    try {
      await _auth.withAuth((t) => ApiService.updateEmployerProfile(t, {
        'companyName': _companyNameCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
      }));
      if (mounted) setState(() => _successMessage = 'Профиль сохранён');
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) context.go('/login');
  }

  String _msg(Object e) =>
      e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? cs.surface : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Профиль компании'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        surfaceTintColor: cs.surface,
        actions: _isVerified
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified_rounded,
                        size: 15, color: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text('Проверено',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A))),
                  ]),
                ),
              ]
            : null,
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLogoSection(cs),
                    const SizedBox(height: 16),
                    _buildSection(
                      cs: cs,
                      title: 'О компании',
                      children: [
                        _buildField(
                          cs: cs,
                          controller: _companyNameCtrl,
                          label: 'Название компании',
                          icon: Icons.business_rounded,
                          required: true,
                        ),
                        _buildField(
                          cs: cs,
                          controller: _descriptionCtrl,
                          label: 'Описание компании',
                          icon: Icons.notes_rounded,
                          maxLines: 4,
                        ),
                        _buildField(
                          cs: cs,
                          controller: _websiteCtrl,
                          label: 'Сайт',
                          icon: Icons.language_rounded,
                          keyboard: TextInputType.url,
                        ),
                        _buildField(
                          cs: cs,
                          controller: _cityCtrl,
                          label: 'Город',
                          icon: Icons.location_city_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSection(
                      cs: cs,
                      title: 'Настройки',
                      children: [
                        _buildThemeRow(cs),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSection(
                      cs: cs,
                      title: 'Продвижение',
                      children: [
                        _buildNavRow(
                          cs: cs,
                          icon: Icons.trending_up_rounded,
                          label: 'Продвинуть вакансию в топ',
                          subtitle: 'Платное продвижение от 1 990 сум',
                          color: const Color(0xFF7C3AED),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PlansScreen()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSection(
                      cs: cs,
                      title: 'О приложении',
                      children: [
                        _buildNavRow(
                          cs: cs,
                          icon: Icons.privacy_tip_outlined,
                          label: 'Политика конфиденциальности',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyScreen()),
                          ),
                        ),
                        const Divider(height: 20),
                        _buildNavRow(
                          cs: cs,
                          icon: Icons.description_outlined,
                          label: 'Пользовательское соглашение',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TermsOfServiceScreen()),
                          ),
                        ),
                        const Divider(height: 20),
                        _buildNavRow(
                          cs: cs,
                          icon: Icons.support_agent_rounded,
                          label: 'Поддержка',
                          subtitle: 'support@aijobsearch.com',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SupportScreen()),
                          ),
                        ),
                        const Divider(height: 20),
                        _buildNavRow(
                          cs: cs,
                          icon: Icons.info_outline_rounded,
                          label: 'О приложении',
                          subtitle: 'Версия 1.0.0',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AboutAppScreen()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      _buildBanner(cs, _error!, isError: true),
                    if (_successMessage != null)
                      _buildBanner(cs, _successMessage!, isError: false),
                    const SizedBox(height: 4),
                    FilledButton(
                      onPressed: _savingProfile ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _savingProfile
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Сохранить',
                              style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _logout,
                      icon: Icon(Icons.logout_rounded, color: cs.error),
                      label: Text('Выйти',
                          style: TextStyle(color: cs.error)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(color: cs.error),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLogoSection(ColorScheme cs) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              image: _logoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_logoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _logoUrl == null
                ? Icon(Icons.business_rounded,
                    size: 48, color: cs.onSurfaceVariant)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _uploadingLogo ? null : _pickAndUploadLogo,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 2),
                ),
                child: _uploadingLogo
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
    );
  }

  Widget _buildSection(
      {required ColorScheme cs,
      required String title,
      required List<Widget> children}) {
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

  Widget _buildField({
    required ColorScheme cs,
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool required = false,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'Обязательное поле' : null
            : null,
      ),
    );
  }

  Widget _buildThemeRow(ColorScheme cs) {
    final themeProvider = context.watch<ThemeProvider>();
    return Row(
      children: [
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
                  style:
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Switch(
          value: themeProvider.isDark,
          onChanged: (_) => themeProvider.toggle(),
        ),
      ],
    );
  }

  Widget _buildNavRow({
    required ColorScheme cs,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? subtitle,
    Color? color,
  }) {
    final iconColor = color ?? cs.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 20, color: iconColor),
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

  Widget _buildBanner(ColorScheme cs, String text, {required bool isError}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? cs.errorContainer
            : const Color(0xFF16A34A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isError ? cs.onErrorContainer : const Color(0xFF16A34A),
        ),
      ),
    );
  }
}

