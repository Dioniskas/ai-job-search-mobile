import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _blue = Color(0xFF2563EB);
const _bg = Color(0xFFF2F2F7);
const _sectionLabel = TextStyle(
  color: Color(0xFF8E8E93),
  fontSize: 13,
  fontWeight: FontWeight.w500,
);

class FiltersScreen extends StatefulWidget {
  const FiltersScreen({
    super.key,
    this.city,
    this.salaryMin,
    this.salaryMax,
    this.employmentType,
    this.experience,
  });

  final String? city;
  final int? salaryMin;
  final int? salaryMax;
  final String? employmentType;
  final String? experience;

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  late final TextEditingController _cityCtrl;
  late final TextEditingController _salaryCtrl;

  String _publishPeriod = 'all';
  Set<String> _employmentTypes = {};
  String? _experience;
  String _workFormat = '';

  @override
  void initState() {
    super.initState();
    _cityCtrl = TextEditingController(text: widget.city ?? '');
    _salaryCtrl = TextEditingController(
      text: widget.salaryMin != null ? '${widget.salaryMin}' : '',
    );
    if (widget.employmentType != null) {
      _employmentTypes = {widget.employmentType!};
    }
    _experience = widget.experience;
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _cityCtrl.clear();
      _salaryCtrl.clear();
      _publishPeriod = 'all';
      _employmentTypes = {};
      _experience = null;
      _workFormat = '';
    });
  }

  void _apply() {
    final salaryMinVal = int.tryParse(_salaryCtrl.text.trim());
    Navigator.pop(context, {
      'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      'salaryMin': salaryMinVal,
      'salaryMax': null,
      'employmentType':
          _employmentTypes.isEmpty ? null : _employmentTypes.first,
      'experience': _experience,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Фильтры',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text(
              'Сбросить',
              style: TextStyle(color: _blue, fontSize: 15),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Section(
                    title: 'Время публикации',
                    child: _ChipGroup(
                      options: const {
                        'all': 'За всё время',
                        'week': 'За неделю',
                        '3days': 'За три дня',
                        'day': 'За сутки',
                      },
                      selected: {_publishPeriod},
                      multiSelect: false,
                      onChanged: (v) => setState(() => _publishPeriod = v.first),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Регион',
                    child: _CityField(controller: _cityCtrl),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Уровень дохода',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _salaryCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _fieldDecoration('От'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'сум',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        _ChipGroup(
                          options: const {
                            'month': 'За месяц',
                            'hour': 'За час',
                          },
                          selected: const {},
                          multiSelect: false,
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Тип занятости',
                    child: _ChipGroup(
                      options: const {
                        'FULL_TIME': 'Полная занятость',
                        'PART_TIME_SUB': 'Подработка',
                        'PART_TIME': 'Частичная',
                        'CONTRACT': 'Вахта',
                        'REMOTE': 'Удалённая',
                      },
                      selected: _employmentTypes,
                      multiSelect: true,
                      onChanged: (v) => setState(() => _employmentTypes = v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Опыт работы',
                    child: _ChipGroup(
                      options: const {
                        'NO_EXPERIENCE': 'Нет опыта',
                        '1-3': 'От 1 до 3 лет',
                        '3-6': 'От 3 до 6 лет',
                        '6+': 'Более 6 лет',
                      },
                      selected: _experience != null ? {_experience!} : {},
                      multiSelect: false,
                      onChanged: (v) =>
                          setState(() => _experience = v.isEmpty ? null : v.first),
                      allowDeselect: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Формат работы',
                    child: _ChipGroup(
                      options: const {
                        'onsite': 'На месте работодателя',
                        'remote': 'Удалённо',
                        'hybrid': 'Гибрид',
                      },
                      selected: _workFormat.isEmpty ? {} : {_workFormat},
                      multiSelect: false,
                      onChanged: (v) =>
                          setState(() => _workFormat = v.isEmpty ? '' : v.first),
                      allowDeselect: true,
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _apply,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Показать вакансии',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section wrapper ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _sectionLabel),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Chip group ─────────────────────────────────────────────────────────────────

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.multiSelect,
    required this.onChanged,
    this.allowDeselect = false,
  });

  final Map<String, String> options;
  final Set<String> selected;
  final bool multiSelect;
  final bool allowDeselect;
  final void Function(Set<String>) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((e) {
        final active = selected.contains(e.key);
        return GestureDetector(
          onTap: () {
            if (multiSelect) {
              final next = Set<String>.from(selected);
              active ? next.remove(e.key) : next.add(e.key);
              onChanged(next);
            } else {
              if (active && allowDeselect) {
                onChanged({});
              } else {
                onChanged({e.key});
              }
            }
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    active ? Colors.black : const Color(0xFFD1D1D6),
              ),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                fontSize: 14,
                color: active ? Colors.white : const Color(0xFF3C3C43),
                fontWeight:
                    active ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── City field ─────────────────────────────────────────────────────────────────

class _CityField extends StatefulWidget {
  const _CityField({required this.controller});
  final TextEditingController controller;

  @override
  State<_CityField> createState() => _CityFieldState();
}

class _CityFieldState extends State<_CityField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: _fieldDecoration('Город').copyWith(
        suffixIcon: widget.controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: Color(0xFF8E8E93)),
                onPressed: widget.controller.clear,
              )
            : null,
      ),
    );
  }
}

// ── Shared decoration ──────────────────────────────────────────────────────────

InputDecoration _fieldDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFAEAEB2), fontSize: 15),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFF2F2F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _blue),
      ),
    );
