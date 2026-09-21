import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LajuSoundService {
  static const MethodChannel _channel = MethodChannel('com.laju/sound');

  /// Plays the synthesized or system ringtone by name
  static Future<void> playRingtone(String name) async {
    if (name.toLowerCase().contains('hening') || name.toLowerCase().contains('mute')) {
      HapticFeedback.selectionClick();
      return;
    }

    try {
      await _channel.invokeMethod('playRingtone', {'name': name});
    } catch (e) {
      debugPrint('[LajuSoundService] playRingtone platform channel fallback: $e');
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Triggers hardware vibrator with specified profile ('Mati', 'Default', 'Pendek', 'Panjang')
  static Future<void> triggerVibrate(String mode) async {
    if (mode == 'Mati') return;

    try {
      await _channel.invokeMethod('triggerVibrate', {'mode': mode});
    } catch (e) {
      debugPrint('[LajuSoundService] triggerVibrate platform channel fallback: $e');
      switch (mode) {
        case 'Pendek':
          HapticFeedback.mediumImpact();
          break;
        case 'Panjang':
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 220), () {
            HapticFeedback.heavyImpact();
          });
          break;
        case 'Default':
        default:
          HapticFeedback.vibrate();
          break;
      }
    }
  }

  /// Stops current playing audio track
  static Future<void> stopRingtone() async {
    try {
      await _channel.invokeMethod('stopRingtone');
    } catch (_) {}
  }

  /// Triggers full notification audio & haptics based on user's saved preferences
  static Future<void> playIncomingNotification({bool isGroup = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationTones = prefs.getBool('notif_conversation_tones') ?? true;
      if (!conversationTones) return;

      final ringtoneKey = isGroup ? 'notif_group_ringtone' : 'notif_msg_ringtone';
      final vibrateKey = isGroup ? 'notif_group_vibrate' : 'notif_msg_vibrate';

      final ringtone = prefs.getString(ringtoneKey) ?? (isGroup ? 'LAJU Neon Pulse' : 'LAJU Quantum Wave');
      final vibrate = prefs.getString(vibrateKey) ?? 'Default';

      await triggerVibrate(vibrate);
      await playRingtone(ringtone);
    } catch (e) {
      debugPrint('[LajuSoundService] playIncomingNotification error: $e');
      try {
        await SystemSound.play(SystemSoundType.alert);
        await HapticFeedback.vibrate();
      } catch (_) {}
    }
  }

  /// Plays outgoing message chime if conversation tones are enabled
  static Future<void> playOutgoingTone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationTones = prefs.getBool('notif_conversation_tones') ?? true;
      if (!conversationTones) return;

      await HapticFeedback.lightImpact();
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }
}
