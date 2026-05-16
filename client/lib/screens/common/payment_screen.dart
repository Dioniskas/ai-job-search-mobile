import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

enum PaymentProvider { payme, click }

class PaymentScreen extends StatefulWidget {
  final String boostType; // 'RESUME_BOOST' | 'VACANCY_BOOST'
  final String? vacancyId;

  const PaymentScreen({
    super.key,
    required this.boostType,
    this.vacancyId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentProvider? _selected;
  bool _loading = false;
  String? _error;

  String get _title =>
      widget.boostType == 'RESUME_BOOST' ? 'Поднять резюме' : 'Продвинуть вакансию';

  String get _priceLabel =>
      widget.boostType == 'RESUME_BOOST' ? '1 990 сум' : '4 990 сум';

  Future<void> _pay() async {
    if (_selected == null) return;
    final token = context.read<AuthProvider>().token!;
    setState(() { _loading = true; _error = null; });
    try {
      final Map<String, dynamic> data;
      if (_selected == PaymentProvider.payme) {
        data = await ApiService.createPaymePayment(
          token,
          widget.boostType,
          vacancyId: widget.vacancyId,
        );
      } else {
        data = await ApiService.createClickPayment(
          token,
          widget.boostType,
          vacancyId: widget.vacancyId,
        );
      }
      final paymentId = data['paymentId'] as String;
      final testMode = data['testMode'] as bool? ?? false;
      final url = data['checkoutUrl'] as String?;

      if (!mounted) return;
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => testMode
              ? _TestPaymentScreen(
                  paymentId: paymentId,
                  provider: _selected!,
                  priceLabel: _priceLabel,
                )
              : _WebViewPayment(
                  url: url!,
                  paymentId: paymentId,
                  provider: _selected!,
                ),
        ),
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (success == true) {
        Navigator.pop(context, true); // signal caller to refresh
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: cs.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '7 дней — $_priceLabel',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Выберите способ оплаты',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            _ProviderTile(
              label: 'Payme',
              subtitle: 'Visa, MasterCard, Humo, Uzcard',
              logoColor: const Color(0xFF00AEEF),
              icon: Icons.credit_card_rounded,
              selected: _selected == PaymentProvider.payme,
              onTap: () => setState(() => _selected = PaymentProvider.payme),
            ),
            const SizedBox(height: 10),
            _ProviderTile(
              label: 'Click',
              subtitle: 'Visa, MasterCard, Humo, Uzcard',
              logoColor: const Color(0xFF1FA8E0),
              icon: Icons.touch_app_rounded,
              selected: _selected == PaymentProvider.click,
              onTap: () => setState(() => _selected = PaymentProvider.click),
            ),
            const Spacer(),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: cs.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: (_selected == null || _loading) ? null : _pay,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Перейти к оплате', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Provider tile ─────────────────────────────────────────────────────────────

class _ProviderTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color logoColor;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ProviderTile({
    required this.label,
    required this.subtitle,
    required this.logoColor,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: cs.primary.withValues(alpha: 0.15), blurRadius: 10)]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: logoColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: logoColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? cs.primary : cs.outlineVariant,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Test payment screen (3-second simulation) ─────────────────────────────────

class _TestPaymentScreen extends StatefulWidget {
  final String paymentId;
  final PaymentProvider provider;
  final String priceLabel;

  const _TestPaymentScreen({
    required this.paymentId,
    required this.provider,
    required this.priceLabel,
  });

  @override
  State<_TestPaymentScreen> createState() => _TestPaymentScreenState();
}

class _TestPaymentScreenState extends State<_TestPaymentScreen> {
  int _seconds = 3;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _seconds--);
      if (_seconds > 0) {
        _startCountdown();
      } else {
        _confirmPayment();
      }
    });
  }

  Future<void> _confirmPayment() async {
    setState(() => _processing = true);
    try {
      final token = context.read<AuthProvider>().token!;
      await ApiService.completeTestPayment(token, widget.paymentId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final providerName =
        widget.provider == PaymentProvider.payme ? 'Payme' : 'Click';

    return Scaffold(
      appBar: AppBar(
        title: Text('Тест: $providerName'),
        backgroundColor: cs.surface,
        automaticallyImplyLeading: false,
        actions: [
          if (!_processing)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.science_rounded,
                  size: 40,
                  color: Color(0xFFF97316),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Тестовый режим',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Симуляция оплаты через $providerName',
                style: TextStyle(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                widget.priceLabel,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: cs.error)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _confirmPayment,
                  child: const Text('Повторить'),
                ),
              ] else if (_processing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Применяем продвижение...'),
              ] else ...[
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: (3 - _seconds) / 3,
                        strokeWidth: 6,
                        color: cs.primary,
                      ),
                      Text(
                        '$_seconds',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Оплата будет подтверждена...',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── WebView screen ────────────────────────────────────────────────────────────

class _WebViewPayment extends StatefulWidget {
  final String url;
  final String paymentId;
  final PaymentProvider provider;

  const _WebViewPayment({
    required this.url,
    required this.paymentId,
    required this.provider,
  });

  @override
  State<_WebViewPayment> createState() => _WebViewPaymentState();
}

class _WebViewPaymentState extends State<_WebViewPayment> {
  late final WebViewController _controller;
  bool _pageLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _pageLoading = true),
        onPageFinished: (_) => setState(() => _pageLoading = false),
        onNavigationRequest: (req) {
          // Intercept return URL / deep link
          if (req.url.contains('aijobsearch://payment/result') ||
              req.url.contains('success') ||
              req.url.contains('payment/success')) {
            Navigator.pop(context, true);
            return NavigationDecision.prevent;
          }
          if (req.url.contains('cancel') || req.url.contains('failed')) {
            Navigator.pop(context, false);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.provider == PaymentProvider.payme ? 'Оплата через Payme' : 'Оплата через Click',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_pageLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
