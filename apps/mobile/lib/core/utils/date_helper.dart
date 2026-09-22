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
}
