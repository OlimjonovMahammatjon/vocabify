import 'dart:math';

class AppHelpers {
  static String normalizeAnswer(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String maskWord(String sentence, String word) {
    if (word.isEmpty || sentence.isEmpty) return sentence;
    final escaped = RegExp.escape(word.trim());
    return sentence.replaceAll(RegExp(escaped, caseSensitive: false), '_____');
  }

  static String getWordHint(String word, int level) {
    final clean = word.trim();
    if (level <= 0 || clean.isEmpty) return '';
    if (clean.length <= 2) return clean[0];
    final visibleCount = level == 1 ? 1 : max(2, (clean.length / 3).ceil());
    final visiblePart = clean.substring(0, min(visibleCount, clean.length));
    final remainingCount = max(0, clean.length - visibleCount);
    return '$visiblePart${" _" * remainingCount}';
  }

  /// Normalizes Uzbek and international phone inputs to E.164 (`+998901234567`).
  static String normalizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    final startsWithPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    if (startsWithPlus) {
      return '+$digits';
    }
    if (digits.length == 9) {
      return '+998$digits';
    }
    if (digits.length == 12 && digits.startsWith('998')) {
      return '+$digits';
    }
    return '+$digits';
  }

  /// Validates a normalized E.164 phone number (`+998XXXXXXXXX` or `+...`).
  static bool isValidPhone(String input) {
    final normalized = normalizePhone(input);
    if (!RegExp(r'^\+[1-9]\d{8,14}$').hasMatch(normalized)) {
      return false;
    }
    if (normalized.startsWith('+998')) {
      return normalized.length == 13;
    }
    return true;
  }

  /// Formats `+998901234567` as `+998 90 123 45 67` for clean UI display.
  static String formatPhoneDisplay(String phone) {
    final normalized = normalizePhone(phone);
    if (normalized.startsWith('+998') && normalized.length == 13) {
      final d = normalized.substring(4);
      return '+998 ${d.substring(0, 2)} ${d.substring(2, 5)} ${d.substring(5, 7)} ${d.substring(7, 9)}';
    }
    return normalized.isEmpty ? phone : normalized;
  }
}
