import 'package:flutter_test/flutter_test.dart';
import 'package:fbla_member_app/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepts well-formed addresses', () {
      expect(Validators.email('member@school.org'), isNull);
      expect(Validators.email('first.last@fbla.org'), isNull);
    });

    test('requires a value', () {
      expect(Validators.email(''), 'Email is required');
      expect(Validators.email(null), 'Email is required');
    });

    test('rejects malformed shapes (missing @ or TLD)', () {
      expect(Validators.email('no-at-sign.com'), 'Enter a valid email');
      expect(Validators.email('missing@tld'), 'Enter a valid email');
      expect(Validators.email('has space@x.com'), 'Enter a valid email');
    });

    test('rejects consecutive dots', () {
      expect(Validators.email('a..b@school.org'), 'Enter a valid email');
    });

    test('rejects known disposable domains', () {
      expect(Validators.email('throwaway@mailinator.com'),
          'Please use a permanent email address');
      expect(Validators.email('x@guerrillamail.com'),
          'Please use a permanent email address');
    });

    test('is case-insensitive about disposable domains', () {
      expect(Validators.email('x@Mailinator.com'),
          'Please use a permanent email address');
    });
  });

  group('Validators.password (sign-in, lenient)', () {
    test('requires a value', () {
      expect(Validators.password(''), 'Password is required');
      expect(Validators.password(null), 'Password is required');
    });

    test('enforces a 6-character floor only', () {
      expect(Validators.password('12345'), 'Minimum 6 characters');
      expect(Validators.password('123456'), isNull);
      expect(Validators.password('plainpassword'), isNull);
    });
  });

  group('Validators.newPassword (sign-up, strong policy)', () {
    test('requires 8+ characters', () {
      expect(Validators.newPassword('Aa1!xy'), 'Use at least 8 characters');
    });

    test('requires an uppercase letter', () {
      expect(Validators.newPassword('lower1!xx'), 'Add an uppercase letter');
    });

    test('requires a lowercase letter', () {
      expect(Validators.newPassword('UPPER1!XX'), 'Add a lowercase letter');
    });

    test('requires a digit', () {
      expect(Validators.newPassword('NoDigits!x'), 'Add a number');
    });

    test('requires a symbol', () {
      expect(Validators.newPassword('NoSymbol1x'),
          'Add a symbol (e.g. ! @ # \$)');
    });

    test('accepts a strong password', () {
      expect(Validators.newPassword('Strong1!pass'), isNull);
    });

    test('requires a value', () {
      expect(Validators.newPassword(''), 'Password is required');
      expect(Validators.newPassword(null), 'Password is required');
    });
  });

  group('Validators.confirmPassword', () {
    test('requires a value', () {
      expect(Validators.confirmPassword('', 'Strong1!pass'),
          'Please confirm your password');
    });

    test('flags mismatches', () {
      expect(Validators.confirmPassword('different', 'Strong1!pass'),
          'Passwords do not match');
    });

    test('passes on a match', () {
      expect(Validators.confirmPassword('Strong1!pass', 'Strong1!pass'), isNull);
    });
  });

  group('Validators.name', () {
    test('requires a value with the field label', () {
      expect(Validators.name('', field: 'Full name'),
          'Full name is required');
    });

    test('rejects too-short names', () {
      expect(Validators.name('A'), 'Name is too short');
    });

    test('rejects names containing digits', () {
      expect(Validators.name('Jane2'), 'Name cannot contain numbers');
    });

    test('accepts a normal name', () {
      expect(Validators.name('Jane Smith'), isNull);
    });
  });

  group('Validators.estimateStrength', () {
    test('empty input is empty tier', () {
      expect(Validators.estimateStrength(''), PasswordStrength.empty);
    });

    test('very short input is weak', () {
      expect(Validators.estimateStrength('ab'), PasswordStrength.weak);
    });

    test('moderate input lands in fair/good range', () {
      // 8 chars + upper/lower mix only -> score 2 -> fair
      expect(Validators.estimateStrength('Abcdefgh'), PasswordStrength.fair);
    });

    test('a long mixed password is strong', () {
      expect(Validators.estimateStrength('Str0ng!Passw0rd'),
          PasswordStrength.strong);
    });

    test('strength tiers expose fraction and label', () {
      expect(PasswordStrength.strong.fraction, 1.0);
      expect(PasswordStrength.good.label, 'Good');
      expect(PasswordStrength.empty.label, '');
    });
  });
}
