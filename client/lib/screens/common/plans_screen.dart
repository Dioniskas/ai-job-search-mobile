import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'payment_screen.dart';
import 'payment_history_screen.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  bool _loadingStatus = true;
  String? _error;

  // Seeker boost state
  DateTime? _seekerBoostedUntil;
  bool _seekerIsBoosted = false;

  // Employer boost state
  List<Map<String, dynamic>> _employerVacancies = [];
  String? _selectedVacancyId;

  String? get _role => context.read<AuthProvider>().role;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final data = await ApiService.getBoostStatus(token);
      if (mounted) {
        if (_role == 'SEEKER') {
          setState(() {
            _seekerIsBoosted = data['isBoosted'] as bool? ?? false;
            final raw = data['boostedUntil'];
            _seekerBoostedUntil =
                raw != null ? DateTime.tryParse(raw as String) : null;
            _loadingStatus = false;
          });
        } else {
          final vacancies = (data['vacancies'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          setState(() {
            _employerVacancies = vacancies;
            if (vacancies.isNotEmpty) _selectedVacancyId = vacancies[0]['id'] as String;
            _loadingStatus = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _msg(e);
          _loadingStatus = false;
        });
      }
    }
  }

  Future<void> _applyBoost(int days) async {
    if (_role != 'SEEKER' && _selectedVacancyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите вакансию')),
      );
      return;
    }

    final boostType = _role == 'SEEKER' ? 'RESUME_BOOST' : 'VACANCY_BOOST';
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          boostType: boostType,
          vacancyId: _role == 'EMPLOYER' ? _selectedVacancyId : null,
        ),
      ),
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _role == 'SEEKER'
                ? 'Резюме поднято на $days дней!'
                : 'Вакансия продвинута на $days дней!',
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      setState(() => _loadingStatus = true);
      _loadStatus();
    }
  }

  String _msg(Object e) =>
      e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSeeker = _role == 'SEEKER';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тарифы и продвижение'),
        backgroundColor: cs.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'История платежей',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
            ),
          ),
        ],
      ),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: cs.error),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _loadingStatus = true;
                              _error = null;
                            });
                            _loadStatus();
                          },
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeroCard(cs, isSeeker),
                      const SizedBox(height: 20),
                      if (!isSeeker && _employerVacancies.isNotEmpty) ...[
                        _buildVacancySelector(cs),
                        const SizedBox(height: 16),
                      ],
                      if (!isSeeker && _employerVacancies.isEmpty) ...[
                        _buildNoVacanciesCard(cs),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'Выберите тариф',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PlanCard(
                        days: 7,
                        price: '1 990',
                        title: 'Стандарт',
                        subtitle: '7 дней продвижения',
                        features: isSeeker
                            ? ['Резюме в топе выдачи', 'Больше просмотров']
                            : ['Вакансия в топе поиска', 'Повышенный охват'],
                        color: cs.primary,
                        onTap: !isSeeker && _employerVacancies.isEmpty
                            ? null
                            : () => _applyBoost(7),
                      ),
                      const SizedBox(height: 10),
                      _PlanCard(
                        days: 30,
                        price: '5 990',
                        title: 'Расширенный',
                        subtitle: '30 дней продвижения',
                        features: isSeeker
                            ? [
                                'Резюме в топе выдачи',
                                'Метка «Активно ищу»',
                                'Приоритет у работодателей',
                              ]
                            : [
                                'Вакансия в топе поиска',
                                'Метка «Горячая вакансия»',
                                'Повышенный охват кандидатов',
                              ],
                        color: const Color(0xFF7C3AED),
                        highlighted: true,
                        onTap: !isSeeker && _employerVacancies.isEmpty
                            ? null
                            : () => _applyBoost(30),
                      ),
                      const SizedBox(height: 10),
                      _PlanCard(
                        days: 90,
                        price: '14 990',
                        title: 'Премиум',
                        subtitle: '90 дней продвижения',
                        features: isSeeker
                            ? [
                                'Резюме в топе выдачи',
                                'Метка «Активно ищу»',
                                'Приоритет у работодателей',
                                'Выгода — скидка 25%',
                              ]
                            : [
                                'Вакансия в топе поиска',
                                'Метка «Горячая вакансия»',
                                'Максимальный охват',
                                'Выгода — скидка 25%',
                              ],
                        color: const Color(0xFFD97706),
                        onTap: !isSeeker && _employerVacancies.isEmpty
                            ? null
                            : () => _applyBoost(90),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_rounded,
                                size: 18, color: cs.onSurfaceVariant),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Оплата через Payme или Click. Безопасно — данные карты не хранятся.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeroCard(ColorScheme cs, bool isSeeker) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSeeker
              ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
              : [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSeeker
                    ? Icons.rocket_launch_rounded
                    : Icons.trending_up_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isSeeker
                      ? 'Поднять резюме в поиске'
                      : 'Продвинуть вакансию в топ',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isSeeker
                ? 'Ваше резюме увидят первыми. Больше приглашений на интервью.'
                : 'Ваша вакансия на первой строке. Больше откликов от лучших кандидатов.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          if (isSeeker && _seekerIsBoosted && _seekerBoostedUntil != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Активно до ${_formatDate(_seekerBoostedUntil!)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVacancySelector(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Выберите вакансию для продвижения',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedVacancyId,
              isExpanded: true,
              onChanged: (v) => setState(() => _selectedVacancyId = v),
              items: _employerVacancies.map((v) {
                final isBoosted = v['isBoosted'] as bool? ?? false;
                return DropdownMenuItem<String>(
                  value: v['id'] as String,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          v['title'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isBoosted)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'В топе',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoVacanciesCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'У вас нет активных вакансий. Создайте вакансию, чтобы продвигать её.',
              style: TextStyle(fontSize: 13, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

// ──────────────────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final int days;
  final String price;
  final String title;
  final String subtitle;
  final List<String> features;
  final Color color;
  final bool highlighted;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.days,
    required this.price,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.color,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted ? color : cs.outlineVariant,
              width: highlighted ? 2 : 1,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$price сум',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            Text(
                              '/ $days дней',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...features.map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 16, color: color),
                            const SizedBox(width: 8),
                            Text(
                              f,
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Подключить'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (highlighted)
          Positioned(
            top: 0,
            right: 16,
            child: Transform.translate(
              offset: const Offset(0, -10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Популярный',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

