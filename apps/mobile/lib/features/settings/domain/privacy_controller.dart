import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyController extends ChangeNotifier {
  PrivacyController._();
  static final PrivacyController instance = PrivacyController._();

  // Settings
  String _lastSeen = 'My contacts'; // 'Everyone', 'My contacts', 'My contacts except...', 'Nobody'
  String _profilePhoto = 'My contacts'; // 'Everyone', 'My contacts', 'Nobody'
  String _disappearingTimer = 'Off'; // 'Off', '24 hours', '7 days', '90 days'
  bool _readReceipts = true;

  // Getters
  String get lastSeen => _lastSeen;
  String get profilePhoto => _profilePhoto;
  String get disappearingTimer => _disappearingTimer;
  bool get readReceipts => _readReceipts;

  bool get isOnlineVisible => _lastSeen != 'Nobody';
  bool get isProfilePhotoVisible => _profilePhoto != 'Nobody';

  int? get disappearingSeconds {
    switch (_disappearingTimer) {
      case '24 hours':
        return 86400;
      case '7 days':
        return 604800;
      case '90 days':
        return 7776000;
      case 'Off':
      default:
        return null;
    }
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastSeen = prefs.getString('privacy_last_seen') ?? 'My contacts';
      _profilePhoto = prefs.getString('privacy_profile_photo') ?? 'My contacts';
      _disappearingTimer = prefs.getString('privacy_disappearing_timer') ?? 'Off';
      _readReceipts = prefs.getBool('privacy_read_receipts') ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setLastSeen(String val) async {
    _lastSeen = val;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('privacy_last_seen', val);
    } catch (_) {}
  }

  Future<void> setProfilePhoto(String val) async {
    _profilePhoto = val;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('privacy_profile_photo', val);
    } catch (_) {}
  }

  Future<void> setDisappearingTimer(String val) async {
    _disappearingTimer = val;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('privacy_disappearing_timer', val);
    } catch (_) {}
  }

  Future<void> setReadReceipts(bool val) async {
    _readReceipts = val;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('privacy_read_receipts', val);
    } catch (_) {}
  }
}
