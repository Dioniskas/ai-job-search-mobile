import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'vacancy_detail_screen.dart';
import 'chat_screen.dart';
import 'filters_screen.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _blue = Color(0xFF2563EB);
const _slate = Color(0xFF64748B);

const _employmentTypes = [
  'FULL_TIME', 'PART_TIME', 'REMOTE', 'CONTRACT', 'INTERNSHIP',
];

// Category chip key → employmentType filter value (null = no filter)
const _categoryFilterMap = <String, String?>{
  'all':        null,
  'near':       null,
  'PART_TIME':  'PART_TIME',
  'CONTRACT':   'CONTRACT',
  'age16':      null,
  'REMOTE':     'REMOTE',
  'INTERNSHIP': 'INTERNSHIP',
};

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

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);

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
      _employmentType = _categoryFilterMap[cat];
    });
    _loadVacancies(reset: true);
  }

  void _applySearch(String query) {
    _searchCtrl.text = query;
    _loadVacancies(reset: true);
  }

  void _openSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SearchSheet(
        initialQuery: _searchCtrl.text,
        onSearch: _applySearch,
      ),
    );
  }

  Future<void> _openFilters() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => FiltersScreen(
          city: _city,
          salaryMin: _salaryMin,
          salaryMax: _salaryMax,
          employmentType: _employmentType,
          experience: _experience,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _city = result['city'] as String? ?? '';
        _salaryMin = result['salaryMin'] as int?;
        _salaryMax = result['salaryMax'] as int?;
        final empType = result['employmentType'] as String?;
        _employmentType = empType;
        _experience = result['experience'] as String?;
        if (empType != null) {
          _selectedCategory = empType;
        } else if (_categoryFilterMap[_selectedCategory] != null) {
          _selectedCategory = 'all';
        }
      });
      _loadVacancies(reset: true);
    }
  }

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
                  child: GestureDetector(
                    onTap: _openSearchSheet,
                    child: IgnorePointer(
                      child: TextField(
                        controller: _searchCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(
                          hintText: 'Должность, компания...',
                          hintStyle: TextStyle(
                              color: Color(0xFF9E9E9E), fontSize: 15),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: Color(0xFF9E9E9E), size: 22),
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Color(0xFFF2F2F7),
                        ),
                      ),
                    ),
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
                  _categoryChip('all',        'Для вас'),
                  const SizedBox(width: 8),
                  _categoryChip('near',       'У дома'),
                  const SizedBox(width: 8),
                  _categoryChip('PART_TIME',  'Подработка'),
                  const SizedBox(width: 8),
                  _categoryChip('CONTRACT',   'Вахта'),
                  const SizedBox(width: 8),
                  _categoryChip('age16',      'От 16 лет'),
                  const SizedBox(width: 8),
                  _categoryChip('REMOTE',     'Удалённая'),
                  const SizedBox(width: 8),
                  _categoryChip('INTERNSHIP', 'Стажировка'),
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
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => _ApplySheet(vacancy: vacancy),
                ),
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

// ── Search Sheet ───────────────────────────────────────────────────────────────

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({
    required this.initialQuery,
    required this.onSearch,
  });
  final String initialQuery;
  final void Function(String) onSearch;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _ctrl = TextEditingController();
  List<String> _history = [];
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.initialQuery;
    _ctrl.addListener(_onChanged);
    _loadHistory();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('search_history') ?? [];
    if (!mounted) return;
    setState(() {
      _history = list;
      _suggestions = _filter(_ctrl.text);
    });
  }

  List<String> _filter(String q) {
    if (q.isEmpty) return _history.take(5).toList();
    return _history
        .where((h) => h.toLowerCase().contains(q.toLowerCase()))
        .take(5)
        .toList();
  }

  void _onChanged() => setState(() => _suggestions = _filter(_ctrl.text));

  Future<void> _submit(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('search_history') ?? [];
    list.remove(query);
    list.insert(0, query);
    if (list.length > 20) list.removeLast();
    await prefs.setStringList('search_history', list);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _ctrl.text.isEmpty;
    final showDefaults = isEmpty && _history.isEmpty;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              decoration: const InputDecoration(
                hintText: 'Должность, компания...',
                hintStyle:
                    TextStyle(color: Color(0xFF9E9E9E), fontSize: 15),
                prefixIcon:
                    Icon(Icons.search_rounded, color: _blue, size: 22),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: _blue),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: _blue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: _blue, width: 2),
                ),
                filled: true,
                fillColor: Color(0xFFF0F4FF),
              ),
            ),
          ),
          // location row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: const [
              Icon(Icons.location_on_rounded, color: _blue, size: 18),
              SizedBox(width: 6),
              Text(
                'Ташкент',
                style: TextStyle(
                  color: _blue,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          ),
          const Divider(height: 1),
          // history header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'История поиска',
                style: const TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (showDefaults) ...[
            _tile('Все вакансии'),
            _tile('Все регионы'),
          ] else
            for (final item in _suggestions) _tile(item),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _tile(String text) => ListTile(
        dense: true,
        leading: const Icon(Icons.history_rounded,
            color: Color(0xFF9E9E9E), size: 20),
        title: Text(text,
            style: const TextStyle(
                fontSize: 15, color: Color(0xFF3C3C43))),
        onTap: () {
          _ctrl.text = text;
          _submit(text);
        },
      );
}

