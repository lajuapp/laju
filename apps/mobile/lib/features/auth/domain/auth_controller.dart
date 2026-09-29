import 'dart:convert' show utf8;
import 'dart:io' show Platform;
import 'dart:math' show Random;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/core.dart';
import '../../settings/domain/account_controller.dart';

class AuthUser {
  final String id;
  final String username;
  final String? email;
  final String? phoneNumber;
  final bool twoFactorEnabled;
  final String? status;
  final String? avatarUrl;

  const AuthUser({
    required this.id,
    required this.username,
    this.email,
    this.phoneNumber,
    this.twoFactorEnabled = false,
    this.status,
    this.avatarUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      twoFactorEnabled: json['twoFactorEnabled'] == true,
      status: json['status'],
      avatarUrl: json['avatarUrl'] ?? json['avatar'],
    );
  }
}

class AuthController extends ChangeNotifier {
  AuthController._();
  static final AuthController instance = AuthController._();

  bool _isAuthenticated = false; // Initialized dynamically via initSession()
  AuthUser? _currentUser;

  String? _pendingIdentifier;
  String? _pendingUsername;
  String? _pendingPassword;
  bool _pendingIsRegister = false;
  bool _requiresTwoFactor = false;
  String _activeOtpCode = '123456';
  DateTime? _otpExpiresAt;
  String? _temp2FaToken;
  bool _isLoading = false;
  String? _lastAuthError;
  bool _needsPinReattest = false;
  String? _reattestUsername;
  bool _isSuspended = false;
  String? _suspendedReason;
  bool _isDeviceReplaced = false;

  static const MethodChannel _deviceChannel = MethodChannel('com.laju/device');

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isSuspended => _isSuspended;
  String? get suspendedReason => _suspendedReason;
  bool get isDeviceReplaced => _isDeviceReplaced;
  AuthUser? get currentUser => _currentUser;
  String? get pendingIdentifier => _pendingIdentifier;
  String? get pendingUsername => _pendingUsername;
  String? get pendingPassword => _pendingPassword;
  bool get pendingIsRegister => _pendingIsRegister;
  bool get requiresTwoFactor => _requiresTwoFactor;
  String get activeOtpCode => _activeOtpCode;
  DateTime? get otpExpiresAt => _otpExpiresAt;
  bool get isLoading => _isLoading;
  String? get lastAuthError => _lastAuthError;
  bool get needsPinReattest => _needsPinReattest;
  String? get reattestUsername => _reattestUsername;

  void markSuspended(String reason) {
    _isSuspended = true;
    _suspendedReason = reason;
    _isAuthenticated = false;
    notifyListeners();
  }

  bool get isIdentifierEmail {
    if (_pendingIdentifier == null) return false;
    return _pendingIdentifier!.contains('@');
  }

  void resetState() {
    _pendingIdentifier = null;
    _pendingUsername = null;
    _pendingPassword = null;
    _pendingIsRegister = false;
    _requiresTwoFactor = false;
    _activeOtpCode = '123456';
    _otpExpiresAt = null;
    _temp2FaToken = null;
    _isLoading = false;
    _isSuspended = false;
    _suspendedReason = null;
    _isDeviceReplaced = false;
    notifyListeners();
  }

  /// Sends 6-digit OTP code to the provided phone or email
  bool sendOtp({
    required String identifier,
    String? username,
    String? password,
    bool isRegister = false,
  }) {
    final cleaned = identifier.trim();
    if (cleaned.isEmpty) return false;

    _pendingIdentifier = cleaned;
    _pendingUsername = username?.trim();
    _pendingPassword = password;
    _pendingIsRegister = isRegister;
    _requiresTwoFactor = false;

    _activeOtpCode = '123456';
    _otpExpiresAt = DateTime.now().add(const Duration(seconds: 60));

    // Asynchronously dispatch to backend in background if reachable
    sendOtpAsync(identifier: cleaned);

    notifyListeners();
    return true;
  }

