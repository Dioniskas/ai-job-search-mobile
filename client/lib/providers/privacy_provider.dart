import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyProvider extends ChangeNotifier {
  static const _key = 'privacy_accepted_v1';

  bool _accepted = false;
  bool _initialized = false;

  bool get isAccepted => _accepted;
  bool get initialized => _initialized;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accepted = prefs.getBool(_key) ?? false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    _accepted = true;
    notifyListeners();
  }
}
