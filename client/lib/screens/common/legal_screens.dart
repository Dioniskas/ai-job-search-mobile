import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Texts
// ─────────────────────────────────────────────────────────────────────────────

const _privacyPolicyText = '''
ПОЛИТИКА КОНФИДЕНЦИАЛЬНОСТИ

Дата вступления в силу: 1 января 2025 года

1. ОБЩИЕ ПОЛОЖЕНИЯ

1.1. Настоящая Политика конфиденциальности (далее — «Политика») определяет порядок сбора, хранения, обработки и защиты персональных данных пользователей мобильного приложения AI Job Search (далее — «Приложение»).

1.2. Использование Приложения означает безоговорочное согласие пользователя с настоящей Политикой и указанными в ней условиями обработки его персональных данных.

1.3. Обработка персональных данных осуществляется в соответствии с требованиями законодательства Республики Узбекистан, в том числе Закона «О персональных данных» от 2 июля 2019 года № ЗРУ-547.

2. КАКИЕ ДАННЫЕ МЫ СОБИРАЕМ

2.1. Данные, предоставляемые пользователем:
— имя и фамилия;
— адрес электронной почты и номер телефона;
— город проживания;
— сведения об образовании и опыте работы;
— профессиональные навыки и желаемая должность;
— фотография профиля;
— иные сведения, указанные в резюме или профиле работодателя.

2.2. Данные, собираемые автоматически:
— идентификатор устройства (Device ID);
— операционная система и версия приложения;
— статистика использования функций приложения;
— токен для push-уведомлений (Firebase Cloud Messaging).

3. ЦЕЛИ ОБРАБОТКИ ДАННЫХ

3.1. Мы используем ваши данные для:
— предоставления услуг по поиску работы и подбору персонала;
— сопоставления соискателей с подходящими вакансиями;
— обеспечения связи между соискателями и работодателями;
— формирования резюме с помощью технологий искусственного интеллекта;
— отправки уведомлений о новых вакансиях и статусе отклика;
— улучшения качества работы Приложения;
— соблюдения требований законодательства.

4. ПЕРЕДАЧА ДАННЫХ ТРЕТЬИМ ЛИЦАМ

4.1. Мы используем следующие сторонние сервисы:
— Google Firebase — аутентификация, база данных, push-уведомления (политика конфиденциальности Google: policies.google.com/privacy);
— Google Gemini AI — генерация текста резюме и вакансий (обработка происходит без сохранения персональных данных).

4.2. Мы не продаём и не передаём ваши персональные данные третьим лицам в коммерческих целях.

4.3. Работодатели, зарегистрированные в Приложении, получают доступ только к тем данным соискателя, которые тот явно сделал общедоступными (имя, должность, навыки, опыт работы). Контактные данные передаются только при взаимном согласии сторон.

5. ХРАНЕНИЕ И ЗАЩИТА ДАННЫХ

5.1. Данные хранятся на защищённых серверах. Мы применяем технические и организационные меры для защиты информации от несанкционированного доступа.

5.2. Срок хранения персональных данных — в течение всего срока действия учётной записи пользователя и 30 дней после её удаления.

6. ПРАВА ПОЛЬЗОВАТЕЛЕЙ

6.1. Вы имеете право:
— получить информацию об обрабатываемых персональных данных;
— потребовать исправления неточных данных;
— удалить свою учётную запись и все связанные данные;
— отозвать согласие на обработку данных.

6.2. Для реализации прав обратитесь на: support@aijobsearch.com

7. ИЗМЕНЕНИЯ ПОЛИТИКИ

7.1. Мы вправе изменять настоящую Политику. Актуальная версия всегда доступна в Приложении.

8. КОНТАКТЫ

По вопросам, связанным с обработкой персональных данных, обращайтесь:
Email: support@aijobsearch.com
''';

