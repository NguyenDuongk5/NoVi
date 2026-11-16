import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NoviThemeController extends ChangeNotifier {
  NoviThemeController._();
  static final instance = NoviThemeController._();
  static const _preferenceKey = 'novi_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> initialize() async {
    final value = (await SharedPreferences.getInstance()).getString(
      _preferenceKey,
    );
    _mode = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode value) async {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(
      _preferenceKey,
      value.name,
    );
  }

  Future<void> toggle(Brightness effectiveBrightness) => setMode(
    effectiveBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
  );
}
