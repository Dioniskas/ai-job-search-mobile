import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'vacancy_detail_screen.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _blue = Color(0xFF2563EB);
const _slate = Color(0xFF64748B);

const _employmentTypes = [
  'FULL_TIME', 'PART_TIME', 'REMOTE', 'CONTRACT', 'INTERNSHIP',
];

const _employmentLabels = {
  'FULL_TIME': 'Полная занятость',
  'PART_TIME': 'Частичная',
  'REMOTE': 'Удалённо',
  'CONTRACT': 'Контракт',
  'INTERNSHIP': 'Стажировка',
};

const _experienceOptions = ['NO_EXPERIENCE', '1-3', '3-6', '6+'];

const _experienceLabels = {
  'NO_EXPERIENCE': 'Без опыта',
  '1-3': '1–3 года',
  '3-6': '3–6 лет',
  '6+': 'Более 6 лет',
};

// ── Screen ─────────────────────────────────────────────────────────────────────

class SeekerSearchScreen extends StatefulWidget {
  const SeekerSearchScreen({super.key});

  @override
  State<SeekerSearchScreen> createState() => _SeekerSearchScreenState();
}

class _SeekerSearchScreenState extends State<SeekerSearchScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<dynamic> _vacancies = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  String _city = '';
  int? _salaryMin;
  int? _salaryMax;
  String? _employmentType;
  String? _experience;

  String _selectedCategory = 'all';

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(_onSearchChanged);

    final cached = ApiService.getCachedVacanciesPage(null, 1);
    if (cached != null) {
      _vacancies = List<dynamic>.from(cached['data'] as List);
      _totalPages = (cached['totalPages'] as num?)?.toInt() ?? 1;
      _loading = false;
    }
    _loadVacancies(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadVacancies(reset: true);
    });
  }

  AuthProvider get _auth => context.read<AuthProvider>();

  Map<String, String> get _activeFilters {
    final m = <String, String>{};
    final q = _searchCtrl.text.trim();
    if (q.isNotEmpty) m['search'] = q;
    if (_city.isNotEmpty) m['city'] = _city;
    if (_salaryMin != null) m['salaryMin'] = '$_salaryMin';
    if (_salaryMax != null) m['salaryMax'] = '$_salaryMax';
    if (_employmentType != null) m['employmentType'] = _employmentType!;
    if (_experience != null) m['experience'] = _experience!;
    return m;
  }

  bool get _hasFilters =>
      _city.isNotEmpty ||
      _salaryMin != null ||
      _salaryMax != null ||
      _employmentType != null ||
      _experience != null;

  Future<void> _loadVacancies({bool reset = false}) async {
    if (reset) {
      _page = 1;
      if (_vacancies.isEmpty) {
        setState(() { _loading = true; _error = null; });
      } else {
        setState(() => _error = null);
      }
    }
    try {
      final filters = _activeFilters;
      final result = await _auth.withAuth((t) => ApiService.getVacanciesPage(
        t,
        filters: filters.isEmpty ? null : filters,
        page: _page,
      ));
      final list = result['data'] as List<dynamic>;
      final totalPages = (result['totalPages'] as num?)?.toInt() ?? 1;
      if (!mounted) return;
      setState(() {
        _vacancies = (reset || _page == 1)
            ? list
            : [..._vacancies, ...list];
        _totalPages = totalPages;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_vacancies.isEmpty) {
          _error = e is Exception
              ? e.toString().replaceFirst('Exception: ', '')
              : e.toString();
        }
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _totalPages) return;
    _page++;
    setState(() => _loadingMore = true);
    await _loadVacancies();
  }

  void _selectCategory(String cat) {
    setState(() {
      _selectedCategory = cat;
      _employmentType = cat == 'all' ? null : cat;
    });
    _loadVacancies(reset: true);
  }

  static const _salarySliderMax = 5000000.0;

  void _openFilters() {
    var city = _city;
    var empType = _employmentType;
    var exp = _experience;
    var sliderRange = RangeValues(
      (_salaryMin ?? 0).toDouble(),
      (_salaryMax ?? _salarySliderMax).toDouble(),
    );
    final cityCtrl = TextEditingController(text: city);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          String fmt(double v) =>
              v >= _salarySliderMax ? '∞' : '${(v ~/ 1000)} тыс.';
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('Фильтры',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheet(() {
                            city = '';
                            empType = null;
                            exp = null;
                            sliderRange =
                                const RangeValues(0, _salarySliderMax);
                          });
                          cityCtrl.clear();
                        },
                        child: const Text('Сбросить'),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _sheetField(cityCtrl, 'Город', (v) { city = v; }),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Зарплата, сум',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${fmt(sliderRange.start)} — ${fmt(sliderRange.end)}',
                          style: const TextStyle(
                              color: _blue, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    RangeSlider(
                      values: sliderRange,
                      min: 0,
                      max: _salarySliderMax,
                      divisions: 50,
                      activeColor: _blue,
                      onChanged: (v) => setSheet(() => sliderRange = v),
                    ),
                    const SizedBox(height: 8),
                    const Text('Тип занятости',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _employmentTypes
                          .map((t) => FilterChip(
                                label: Text(_employmentLabels[t] ?? t),
                                selected: empType == t,
                                onSelected: (v) =>
                                    setSheet(() => empType = v ? t : null),
                                selectedColor: const Color(0xFFDBEAFE),
                                checkmarkColor: _blue,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Опыт работы',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _experienceOptions
                          .map((e) => FilterChip(
                                label: Text(_experienceLabels[e] ?? e),
                                selected: exp == e,
                                onSelected: (v) =>
                                    setSheet(() => exp = v ? e : null),
                                selectedColor: const Color(0xFFDBEAFE),
                                checkmarkColor: _blue,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          setState(() {
                            _city = cityCtrl.text.trim();
                            _salaryMin = sliderRange.start > 0
                                ? sliderRange.start.toInt()
                                : null;
                            _salaryMax = sliderRange.end < _salarySliderMax
                                ? sliderRange.end.toInt()
                                : null;
                            _employmentType = empType;
                            _experience = exp;
                            if (empType == 'REMOTE') _selectedCategory = 'REMOTE';
                            else if (empType == 'PART_TIME') _selectedCategory = 'PART_TIME';
                            else if (empType == 'CONTRACT') _selectedCategory = 'CONTRACT';
                            else if (empType == null && _selectedCategory != 'all') {
                              _selectedCategory = 'all';
                            }
                          });
                          Navigator.pop(ctx);
                          _loadVacancies(reset: true);
                        },
                        child: const Text('Применить',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ]),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetField(
    TextEditingController ctrl,
    String hint,
    void Function(String) onChanged, {
    TextInputType keyboard = TextInputType.text,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _blue),
          ),
        ),
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            color: barColor,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Должность, компания...',
                      hintStyle: TextStyle(
                          color: Color(0xFF9E9E9E), fontSize: 15),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: Color(0xFF9E9E9E), size: 22),
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Color(0xFFF2F2F7),
                    ),
                    onSubmitted: (_) => _loadVacancies(reset: true),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: _hasFilters,
                  backgroundColor: _blue,
                  child: GestureDetector(
                    onTap: _openFilters,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Color(0xFF3C3C43), size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.favorite_border_rounded,
                        color: Color(0xFF3C3C43), size: 20),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // ── Category chips ────────────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _categoryChip('all', 'Для вас'),
                  const SizedBox(width: 8),
                  _categoryChip('REMOTE', 'Удалённая'),
                  const SizedBox(width: 8),
                  _categoryChip('PART_TIME', 'Подработка'),
                  const SizedBox(width: 8),
                  _categoryChip('CONTRACT', 'Вахта'),
                ]),
              ),
              const SizedBox(height: 12),
            ]),
          ),
          // ── List ──────────────────────────────────────────────────────────
          Expanded(child: _buildList()),
        ]),
      ),
    );
  }

  Widget _categoryChip(String value, String label) {
    final selected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => _selectCategory(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.black : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : const Color(0xFF3C3C43),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _errorWidget(_error!, () => _loadVacancies(reset: true));
    }
    if (_vacancies.isEmpty) return _emptyWidget();

    return RefreshIndicator(
      onRefresh: () => _loadVacancies(reset: true),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(12),
        itemCount: _vacancies.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _vacancies.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final v = _vacancies[index];
          return _VacancyCard(
            vacancy: v,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    VacancyDetailScreen(vacancyId: v['id'] as String),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _errorWidget(String msg, VoidCallback onRetry) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
      const SizedBox(height: 12),
      Text(msg,
          style: const TextStyle(color: _slate),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FilledButton(onPressed: onRetry, child: const Text('Повторить')),
    ]),
  );

  Widget _emptyWidget() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.work_off_outlined, size: 64, color: _slate),
      const SizedBox(height: 12),
      const Text('Вакансии не найдены',
          style: TextStyle(fontSize: 17, color: _slate)),
      const SizedBox(height: 6),
      const Text('Попробуйте изменить фильтры',
          style: TextStyle(color: _slate)),
      const SizedBox(height: 16),
      TextButton(
          onPressed: () => _loadVacancies(reset: true),
          child: const Text('Обновить')),
    ]),
  );
}

