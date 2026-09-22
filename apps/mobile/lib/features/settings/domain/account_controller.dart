import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/core.dart';

class PasskeyItem {
  final String id;
  final String name;
  final String device;
  final DateTime createdAt;

  PasskeyItem({
    required this.id,
    required this.name,
    required this.device,
    required this.createdAt,
  });
}

class AccountController extends ChangeNotifier {
  AccountController._();
  static final AccountController instance = AccountController._();

  // User Profile
  String _userName = 'User';
  String _phoneNumber = '';
  String _about = 'Available';
  String _avatarUrl = '';
  int _trustScore = 100;

  // Account Security
  String _email = '';
  bool _isEmailVerified = false;
  bool _securityNotificationsEnabled = true;

  bool _twoStepVerificationEnabled = false;
  String _twoStepPin = '';
  String _twoStepRecoveryEmail = '';

  // Passkeys
  final List<PasskeyItem> _passkeys = [];

  // Account Report
  String _accountReportStatus = 'none'; // 'none', 'requested', 'ready'
  DateTime? _accountReportRequestedDate;

  // Blocked Contacts
  final List<String> _blockedContacts = [];

  // Getters
  String get userName => _userName;
  String get phoneNumber => _phoneNumber;
  String get about => _about;
  String get avatarUrl => _avatarUrl;
  int get trustScore => _trustScore;
  String get email => _email;
  bool get isEmailVerified => _isEmailVerified;
  bool get securityNotificationsEnabled => _securityNotificationsEnabled;
  bool get twoStepVerificationEnabled => _twoStepVerificationEnabled;
  String get twoStepPin => _twoStepPin;
  String get twoStepRecoveryEmail => _twoStepRecoveryEmail;
  List<PasskeyItem> get passkeys => List.unmodifiable(_passkeys);
  String get accountReportStatus => _accountReportStatus;
  DateTime? get accountReportRequestedDate => _accountReportRequestedDate;
  List<String> get blockedContacts => List.unmodifiable(_blockedContacts);

  String getDetectedDeviceModel() => 'Android Device';

