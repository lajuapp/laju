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
  DateTime? _lastUnlockedTime;
  bool _isExternalIntentActive = false;
  bool _isBiometricPromptActive = false;

  bool get isAppLockEnabled => _isAppLockEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  String get autoLockTimeout => _autoLockTimeout;
  String get pinCode => _pinCode;
  bool get hasSetPin => _hasSetPin;
  bool get showNotificationPreview => _showNotificationPreview;
  bool get isCurrentlyLocked => _isAppLockEnabled && _isCurrentlyLocked;
  bool get isBiometricPromptActive => _isBiometricPromptActive;

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

      // On cold start, if App Lock is enabled, lock immediately
      if (_isAppLockEnabled) {
        _isCurrentlyLocked = true;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AppLockController] init error: $e');
    }
  }

  bool verifyPin(String input) {
    return _hasSetPin && input == _pinCode;
  }

  void markBiometricAuthStarted() {
    _isBiometricPromptActive = true;
  }

  void markBiometricAuthFinished() {
    _isBiometricPromptActive = false;
    _lastPausedTime = null;
  }

  void markExternalIntentStarted() {
    _isExternalIntentActive = true;
  }

  void markExternalIntentFinished() {
    _isExternalIntentActive = false;
    _lastPausedTime = null; // Clear pause time so returning from camera/gallery never locks
  }

  void unlockApp() {
    _lastPausedTime = null;
    _lastUnlockedTime = DateTime.now();
    if (_isCurrentlyLocked) {
      _isCurrentlyLocked = false;
      notifyListeners();
    }
  }

  void lockApp() {
    if (!_isAppLockEnabled) return;
    if (_isBiometricPromptActive) return;
    if (_isExternalIntentActive) return;
    // Prevent immediate re-locking right after successful unlock (5s grace period)
    if (_lastUnlockedTime != null &&
        DateTime.now().difference(_lastUnlockedTime!).inSeconds < 5) {
      return;
    }

    if (!_isCurrentlyLocked) {
      _isCurrentlyLocked = true;
      notifyListeners();
    }
  }

  void onAppPaused() {
    // If the app is pausing because of native BiometricPrompt or Camera/Gallery intent, ignore it
    if (_isExternalIntentActive || _isBiometricPromptActive) return;
    _lastPausedTime = DateTime.now();
  }

  void onAppResumed() {
    if (_isExternalIntentActive || _isBiometricPromptActive) {
      _isExternalIntentActive = false;
      _lastPausedTime = null;
      return;
    }
    if (!_isAppLockEnabled) {
      _lastPausedTime = null;
      return;
    }
    if (_lastPausedTime == null) return;

    final pausedAt = _lastPausedTime!;
    _lastPausedTime = null; // ALWAYS consume and clear so it can NEVER be evaluated twice

    // If app is already locked, no need to lock again
    if (_isCurrentlyLocked) return;

    // Check if within recent unlock grace period
    if (_lastUnlockedTime != null &&
        DateTime.now().difference(_lastUnlockedTime!).inSeconds < 5) {
      return;
    }

    final elapsed = DateTime.now().difference(pausedAt);
    int thresholdSeconds = 900;
    if (_autoLockTimeout == 'immediately') {
      thresholdSeconds = 2; // Immediately locks after user truly switched away (>2s in background)
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