// ── Apply Sheet ────────────────────────────────────────────────────────────────

class _ApplySheet extends StatefulWidget {
  const _ApplySheet({required this.vacancy});
  final dynamic vacancy;

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  List<dynamic> _resumes = [];
  bool _loading = true;
  String? _selectedResumeId;
  bool _showCover = false;
  bool _applying = false;
  final _coverCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadResumes();
  }

  @override
  void dispose() {
    _coverCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadResumes() async {
    try {
      final auth = context.read<AuthProvider>();
      final list = await auth.withAuth((t) => ApiService.getResumes(t));
      if (!mounted) return;
      setState(() {
        _resumes = list;
        _loading = false;
        if (list.isNotEmpty) {
          final main = list.firstWhere(
              (r) => r['isMain'] == true,
              orElse: () => list.first);
          _selectedResumeId = main['id'] as String?;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _apply() async {
    if (_selectedResumeId == null) return;
    setState(() => _applying = true);
    try {
      final auth = context.read<AuthProvider>();
      final vacancyId = widget.vacancy['id'] as String;
      final coverLetter =
          _showCover ? _coverCtrl.text.trim() : null;
      await auth.withAuth((t) => ApiService.applyToVacancy(
            t,
            vacancyId,
            _selectedResumeId!,
            coverLetter: coverLetter,
          ));
      if (!mounted) return;
      Navigator.pop(context);
      final employer =
          widget.vacancy['employer'] as Map<String, dynamic>? ?? {};
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            vacancyId: vacancyId,
            employerId: employer['id'] as String? ?? '',
            vacancyTitle:
                widget.vacancy['title'] as String? ?? 'Вакансия',
            companyName:
                employer['companyName'] as String? ?? '',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _applying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vacancy = widget.vacancy as Map<String, dynamic>;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Text('Отклик на вакансию',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            vacancy['title'] as String? ?? '',
            style:
                const TextStyle(color: _slate, fontSize: 14),
          ),
          const SizedBox(height: 20),

          // ── Resume list ──────────────────────────────────────────────
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_resumes.isEmpty)
            const Text('Нет резюме. Создайте резюме в разделе "Карьера".',
                style: TextStyle(color: _slate))
          else
            ...List.generate(_resumes.length, (i) {
              final r = _resumes[i] as Map<String, dynamic>;
              final rid = r['id'] as String;
              final photoUrl = r['photoUrl'] as String?;
              final title = r['title'] as String? ?? 'Резюме';
              final salaryMin = r['salaryMin'] as int?;
              final salaryMax = r['salaryMax'] as int?;
              String salary = '';
              if (salaryMin != null && salaryMax != null) {
                salary = '$salaryMin – $salaryMax UZS';
              } else if (salaryMin != null) {
                salary = 'от $salaryMin UZS';
              } else if (salaryMax != null) {
                salary = 'до $salaryMax UZS';
              }
              final selected = _selectedResumeId == rid;

              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedResumeId = rid),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected
                          ? _blue
                          : (isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFE5E5EA)),
                      width: selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RadioListTile<String>(
                    value: rid,
                    groupValue: _selectedResumeId,
                    onChanged: (v) =>
                        setState(() => _selectedResumeId = v),
                    activeColor: _blue,
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                    title: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    subtitle: salary.isNotEmpty
                        ? Text(salary,
                            style: const TextStyle(
                                color: _slate, fontSize: 13))
                        : null,
                    secondary: CircleAvatar(
                      radius: 20,
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      backgroundColor:
                          const Color(0xFFDBEAFE),
                      child: photoUrl == null
                          ? Text(
                              title.isNotEmpty
                                  ? title[0].toUpperCase()
                                  : 'R',
                              style: const TextStyle(
                                  color: _blue,
                                  fontWeight: FontWeight.bold))
                          : null,
                    ),
                  ),
                ),
              );
            }),

          const SizedBox(height: 12),

          // ── Cover letter ─────────────────────────────────────────────
          if (_showCover) ...[
            TextField(
              controller: _coverCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Сопроводительное письмо...',
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _blue),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Actions ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  (_applying || _selectedResumeId == null)
                      ? null
                      : _apply,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _applying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Откликнуться',
                      style: TextStyle(fontSize: 16)),
            ),
          ),
          if (!_showCover) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () =>
                    setState(() => _showCover = true),
                child: const Text('Добавить сопроводительное'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
