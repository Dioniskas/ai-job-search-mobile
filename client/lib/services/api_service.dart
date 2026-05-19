import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class UnauthorizedException implements Exception {
  const UnauthorizedException();
}

class _CacheEntry {
  final dynamic data;
  final DateTime _time;
  _CacheEntry(this.data) : _time = DateTime.now();
  bool get isExpired =>
      DateTime.now().difference(_time) > const Duration(minutes: 5);
}

class ApiService {
  static const String baseUrl = 'https://ai-job-search-mobile-production.up.railway.app';
  static const _timeout = Duration(seconds: 15);

  // ── In-memory cache ────────────────────────────────────────────────────────
  static final Map<String, _CacheEntry> _cache = {};

  static void _writeCache(String key, dynamic data) =>
      _cache[key] = _CacheEntry(data);

  static T? readCache<T>(String key) {
    final e = _cache[key];
    return e != null ? e.data as T? : null;
  }

  static bool isCacheValid(String key) {
    final e = _cache[key];
    return e != null && !e.isExpired;
  }

  static void clearCache() => _cache.clear();

  static String _vacancyCacheKey(Map<String, String>? filters, int page) =>
      'vacancies:${jsonEncode(filters ?? {})}:$page';

  static Map<String, String> _headers({String? token}) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<http.Response> _safeGet(Uri uri,
      {Map<String, String>? headers}) async {
    try {
      return await http.get(uri, headers: headers).timeout(_timeout);
    } on SocketException {
      throw Exception('Нет подключения к интернету');
    } on HttpException {
      throw Exception('Сервер недоступен. Попробуйте позже.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Сервер недоступен. Попробуйте позже.');
      }
      rethrow;
    }
  }

  static Future<http.Response> _safePost(Uri uri,
      {Map<String, String>? headers, Object? body}) async {
    try {
      return await http
          .post(uri, headers: headers, body: body)
          .timeout(_timeout);
    } on SocketException {
      throw Exception('Нет подключения к интернету');
    } on HttpException {
      throw Exception('Сервер недоступен. Попробуйте позже.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Сервер недоступен. Попробуйте позже.');
      }
      rethrow;
    }
  }

  static Future<http.Response> _safePut(Uri uri,
      {Map<String, String>? headers, Object? body}) async {
    try {
      return await http
          .put(uri, headers: headers, body: body)
          .timeout(_timeout);
    } on SocketException {
      throw Exception('Нет подключения к интернету');
    } on HttpException {
      throw Exception('Сервер недоступен. Попробуйте позже.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Сервер недоступен. Попробуйте позже.');
      }
      rethrow;
    }
  }

  static Future<http.Response> _safePatch(Uri uri,
      {Map<String, String>? headers, Object? body}) async {
    try {
      return await http
          .patch(uri, headers: headers, body: body)
          .timeout(_timeout);
    } on SocketException {
      throw Exception('Нет подключения к интернету');
    } on HttpException {
      throw Exception('Сервер недоступен. Попробуйте позже.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Сервер недоступен. Попробуйте позже.');
      }
      rethrow;
    }
  }

  static Future<http.Response> _safeDelete(Uri uri,
      {Map<String, String>? headers}) async {
    try {
      return await http.delete(uri, headers: headers).timeout(_timeout);
    } on SocketException {
      throw Exception('Нет подключения к интернету');
    } on HttpException {
      throw Exception('Сервер недоступен. Попробуйте позже.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Сервер недоступен. Попробуйте позже.');
      }
      rethrow;
    }
  }

  static Map<String, dynamic> _parse(http.Response response) {
    if (response.statusCode == 401) throw const UnauthorizedException();
    try {
      final body = json.decode(response.body) as Map<String, dynamic>;
      if (body['success'] == true) return body['data'] as Map<String, dynamic>;
      final msg = body['error'] ?? body['message'] ?? response.body;
      throw Exception('[${response.statusCode}] $msg');
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      if (e is UnauthorizedException) rethrow;
      throw Exception('[${response.statusCode}] ${response.body}');
    }
  }

  static Map<String, dynamic> _parsePublic(http.Response response) {
    try {
      final body = json.decode(response.body) as Map<String, dynamic>;
      if (body['success'] == true) return body['data'] as Map<String, dynamic>;
      final msg = body['error'] ?? body['message'] ?? response.body;
      throw Exception('[${response.statusCode}] $msg');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('[${response.statusCode}] ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> _parseStreamed(
      http.StreamedResponse streamed) async {
    final bodyStr = await streamed.stream.bytesToString();
    if (streamed.statusCode == 401) throw const UnauthorizedException();
    try {
      final body = json.decode(bodyStr) as Map<String, dynamic>;
      if (body['success'] == true) return body['data'] as Map<String, dynamic>;
      final msg = body['error'] ?? body['message'] ?? bodyStr;
      throw Exception('[${streamed.statusCode}] $msg');
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      if (e is UnauthorizedException) rethrow;
      throw Exception('[${streamed.statusCode}] $bodyStr');
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: _headers(),
      body: json.encode({'email': email, 'password': password}),
    );
    return _parsePublic(response);
  }

  static Future<Map<String, dynamic>> googleLogin(String idToken) async {
  final response = await _safePost(
    Uri.parse('$baseUrl/api/auth/google/mobile'),
    headers: _headers(),
    body: json.encode({'idToken': idToken}),
  );
  return _parsePublic(response);
}

  static Future<Map<String, dynamic>> googleComplete(
      String email, String name, String picture, String role) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/google/complete'),
      headers: _headers(),
      body: json.encode({'email': email, 'name': name, 'picture': picture, 'role': role}),
    );
    return _parsePublic(response);
  }

