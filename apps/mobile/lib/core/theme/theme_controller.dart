import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeController extends ValueNotifier<ThemeMode> {
  ThemeModeController._() : super(ThemeMode.system);

  static final ThemeModeController instance = ThemeModeController._();

  /// Load saved theme from SharedPreferences on app start
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('laju_theme_mode') ?? 'system';
      ThemeMode mode;
      switch (saved) {
        case 'dark':
          mode = ThemeMode.dark;
          break;
        case 'light':
          mode = ThemeMode.light;
          break;
        default:
          mode = ThemeMode.system;
      }
      if (value != mode) {
        value = mode;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (value != mode) {
      value = mode;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        String key;
        switch (mode) {
          case ThemeMode.dark:
            key = 'dark';
            break;
          case ThemeMode.light:
            key = 'light';
            break;
          default:
            key = 'system';
        }
        await prefs.setString('laju_theme_mode', key);
      } catch (_) {}
    }
  }

  bool isDarkMode(BuildContext context) {
    if (value == ThemeMode.dark) return true;
    if (value == ThemeMode.light) return false;
    // system default
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
}