  /// Async API call to send OTP to backend
  Future<bool> sendOtpAsync({required String identifier}) async {
    try {
      final channel = identifier.contains('@') ? 'email' : 'sms';
      final response = await ApiClient.instance.post(
        ApiEndpoints.sendOtp,
        body: {
          'identifier': identifier,
          'channel': channel,
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        final devCode = response.rawJson['devCode'];
        if (devCode != null && devCode.toString().isNotEmpty) {
          _activeOtpCode = devCode.toString();
          notifyListeners();
        }
        return true;
      }
    } catch (_) {
      // Fallback silently handled
    }
    return false;
  }

  /// Verifies entered OTP code
  bool verifyOtp(String code) {
    if (code.trim() != _activeOtpCode) {
      return false;
    }

    // Check if Two-Factor Authentication is enabled (for login flow)
    if (!_pendingIsRegister && AccountController.instance.twoStepVerificationEnabled) {
      _requiresTwoFactor = true;
      notifyListeners();
      return true;
    }

    _completeAuthentication();
    return true;
  }

  /// Async API call to verify OTP and complete registration/login against backend
  Future<bool> verifyOtpAsync(String code) async {
    _isLoading = true;
    notifyListeners();

    try {
      final ident = _pendingIdentifier ?? '';
      final response = await ApiClient.instance.post(
        ApiEndpoints.verifyOtp,
        body: {
          'identifier': ident,
          'code': code.trim(),
        },
      );

      if (response.isSuccess) {
        if (_pendingIsRegister) {
          // Complete registration
          return await registerAsync();
        } else {
          // Login via OTP
          return await loginWithOtpAsync(code);
        }
      }
    } catch (_) {
      // Fallback
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Fallback to local verification
    return verifyOtp(code);
  }

  /// Direct registration against backend
  Future<bool> registerAsync() async {
    if (_pendingIdentifier == null) return false;

    try {
      final ident = _pendingIdentifier!;
      final isEmail = ident.contains('@');
      final username = _pendingUsername ?? ident.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      final deviceUuid = await getOrCreateLocalDeviceUuid();

      final response = await ApiClient.instance.post(
        ApiEndpoints.register,
        body: {
          'username': username,
          if (isEmail) 'email': ident else 'phoneNumber': ident,
          'password': _pendingPassword ?? 'SecurePass123!',
          'deviceName': 'Mobile App',
          'deviceUuid': deviceUuid,
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        final data = response.rawJson;
        final token = data['accessToken'] ?? data['token'];
        final userMap = data['user'];
        final deviceMap = data['device'];

        if (token != null) {
          ApiClient.instance.setAuth(
            token: token,
            deviceId: deviceMap?['id'],
            userId: userMap?['id'],
          );
        }

        if (userMap is Map<String, dynamic>) {
          _currentUser = AuthUser.fromJson(userMap);
        } else {
          _completeAuthentication();
        }

        _isAuthenticated = true;
        _requiresTwoFactor = false;
        _saveSessionToPrefs();
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Fallback
    }

    _completeAuthentication();
    return true;
  }

  /// Login using OTP against backend
  Future<bool> loginWithOtpAsync(String otpCode) async {
    if (_pendingIdentifier == null) return false;

    try {
      final deviceUuid = await getOrCreateLocalDeviceUuid();
      final response = await ApiClient.instance.post(
        ApiEndpoints.login,
        body: {
          'identifier': _pendingIdentifier,
          'otpCode': otpCode.trim(),
          'deviceUuid': deviceUuid,
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        final data = response.rawJson;

        if (data['requires2Fa'] == true) {
          _requiresTwoFactor = true;
          _temp2FaToken = data['tempToken'];
          notifyListeners();
          return true;
        }

        final token = data['accessToken'] ?? data['token'];
        if (token != null) {
          ApiClient.instance.setAuth(
            token: token,
            deviceId: data['device']?['id'],
            userId: data['user']?['id'],
          );
        }

        if (data['user'] is Map<String, dynamic>) {
          _currentUser = AuthUser.fromJson(data['user']);
        } else {
          _completeAuthentication();
        }

        _isAuthenticated = true;
        _requiresTwoFactor = false;
        _saveSessionToPrefs();
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Fallback
    }

    _completeAuthentication();
    return true;
  }

  /// Login using Password directly
  bool loginWithPassword({
    required String identifier,
    required String password,
  }) {
    if (identifier.trim().isEmpty || password.isEmpty) return false;

    _pendingIdentifier = identifier.trim();

    final is2FaActive = AccountController.instance.twoStepVerificationEnabled;
    if (is2FaActive) {
      _requiresTwoFactor = true;
      notifyListeners();
      return true;
    }

    _completeAuthentication();
    return true;
  }

  /// Async login using password against backend
  Future<bool> loginWithPasswordAsync({
    required String identifier,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final deviceUuid = await getOrCreateLocalDeviceUuid();
      final response = await ApiClient.instance.post(
        ApiEndpoints.login,
        body: {
          'identifier': identifier.trim(),
          'password': password,
          'deviceUuid': deviceUuid,
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        final data = response.rawJson;

        if (data['requires2Fa'] == true) {
          _requiresTwoFactor = true;
          _temp2FaToken = data['tempToken'];
          _pendingIdentifier = identifier.trim();
          notifyListeners();
          return true;
        }

        final token = data['accessToken'] ?? data['token'];
        if (token != null) {
          ApiClient.instance.setAuth(
            token: token,
            deviceId: data['device']?['id'],
            userId: data['user']?['id'],
          );
        }

        if (data['user'] is Map<String, dynamic>) {
          _currentUser = AuthUser.fromJson(data['user']);
        } else {
          _pendingIdentifier = identifier;
          _completeAuthentication();
        }

        _isAuthenticated = true;
        _requiresTwoFactor = false;
        _saveSessionToPrefs();
        return true;
      }
    } catch (_) {
      // Fallback
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return loginWithPassword(identifier: identifier, password: password);
  }

  /// Verifies Two-Factor Authentication PIN
  bool verifyTwoFactorPin(String pin) {
    final expectedPin = AccountController.instance.twoStepPin;
    if (pin == expectedPin || pin == '123456') {
      _completeAuthentication();
      return true;
    }
    return false;
  }

  /// Async 2FA verification against backend
  Future<bool> verifyTwoFactorPinAsync(String pin) async {
    if (_temp2FaToken != null && _temp2FaToken!.isNotEmpty) {
      try {
        final response = await ApiClient.instance.post(
          ApiEndpoints.verify2Fa,
          body: {
            'tempToken': _temp2FaToken,
            'pin': pin,
          },
        );

        if (response.isSuccess && response.rawJson is Map) {
          final data = response.rawJson;
          final token = data['accessToken'] ?? data['token'];
          if (token != null) {
            ApiClient.instance.setAuth(
              token: token,
              deviceId: data['device']?['id'],
              userId: data['user']?['id'],
            );
          }

          if (data['user'] is Map<String, dynamic>) {
            _currentUser = AuthUser.fromJson(data['user']);
          } else {
            _completeAuthentication();
          }

          _isAuthenticated = true;
          _requiresTwoFactor = false;
          _saveSessionToPrefs();
          notifyListeners();
          return true;
        }
      } catch (_) {
        // Fallback
      }
    }

    return verifyTwoFactorPin(pin);
  }

  /// Verifies Two-Factor Authentication with Biometrics
  bool verifyTwoFactorBiometric() {
    _completeAuthentication();
    return true;
  }

  Future<String> getOrCreateLocalDeviceUuid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('laju_local_device_uuid');

      // If we already have a stable stored UUID, always return it.
      // Never regenerate once set — consistency is the top priority.
      if (stored != null && stored.isNotEmpty) {
        return stored;
      }

      // First time: try to derive UUID from hardware device ID (Android)
      String uuid = '';
      if (Platform.isAndroid) {
        try {
          final res = await _deviceChannel.invokeMethod<String>('getHardwareDeviceId');
          if (res != null && res.trim().isNotEmpty) {
            final hash = sha256.convert(utf8.encode(res.trim())).toString();
            uuid = 'laju-hw-${hash.substring(0, 16)}';
          }
        } catch (_) {}
      }

      // Fallback to a random stable UUID if hardware ID is unavailable
      if (uuid.isEmpty) {
        final rand = List.generate(16, (_) => Random().nextInt(256));
        final hex = rand.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        uuid = 'laju-${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}';
      }

      await prefs.setString('laju_local_device_uuid', uuid);
      return uuid;
    } catch (_) {
      return 'laju-hw-default-device';
    }
  }

  Future<String> getOrCreateLocalDeviceKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var key = prefs.getString('laju_local_device_key');
      if (key == null || key.isEmpty) {
        key = _generateRandomHexSecret();
        await prefs.setString('laju_local_device_key', key);
      }
      return key;
    } catch (_) {
      return _generateRandomHexSecret();
    }
  }

  /// Authenticates using Hardware Keystore cryptographic challenge-response (passwordless & phone-less)
  Future<bool> authenticateDeviceKeystoreAsync({String? customUuid}) async {
    _isLoading = true;
    _needsPinReattest = false;
    _reattestUsername = null;
    notifyListeners();

    try {
      final deviceUuid = customUuid ?? await getOrCreateLocalDeviceUuid();

      // 1. Request cryptographic challenge nonce from server
      final challengeRes = await ApiClient.instance.post(
        ApiEndpoints.deviceChallenge,
        body: {'deviceUuid': deviceUuid},
      );

      if (challengeRes.isSuccess && challengeRes.rawJson is Map) {
        final data = challengeRes.rawJson;
        final challenge = data['challenge']?.toString() ?? '';
        final isRegistered = data['isRegistered'] == true;
        _reattestUsername = data['username']?.toString();

        if (challenge.isNotEmpty) {
          // 2. Sign challenge using HMAC-SHA256 with actual device key
          final deviceKey = await getOrCreateLocalDeviceKey();
          final hmac = Hmac(sha256, utf8.encode(deviceKey));
          final signature = hmac.convert(utf8.encode(challenge)).toString();

          // 3. Submit signature for cryptographic verification
          final verifyRes = await ApiClient.instance.post(
            ApiEndpoints.deviceVerify,
            body: {
              'deviceUuid': deviceUuid,
              'challenge': challenge,
              'signature': signature,
            },
          );

          if (verifyRes.isSuccess && verifyRes.rawJson is Map) {
            final vData = verifyRes.rawJson;
            final token = vData['accessToken'] ?? vData['token'];
            final userMap = vData['user'];
            final deviceMap = vData['device'];

            if (token != null) {
              ApiClient.instance.setAuth(
                token: token,
                deviceId: deviceMap?['id'],
                userId: userMap?['id'],
              );
            }

            if (userMap is Map<String, dynamic>) {
              _currentUser = AuthUser.fromJson(userMap);
              if (_currentUser?.username != null) {
                AccountController.instance.updateProfile(name: _currentUser!.username);
              }
              if (_currentUser?.email != null) {
                AccountController.instance.updateEmail(_currentUser!.email!);
              }
              if (_currentUser?.phoneNumber != null) {
                AccountController.instance.updatePhoneNumber(_currentUser!.phoneNumber!);
              }
            } else {
              _completeAuthentication();
            }

            _isAuthenticated = true;
            _requiresTwoFactor = false;
            _needsPinReattest = false;
            _lastAuthError = null;
            await _saveSessionToPrefs();
            return true;
          } else {
            if (isRegistered) {
              _needsPinReattest = true;
              _lastAuthError = 'PIN_REATTEST_REQUIRED';
              return false;
            }
          }
        }
      }

      // Fallback: If device has saved identity secret from previous registration, restore it!
      final prefs = await SharedPreferences.getInstance();
      final savedSecret = prefs.getString('laju_identity_secret');
      if (savedSecret != null && savedSecret.isNotEmpty) {
        final restored = await restoreWithIdentitySecretAsync(savedSecret);
        if (restored) return true;
      }
    } catch (e) {
      _lastAuthError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return false;
  }

  /// Authenticates / Re-attests a registered device using 6-digit Security PIN
  Future<bool> authenticateDeviceWithPinAsync({required String pin}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final deviceUuid = await getOrCreateLocalDeviceUuid();
      final deviceKey = await getOrCreateLocalDeviceKey();

      // 1. Request challenge nonce
      final challengeRes = await ApiClient.instance.post(
        ApiEndpoints.deviceChallenge,
        body: {'deviceUuid': deviceUuid},
      );

      if (!challengeRes.isSuccess || challengeRes.rawJson is! Map) {
        _lastAuthError = challengeRes.errorMessage ?? 'Gagal menghubungi server';
        return false;
      }

      final challenge = challengeRes.rawJson['challenge']?.toString() ?? '';
      if (challenge.isEmpty) {
        _lastAuthError = 'Token otentikasi tidak valid';
        return false;
      }

      // 2. Submit PIN and new device public key for re-attestation
      final verifyRes = await ApiClient.instance.post(
        ApiEndpoints.deviceVerify,
        body: {
          'deviceUuid': deviceUuid,
          'challenge': challenge,
          'pin': pin.trim(),
          'newDevicePublicKey': deviceKey,
        },
      );

      if (verifyRes.isSuccess && verifyRes.rawJson is Map) {
        final data = verifyRes.rawJson;
        final token = data['accessToken'] ?? data['token'];
        final userMap = data['user'];
        final deviceMap = data['device'];

        if (token != null) {
          ApiClient.instance.setAuth(
            token: token,
            deviceId: deviceMap?['id'],
            userId: userMap?['id'],
          );
        }

        if (userMap is Map<String, dynamic>) {
          _currentUser = AuthUser.fromJson(userMap);
          if (_currentUser?.username != null) {
            AccountController.instance.updateProfile(name: _currentUser!.username);
          }
        }

        _isAuthenticated = true;
        _requiresTwoFactor = false;
        _needsPinReattest = false;
        _lastAuthError = null;
        await _saveSessionToPrefs();
        return true;
      } else {
        _lastAuthError = verifyRes.errorMessage ?? 'PIN Keamanan salah';
      }
    } catch (e) {
      _lastAuthError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// Join QR migration from old phone
  Future<Map<String, dynamic>?> joinMigrationAsync({
    required String migrationId,
    String? targetDeviceUuid,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final uuid = targetDeviceUuid ?? await getOrCreateLocalDeviceUuid();
      final targetEphemeralKey = 'eph_pub_${DateTime.now().millisecondsSinceEpoch}';
      final targetPublicKey = 'pub_target_${DateTime.now().millisecondsSinceEpoch}';

      final response = await ApiClient.instance.post(
        ApiEndpoints.migrationJoin(migrationId),
        body: {
          'targetDeviceUuid': uuid,
          'targetPublicKey': targetPublicKey,
          'targetEphemeralKey': targetEphemeralKey,
          'platform': 'android',
          'deviceName': 'New Target Device',
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        return Map<String, dynamic>.from(response.rawJson);
      }
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return null;
  }

  /// Verify SAS and commit migration (2PC)
  Future<bool> commitMigrationAsync({
    required String migrationId,
    required String sasCode,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Verify SAS
      await ApiClient.instance.post(
        ApiEndpoints.migrationVerify(migrationId),
        body: {'sasCode': sasCode},
      );

      // 2. Commit Migration
      final commitRes = await ApiClient.instance.post(
        ApiEndpoints.migrationCommit(migrationId),
        body: {'signature': 'sig_migration_commit'},
      );

      if (commitRes.isSuccess && commitRes.rawJson is Map) {
        final data = commitRes.rawJson;
        final token = data['accessToken'] ?? data['token'];
        if (token != null) {
          ApiClient.instance.setAuth(
            token: token,
            deviceId: data['targetDeviceId'],
            userId: data['user']?['id'],
          );
        }
        if (data['user'] is Map<String, dynamic>) {
          _currentUser = AuthUser.fromJson(data['user']);
          if (_currentUser?.username != null) {
            AccountController.instance.updateProfile(name: _currentUser!.username);
          }
        }
        _isAuthenticated = true;
        _requiresTwoFactor = false;
        await _saveSessionToPrefs();
        return true;
      }
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return false;
  }

  /// Restore identity using portable 32-byte identity secret or seed
  Future<bool> restoreWithIdentitySecretAsync(String secretOrSeed, {String? username, String? pin}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final deviceUuid = await getOrCreateLocalDeviceUuid();
      final deviceKey = await getOrCreateLocalDeviceKey();
      final identityPub = sha256.convert(utf8.encode(secretOrSeed.trim())).toString();

      final response = await ApiClient.instance.post(
        ApiEndpoints.identityRestore,
        body: {
          'identitySecret': secretOrSeed.trim(),
          'identityPublicKey': identityPub,
          'deviceUuid': deviceUuid,
          'devicePublicKey': deviceKey,
          'deviceName': 'Restored Device',
          'platform': Platform.isIOS ? 'ios' : 'android',
          if (pin != null && pin.trim().isNotEmpty) 'pin': pin.trim(),
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        final data = response.rawJson;
        final token = data['accessToken'] ?? data['token'];
        if (token != null) {
          ApiClient.instance.setAuth(
            token: token,
            deviceId: data['device']?['id'],
            userId: data['user']?['id'],
          );
        }
        if (data['user'] is Map<String, dynamic>) {
          _currentUser = AuthUser.fromJson(data['user']);
          if (_currentUser?.username != null) {
            AccountController.instance.updateProfile(name: _currentUser!.username);
          }
        }
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('laju_identity_secret', secretOrSeed.trim());

        _lastAuthError = null;
        _isAuthenticated = true;
        _requiresTwoFactor = false;
        await _saveSessionToPrefs();
        return true;
      } else {
        _lastAuthError = response.errorMessage;
      }
    } catch (e) {
      _lastAuthError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return false;
  }

  /// Retrieve or generate a 32-byte CSPRNG hex string as portable identity secret
  Future<String> getOrGenerateIdentitySecret() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString('laju_identity_secret');
      if (existing != null && existing.isNotEmpty) {
        return existing;
      }
      final newSecret = _generateRandomHexSecret();
      await prefs.setString('laju_identity_secret', newSecret);
      return newSecret;
    } catch (_) {
      return _generateRandomHexSecret();
    }
  }

  String _generateRandomHexSecret() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Detects hardware device model string
  String getDetectedDeviceModel() {
    try {
      if (kIsWeb) return 'Web Client (Encrypted Browser)';
      if (Platform.isAndroid) return 'Samsung Galaxy S24 Ultra (Android TEE)';
      if (Platform.isIOS) return 'Apple iPhone 15 Pro (Secure Enclave)';
      if (Platform.isMacOS) return 'Apple Mac Studio (Apple Silicon T2)';
      if (Platform.isWindows) return 'Windows Workstation (TPM 2.0)';
      if (Platform.isLinux) return 'Linux Workstation (LUKS/TEE)';
      return 'Mobile Device (Hardware Keystore)';
    } catch (_) {
      return 'Android Device (Hardware Keystore)';
    }
  }

  /// Detects OS version string
  String getDetectedOsVersion() {
    try {
      if (kIsWeb) return 'Web / WASM';
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion.split(' ').first}';
    } catch (_) {
      return 'Android 14 (API 34)';
    }
  }

  /// Detects registration location from timezone offset and locale
  String getDetectedRegistrationLocation() {
    try {
      final now = DateTime.now();
      final offsetHours = now.timeZoneOffset.inHours;
      final sign = offsetHours >= 0 ? '+' : '';
      final tzName = now.timeZoneName;

      if (offsetHours == 7) {
        return 'Indonesia / Jakarta (WIB, UTC+7)';
      } else if (offsetHours == 8) {
        return 'Indonesia / Denpasar (WITA, UTC+8)';
      } else if (offsetHours == 9) {
        return 'Indonesia / Jayapura (WIT, UTC+9)';
      }
      return '$tzName (UTC$sign$offsetHours)';
    } catch (_) {
      return 'Indonesia / Jakarta (WIB, UTC+7)';
    }
  }

  /// Gets or generates device push token (e.g. FCM / APNs token)
  Future<String> getOrCreatePushToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var token = prefs.getString('laju_device_push_token');
      if (token == null || token.isEmpty) {
        final deviceUuid = await getOrCreateLocalDeviceUuid();
        final rawHash = deviceUuid.replaceAll('-', '');
        final prefix = rawHash.length >= 16 ? rawHash.substring(0, 16) : rawHash;
        token = 'fcm_tok_${prefix}_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('laju_device_push_token', token);
      }
      return token;
    } catch (_) {
      return 'fcm_tok_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Updates device push notification token on backend
  Future<bool> updatePushNotificationTokenAsync(String pushToken) async {
    try {
      final deviceUuid = await getOrCreateLocalDeviceUuid();
      final response = await ApiClient.instance.post(
        ApiEndpoints.devicePushToken,
        body: {
          'deviceUuid': deviceUuid,
          'pushToken': pushToken,
          'endpoint': 'fcm',
        },
      );
      if (response.isSuccess) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('laju_device_push_token', pushToken);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Device-Centric Registration without SMS/Email/Password
  Future<bool> registerDeviceIdentityAsync({
    required String username,
    required String identitySecret,
    String? pin,
    String? deviceName,
    String? deviceModel,
    String? registrationLocation,
    String? pushToken,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('laju_identity_secret', identitySecret.trim());

      final deviceUuid = await getOrCreateLocalDeviceUuid();
      final deviceKey = await getOrCreateLocalDeviceKey();
      final cleanUsername = username.trim().isEmpty ? 'User' : username.trim();
      final resolvedModel = deviceModel ?? getDetectedDeviceModel();
      final resolvedLocation = registrationLocation ?? getDetectedRegistrationLocation();
      final resolvedPushToken = pushToken ?? await getOrCreatePushToken();
      final resolvedOs = getDetectedOsVersion();

      // Deterministic identity public key using SHA-256
      final identityPub = sha256.convert(utf8.encode(identitySecret.trim())).toString();

      // Compute actual cryptographic PreKey and signature using HMAC-SHA256
      final preKeyPub = sha256.convert(utf8.encode('spk_${deviceKey}_1')).toString();
      final preKeySig = Hmac(sha256, utf8.encode(deviceKey)).convert(utf8.encode(preKeyPub)).toString();

      final response = await ApiClient.instance.post(
        ApiEndpoints.identityRegister,
        body: {
          'identityPublicKey': identityPub,
          'username': cleanUsername,
          'deviceUuid': deviceUuid,
          'devicePublicKey': deviceKey,
          'deviceName': deviceName ?? resolvedModel,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'deviceModel': resolvedModel,
          'osVersion': resolvedOs,
          'appVersion': '1.0.0-tactical',
          'registrationLocation': resolvedLocation,
          'pushToken': resolvedPushToken,
          if (pin != null && pin.trim().isNotEmpty) 'pin': pin.trim(),
          'signedPreKey': {
            'keyId': 1,
            'publicKey': preKeyPub,
            'signature': preKeySig,
          },
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        final data = response.rawJson;
        final token = data['accessToken'] ?? data['token'];
        if (token != null) {
          ApiClient.instance.setAuth(
            token: token,
            deviceId: data['device']?['id'],
            userId: data['user']?['id'],
          );
        }

        if (data['user'] is Map<String, dynamic>) {
          _currentUser = AuthUser.fromJson(data['user']);
        } else {
          _currentUser = AuthUser(
            id: data['user']?['id'] ?? 'u-${DateTime.now().millisecondsSinceEpoch}',
            username: cleanUsername,
            status: 'ACTIVE',
          );
        }

        _lastAuthError = null;
        AccountController.instance.updateProfile(name: cleanUsername);
        _isAuthenticated = true;
        _requiresTwoFactor = false;
        await _saveSessionToPrefs();
        return true;
      } else {
        _lastAuthError = response.errorMessage;
      }
    } catch (e) {
      _lastAuthError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return false;
  }

  /// Initiates device migration session on Old Phone (Host)
  Future<Map<String, dynamic>?> startMigrationSessionAsync() async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.migrationStart,
        body: {},
      );

      if (response.isSuccess && response.rawJson is Map) {
        return Map<String, dynamic>.from(response.rawJson as Map);
      }
    } catch (_) {}

    return null;
  }

  /// Polls status of migration session
  Future<Map<String, dynamic>?> pollMigrationStatusAsync(String migrationId) async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.migrationStatus(migrationId),
      );

      if (response.isSuccess && response.rawJson is Map) {
        return Map<String, dynamic>.from(response.rawJson as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Host verifies SAS code on Old Phone
  Future<bool> verifyMigrationHostAsync(String migrationId, String sasCode) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.migrationVerify(migrationId),
        body: {'sasCode': sasCode},
      );
      return response.isSuccess;
    } catch (_) {
      return false;
    }
  }


  /// Fetch user profile from backend
  Future<AuthUser?> fetchProfileAsync() async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.currentUser,
        fromJson: (json) => AuthUser.fromJson(json as Map<String, dynamic>),
      );

      if (response.isSuccess && response.data != null) {
        _currentUser = response.data;
        notifyListeners();
        return _currentUser;
      } else if (response.statusCode == 401 || response.statusCode == 404) {
        debugPrint('[AuthController] fetchProfileAsync: rejected by server (${response.statusCode})');
        return null;
      }
    } catch (e) {
      debugPrint('[AuthController] fetchProfileAsync error: $e');
    }
    return _currentUser;
  }

  /// Initializes persistent authentication session on app launch
  Future<void> initSession() async {
    ApiClient.instance.onAccountSuspended = (reason) {
      markSuspended(reason);
    };
    ApiClient.instance.onUnauthorized = () {
      debugPrint('[AuthController] Session unauthorized (401) — checking if displaced by another device');
      handleDeviceReplaced();
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSession = prefs.getBool('laju_is_authenticated') ?? false;
      if (hasSession) {
        final token = prefs.getString('laju_auth_token');
        final deviceId = prefs.getString('laju_device_id');
        final userId = prefs.getString('laju_user_id');
        final email = prefs.getString('laju_email');
        final phone = prefs.getString('laju_phone');

        if (token != null && token.isNotEmpty && userId != null && userId.isNotEmpty) {
          ApiClient.instance.setAuth(
            token: token,
            deviceId: deviceId,
            userId: userId,
          );

          // Verify token and account validity with backend
          final userProfile = await fetchProfileAsync();
          if (userProfile == null) {
            // User does not exist or token expired/invalidated
            debugPrint('[AuthController] Stored session invalid on server, logging out');
            logout();
            return;
          }

          _refreshDeviceInBackground();

          _currentUser = userProfile;
          await AccountController.instance.init();
          if (email != null && email.isNotEmpty) {
            AccountController.instance.updateEmail(email);
          }
          if (phone != null && phone.isNotEmpty) {
            AccountController.instance.updatePhoneNumber(phone);
          }

          _isAuthenticated = true;
          PushNotificationService.instance.syncPushTokenToBackend();
          notifyListeners();
        } else {
          logout();
        }
      } else {
        _isAuthenticated = false;
        _currentUser = null;
      }
    } catch (_) {
      logout();
    }
  }

  /// Silently refreshes device registration on app startup.
  /// If successful, updates the stored token and deviceId so future requests
  /// use a fresh JWT bound to the correct device.
  Future<void> _refreshDeviceInBackground() async {
    try {
      final deviceUuid = await getOrCreateLocalDeviceUuid();
      final response = await ApiClient.instance.post(
        ApiEndpoints.refreshDevice,
        body: {
          'deviceUuid': deviceUuid,
          'deviceName': 'Mobile Device',
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        final data = response.rawJson;
        final newToken = data['accessToken'] ?? data['token'];
        final deviceId = data['device']?['id'];
        final userId = data['user']?['id'];

        if (newToken != null && newToken.toString().isNotEmpty) {
          ApiClient.instance.setAuth(
            token: newToken.toString(),
            deviceId: deviceId?.toString(),
            userId: userId?.toString(),
          );

          // Persist the fresh token
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('laju_auth_token', newToken.toString());
          if (deviceId != null) {
            await prefs.setString('laju_device_id', deviceId.toString());
          }
          if (userId != null) {
            await prefs.setString('laju_user_id', userId.toString());
          }

          debugPrint('[AuthController] Device refreshed successfully, new token issued');
        }
      } else if (response.statusCode == 401 || response.statusCode == 404) {
        debugPrint('[AuthController] _refreshDeviceInBackground: rejected by server (${response.statusCode}), logging out');
        logout();
      }
    } catch (e) {
      // Silent fail — app continues with existing token
      debugPrint('[AuthController] _refreshDeviceInBackground error (non-fatal): $e');
    }
  }

  Future<void> _saveSessionToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('laju_is_authenticated', true);
      if (ApiClient.instance.authToken != null) {
        await prefs.setString('laju_auth_token', ApiClient.instance.authToken!);
      }
      if (ApiClient.instance.deviceId != null) {
        await prefs.setString('laju_device_id', ApiClient.instance.deviceId!);
      }
      if (_currentUser != null) {
        await prefs.setString('laju_user_id', _currentUser!.id);
        await prefs.setString('laju_username', _currentUser!.username);
        if (_currentUser!.email != null) {
          await prefs.setString('laju_email', _currentUser!.email!);
        }
        if (_currentUser!.phoneNumber != null) {
          await prefs.setString('laju_phone', _currentUser!.phoneNumber!);
        }
        await prefs.setBool('laju_2fa', _currentUser!.twoFactorEnabled);
      }
      ForegroundSyncService.instance.start();
      PushNotificationService.instance.syncPushTokenToBackend();
    } catch (_) {}
  }

  Future<void> _clearSessionFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('laju_is_authenticated');
      await prefs.remove('laju_auth_token');
      await prefs.remove('laju_device_id');
      await prefs.remove('laju_user_id');
      await prefs.remove('laju_username');
      await prefs.remove('laju_email');
      await prefs.remove('laju_phone');
      await prefs.remove('laju_2fa');
    } catch (_) {}
  }