const _termsOfServiceText = '''
ПОЛЬЗОВАТЕЛЬСКОЕ СОГЛАШЕНИЕ

Дата вступления в силу: 1 января 2025 года

1. ПРЕДМЕТ СОГЛАШЕНИЯ

1.1. Настоящее Пользовательское соглашение (далее — «Соглашение») регулирует отношения между пользователем и командой AI Job Search (далее — «Сервис») при использовании мобильного приложения AI Job Search.

1.2. Начав использование Приложения, вы подтверждаете, что ознакомились с настоящим Соглашением и полностью его принимаете.

2. ОПИСАНИЕ СЕРВИСА

2.1. Приложение AI Job Search предоставляет платформу для поиска работы и подбора сотрудников на территории Республики Узбекистан.

2.2. Сервис предоставляется в двух режимах:
— для соискателей: создание резюме с помощью ИИ, поиск вакансий, отклик на вакансии, подготовка к интервью, тесты навыков;
— для работодателей: публикация вакансий с помощью ИИ, просмотр резюме, управление откликами.

3. РЕГИСТРАЦИЯ И УЧЁТНАЯ ЗАПИСЬ

3.1. Для использования Приложения необходима регистрация с указанием действующего адреса электронной почты.

3.2. Вы обязуетесь предоставлять достоверные сведения и своевременно их обновлять.

3.3. Вы несёте ответственность за сохранность данных для входа в свою учётную запись.

4. ПРАВИЛА ИСПОЛЬЗОВАНИЯ

4.1. Соискатели обязуются:
— размещать достоверную информацию о себе и своём опыте;
— использовать Приложение только в целях поиска работы для себя;
— не передавать доступ к учётной записи третьим лицам.

4.2. Работодатели обязуются:
— публиковать только реальные вакансии своей организации;
— не вводить соискателей в заблуждение относительно условий труда;
— соблюдать трудовое законодательство Республики Узбекистан.

4.3. Запрещено:
— размещать ложную, вводящую в заблуждение или незаконную информацию;
— использовать Приложение в целях мошенничества или спама;
— собирать персональные данные других пользователей без их согласия;
— нарушать работу Приложения техническими средствами.

5. ПЛАТНЫЕ УСЛУГИ

5.1. Ряд функций Приложения является платным: продвижение резюме и вакансий, расширенный доступ к базе кандидатов.

5.2. Оплата производится в соответствии с действующими тарифами, указанными в Приложении.

5.3. Оплаченные услуги возврату и обмену не подлежат, если иное не установлено законодательством.

6. ИНТЕЛЛЕКТУАЛЬНАЯ СОБСТВЕННОСТЬ

6.1. Все права на Приложение, его дизайн и технологии принадлежат команде AI Job Search.

6.2. Контент, размещённый пользователями (резюме, описания вакансий), принадлежит пользователям. Размещая контент, вы предоставляете Сервису право использовать его для работы Приложения.

7. ОГРАНИЧЕНИЕ ОТВЕТСТВЕННОСТИ

7.1. Сервис не несёт ответственности за:
— достоверность информации, размещённой пользователями;
— результат трудоустройства или найма;
— действия работодателей или соискателей.

7.2. Сервис предоставляется «как есть». Мы не гарантируем бесперебойную работу Приложения.

8. ПРЕКРАЩЕНИЕ ДЕЙСТВИЯ СОГЛАШЕНИЯ

8.1. Вы можете прекратить использование Приложения в любой момент, удалив учётную запись.

8.2. Мы вправе заблокировать учётную запись при нарушении настоящего Соглашения.

9. ПРИМЕНИМОЕ ПРАВО

9.1. Настоящее Соглашение регулируется законодательством Республики Узбекистан.

10. КОНТАКТЫ

По вопросам, связанным с Соглашением:
Email: support@aijobsearch.com
''';

// ─────────────────────────────────────────────────────────────────────────────
// Reusable scrollable text screen
// ─────────────────────────────────────────────────────────────────────────────

class _LegalTextScreen extends StatelessWidget {
  final String title;
  final String body;

