import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _blue = Color(0xFF2563EB);
const _bg = Color(0xFFF8FAFC);

const _employmentTypes = [
  ('FULL_TIME', 'Полная занятость'),
  ('PART_TIME', 'Частичная занятость'),
  ('REMOTE', 'Удалённая работа'),
  ('CONTRACT', 'Контракт'),
  ('INTERNSHIP', 'Стажировка'),
];

const _experienceOptions = [
  ('NO_EXPERIENCE', 'Без опыта'),
  ('1-3', '1–3 года'),
  ('3-6', '3–6 лет'),
  ('6+', 'Более 6 лет'),
];

// ── Screen ─────────────────────────────────────────────────────────────────────

class EmployerVacancyCreateScreen extends StatefulWidget {
  const EmployerVacancyCreateScreen({super.key});

  @override
  State<EmployerVacancyCreateScreen> createState() =>
      _EmployerVacancyCreateScreenState();
}

class _EmployerVacancyCreateScreenState
    extends State<EmployerVacancyCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _salaryMinCtrl = TextEditingController();
  final _salaryMaxCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String? _employmentType;
  String? _experience;
  bool _saving = false;
  bool _generatingDesc = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _salaryMinCtrl.dispose();
    _salaryMaxCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  String _token() => context.read<AuthProvider>().token ?? '';

  Future<void> _generateDescription() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала введите название вакансии')),
      );
      return;
    }

    final requirementsCtrl = TextEditingController();
    final conditionsCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: _blue, size: 20),
          const SizedBox(width: 8),
          const Text('ИИ-помощник'),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Вакансия: «$title»',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'ИИ сгенерирует описание вакансии. Добавьте подсказки (необязательно):',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text('Требования к кандидату:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: requirementsCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Опыт, образование, навыки...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Условия работы:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: conditionsCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Зарплата, график, офис/удалёнка...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(10),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _blue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сгенерировать'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _generatingDesc = true);
    try {
      final desc = await ApiService.aiVacancyDescription(
        _token(),
        title: title,
        requirements: requirementsCtrl.text.trim(),
        conditions: conditionsCtrl.text.trim(),
      );
      if (mounted) {
        setState(() { _descCtrl.text = desc; _generatingDesc = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generatingDesc = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
      };
      final sMin = _salaryMinCtrl.text.trim();
      final sMax = _salaryMaxCtrl.text.trim();
      final city = _cityCtrl.text.trim();
      if (sMin.isNotEmpty) body['salaryMin'] = int.tryParse(sMin);
      if (sMax.isNotEmpty) body['salaryMax'] = int.tryParse(sMax);
      if (city.isNotEmpty) body['city'] = city;
      if (_employmentType != null) body['employmentType'] = _employmentType;
      if (_experience != null) body['experience'] = _experience;

      await ApiService.createVacancy(_token(), body);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Вакансия опубликована!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Создать вакансию',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Основное ──────────────────────────────────────────────────
              _sectionHeader('Основное'),
              _labeledField(
                label: 'Название вакансии *',
                child: TextFormField(
                  controller: _titleCtrl,
                  decoration:
                      _deco('Например: Flutter-разработчик, Повар, Менеджер'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Обязательное поле' : null,
                ),
              ),
              const SizedBox(height: 12),
              // Description with AI button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Описание *',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF334155))),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _generatingDesc ? null : _generateDescription,
                    icon: _generatingDesc
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(
                      _generatingDesc ? 'Генерирую...' : 'Заполнить с ИИ',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: _blue,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _descCtrl,
                maxLines: 6,
                decoration:
                    _deco('Опишите обязанности, требования и условия работы...'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Обязательное поле' : null,
              ),

              // ── Зарплата ───────────────────────────────────────────────────
              const SizedBox(height: 20),
              _sectionHeader('Зарплата'),
              Row(children: [
                Expanded(
                  child: _labeledField(
                    label: 'От (сум)',
                    child: TextFormField(
                      controller: _salaryMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _deco('1 000 000'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _labeledField(
                    label: 'До (сум)',
                    child: TextFormField(
                      controller: _salaryMaxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _deco('3 000 000'),
                    ),
                  ),
                ),
              ]),

              // ── Детали ─────────────────────────────────────────────────────
              const SizedBox(height: 20),
              _sectionHeader('Детали'),
              _labeledField(
                label: 'Город',
                child: TextFormField(
                  controller: _cityCtrl,
                  decoration: _deco('Ташкент'),
                ),
              ),
              const SizedBox(height: 12),
              _labeledField(
                label: 'Тип занятости',
                child: DropdownButtonFormField<String>(
                  initialValue: _employmentType,
                  hint: const Text('Выберите тип'),
                  decoration: _deco(null),
                  items: _employmentTypes
                      .map((t) => DropdownMenuItem(
                            value: t.$1,
                            child: Text(t.$2),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _employmentType = v),
                ),
              ),
              const SizedBox(height: 12),
              _labeledField(
                label: 'Опыт работы',
                child: DropdownButtonFormField<String>(
                  initialValue: _experience,
                  hint: const Text('Выберите опыт'),
                  decoration: _deco(null),
                  items: _experienceOptions
                      .map((e) => DropdownMenuItem(
                            value: e.$1,
                            child: Text(e.$2),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _experience = v),
                ),
              ),

              // ── Save button ─────────────────────────────────────────────────
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Опубликовать вакансию',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A))),
  );

  Widget _labeledField({required String label, required Widget child}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF334155))),
        const SizedBox(height: 4),
        child,
      ]);

  InputDecoration _deco(String? hint) => InputDecoration(
    hintText: hint,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _blue),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.red),
    ),
    filled: true,
    fillColor: Colors.white,
  );
}
