import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class SkillTestsScreen extends StatefulWidget {
  const SkillTestsScreen({super.key});

  @override
  State<SkillTestsScreen> createState() => _SkillTestsScreenState();
}

class _SkillTestsScreenState extends State<SkillTestsScreen> {
  List<dynamic> _tests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final tests = await ApiService.getSkillTests(token);
      if (mounted) setState(() { _tests = tests; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = _msg(e); _loading = false; });
    }
  }

  String _msg(Object e) =>
      e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';

  void _openTest(Map<String, dynamic> testMeta) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SkillTestPage(
          skill: testMeta['skill'] as String,
          title: testMeta['title'] as String,
          description: testMeta['description'] as String,
          onCompleted: _loadTests,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тесты навыков'),
        backgroundColor: cs.surface,
      ),
      body: _loading
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
                            setState(() { _loading = true; _error = null; });
                            _loadTests();
                          },
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTests,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Подтвердите свои навыки',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Пройдите тест по своей специальности — набери 70% и получи бейдж на профиль.',
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Доступные тесты',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._tests.map((t) {
                        final test = t as Map<String, dynamic>;
                        final best = test['userBest'] as Map<String, dynamic>?;
                        final hasBadge = test['hasBadge'] as bool? ?? false;
                        final bestScore = best?['score'] as int?;
                        return _SkillTestCard(
                          icon: test['icon'] as String,
                          title: test['title'] as String,
                          description: test['description'] as String,
                          bestScore: bestScore,
                          hasBadge: hasBadge,
                          onTap: () => _openTest(test),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _SkillTestCard extends StatelessWidget {
  final String icon;
  final String title;
  final String description;
  final int? bestScore;
  final bool hasBadge;
  final VoidCallback onTap;

  const _SkillTestCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.bestScore,
    required this.hasBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        if (hasBadge) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '✓ Бейдж',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                    if (bestScore != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 14, color: cs.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Лучший результат: $bestScore%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Test page ────────────────────────────────

class _SkillTestPage extends StatefulWidget {
  final String skill;
  final String title;
  final String description;
  final VoidCallback onCompleted;

  const _SkillTestPage({
    required this.skill,
    required this.title,
    required this.description,
    required this.onCompleted,
  });

  @override
  State<_SkillTestPage> createState() => _SkillTestPageState();
}

class _SkillTestPageState extends State<_SkillTestPage> {
  List<dynamic> _questions = [];
  List<int?> _answers = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final data = await ApiService.getSkillTestQuestions(token, widget.skill);
      final questions = data['questions'] as List<dynamic>;
      if (mounted) {
        setState(() {
          _questions = questions;
          _answers = List.filled(questions.length, null);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = _msg(e); _loading = false; });
    }
  }

  Future<void> _submit() async {
    if (_answers.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ответьте на все вопросы')),
      );
      return;
    }

    setState(() => _submitting = true);
    final token = context.read<AuthProvider>().token!;
    try {
      final result = await ApiService.submitSkillTest(
        token,
        widget.skill,
        _answers.cast<int>(),
      );
      if (mounted) {
        setState(() { _result = result; _submitting = false; });
        widget.onCompleted();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_msg(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _msg(Object e) =>
      e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: cs.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _result != null
                  ? _buildResult(cs)
                  : _buildTest(cs),
    );
  }

  Widget _buildTest(ColorScheme cs) {
    final question = _questions[_currentIndex] as Map<String, dynamic>;
    final options = (question['options'] as List<dynamic>).cast<String>();
    final progress = (_currentIndex + 1) / _questions.length;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: cs.surfaceContainerHighest,
          color: cs.primary,
          minHeight: 4,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Вопрос ${_currentIndex + 1} из ${_questions.length}',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Text(
                  question['text'] as String,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ...options.asMap().entries.map((entry) {
                  final i = entry.key;
                  final text = entry.value;
                  final selected = _answers[_currentIndex] == i;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _answers[_currentIndex] = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? cs.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? cs.primary : cs.outline,
                                width: 2,
                              ),
                              color: selected ? cs.primary : Colors.transparent,
                            ),
                            child: selected
                                ? Icon(Icons.check_rounded,
                                    size: 14, color: cs.onPrimary)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: 15,
                                color: selected
                                    ? cs.onPrimaryContainer
                                    : cs.onSurface,
                                fontWeight: selected
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_currentIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _currentIndex--),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Назад'),
                  ),
                ),
              if (_currentIndex > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _currentIndex < _questions.length - 1
                    ? FilledButton(
                        onPressed: _answers[_currentIndex] == null
                            ? null
                            : () => setState(() => _currentIndex++),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Далее'),
                      )
                    : FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Завершить тест'),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult(ColorScheme cs) {
    final result = _result!;
    final score = result['score'] as int;
    final passed = result['passed'] as bool;
    final correct = result['correct'] as int;
    final total = result['total'] as int;
    final badge = result['badge'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 12,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: passed ? const Color(0xFF16A34A) : cs.error,
                ),
              ),
              Column(
                children: [
                  Text(
                    '$score%',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: passed ? const Color(0xFF16A34A) : cs.error,
                    ),
                  ),
                  Text(
                    '$correct / $total',
                    style: TextStyle(
                        fontSize: 14, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            passed ? 'Отлично! Тест пройден' : 'Тест не пройден',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            passed
                ? 'Вы успешно подтвердили навык "${widget.title}"'
                : 'Для получения бейджа необходимо набрать 70%. Попробуйте ещё раз!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          if (badge != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded,
                      color: Color(0xFF16A34A), size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Бейдж получен!',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      Text(
                        '${badge['title']} — $score%',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              setState(() {
                _currentIndex = 0;
                _answers = List.filled(_questions.length, null);
                _result = null;
              });
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Пройти снова'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(200, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(200, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('К списку тестов'),
          ),
        ],
      ),
    );
  }
}