  /// Initializes profile and account settings from SharedPreferences
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('laju_username') ?? _userName;
      _phoneNumber = prefs.getString('laju_phone') ?? _phoneNumber;
      _about = prefs.getString('laju_about') ?? _about;
      _avatarUrl = prefs.getString('laju_avatar_url') ?? '';
      _trustScore = prefs.getInt('laju_trust_score') ?? 100;
      _email = prefs.getString('laju_email') ?? _email;
      _isEmailVerified = prefs.getBool('laju_email_verified') ?? _isEmailVerified;
      _securityNotificationsEnabled = prefs.getBool('laju_security_notifications') ?? _securityNotificationsEnabled;
      _twoStepVerificationEnabled = prefs.getBool('laju_2fa') ?? _twoStepVerificationEnabled;
      _twoStepPin = prefs.getString('laju_2fa_pin') ?? _twoStepPin;
      _twoStepRecoveryEmail = prefs.getString('laju_2fa_recovery_email') ?? _twoStepRecoveryEmail;
      final blocked = prefs.getStringList('laju_blocked_contacts');
      if (blocked != null) {
        _blockedContacts.clear();
        _blockedContacts.addAll(blocked);
      }
      notifyListeners();
      syncProfileFromBackend();
      if (_avatarUrl.isNotEmpty) {
        _syncWithBackend();
      }
    } catch (e) {
      debugPrint('[AccountController] init error: $e');
    }
  }

  Future<void> updateTrustScore(int newScore) async {
    _trustScore = newScore.clamp(0, 100);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('laju_trust_score', _trustScore);
    } catch (_) {}
  }

  // Setters & Actions
  Future<void> updateProfile({String? name, String? about, String? avatarUrl}) async {
    if (name != null && name.trim().isNotEmpty) _userName = name.trim();
    if (about != null) _about = about.trim();
    if (avatarUrl != null) {
      if (avatarUrl.isNotEmpty && !avatarUrl.startsWith('http://') && !avatarUrl.startsWith('https://')) {
        // Save to internal permanent directory to prevent cache wipe
        _avatarUrl = await DeviceMediaService.savePermanentAvatar(avatarUrl);
      } else {
        _avatarUrl = avatarUrl;
      }
    }
    notifyListeners();
    _syncWithBackend();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (name != null) await prefs.setString('laju_username', _userName);
      if (about != null) await prefs.setString('laju_about', _about);
      if (avatarUrl != null) await prefs.setString('laju_avatar_url', _avatarUrl);
    } catch (_) {}
  }

  Future<void> updatePhoneNumber(String newNumber) async {
    if (newNumber.trim().isNotEmpty) {
      _phoneNumber = newNumber.trim();
      notifyListeners();
      _syncWithBackend();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('laju_phone', _phoneNumber);
      } catch (_) {}
    }
  }

  Future<void> updateEmail(String newEmail) async {
    if (newEmail.trim().isNotEmpty) {
      _email = newEmail.trim();
      _isEmailVerified = true;
      notifyListeners();
      _syncWithBackend();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('laju_email', _email);
        await prefs.setBool('laju_email_verified', true);
      } catch (_) {}
    }
  }

  Future<void> setSecurityNotifications(bool enabled) async {
    _securityNotificationsEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('laju_security_notifications', enabled);
    } catch (_) {}
  }

  Future<void> setTwoStepVerification(bool enabled, {String? pin, String? email}) async {
    _twoStepVerificationEnabled = enabled;
    if (pin != null) _twoStepPin = pin;
    if (email != null) _twoStepRecoveryEmail = email;
    notifyListeners();
    _syncWithBackend();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('laju_2fa', enabled);
      if (pin != null) await prefs.setString('laju_2fa_pin', pin);
      if (email != null) await prefs.setString('laju_2fa_recovery_email', email);
    } catch (_) {}
  }

  Future<void> syncProfileFromBackend() async {
    try {
      if (ApiClient.instance.authToken == null) return;
      final response = await ApiClient.instance.get(ApiEndpoints.currentUser);
      if (response.isSuccess && response.rawJson is Map) {
        final data = response.rawJson as Map<String, dynamic>;
        final bAvatar = data['avatarUrl'] as String? ?? data['avatar'] as String?;
        if (bAvatar != null && bAvatar.isNotEmpty && _avatarUrl.isEmpty) {
          _avatarUrl = bAvatar;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('laju_avatar_url', _avatarUrl);
          notifyListeners();
        }
        final bAbout = data['about'] as String? ?? data['status'] as String?;
        if (bAbout != null && bAbout.isNotEmpty && (_about.isEmpty || _about == 'Available')) {
          _about = bAbout;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('laju_about', _about);
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void _syncWithBackend() async {
    try {
      if (ApiClient.instance.authToken != null) {
        String? avatarPayload;
        if (_avatarUrl.isNotEmpty) {
          if (_avatarUrl.startsWith('data:') || _avatarUrl.startsWith('http://') || _avatarUrl.startsWith('https://')) {
            avatarPayload = _avatarUrl;
          } else {
            try {
              final file = File(_avatarUrl);
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                final base64String = base64Encode(bytes);
                avatarPayload = 'data:image/jpeg;base64,$base64String';
              }
            } catch (e) {
              debugPrint('[AccountController] error reading avatar file: $e');
            }
          }
        }

        final body = <String, dynamic>{
          'username': _userName,
          'twoFactorEnabled': _twoStepVerificationEnabled,
        };
        if (_email.trim().isNotEmpty) body['email'] = _email.trim();
        if (_phoneNumber.trim().isNotEmpty) body['phoneNumber'] = _phoneNumber.trim();
        if (_about.trim().isNotEmpty) body['status'] = _about.trim();
        if (_twoStepPin.trim().isNotEmpty) body['twoFactorPin'] = _twoStepPin.trim();
        if (avatarPayload != null && avatarPayload.isNotEmpty) body['avatarUrl'] = avatarPayload;

        final res = await ApiClient.instance.patch(
          ApiEndpoints.currentUser,
          body: body,
        );
        if (res.isSuccess) {
          debugPrint('[AccountController] profile successfully synced to backend');
        } else {
          debugPrint('[AccountController] profile sync failed: ${res.statusCode} ${res.message}');
        }
      }
    } catch (e) {
      debugPrint('[AccountController] _syncWithBackend error: $e');
    }
  }

  void addPasskey(String name, String device) {
    _passkeys.add(
      PasskeyItem(
        id: 'passkey-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        device: device,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void removePasskey(String id) {
    _passkeys.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void requestAccountReport() {
    _accountReportStatus = 'requested';
    _accountReportRequestedDate = DateTime.now();
    notifyListeners();
  }

  void cancelAccountReport() {
    _accountReportStatus = 'none';
    _accountReportRequestedDate = null;
    notifyListeners();
  }

  void setAccountReportReady() {
    _accountReportStatus = 'ready';
    notifyListeners();
  }

  Future<void> addBlockedContact(String name) async {
    if (!_blockedContacts.contains(name)) {
      _blockedContacts.add(name);
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('laju_blocked_contacts', _blockedContacts);
      } catch (_) {}
    }
  }

  Future<void> removeBlockedContact(String name) async {
    _blockedContacts.remove(name);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('laju_blocked_contacts', _blockedContacts);
    } catch (_) {}
  }

  void resetAccount() {
    _userName = 'User';
    _phoneNumber = '';
    _about = 'Available';
    _avatarUrl = '';
    _email = '';
    _isEmailVerified = false;
    _securityNotificationsEnabled = true;
    _twoStepVerificationEnabled = false;
    _twoStepPin = '';
    _twoStepRecoveryEmail = '';
    _passkeys.clear();
    _accountReportStatus = 'none';
    _accountReportRequestedDate = null;
    _blockedContacts.clear();
    notifyListeners();
  }
}
