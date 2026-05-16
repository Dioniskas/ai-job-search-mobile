import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeProvider extends ChangeNotifier {
  static const _keyTheme = 'app_theme_mode';

  final _storage = const FlutterSecureStorage();

  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoading = true;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    final saved = await _storage.read(key: _keyTheme);
    if (saved == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    _themeMode = value ? ThemeMode.dark : ThemeMode.light;
    await _storage.write(key: _keyTheme, value: value ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> toggle() => setDark(!isDark);
}