// ── Vacancy Card ───────────────────────────────────────────────────────────────

class _VacancyCard extends StatelessWidget {
  const _VacancyCard({required this.vacancy, required this.onTap});
  final dynamic vacancy;
  final VoidCallback onTap;

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _dateLabel(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'Опубликовано сегодня';
    if (diff == 1) return 'Опубликовано вчера';
    return 'Опубликовано $diff дней назад';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final employer = vacancy['employer'] as Map<String, dynamic>?;
    final salaryMin = vacancy['salaryMin'] as int?;
    final salaryMax = vacancy['salaryMax'] as int?;
    final city = vacancy['city'] as String?;
    final empType = vacancy['employmentType'] as String?;
    final experience = vacancy['experience'] as String?;
    final viewCount = vacancy['viewCount'] as int?;
    final boostedUntil = vacancy['boostedUntil'];
    final isVerified = employer?['isVerified'] as bool? ?? false;
    final companyName = employer?['companyName'] as String? ?? '';
    final dateStr = _dateLabel(vacancy['createdAt'] as String?);

    String salary = '';
    if (salaryMin != null && salaryMax != null) {
      salary = '${_fmt(salaryMin)} – ${_fmt(salaryMax)} UZS';
    } else if (salaryMin != null) {
      salary = 'от ${_fmt(salaryMin)} UZS';
    } else if (salaryMax != null) {
      salary = 'до ${_fmt(salaryMax)} UZS';
    }

    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final textColor = isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Views row ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (viewCount != null && viewCount > 0)
                  Text(
                    'Сейчас смотрит $viewCount человек',
                    style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Icon(
                  Icons.favorite_border_rounded,
                  size: 22,
                  color: isDark
                      ? Colors.white54
                      : const Color(0xFF9E9E9E),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Title ──────────────────────────────────────────────────────
            Text(
              vacancy['title'] as String? ?? '',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),

            // ── Salary ─────────────────────────────────────────────────────
            if (salary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                salary,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
            const SizedBox(height: 8),

            // ── Company + verified ─────────────────────────────────────────
            Row(children: [
              Expanded(
                child: Text(
                  companyName,
                  style: const TextStyle(color: _slate, fontSize: 14),
                ),
              ),
              if (isVerified)
                const Icon(Icons.verified_rounded,
                    size: 16, color: _blue),
            ]),

            // ── City ───────────────────────────────────────────────────────
            if (city != null && city.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(city,
                  style: const TextStyle(
                      color: Color(0xFF9E9E9E), fontSize: 13)),
            ],
            const SizedBox(height: 10),

            // ── Tags ───────────────────────────────────────────────────────
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (experience != null)
                _tag(
                  icon: Icons.work_outline_rounded,
                  label: _experienceLabels[experience] ?? experience,
                  isDark: isDark,
                ),
              if (empType != null)
                _tag(
                  icon: Icons.access_time_outlined,
                  label: _employmentLabels[empType] ?? empType,
                  isDark: isDark,
                ),
              if (boostedUntil != null)
                _colorTag(
                  label: 'Премиум вакансия',
                  color: const Color(0xFFEA580C),
                  bg: const Color(0xFFFFF7ED),
                ),
            ]),

            // ── Date ───────────────────────────────────────────────────────
            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(dateStr,
                  style: const TextStyle(
                      color: Color(0xFF9E9E9E), fontSize: 12)),
            ],
            const SizedBox(height: 14),

            // ── Buttons ────────────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Откликнуться'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(
                        color: isDark
                            ? const Color(0xFF3A3A3C)
                            : const Color(0xFFE5E5EA)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Связаться'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _tag(
      {required IconData icon,
      required String label,
      required bool isDark}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: const Color(0xFF9E9E9E)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9E9E9E), fontSize: 13)),
        ]),
      );

  Widget _colorTag(
      {required String label,
      required Color color,
      required Color bg}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      );
}
