import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ValueNotifier<Locale> {
  LocaleController._() : super(const Locale('en'));

  static final LocaleController instance = LocaleController._();

  /// Load saved locale from SharedPreferences on app start and load the JSON strings
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('laju_locale') ?? 'en';
      final locale = Locale(saved);
      value = locale;

      // Preload active locale and fallback 'en'
      await AppStrings.loadLanguage(saved);
      if (saved != 'en') {
        await AppStrings.loadLanguage('en');
      }
    } catch (_) {
      // Fallback
      await AppStrings.loadLanguage('en');
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    if (value != newLocale) {
      await AppStrings.loadLanguage(newLocale.languageCode);
      value = newLocale;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('laju_locale', newLocale.languageCode);
      } catch (_) {}
    }
  }

  void toggleLocale() {
    if (value.languageCode == 'en') {
      setLocale(const Locale('id'));
    } else {
      setLocale(const Locale('en'));
    }
  }
}

class AppStrings {
  // Loaded language maps stored in memory for synchronous O(1) access
  static final Map<String, Map<String, String>> _loadedTranslations = {};

  /// Loads a language JSON file from assets/i18n/<lang>.json
  static Future<void> loadLanguage(String langCode) async {
    if (_loadedTranslations.containsKey(langCode)) return;

    try {
      final jsonString = await rootBundle.loadString('assets/i18n/$langCode.json');
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        final map = <String, String>{};
        decoded.forEach((key, val) {
          map[key] = val.toString();
        });
        _loadedTranslations[langCode] = map;
      }
    } catch (e) {
      debugPrint('[AppStrings] Failed to load assets/i18n/$langCode.json: $e');
    }
  }

  /// Synchronous translation lookup
  static String tr(String key, [Locale? locale]) {
    final lang = locale?.languageCode ?? LocaleController.instance.value.languageCode;
    final map = _loadedTranslations[lang];
    if (map != null && map.containsKey(key)) {
      return map[key]!;
    }
    // Fallback to English
    final fallbackMap = _loadedTranslations['en'];
    if (fallbackMap != null && fallbackMap.containsKey(key)) {
      return fallbackMap[key]!;
    }
    return key;
  }
}

extension LocalizationExtension on BuildContext {
  String tr(String key) => AppStrings.tr(key, Localizations.maybeLocaleOf(this));
}