  const _LegalTextScreen({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        surfaceTintColor: cs.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          body,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Privacy Policy Screen
// ─────────────────────────────────────────────────────────────────────────────

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LegalTextScreen(
        title: 'Политика конфиденциальности',
        body: _privacyPolicyText,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Terms of Service Screen
// ─────────────────────────────────────────────────────────────────────────────

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LegalTextScreen(
        title: 'Пользовательское соглашение',
        body: _termsOfServiceText,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// About App Screen
// ─────────────────────────────────────────────────────────────────────────────

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('О приложении'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        surfaceTintColor: cs.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Logo block
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
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
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.work_rounded,
                        color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AI Job Search',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Поиск работы с искусственным интеллектом',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Версия 1.0.0',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Info block
            _InfoSection(
              cs: cs,
              title: 'Контакты',
              items: const [
                _InfoItem(
                  icon: Icons.email_outlined,
                  label: 'Email поддержки',
                  value: 'support@aijobsearch.com',
                ),
                _InfoItem(
                  icon: Icons.location_on_outlined,
                  label: 'Регион',
                  value: 'Республика Узбекистан',
                ),
              ],
            ),
            const SizedBox(height: 12),

            _InfoSection(
              cs: cs,
              title: 'Технологии',
              items: const [
                _InfoItem(
                  icon: Icons.bolt_rounded,
                  label: 'ИИ-движок',
                  value: 'Google Gemini',
                ),
                _InfoItem(
                  icon: Icons.cloud_outlined,
                  label: 'Backend',
                  value: 'Firebase + FastAPI',
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              '© 2025 AI Job Search. Все права защищены.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Приложение разработано для рынка труда\nРеспублики Узбекистан.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final ColorScheme cs;
  final String title;
  final List<_InfoItem> items;

  const _InfoSection(
      {required this.cs, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _buildRow(item)),
        ],
      ),
    );
  }

  Widget _buildRow(_InfoItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(item.icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style:
                        TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                Text(item.value,
                    style: TextStyle(fontSize: 14, color: cs.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem(
      {required this.icon, required this.label, required this.value});
}

// ─────────────────────────────────────────────────────────────────────────────
// Support Screen
// ─────────────────────────────────────────────────────────────────────────────

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const _email = 'support@aijobsearch.com';

  Future<void> _sendEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _email,
      queryParameters: {
        'subject': 'Обращение в поддержку AI Job Search',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть почтовый клиент.\n'
              'Напишите нам: $_email'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Поддержка'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        surfaceTintColor: cs.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
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
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.support_agent_rounded,
                        color: cs.primary, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Служба поддержки',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Мы готовы помочь вам. Опишите вашу проблему или задайте вопрос — мы ответим в течение рабочего дня.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.email_outlined,
                            size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        Text(
                          _email,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _sendEmail(context),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Написать в поддержку',
                  style: TextStyle(fontSize: 16)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Режим работы: Пн–Пт, 9:00–18:00 (UTC+5)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Privacy Acceptance Dialog (first-launch gate)
// ─────────────────────────────────────────────────────────────────────────────

class PrivacyGateScreen extends StatefulWidget {
  final VoidCallback onAccept;

  const PrivacyGateScreen({super.key, required this.onAccept});

  @override
  State<PrivacyGateScreen> createState() => _PrivacyGateScreenState();
}

class _PrivacyGateScreenState extends State<PrivacyGateScreen> {
  bool _checked = false;

  void _viewPolicy() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
  }

  void _viewTerms() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Icon
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.privacy_tip_rounded,
                      color: cs.primary, size: 48),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Перед началом',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Пожалуйста, ознакомьтесь с нашими документами. '
                'Для использования приложения необходимо принять условия.',
                style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Links
              _DocLink(
                cs: cs,
                icon: Icons.shield_outlined,
                title: 'Политика конфиденциальности',
                subtitle: 'Как мы обрабатываем ваши данные',
                onTap: _viewPolicy,
              ),
              const SizedBox(height: 12),
              _DocLink(
                cs: cs,
                icon: Icons.description_outlined,
                title: 'Пользовательское соглашение',
                subtitle: 'Правила использования сервиса',
                onTap: _viewTerms,
              ),
              const SizedBox(height: 24),

              // Checkbox
              GestureDetector(
                onTap: () => setState(() => _checked = !_checked),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _checked,
                      onChanged: (v) => setState(() => _checked = v ?? false),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Я ознакомился(-ась) и принимаю Политику конфиденциальности и Пользовательское соглашение',
                          style: TextStyle(
                              fontSize: 14, color: cs.onSurface),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              FilledButton(
                onPressed: _checked ? widget.onAccept : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Принять и продолжить',
                    style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 8),
              Text(
                'Без принятия условий использование приложения невозможно',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocLink extends StatelessWidget {
  final ColorScheme cs;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DocLink({
    required this.cs,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded,
                size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