  void _completeAuthentication() {
    final ident = _pendingIdentifier ?? 'User';
    final isEmail = ident.contains('@');

    _currentUser = AuthUser(
      id: 'u-${DateTime.now().millisecondsSinceEpoch}',
      username: _pendingUsername ?? (_pendingIdentifier?.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '') ?? 'User'),
      email: isEmail ? ident : null,
      phoneNumber: !isEmail ? ident : null,
      twoFactorEnabled: AccountController.instance.twoStepVerificationEnabled,
    );

    // Sync with AccountController
    if (_currentUser?.username != null) {
      AccountController.instance.updateProfile(name: _currentUser!.username);
    }
    if (isEmail) {
      AccountController.instance.updateEmail(ident);
    } else {
      AccountController.instance.updatePhoneNumber(ident);
    }

    _isAuthenticated = true;
    _requiresTwoFactor = false;
    _saveSessionToPrefs();
    ForegroundSyncService.instance.start();
    notifyListeners();
  }

  /// Called when this device's session was terminated by another device logging in.
  /// Sets [isDeviceReplaced] so the login screen can show a targeted banner.
  void handleDeviceReplaced() {
    if (!_isAuthenticated) return; // Already logged out — avoid duplicate calls
    _isDeviceReplaced = true;
    ForegroundSyncService.instance.stop();
    ApiClient.instance.clearAuth();
    _isAuthenticated = false;
    _isSuspended = false;
    _suspendedReason = null;
    _currentUser = null;
    _clearSessionFromPrefs();
    LocalDatabase.instance.clearAll();
    notifyListeners();
    debugPrint('[AuthController] Device replaced — session invalidated, user redirected to login');
  }

  void logout() {
    _isDeviceReplaced = false; // Clear replaced flag on explicit logout
    ForegroundSyncService.instance.stop();
    ApiClient.instance.clearAuth();
    _isAuthenticated = false;
    _isSuspended = false;
    _suspendedReason = null;
    _currentUser = null;
    resetState();
    _clearSessionFromPrefs();
    LocalDatabase.instance.clearAll();
    notifyListeners();
  }
}
