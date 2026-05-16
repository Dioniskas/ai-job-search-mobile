import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class InterviewPrepScreen extends StatefulWidget {
  const InterviewPrepScreen({super.key});

  @override
  State<InterviewPrepScreen> createState() => _InterviewPrepScreenState();
}

class _InterviewPrepScreenState extends State<InterviewPrepScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _loadingQuestions = false;
  List<String> _questions = [];
  String _vacancyTitle = '';

  // Per-question state
  int _currentQuestion = 0;
  final List<TextEditingController> _answerCtrls = [];
  final List<Map<String, dynamic>?> _feedbacks = [];
  bool _loadingFeedback = false;

  String _msg(Object e) =>
      e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _answerCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _startPrep() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название вакансии')),
      );
      return;
    }

    setState(() => _loadingQuestions = true);
    final token = context.read<AuthProvider>().token!;
    try {
      final data = await ApiService.interviewPrep(
        token,
        title,
        vacancyDescription: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
      );
      final questions = (data['questions'] as List<dynamic>).cast<String>();
      if (mounted) {
        setState(() {
          _questions = questions;
          _vacancyTitle = title;
          _currentQuestion = 0;
          _answerCtrls.clear();
          _feedbacks.clear();
          for (int i = 0; i < questions.length; i++) {
            _answerCtrls.add(TextEditingController());
            _feedbacks.add(null);
          }
          _loadingQuestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingQuestions = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_msg(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _getFeedback(int index) async {
    final answer = _answerCtrls[index].text.trim();
    if (answer.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Напишите более развёрнутый ответ')),
      );
      return;
    }

    setState(() => _loadingFeedback = true);
    final token = context.read<AuthProvider>().token!;
    try {
      final feedback = await ApiService.interviewFeedback(
        token,
        question: _questions[index],
        answer: answer,
        vacancyTitle: _vacancyTitle,
      );
      if (mounted) {
        setState(() {
          _feedbacks[index] = feedback;
          _loadingFeedback = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingFeedback = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_msg(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Подготовка к интервью'),
        backgroundColor: cs.surface,
        actions: _questions.isNotEmpty
            ? [
                TextButton.icon(
                  onPressed: () => setState(() {
                    _questions = [];
                    _answerCtrls.clear();
                    _feedbacks.clear();
                  }),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Сначала'),
                ),
              ]
            : null,
      ),
      body: _questions.isEmpty
          ? _buildSetupView(cs)
          : _buildInterviewView(cs),
    );
  }

  Widget _buildSetupView(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  'ИИ-тренер для интервью',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Введите вакансию — ИИ задаст 5 профессиональных вопросов и оценит ваши ответы.',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Вакансия',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              hintText: 'Например: Frontend разработчик, Project Manager...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.work_outline_rounded),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          Text(
            'Описание вакансии (необязательно)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Вставьте описание для более релевантных вопросов...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadingQuestions ? null : _startPrep,
            icon: _loadingQuestions
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.psychology_rounded),
            label: Text(_loadingQuestions
                ? 'Генерирую вопросы...'
                : 'Начать подготовку'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterviewView(ColorScheme cs) {
    final allAnswered =
        _answerCtrls.every((c) => c.text.trim().length >= 5);
    final allFeedback = _feedbacks.every((f) => f != null);

    return Column(
      children: [
        // Progress bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _vacancyTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    'Вопрос ${_currentQuestion + 1} / ${_questions.length}',
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(_questions.length, (i) {
                  final hasAnswer =
                      _answerCtrls[i].text.trim().length >= 5;
                  final hasFeedback = _feedbacks[i] != null;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _currentQuestion = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin:
                            const EdgeInsets.symmetric(horizontal: 2),
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: i == _currentQuestion
                              ? cs.primary
                              : hasFeedback
                                  ? const Color(0xFF16A34A)
                                  : hasAnswer
                                      ? cs.primaryContainer
                                      : cs.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildQuestionView(cs, _currentQuestion),
        ),
        if (!allFeedback || !allAnswered)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentQuestion > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _currentQuestion--),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Назад'),
                    ),
                  ),
                if (_currentQuestion > 0) const SizedBox(width: 12),
                if (_currentQuestion < _questions.length - 1)
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () =>
                          setState(() => _currentQuestion++),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Следующий'),
                    ),
                  ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () => _showSummary(cs),
              icon: const Icon(Icons.emoji_events_rounded),
              label: const Text('Посмотреть итоги'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionView(ColorScheme cs, int index) {
    final question = _questions[index];
    final feedback = _feedbacks[index];
    final ctrl = _answerCtrls[index];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Вопрос от ИИ',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  question,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ваш ответ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Напишите подробный ответ...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          if (feedback == null)
            FilledButton.icon(
              onPressed: _loadingFeedback ||
                      ctrl.text.trim().length < 5
                  ? null
                  : () => _getFeedback(index),
              icon: _loadingFeedback
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.rate_review_rounded),
              label: Text(
                  _loadingFeedback ? 'Оцениваю...' : 'Получить оценку'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )
          else
            _buildFeedbackCard(cs, feedback),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(
      ColorScheme cs, Map<String, dynamic> feedback) {
    final score = feedback['score'] as int? ?? 5;
    final feedbackText = feedback['feedback'] as String? ?? '';
    final tips = (feedback['tips'] as List<dynamic>? ?? []).cast<String>();

    Color scoreColor;
    if (score >= 8) {
      scoreColor = const Color(0xFF16A34A);
    } else if (score >= 5) {
      scoreColor = const Color(0xFFD97706);
    } else {
      scoreColor = cs.error;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: scoreColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded,
                        size: 16, color: scoreColor),
                    const SizedBox(width: 5),
                    Text(
                      '$score / 10',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Оценка ИИ',
                style: TextStyle(
                    fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            feedbackText,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface,
              height: 1.5,
            ),
          ),
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Советы по улучшению:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right_rounded,
                        size: 18, color: scoreColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSummary(ColorScheme cs) {
    final scores = _feedbacks
        .where((f) => f != null)
        .map((f) => f!['score'] as int? ?? 5)
        .toList();
    final avg = scores.isEmpty
        ? 0
        : (scores.reduce((a, b) => a + b) / scores.length).round();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Итоги подготовки',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _vacancyTitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: cs.primary),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primaryContainer,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$avg',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Средняя оценка из 10',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              ...List.generate(_questions.length, (i) {
                final fb = _feedbacks[i];
                final sc = fb?['score'] as int? ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.surfaceContainerHighest,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _questions[i],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurface),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        fb != null ? '$sc/10' : '—',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: fb != null ? cs.primary : cs.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _questions = [];
                    _answerCtrls.clear();
                    _feedbacks.clear();
                  });
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Начать заново'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

