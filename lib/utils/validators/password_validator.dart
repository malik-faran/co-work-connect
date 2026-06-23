// Password validation utilities
// Rule: >= 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special char

class PasswordValidator {
  PasswordValidator._();

  static const int minLength = 8;

  static bool hasMinLength(String v) => v.length >= minLength;
  static bool hasUpper(String v) => RegExp(r'[A-Z]').hasMatch(v);
  static bool hasLower(String v) => RegExp(r'[a-z]').hasMatch(v);
  static bool hasDigit(String v) => RegExp(r'[0-9]').hasMatch(v);
  static bool hasSpecial(String v) =>
      RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\/~`';]''').hasMatch(v);

  /// Returns a score 0..5 based on satisfied rules.
  static int score(String v) {
    int s = 0;
    if (hasMinLength(v)) s++;
    if (hasUpper(v)) s++;
    if (hasLower(v)) s++;
    if (hasDigit(v)) s++;
    if (hasSpecial(v)) s++;
    return s;
  }

  /// Returns null if valid, otherwise the first failed rule message.
  static String? validate(String? v) {
    if (v == null || v.isEmpty) return 'Please enter your password';
    if (!hasMinLength(v)) return 'Password must be at least 8 characters';
    if (!hasUpper(v)) return 'Add at least one uppercase letter';
    if (!hasLower(v)) return 'Add at least one lowercase letter';
    if (!hasDigit(v)) return 'Add at least one number';
    if (!hasSpecial(v)) return 'Add at least one special character';
    return null;
  }

  static bool isStrong(String v) => score(v) == 5;
}
