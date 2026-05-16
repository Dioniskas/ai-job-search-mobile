import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _keyAccessToken  = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyRole         = 'user_role';

  final _storage = const FlutterSecureStorage();

  String? _token;
  String? _refreshToken;
  String? _role;
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  String? get token          => _token;
  String? get role           => _role;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated   => _token != null;
  bool get isLoading         => _isLoading;

  Future<void> init() async {
    _token        = await _storage.read(key: _keyAccessToken);
    _refreshToken = await _storage.read(key: _keyRefreshToken);
    _role         = await _storage.read(key: _keyRole);
    _isLoading    = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    try {
      final data = await ApiService.login(email, password);
      await _saveSession(data);
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  Future<String?> register(String email, String password, String role) async {
    try {
      final data = await ApiService.register(email, password, role);
      await _saveSession(data);
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  Future<void> logout() async {
    if (_token != null) {
      await FcmService.deleteToken(_token!);
      if (_refreshToken != null) await ApiService.logout(_token!, _refreshToken!);
    }
    _token        = null;
    _refreshToken = null;
    _role         = null;
    _user         = null;
    await _storage.deleteAll();
    notifyListeners();
  }

  /// Wraps an API call with automatic token refresh on 401.
  /// Usage: authProvider.withAuth((t) => ApiService.someCall(t, ...))
  Future<T> withAuth<T>(Future<T> Function(String token) call) async {
    if (_token == null) throw Exception('Не авторизован');
    try {
      return await call(_token!);
    } on UnauthorizedException {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        await _clearSession();
        throw Exception('Сессия истекла. Войдите снова.');
      }
      return await call(_token!);
    }
  }

  Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    try {
      final data = await ApiService.refreshToken(_refreshToken!);
      _token        = data['accessToken'] as String;
      _refreshToken = data['refreshToken'] as String;
      await _storage.write(key: _keyAccessToken,  value: _token);
      await _storage.write(key: _keyRefreshToken, value: _refreshToken);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    _token        = data['accessToken']  as String;
    _refreshToken = data['refreshToken'] as String;
    _user         = data['user']         as Map<String, dynamic>;
    _role         = _user!['role']       as String;
    await _storage.write(key: _keyAccessToken,  value: _token);
    await _storage.write(key: _keyRefreshToken, value: _refreshToken);
    await _storage.write(key: _keyRole,         value: _role);
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _token = _refreshToken = _role = _user = null;
    await _storage.deleteAll();
    notifyListeners();
  }

  String _message(Object e) =>
      e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';
}
