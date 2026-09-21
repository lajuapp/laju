import 'package:flutter/material.dart';

class ThemeModeController extends ValueNotifier<ThemeMode> {
  ThemeModeController._() : super(ThemeMode.system);

  static final ThemeModeController instance = ThemeModeController._();

  void setThemeMode(ThemeMode mode) {
    if (value != mode) {
      value = mode;
      notifyListeners();
    }
  }

  bool isDarkMode(BuildContext context) {
    if (value == ThemeMode.dark) return true;
    if (value == ThemeMode.light) return false;
    // system default
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
}
