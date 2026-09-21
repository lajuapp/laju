import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockController extends ChangeNotifier {
  AppLockController._();
  static final AppLockController instance = AppLockController._();

  bool _isAppLockEnabled = false; // Default disabled
  bool _isBiometricEnabled = true;
  String _autoLockTimeout = '15_min'; // 'immediately', '1_min', '15_min', '1_hour'
  String _pinCode = '123456';
  bool _hasSetPin = false;
  bool _showNotificationPreview = false;
  bool _isCurrentlyLocked = false;
  DateTime? _lastPausedTime;
  bool _isExternalIntentActive = false;

  bool get isAppLockEnabled => _isAppLockEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  String get autoLockTimeout => _autoLockTimeout;
  String get pinCode => _pinCode;
  bool get hasSetPin => _hasSetPin;
  bool get showNotificationPreview => _showNotificationPreview;
  bool get isCurrentlyLocked => _isAppLockEnabled && _isCurrentlyLocked;

  /// Loads security lock preferences from persistent storage
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAppLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      _isBiometricEnabled = prefs.getBool('app_lock_biometric') ?? true;
      _autoLockTimeout = prefs.getString('app_lock_timeout') ?? '15_min';
      final savedPin = prefs.getString('app_lock_pin');
      if (savedPin != null && savedPin.length == 6) {
        _pinCode = savedPin;
        _hasSetPin = true;
      } else {
        _hasSetPin = prefs.getBool('app_lock_has_pin') ?? false;
      }
      _showNotificationPreview = prefs.getBool('app_lock_show_preview') ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('[AppLockController] init error: $e');
    }
  }

  bool verifyPin(String input) {
    return _hasSetPin && input == _pinCode;
  }

  void markExternalIntentStarted() {
    _isExternalIntentActive = true;
  }

  void markExternalIntentFinished() {
    _isExternalIntentActive = false;
    _lastPausedTime = null; // Clear pause time so returning from camera/gallery never locks
  }

  void unlockApp() {
    if (_isCurrentlyLocked) {
      _isCurrentlyLocked = false;
      notifyListeners();
    }
  }

  void lockApp() {
    if (!_isCurrentlyLocked) {
      _isCurrentlyLocked = true;
      notifyListeners();
    }
  }

  void onAppPaused() {
    if (_isExternalIntentActive) return;
    _lastPausedTime = DateTime.now();
  }

  void onAppResumed() {
    if (_isExternalIntentActive) {
      _isExternalIntentActive = false;
      _lastPausedTime = null;
      return;
    }
    if (!_isAppLockEnabled) return;
    if (_lastPausedTime == null) return;

    final elapsed = DateTime.now().difference(_lastPausedTime!);
    int thresholdSeconds = 900;
    if (_autoLockTimeout == 'immediately') {
      thresholdSeconds = 15; // At least 15 seconds buffer so camera/permission/quick switch never locks
    } else if (_autoLockTimeout == '1_min') {
      thresholdSeconds = 60;
    } else if (_autoLockTimeout == '15_min') {
      thresholdSeconds = 900;
    } else if (_autoLockTimeout == '1_hour') {
      thresholdSeconds = 3600;
    }

    if (elapsed.inSeconds >= thresholdSeconds) {
      lockApp();
    }
  }

  Future<void> setAppLockEnabled(bool value) async {
    if (_isAppLockEnabled != value) {
      _isAppLockEnabled = value;
      if (!value) {
        _isCurrentlyLocked = false;
      }
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('app_lock_enabled', value);
      } catch (_) {}
    }
  }

  Future<void> setBiometricEnabled(bool value) async {
    if (_isBiometricEnabled != value) {
      _isBiometricEnabled = value;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('app_lock_biometric', value);
      } catch (_) {}
    }
  }

  Future<void> setAutoLockTimeout(String value) async {
    if (_autoLockTimeout != value) {
      _autoLockTimeout = value;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_lock_timeout', value);
      } catch (_) {}
    }
  }

  Future<void> setPinCode(String newPin) async {
    if (newPin.length == 6) {
      _pinCode = newPin;
      _hasSetPin = true;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_lock_pin', newPin);
        await prefs.setBool('app_lock_has_pin', true);
      } catch (_) {}
    }
  }

  Future<void> setShowNotificationPreview(bool value) async {
    if (_showNotificationPreview != value) {
      _showNotificationPreview = value;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('app_lock_show_preview', value);
      } catch (_) {}
    }
  }
}