static Future<Map<String, dynamic>> updateResume(String token, String id, Map<String, dynamic> data) async {
  final response = await _safePut(
    Uri.parse('$baseUrl/api/resume/$id'),
    headers: _headers(token: token),
    body: json.encode(data),
  );
  return _parse(response);
}

static Future<void> uploadResumePhoto(String token, String resumeId, File photo) async {
  final uri = Uri.parse('$baseUrl/api/resume/$resumeId/photo');
  final request = http.MultipartRequest('POST', uri);
  request.headers['Authorization'] = 'Bearer $token';
  request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
  await request.send();
}

  static Future<Map<String, dynamic>> register(
      String email, String password, String role) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: _headers(),
      body: json.encode({'email': email, 'password': password, 'role': role}),
    );
    return _parsePublic(response);
  }

  static Future<Map<String, dynamic>> refreshToken(
      String refreshToken) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/refresh'),
      headers: _headers(),
      body: json.encode({'refreshToken': refreshToken}),
    );
    // parse manually — no UnauthorizedException loop
    final body = json.decode(response.body) as Map<String, dynamic>;
    if (body['success'] == true) return body['data'] as Map<String, dynamic>;
    throw Exception(body['error'] ?? 'Ошибка обновления токена');
  }

  static Future<void> logout(String token, String storedRefreshToken) async {
    await _safePost(
      Uri.parse('$baseUrl/api/auth/logout'),
      headers: _headers(token: token),
      body: json.encode({'refreshToken': storedRefreshToken}),
    ).catchError((_) {});
  }

  static Future<Map<String, dynamic>> me(String token) async {
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: _headers(token: token),
    );
    return _parse(response);
  }

  // ── FCM token ─────────────────────────────────────────────────────────

  static Future<void> saveFcmToken(String token, String fcmToken) async {
    await _safePost(
      Uri.parse('$baseUrl/api/users/fcm-token'),
      headers: _headers(token: token),
      body: json.encode({'token': fcmToken}),
    ).catchError((_) {});
  }

  static Future<void> deleteFcmToken(String token) async {
    await http
        .delete(
          Uri.parse('$baseUrl/api/users/fcm-token'),
          headers: _headers(token: token),
        )
        .timeout(_timeout)
        .catchError((_) {});
  }

  // ── Seeker profile ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getSeekerProfile(String token,
      {bool useCache = false}) async {
    const key = 'seeker_profile';
    if (useCache && isCacheValid(key)) {
      return readCache<Map<String, dynamic>>(key)!;
    }
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/seeker/profile'),
      headers: _headers(token: token),
    );
    final data = _parse(response);
    _writeCache(key, data);
    return data;
  }

  static Map<String, dynamic>? getCachedSeekerProfile() =>
      readCache<Map<String, dynamic>>('seeker_profile');

  static Future<void> updateSeekerProfile(
      String token, Map<String, dynamic> data) async {
    final response = await _safePut(
      Uri.parse('$baseUrl/api/seeker/profile'),
      headers: _headers(token: token),
      body: json.encode(data),
    );
    _parse(response);
  }

  static Future<void> setSeekerVisibility(
      String token, bool isVisible) async {
    final response = await _safePut(
      Uri.parse('$baseUrl/api/seeker/profile/visibility'),
      headers: _headers(token: token),
      body: json.encode({'isVisible': isVisible}),
    );
    _parse(response);
  }

  static MediaType _mimeFromPath(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':  return MediaType('image', 'png');
      case 'webp': return MediaType('image', 'webp');
      default:     return MediaType('image', 'jpeg');
    }
  }

  // Same logic but also handles bare filenames without directory dots
  static MediaType _mimeFromName(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'png':  return MediaType('image', 'png');
      case 'webp': return MediaType('image', 'webp');
      default:     return MediaType('image', 'jpeg');
    }
  }

  static Future<String> uploadSeekerPhoto(
      String token, Uint8List bytes, String fileName) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/seeker/profile/photo'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    // Use fromBytes so content:// URIs (Android) and temp paths both work
    request.files.add(http.MultipartFile.fromBytes(
      'photo', bytes,
      filename: fileName,
      contentType: _mimeFromName(fileName),
    ));
    try {
      final data = await _parseStreamed(
          await request.send().timeout(_timeout));
      return data['photoUrl'] as String;
    } on SocketException {
      throw Exception('Нет подключения к интернету');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Сервер недоступен. Попробуйте позже.');
      }
      rethrow;
    }
  }

  // ── Employer profile ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getEmployerProfile(String token,
      {bool useCache = false}) async {
    const key = 'employer_profile';
    if (useCache && isCacheValid(key)) {
      return readCache<Map<String, dynamic>>(key)!;
    }
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/employer/profile'),
      headers: _headers(token: token),
    );
    final data = _parse(response);
    _writeCache(key, data);
    return data;
  }

  static Map<String, dynamic>? getCachedEmployerProfile() =>
      readCache<Map<String, dynamic>>('employer_profile');

  static Future<void> updateEmployerProfile(
      String token, Map<String, dynamic> data) async {
    final response = await _safePut(
      Uri.parse('$baseUrl/api/employer/profile'),
      headers: _headers(token: token),
      body: json.encode(data),
    );
    _parse(response);
  }

  static Future<String> uploadEmployerLogo(
      String token, Uint8List bytes, String fileName) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/employer/profile/logo'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'logo', bytes,
      filename: fileName,
      contentType: _mimeFromName(fileName),
    ));
    try {
      final data = await _parseStreamed(
          await request.send().timeout(_timeout));
      return data['logoUrl'] as String;
    } on SocketException {
      throw Exception('Нет подключения к интернету');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Сервер недоступен. Попробуйте позже.');
      }
      rethrow;
    }
  }

  // ── Resume ────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getResumes(String token) async {
    final data = await getResumesPage(token, page: 1);
    return data['data'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getResumesPage(
    String token, {
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/api/resume').replace(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final response = await _safeGet(uri, headers: _headers(token: token));
    return _parse(response);
  }

  static Future<Map<String, dynamic>> uploadResumePdf(
      String token, String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/resume/upload'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(
      'pdf', filePath,
      contentType: MediaType('application', 'pdf'),
    ));
    final data = await _parseStreamed(await request.send().timeout(_timeout));
    return data['resume'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> improveResumePdf(
      String token, String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/resume/improve'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(
      'pdf', filePath,
      contentType: MediaType('application', 'pdf'),
    ));
    final data = await _parseStreamed(await request.send().timeout(_timeout));
    return data['resume'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> generateResumeFromText(
      String token, Map<String, String> formData) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/resume/generate/text'),
      headers: _headers(token: token),
      body: json.encode(formData),
    );
    final data = _parse(response);
    return data['resume'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> generateResumeFromVoice(
      String token, String audioPath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/resume/generate/voice'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(
      'audio', audioPath,
      contentType: MediaType('audio', 'mp4'),
    ));
    final data = await _parseStreamed(await request.send().timeout(_timeout));
    return data['resume'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> scoreResume(
      String token, String resumeId) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/resume/$resumeId/score'),
      headers: _headers(token: token),
    );
    final data = _parse(response);
    return data['resume'] as Map<String, dynamic>;
  }

  static Future<void> setMainResume(String token, String resumeId) async {
    final response = await _safePut(
      Uri.parse('$baseUrl/api/resume/$resumeId/main'),
      headers: _headers(token: token),
    );
    _parse(response);
  }

  static Future<void> deleteResume(String token, String resumeId) async {
    final response = await _safeDelete(
      Uri.parse('$baseUrl/api/resume/$resumeId'),
      headers: _headers(token: token),
    );
    _parse(response);
  }

 
