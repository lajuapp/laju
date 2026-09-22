class DateHelper {
  DateHelper._();

  /// Reliably parses any UTC ISO 8601 date string from backend and converts to local device time.
  /// Handles dates with or without 'Z' suffix, SQLite / Postgres datetime formats,
  /// and null or empty values gracefully.
  static DateTime parseUtc(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is DateTime) return raw.toLocal();

    final str = raw.toString().trim();
    if (str.isEmpty) return DateTime.now();

    String normalized = str;
    // If the date string has no timezone indicator ('Z' or '+HH:mm' or '-HH:mm'), append 'Z'
    // so Dart parses it as UTC rather than device local time.
    final hasTzOffset = normalized.endsWith('Z') ||
        RegExp(r'[+-]\d{2}(:?\d{2})?$').hasMatch(normalized);

    if (!hasTzOffset) {
      normalized = '${normalized.replaceAll(' ', 'T')}Z';
    }

    final parsed = DateTime.tryParse(normalized) ?? DateTime.tryParse(str);
    return parsed != null ? parsed.toLocal() : DateTime.now();
  }

  /// Checks if two DateTimes represent the exact same calendar day in local time.
  static bool isSameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  /// WhatsApp-style chat date divider string:
  /// - Today -> 'Hari Ini'
  /// - Yesterday -> 'Kemarin'
  /// - Within past 7 days -> Day of the week ('Senin', 'Selasa', etc.)
  /// - Otherwise -> 'd MMMM yyyy' ('22 September 2026')
  static String formatChatDivider(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(local.year, local.month, local.day);

    final diffDays = today.difference(msgDate).inDays;
    if (diffDays == 0) {
      return 'Hari Ini';
    } else if (diffDays == 1) {
      return 'Kemarin';
    } else if (diffDays > 1 && diffDays < 7) {
      const days = [
        'Senin',
        'Selasa',
        'Rabu',
        'Kamis',
        'Jumat',
        'Sabtu',
        'Minggu',
      ];
      return days[local.weekday - 1];
    } else {
      const months = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];
      return '${local.day} ${months[local.month - 1]} ${local.year}';
    }
  }
}
