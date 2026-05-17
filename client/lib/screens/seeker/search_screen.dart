import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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

class _SeekerSearchScreenState extends State<SeekerSearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Vacancy list state
  List<dynamic> _vacancies = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  // Filters
  String _city = '';
  int? _salaryMin;
  int? _salaryMax;
  String? _employmentType;
  String? _experience;

  // Sort
  String _sortBy = 'date'; // 'date' | 'salary' | 'relevance'

  // Map / Saved
  List<dynamic> _mapVacancies = [];
  bool _mapLoading = false;
  List<dynamic> _savedVacancies = [];
  bool _savedLoading = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(_onTabChanged);
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(_onSearchChanged);

    // Show cached page 1 immediately while network loads
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
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tab.indexIsChanging) return;
    if (_tab.index == 1 && _mapVacancies.isEmpty && !_mapLoading) _loadMap();
    if (_tab.index == 2) _loadSaved();
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
  String _token() => _auth.token ?? '';

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

  List<dynamic> get _sortedVacancies {
    final list = List<dynamic>.from(_vacancies);
    if (_sortBy == 'salary') {
      list.sort((a, b) {
        final aMax = (a['salaryMax'] as int?) ?? (a['salaryMin'] as int?) ?? 0;
        final bMax = (b['salaryMax'] as int?) ?? (b['salaryMin'] as int?) ?? 0;
        return bMax.compareTo(aMax);
      });
    } else if (_sortBy == 'relevance') {
      list.sort((a, b) {
        final aB = a['boostedUntil'] != null ? 1 : 0;
        final bB = b['boostedUntil'] != null ? 1 : 0;
        return bB.compareTo(aB);
      });
    }
    // 'date' — server already returns sorted by date
    return list;
  }

  Future<void> _loadVacancies({bool reset = false}) async {
    if (reset) {
      _page = 1;
      if (_vacancies.isEmpty) {
        setState(() { _loading = true; _error = null; });
      } else {
        // Already have cached data — refresh silently
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
        if (reset || _page == 1) {
          _vacancies = list;
        } else {
          _vacancies = [..._vacancies, ...list];
        }
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

  Future<void> _loadMap() async {
    setState(() => _mapLoading = true);
    try {
      final list = await _auth.withAuth((t) => ApiService.getMapVacancies(t));
      if (mounted) setState(() { _mapVacancies = list; _mapLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _mapLoading = false);
    }
  }

  Future<void> _loadSaved() async {
    setState(() => _savedLoading = true);
    try {
      final list = await _auth.withAuth((t) => ApiService.getSavedVacancies(t));
      if (mounted) setState(() { _savedVacancies = list; _savedLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _savedLoading = false);
    }
  }

  bool get _hasFilters =>
      _city.isNotEmpty || _salaryMin != null ||
      _salaryMax != null || _employmentType != null || _experience != null;

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
          String fmt(double v) => v >= _salarySliderMax
              ? '∞'
              : '${(v ~/ 1000)} тыс.';
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('Фильтры',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setSheet(() {
                        city = '';
                        empType = null; exp = null;
                        sliderRange = const RangeValues(0, _salarySliderMax);
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
                      style: const TextStyle(color: _blue, fontWeight: FontWeight.w600),
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
                  children: _employmentTypes.map((t) => FilterChip(
                    label: Text(_employmentLabels[t] ?? t),
                    selected: empType == t,
                    onSelected: (v) => setSheet(() => empType = v ? t : null),
                    selectedColor: const Color(0xFFDBEAFE),
                    checkmarkColor: _blue,
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Опыт работы',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _experienceOptions.map((e) => FilterChip(
                    label: Text(_experienceLabels[e] ?? e),
                    selected: exp == e,
                    onSelected: (v) => setSheet(() => exp = v ? e : null),
                    selectedColor: const Color(0xFFDBEAFE),
                    checkmarkColor: _blue,
                  )).toList(),
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
                            ? sliderRange.start.toInt() : null;
                        _salaryMax = sliderRange.end < _salarySliderMax
                            ? sliderRange.end.toInt() : null;
                        _employmentType = empType;
                        _experience = exp;
                      });
                      Navigator.pop(ctx);
                      _loadVacancies(reset: true);
                    },
                    child: const Text('Применить', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _sortChip(String value, String label) {
    final selected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _sortBy = value),
      selectedColor: const Color(0xFFDBEAFE),
      checkmarkColor: _blue,
      labelStyle: TextStyle(
        color: selected ? _blue : _slate,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _blue),
          ),
        ),
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Поиск вакансий',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          labelColor: _blue,
          unselectedLabelColor: _slate,
          indicatorColor: _blue,
          tabs: const [
            Tab(icon: Icon(Icons.list_rounded), text: 'Список'),
            Tab(icon: Icon(Icons.map_rounded), text: 'Карта'),
            Tab(icon: Icon(Icons.favorite_rounded), text: 'Избранное'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_buildList(), _buildMap(), _buildSaved()],
      ),
    );
  }

  // ── List tab ──────────────────────────────────────────────────────────────────

  Widget _buildList() {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Container(
        color: cs.surface,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Должность, компания...',
                prefixIcon: const Icon(Icons.search_rounded, color: _slate),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
              ),
              // Search fires via debounce listener, not onSubmitted
              onSubmitted: (_) => _loadVacancies(reset: true),
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: _hasFilters,
            backgroundColor: _blue,
            child: IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: _openFilters,
              style: IconButton.styleFrom(
                backgroundColor: cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
      ),
      // ── Sort chips ──────────────────────────────────────────────────────────
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          _sortChip('date', 'По дате'),
          const SizedBox(width: 8),
          _sortChip('salary', 'По зарплате'),
          const SizedBox(width: 8),
          _sortChip('relevance', 'По релевантности'),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorWidget(_error!, () => _loadVacancies(reset: true))
                : _vacancies.isEmpty
                    ? _emptyWidget()
                    : RefreshIndicator(
                        onRefresh: () => _loadVacancies(reset: true),
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(12),
                          itemCount: _sortedVacancies.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _sortedVacancies.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              );
                            }
                            final v = _sortedVacancies[index];
                            return _VacancyCard(
                              vacancy: v,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VacancyDetailScreen(
                                    vacancyId: v['id'] as String,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    ]);
  }

  // ── Map tab ───────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    if (_mapLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    const center = LatLng(41.2995, 69.2401); // Tashkent

    final markers = _mapVacancies
        .where((v) => v['lat'] != null && v['lng'] != null)
        .map((v) {
          final lat = (v['lat'] as num).toDouble();
          final lng = (v['lng'] as num).toDouble();
          final id = v['id'] as String;
          return Marker(
            point: LatLng(lat, lng),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VacancyDetailScreen(vacancyId: id),
                ),
              ),
              child: const Icon(Icons.location_pin, color: _blue, size: 36),
            ),
          );
        })
        .toList();

    if (markers.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.map_outlined, size: 64, color: _slate),
          const SizedBox(height: 12),
          const Text('Вакансии на карте не найдены',
              style: TextStyle(color: _slate, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Работодатели ещё не указали адреса',
              style: TextStyle(color: _slate, fontSize: 13)),
        ]),
      );
    }

    return FlutterMap(
      options: const MapOptions(initialCenter: center, initialZoom: 12.0),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.client',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  // ── Saved tab ─────────────────────────────────────────────────────────────────

  Widget _buildSaved() {
    if (_savedLoading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
    if (_savedVacancies.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.favorite_border_rounded, size: 64, color: _slate),
          const SizedBox(height: 12),
          const Text('Нет избранных вакансий',
              style: TextStyle(fontSize: 17, color: _slate)),
          const SizedBox(height: 6),
          const Text('Нажмите ❤ на вакансии, чтобы сохранить',
              style: TextStyle(color: _slate, fontSize: 13)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSaved,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _savedVacancies.length,
        itemBuilder: (context, i) {
          final vacancy = (_savedVacancies[i]['vacancy']
              as Map<String, dynamic>?) ?? {};
          return _VacancyCard(
            vacancy: vacancy,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VacancyDetailScreen(
                    vacancyId: vacancy['id'] as String),
              ),
            ).then((_) => _loadSaved()),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final employer = vacancy['employer'] as Map<String, dynamic>?;
    final salaryMin = vacancy['salaryMin'] as int?;
    final salaryMax = vacancy['salaryMax'] as int?;
    final city = vacancy['city'] as String?;
    final empType = vacancy['employmentType'] as String?;
    final createdAt = vacancy['createdAt'] as String?;

    String salary = '';
    if (salaryMin != null && salaryMax != null) {
      salary = '${salaryMin ~/ 1000}–${salaryMax ~/ 1000} тыс. сум';
    } else if (salaryMin != null) {
      salary = 'от ${salaryMin ~/ 1000} тыс. сум';
    } else if (salaryMax != null) {
      salary = 'до ${salaryMax ~/ 1000} тыс. сум';
    }

    String dateStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        dateStr = '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      color: cs.surfaceContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _logoAvatar(employer?['logoUrl'] as String?),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vacancy['title'] as String? ?? '',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        employer?['companyName'] as String? ?? '',
                        style: const TextStyle(color: _slate, fontSize: 13),
                      ),
                    ]),
              ),
            ]),
            if (salary.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(salary,
                  style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (city != null) _chip(Icons.location_on_outlined, city),
                if (empType != null)
                  _chip(Icons.access_time_outlined,
                      _employmentLabels[empType] ?? empType),
                if (dateStr.isNotEmpty)
                  _chip(Icons.calendar_today_outlined, dateStr),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _logoAvatar(String? url) {
    if (url != null) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFEFF6FF),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            placeholder: (_, __) => const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            errorWidget: (_, __, ___) => const Icon(
              Icons.business_rounded,
              color: _blue,
              size: 22,
            ),
          ),
        ),
      );
    }
    return const CircleAvatar(
      radius: 22,
      backgroundColor: Color(0xFFEFF6FF),
      child: Icon(Icons.business_rounded, color: _blue, size: 22),
    );
  }

  Widget _chip(IconData icon, String label) => Builder(
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: _slate),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: _slate, fontSize: 12)),
        ]),
      );
    },
  );
}
