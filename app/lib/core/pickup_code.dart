import 'dart:math';

/// Pickup confirmation code: 4 characters, mixed letters + numbers.
/// Ambiguous characters are excluded so a code read off a printed label
/// can never be misread: no 0/O, no 1/I.
class PickupCode {
  static const _letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const _digits = '23456789';
  static const _all = '$_letters$_digits';

  static final Random _random = Random.secure();

  /// Generate a fresh 4-character code with at least one letter and one digit.
  static String generate() {
    while (true) {
      final chars = List.generate(4, (_) => _all[_random.nextInt(_all.length)]);
      final hasLetter = chars.any(_letters.contains);
      final hasDigit = chars.any(_digits.contains);
      if (hasLetter && hasDigit) return chars.join();
    }
  }

  /// A code is valid only if it is exactly 4 allowed characters.
  static bool isValidFormat(String code) {
    if (code.length != 4) return false;
    return code.split('').every(_all.contains);
  }

  /// Case-insensitive comparison (labels are uppercase; a driver may type
  /// lowercase on a small keyboard).
  static bool matches(String typed, String expected) =>
      typed.trim().toUpperCase() == expected.trim().toUpperCase();
}
