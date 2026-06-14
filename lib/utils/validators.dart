// Centralized form-input validation for the FBLA app.
//
// Previously the same email/password validators were copy-pasted across
// login_screen.dart, signup_screen.dart, and firebase_auth_screen.dart.
// They now live here so every form validates input consistently, on both a
// *syntactic* level (format/shape) and a *semantic* level (is this a
// plausible, acceptable value — real-looking domain, strong-enough password,
// a name that isn't a number, etc.).

/// Qualitative strength buckets for a password, used to drive the strength meter.
enum PasswordStrength { empty, weak, fair, good, strong }

extension PasswordStrengthInfo on PasswordStrength {
  /// 0.0–1.0 fill fraction for a progress bar.
  double get fraction {
    switch (this) {
      case PasswordStrength.empty:
        return 0.0;
      case PasswordStrength.weak:
        return 0.25;
      case PasswordStrength.fair:
        return 0.5;
      case PasswordStrength.good:
        return 0.75;
      case PasswordStrength.strong:
        return 1.0;
    }
  }

  String get label {
    switch (this) {
      case PasswordStrength.empty:
        return '';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }
}

class Validators {
  Validators._();

  // RFC-pragmatic email shape: local@domain.tld with no spaces.
  static final RegExp _emailPattern =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  // A handful of throwaway/disposable domains we reject for a real member app.
  static const Set<String> _disposableDomains = {
    'mailinator.com',
    'guerrillamail.com',
    '10minutemail.com',
    'tempmail.com',
    'temp-mail.org',
    'trashmail.com',
    'yopmail.com',
    'throwawaymail.com',
    'getnada.com',
    'sharklasers.com',
  };

  static final RegExp _hasUpper = RegExp(r'[A-Z]');
  static final RegExp _hasLower = RegExp(r'[a-z]');
  static final RegExp _hasDigit = RegExp(r'\d');
  static final RegExp _hasSymbol = RegExp(r'[^A-Za-z0-9]');

  /// Email validation. Syntactic (shape) + semantic (no consecutive dots,
  /// real-looking TLD, not a known disposable provider).
  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailPattern.hasMatch(v)) return 'Enter a valid email';
    if (v.contains('..')) return 'Enter a valid email';

    final domain = v.substring(v.indexOf('@') + 1).toLowerCase();
    if (domain.startsWith('.') || domain.endsWith('.')) {
      return 'Enter a valid email';
    }
    if (_disposableDomains.contains(domain)) {
      return 'Please use a permanent email address';
    }
    return null;
  }

  /// Lenient password check for *sign-in* (existing accounts may predate the
  /// stronger policy below). Syntactic only.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Minimum 6 characters';
    return null;
  }

  /// Strong password policy for *account creation*. Semantic: requires a mix of
  /// character classes, not just a minimum length.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!_hasUpper.hasMatch(v)) return 'Add an uppercase letter';
    if (!_hasLower.hasMatch(v)) return 'Add a lowercase letter';
    if (!_hasDigit.hasMatch(v)) return 'Add a number';
    if (!_hasSymbol.hasMatch(v)) return 'Add a symbol (e.g. ! @ # \$)';
    return null;
  }

  /// Confirm-password match check.
  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  /// Person/field name. Semantic: not blank, not purely numeric, reasonable
  /// length, no digits.
  static String? name(String? value, {String field = 'Name'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$field is required';
    if (v.length < 2) return '$field is too short';
    if (_hasDigit.hasMatch(v)) return '$field cannot contain numbers';
    return null;
  }

  /// Generic required-text check.
  static String? requiredField(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  /// Estimate password strength for the live meter. Scores length + the number
  /// of distinct character classes present.
  static PasswordStrength estimateStrength(String value) {
    if (value.isEmpty) return PasswordStrength.empty;

    var score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (_hasUpper.hasMatch(value) && _hasLower.hasMatch(value)) score++;
    if (_hasDigit.hasMatch(value)) score++;
    if (_hasSymbol.hasMatch(value)) score++;

    if (value.length < 6) return PasswordStrength.weak;
    if (score <= 1) return PasswordStrength.weak;
    if (score == 2) return PasswordStrength.fair;
    if (score == 3) return PasswordStrength.good;
    return PasswordStrength.strong;
  }
}
