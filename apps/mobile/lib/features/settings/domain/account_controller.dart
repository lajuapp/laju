import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/core.dart';
import '../../auth/domain/auth_controller.dart';

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'device': device,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PasskeyItem.fromJson(Map<String, dynamic> json) => PasskeyItem(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        device: json['device'] ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
      );
}

class LajuContactItem {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? about;
  final String? phoneNumber;
  final int trustScore;
  final bool isVerified;
  final DateTime addedAt;

  const LajuContactItem({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.about,
    this.phoneNumber,
    this.trustScore = 100,
    this.isVerified = true,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'about': about,
        'phoneNumber': phoneNumber,
        'trustScore': trustScore,
        'isVerified': isVerified,
        'addedAt': addedAt.toIso8601String(),
      };

  factory LajuContactItem.fromJson(Map<String, dynamic> json) => LajuContactItem(
        id: json['id'] ?? '',
        username: json['username'] ?? '',
        displayName: json['displayName'],
        avatarUrl: json['avatarUrl'],
        about: json['about'],
        phoneNumber: json['phoneNumber'],
        trustScore: json['trustScore'] ?? 100,
        isVerified: json['isVerified'] ?? true,
        addedAt: json['addedAt'] != null
            ? DateTime.tryParse(json['addedAt']) ?? DateTime.now()
            : DateTime.now(),
      );
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
  bool _twoStepVerificationEnabled = true;
  String _twoStepPin = '';
  String _twoStepRecoveryEmail = '';

  // Passkeys
  final List<PasskeyItem> _passkeys = [];

  // Account Report
  String _accountReportStatus = 'none'; // 'none', 'requested', 'ready'
  DateTime? _accountReportRequestedDate;

  // Blocked Contacts
  final List<String> _blockedContacts = [];

  // Saved Contacts (Local LAJU Directory)
  final List<LajuContactItem> _savedContacts = [];

  // Getters
  String get userName {
    if (_userName.isNotEmpty && _userName != 'User') return _userName;
    final authName = AuthController.instance.currentUser?.username;
    if (authName != null && authName.isNotEmpty) return authName;
    return _userName;
  }
  String get phoneNumber => _phoneNumber;
  String get about => _about;
  String get avatarUrl {
    if (_avatarUrl.isNotEmpty) return _avatarUrl;
    final authAvatar = AuthController.instance.currentUser?.avatarUrl;
    if (authAvatar != null && authAvatar.isNotEmpty) return authAvatar;
    return '';
  }
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
  List<LajuContactItem> get savedContacts => List.unmodifiable(_savedContacts);

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
      _twoStepVerificationEnabled = prefs.getBool('laju_2fa') ?? true;
      _twoStepPin = prefs.getString('laju_2fa_pin') ?? _twoStepPin;
      if (_twoStepPin.isEmpty) {
        final appLockPin = prefs.getString('app_lock_pin');
        if (appLockPin != null && appLockPin.length == 6) {
          _twoStepPin = appLockPin;
          _twoStepVerificationEnabled = true;
        }
      }
      _twoStepRecoveryEmail = prefs.getString('laju_2fa_recovery_email') ?? _twoStepRecoveryEmail;
      final blocked = prefs.getStringList('laju_blocked_contacts');
      if (blocked != null) {
        _blockedContacts.clear();
        _blockedContacts.addAll(blocked);
      }
      final savedContactsRaw = prefs.getStringList('laju_saved_contacts_list');
      if (savedContactsRaw != null) {
        _savedContacts.clear();
        for (final item in savedContactsRaw) {
          try {
            _savedContacts.add(LajuContactItem.fromJson(jsonDecode(item) as Map<String, dynamic>));
          } catch (_) {}
        }
      }
      final passkeysRaw = prefs.getStringList('laju_passkeys_list');
      if (passkeysRaw != null) {
        _passkeys.clear();
        for (final item in passkeysRaw) {
          try {
            _passkeys.add(PasskeyItem.fromJson(jsonDecode(item) as Map<String, dynamic>));
          } catch (_) {}
        }
      }
      _accountReportStatus = prefs.getString('laju_account_report_status') ?? 'none';
      final reqDateStr = prefs.getString('laju_account_report_requested_date');
      if (reqDateStr != null) {
        _accountReportRequestedDate = DateTime.tryParse(reqDateStr);
        if (_accountReportStatus == 'requested' && _accountReportRequestedDate != null) {
          final diff = DateTime.now().difference(_accountReportRequestedDate!);
          if (diff.inDays >= 3) {
            _accountReportStatus = 'ready';
            await prefs.setString('laju_account_report_status', 'ready');
          }
        }
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
    if (pin != null && pin.isNotEmpty) {
      _twoStepPin = pin;
      AppLockController.instance.setPinCode(pin);
    }
    if (email != null) _twoStepRecoveryEmail = email;
    notifyListeners();
    _syncWithBackend();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('laju_2fa', enabled);
      if (pin != null && pin.isNotEmpty) {
        await prefs.setString('laju_2fa_pin', pin);
        await prefs.setString('app_lock_pin', pin);
      }
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
        if (bAvatar != null && bAvatar.isNotEmpty) {
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
          debugPrint('[AccountController] profile sync failed: ${res.statusCode} ${res.errorMessage}');
        }
      }
    } catch (e) {
      debugPrint('[AccountController] _syncWithBackend error: $e');
    }
  }

  Future<void> addPasskey(String name, String device) async {
    _passkeys.add(
      PasskeyItem(
        id: 'passkey-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        device: device,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    await _persistPasskeys();
    // Synchronize with AppLockController
    await AppLockController.instance.setBiometricEnabled(true);
    await AppLockController.instance.setAppLockEnabled(true);
  }

  Future<void> removePasskey(String id) async {
    _passkeys.removeWhere((p) => p.id == id);
    notifyListeners();
    await _persistPasskeys();
    if (_passkeys.isEmpty) {
      await AppLockController.instance.setBiometricEnabled(false);
    }
  }

  Future<void> _persistPasskeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _passkeys.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList('laju_passkeys_list', list);
    } catch (_) {}
  }

  Future<void> requestAccountReport() async {
    _accountReportStatus = 'requested';
    _accountReportRequestedDate = DateTime.now();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('laju_account_report_status', _accountReportStatus);
      await prefs.setString('laju_account_report_requested_date', _accountReportRequestedDate!.toIso8601String());
    } catch (_) {}
  }

  Future<void> cancelAccountReport() async {
    _accountReportStatus = 'none';
    _accountReportRequestedDate = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('laju_account_report_status');
      await prefs.remove('laju_account_report_requested_date');
    } catch (_) {}
  }

  Future<void> setAccountReportReady() async {
    _accountReportStatus = 'ready';
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('laju_account_report_status', 'ready');
    } catch (_) {}
  }

  bool isContactBlocked(String identifier) {
    final clean = identifier.trim().toLowerCase().replaceFirst('@', '');
    if (clean.isEmpty) return false;
    for (final b in _blockedContacts) {
      final cleanB = b.trim().toLowerCase().replaceFirst('@', '');
      if (cleanB == clean) return true;
      if (cleanB.contains(clean) || clean.contains(cleanB)) return true;
    }
    return false;
  }

  Future<void> addBlockedContact(String name) async {
    final clean = name.trim();
    if (clean.isNotEmpty && !_blockedContacts.contains(clean)) {
      _blockedContacts.add(clean);
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('laju_blocked_contacts', _blockedContacts);
      } catch (_) {}
    }
  }

  Future<void> removeBlockedContact(String name) async {
    final clean = name.trim().toLowerCase();
    _blockedContacts.removeWhere((item) {
      final itemClean = item.trim().toLowerCase();
      return itemClean == clean || itemClean.contains(clean) || clean.contains(itemClean);
    });
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('laju_blocked_contacts', _blockedContacts);
    } catch (_) {}
  }

  bool isContactSaved(String userIdOrUsername) {
    final query = userIdOrUsername.trim().toLowerCase().replaceFirst('@', '');
    return _savedContacts.any((c) =>
        c.id.toLowerCase() == query || c.username.toLowerCase() == query);
  }

  Future<void> addSavedContact(LajuContactItem contact) async {
    final existingIdx = _savedContacts.indexWhere(
        (c) => c.id == contact.id || c.username.toLowerCase() == contact.username.toLowerCase());
    if (existingIdx >= 0) {
      _savedContacts[existingIdx] = contact;
    } else {
      _savedContacts.insert(0, contact);
    }
    notifyListeners();
    await _persistSavedContacts();
  }

  Future<void> removeSavedContact(String contactIdOrUsername) async {
    final q = contactIdOrUsername.trim().toLowerCase().replaceFirst('@', '');
    _savedContacts.removeWhere(
        (c) => c.id.toLowerCase() == q || c.username.toLowerCase() == q);
    notifyListeners();
    await _persistSavedContacts();
  }

  Future<void> _persistSavedContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _savedContacts.map((c) => jsonEncode(c.toJson())).toList();
      await prefs.setStringList('laju_saved_contacts_list', list);
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