static Future<Map<String, dynamic>> aiImproveResumeText(String token, {
  required String title,
  required String summary,
  required String experience,
  required String education,
  required String skills,
}) async {
  final res = await http.post(
    Uri.parse('$baseUrl/api/resume/improve-text'),
    headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    body: jsonEncode({
      'title': title, 'summary': summary, 'experience': experience,
      'education': education, 'skills': skills,
    }),
  );
  final data = jsonDecode(res.body);
  return data['data'] ?? data;
}

  static Future<Uint8List> downloadResumePdf(String token, String resumeId) async {
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/resume/$resumeId/pdf'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception('Ошибка генерации PDF (${response.statusCode})');
    }
    return response.bodyBytes;
  }

  // ── Vacancies ─────────────────────────────────────────────────────────

  static Future<List<dynamic>> getVacancies(String token,
      {Map<String, String>? filters}) async {
    final result = await getVacanciesPage(token, filters: filters, page: 1);
    return result['data'] as List<dynamic>;
  }

  /// Paginated — returns { data, total, page, totalPages }.
  /// Caches page 1 per filter set for 5 min.
  static Future<Map<String, dynamic>> getVacanciesPage(
    String token, {
    Map<String, String>? filters,
    int page = 1,
    int limit = 20,
  }) async {
    final cacheKey = _vacancyCacheKey(filters, page);
    final params = {
      ...?filters,
      'page': '$page',
      'limit': '$limit',
    };
    final uri =
        Uri.parse('$baseUrl/api/vacancies').replace(queryParameters: params);
    final response = await _safeGet(uri, headers: _headers(token: token));
    final data = _parse(response);
    _writeCache(cacheKey, data);
    return data;
  }

  /// Returns cached vacancy page without network call (stale-while-revalidate).
  static Map<String, dynamic>? getCachedVacanciesPage(
          Map<String, String>? filters, int page) =>
      readCache<Map<String, dynamic>>(_vacancyCacheKey(filters, page));

  static Future<Map<String, dynamic>> getVacancy(
      String token, String id) async {
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/vacancies/$id'),
      headers: _headers(token: token),
    );
    return _parse(response);
  }

  static Future<List<dynamic>> getMapVacancies(String token) async {
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/vacancies/map'),
      headers: _headers(token: token),
    );
    final data = _parse(response);
    return data['vacancies'] as List<dynamic>;
  }

  static Future<List<dynamic>> getEmployerVacancies(String token) async {
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/vacancies/employer/mine'),
      headers: _headers(token: token),
    );
    final data = _parse(response);
    return data['vacancies'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createVacancy(
      String token, Map<String, dynamic> data) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/vacancies'),
      headers: _headers(token: token),
      body: json.encode(data),
    );
    final result = _parse(response);
    return result['vacancy'] as Map<String, dynamic>;
  }

  static Future<void> updateVacancy(
      String token, String id, Map<String, dynamic> data) async {
    final response = await _safePatch(
      Uri.parse('$baseUrl/api/vacancies/$id'),
      headers: _headers(token: token),
      body: json.encode(data),
    );
    _parse(response);
  }

  static Future<void> deleteVacancy(String token, String id) async {
    final response = await _safeDelete(
      Uri.parse('$baseUrl/api/vacancies/$id'),
      headers: _headers(token: token),
    );
    _parse(response);
  }

  static Future<String> aiVacancyDescription(String token,
      {required String title, String? requirements, String? conditions}) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/vacancies/ai-description'),
      headers: _headers(token: token),
      body: json.encode({
        'title': title,
        if (requirements != null && requirements.isNotEmpty)
          'requirements': requirements,
        if (conditions != null && conditions.isNotEmpty)
          'conditions': conditions,
      }),
    );
    final data = _parse(response);
    return data['description'] as String;
  }

  static Future<void> applyToVacancy(
      String token, String vacancyId, String resumeId,
      {String? coverLetter}) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/vacancies/$vacancyId/apply'),
      headers: _headers(token: token),
      body: json.encode({
        'resumeId': resumeId,
        if (coverLetter != null && coverLetter.isNotEmpty)
          'coverLetter': coverLetter,
      }),
    );
    _parse(response);
  }

  // ── AI Services ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> aiMatchPercent(
      String token, String resumeId, String vacancyId) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/ai/match-percent'),
      headers: _headers(token: token),
      body: json.encode({'resumeId': resumeId, 'vacancyId': vacancyId}),
    );
    return _parse(response);
  }

  static Future<List<dynamic>> aiMatchVacancies(
      String token, String resumeId) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/ai/match-vacancies'),
      headers: _headers(token: token),
      body: json.encode({'resumeId': resumeId}),
    );
    final data = _parse(response);
    return data['matches'] as List<dynamic>;
  }

  static Future<List<dynamic>> aiMatchResumes(
      String token, String vacancyId) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/ai/match-resumes'),
      headers: _headers(token: token),
      body: json.encode({'vacancyId': vacancyId}),
    );
    final data = _parse(response);
    return data['matches'] as List<dynamic>;
  }

  static Future<String> aiCoverLetter(
      String token, String resumeId, String vacancyId) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/ai/cover-letter'),
      headers: _headers(token: token),
      body: json.encode({'resumeId': resumeId, 'vacancyId': vacancyId}),
    );
    final data = _parse(response);
    return data['coverLetter'] as String? ?? '';
  }

  static Future<Map<String, dynamic>> aiSalaryEstimate(
      String token, String resumeId) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/ai/salary-estimate'),
      headers: _headers(token: token),
      body: json.encode({'resumeId': resumeId}),
    );
    return _parse(response);
  }

  // ── Applications ──────────────────────────────────────────────────────────

  static Future<List<dynamic>> getSeekerApplications(String token) async {
    final data = await getSeekerApplicationsPage(token, page: 1);
    return data['data'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getSeekerApplicationsPage(
    String token, {
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/api/applications/seeker').replace(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final response = await _safeGet(uri, headers: _headers(token: token));
    return _parse(response);
  }

  static Future<List<dynamic>> getEmployerApplications(String token) async {
    final data = await getEmployerApplicationsPage(token, page: 1);
    return data['data'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getEmployerApplicationsPage(
    String token, {
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/api/applications/employer').replace(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final response = await _safeGet(uri, headers: _headers(token: token));
    return _parse(response);
  }

  static Future<void> updateApplicationStatus(
      String token, String appId, String status) async {
    final response = await _safePatch(
      Uri.parse('$baseUrl/api/applications/$appId/status'),
      headers: _headers(token: token),
      body: json.encode({'status': status}),
    );
    _parse(response);
  }

  static Future<void> deleteApplication(String token, String id) async {
    final response = await _safeDelete(
      Uri.parse('$baseUrl/api/applications/$id'),
      headers: _headers(token: token),
    );
    _parse(response);
  }

  // ── Saved vacancies ───────────────────────────────────────────────────────

  static Future<List<dynamic>> getSavedVacancies(String token) async {
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/saved'),
      headers: _headers(token: token),
    );
    final data = _parse(response);
    return data['saved'] as List<dynamic>;
  }

  static Future<void> saveVacancy(String token, String vacancyId) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/saved/$vacancyId'),
      headers: _headers(token: token),
    );
    _parse(response);
  }

  static Future<void> unsaveVacancy(String token, String vacancyId) async {
    final response = await _safeDelete(
      Uri.parse('$baseUrl/api/saved/$vacancyId'),
      headers: _headers(token: token),
    );
    _parse(response);
  }

  static Future<bool> checkSavedVacancy(String token, String vacancyId) async {
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/saved/$vacancyId/check'),
      headers: _headers(token: token),
    );
    final data = _parse(response);
    return data['isSaved'] as bool? ?? false;
  }

  // ── Subscriptions ─────────────────────────────────────────────────────────

  static Future<List<dynamic>> getSubscriptions(String token) async {
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/subscriptions'),
      headers: _headers(token: token),
    );
    final data = _parse(response);
    return data['subscriptions'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createSubscription(
      String token, Map<String, dynamic> data) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/subscriptions'),
      headers: _headers(token: token),
      body: json.encode(data),
    );
    final result = _parse(response);
    return result['subscription'] as Map<String, dynamic>;
  }

  static Future<void> deleteSubscription(String token, String id) async {
    final response = await _safeDelete(
      Uri.parse('$baseUrl/api/subscriptions/$id'),
      headers: _headers(token: token),
    );
    _parse(response);
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getNotifications(String token) async {
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/notifications'),
      headers: _headers(token: token),
    );
    return _parse(response);
  }

  static Future<void> markNotificationsRead(String token) async {
    final response = await _safePatch(
      Uri.parse('$baseUrl/api/notifications/read'),
      headers: _headers(token: token),
    );
    _parse(response);
  }

  // ── Skill Tests ───────────────────────────────────────────────────────────

  static Future<List<dynamic>> getSkillTests(String token) async {
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/skills/tests'),
      headers: _headers(token: token),
    );
    final data = _parse(response);
    return data['tests'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getSkillTestQuestions(
      String token, String skill) async {
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/skills/tests/$skill'),
      headers: _headers(token: token),
    );
    return _parse(response);
  }

  static Future<Map<String, dynamic>> submitSkillTest(
      String token, String skill, List<int> answers) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/skills/tests/$skill/submit'),
      headers: _headers(token: token),
      body: json.encode({'answers': answers}),
    );
    return _parse(response);
  }

  // ── Interview Prep ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> interviewPrep(
      String token, String vacancyTitle,
      {String? vacancyDescription}) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/ai/interview-prep'),
      headers: _headers(token: token),
      body: json.encode({
        'vacancyTitle': vacancyTitle,
        if (vacancyDescription != null && vacancyDescription.isNotEmpty)
          'vacancyDescription': vacancyDescription,
      }),
    );
    return _parse(response);
  }

  static Future<Map<String, dynamic>> interviewFeedback(
      String token, {
      required String question,
      required String answer,
      required String vacancyTitle,
    }) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/ai/interview-feedback'),
      headers: _headers(token: token),
      body: json.encode({
        'question': question,
        'answer': answer,
        'vacancyTitle': vacancyTitle,
      }),
    );
    return _parse(response);
  }

  // ── Boost ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getBoostStatus(String token) async {
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/boost/status'),
      headers: _headers(token: token),
    );
    return _parse(response);
  }

  static Future<Map<String, dynamic>> boostResume(
      String token, int days) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/boost/resume'),
      headers: _headers(token: token),
      body: json.encode({'days': days}),
    );
    return _parse(response);
  }

  static Future<Map<String, dynamic>> boostVacancy(
      String token, String vacancyId, int days) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/boost/vacancy'),
      headers: _headers(token: token),
      body: json.encode({'vacancyId': vacancyId, 'days': days}),
    );
    return _parse(response);
  }

  // ── Payments ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createPaymePayment(
      String token, String type, {String? vacancyId}) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/payments/payme/create'),
      headers: _headers(token: token),
      body: json.encode({'type': type, 'vacancyId': vacancyId}),
    );
    return _parse(response);
  }

  static Future<Map<String, dynamic>> createClickPayment(
      String token, String type, {String? vacancyId}) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/payments/click/create'),
      headers: _headers(token: token),
      body: json.encode({'type': type, 'vacancyId': vacancyId}),
    );
    return _parse(response);
  }

  static Future<Map<String, dynamic>> completeTestPayment(
      String token, String paymentId) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/payments/test/complete'),
      headers: _headers(token: token),
      body: json.encode({'paymentId': paymentId}),
    );
    return _parse(response);
  }

  static Future<List<dynamic>> getPaymentHistory(String token) async {
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/payments/history'),
      headers: _headers(token: token),
    );
    final data = _parse(response);
    return data as List<dynamic>;
  }

  // ── Reports ───────────────────────────────────────────────────────────────

  static Future<void> createReport(
      String token, String targetId, String targetType, String reason) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/reports'),
      headers: _headers(token: token),
      body: json.encode({
        'targetId': targetId,
        'targetType': targetType,
        'reason': reason,
      }),
    );
    _parse(response);
  }
}
