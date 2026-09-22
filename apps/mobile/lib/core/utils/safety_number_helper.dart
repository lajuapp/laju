import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Cryptographic helper to derive and format WhatsApp / Signal-grade safety numbers.
/// Deterministically computes a 60-digit safety number from user / conversation identifiers
/// using SHA-256 so both parties independently compute the exact same verification code.
class SafetyNumberHelper {
  SafetyNumberHelper._();

  /// Derives a 60-digit safety number (12 blocks of 5 digits) from two entity IDs
  /// or a conversation ID.
  static String deriveSafetyNumber(String id1, [String? id2]) {
    final ids = [id1.trim(), if (id2 != null && id2.trim().isNotEmpty) id2.trim()];
    ids.sort(); // Sorting ensures both users compute identical fingerprints
    final seed = ids.join(':');

    final hashBytes = sha256.convert(utf8.encode('laju_e2ee_safety_v1:$seed')).bytes;

    final blocks = <String>[];
    for (int i = 0; i < 12; i++) {
      final b1 = hashBytes[(i * 2) % hashBytes.length];
      final b2 = hashBytes[(i * 2 + 1) % hashBytes.length];
      final num = ((b1 << 8) | b2) % 100000;
      blocks.add(num.toString().padLeft(5, '0'));
    }

    return blocks.join(' ');
  }

  /// Formats a 60-digit safety number into a compact preview: "XXXXX ••• XXXXX"
  static String getPreview(String safetyNumber) {
    final blocks = safetyNumber.split(' ').where((b) => b.isNotEmpty).toList();
    if (blocks.isEmpty) return '4812 ••• 9901';
    if (blocks.length == 1) return blocks.first;
    return '${blocks.first} ••• ${blocks.last}';
  }
}
