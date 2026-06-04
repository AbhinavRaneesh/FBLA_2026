// Compatibility shim for legacy MongoDbService API.
// The app moved to Firebase; this stub keeps old callsites compiling
// and delegates behavior to FirebaseService where possible.
import 'package:fbla_member_app/services/firebase_service.dart';

class MongoDbService {
  // No-op: retained for compatibility with older code.
  static void configureUri(String uri) {
    // Intentionally left blank. Firebase is used instead of MongoDB.
  }

  static Future<Map<String, dynamic>> createUser({
    String? username,
    String? email,
    required String password,
    required String name,
    required String role,
    required String gradeLevel,
  }) async {
    // Normalize identifier similar to the old implementation.
    final rawIdentifier = (username != null && username.trim().isNotEmpty)
        ? username.trim()
        : (email ?? '').trim();

    final normalizedUsername = _normalizeUsername(rawIdentifier);
    if (normalizedUsername.isEmpty) {
      throw Exception('Username is required.');
    }

    final generatedEmail = _normalizeEmail('$normalizedUsername@fbla.local');

    // Create Firebase auth user using the generated email.
    final credential = await FirebaseService.signUpWithEmail(
      generatedEmail,
      password,
    );

    final userId = credential?.user?.uid;
    if (userId == null) {
      throw Exception('Failed to create user account.');
    }

    // Create user profile in Firestore
    await FirebaseService.createUserProfile(
      userId: userId,
      name: name,
      email: generatedEmail,
      points: 0,
      streak: 0,
    );

    return {
      'email': generatedEmail,
      'username': normalizedUsername,
      'name': name,
      'role': role,
      'gradeLevel': gradeLevel,
    };
  }

  static Future<Map<String, dynamic>> loginUser({
    String? username,
    String? email,
    required String password,
  }) async {
    final rawIdentifier = (username != null && username.trim().isNotEmpty)
        ? username.trim()
        : (email ?? '').trim();
    if (rawIdentifier.isEmpty) {
      throw Exception('Username is required.');
    }

    final normalizedUsername = _normalizeUsername(rawIdentifier);
    final candidateEmail = _normalizeEmail('$normalizedUsername@fbla.local');

    // Try signing in with provided email first, then with generated username email.
    try {
      if (email != null && email.trim().isNotEmpty) {
        final cred = await FirebaseService.signInWithEmail(email.trim(), password);
        final uid = cred?.user?.uid;
        final profile = uid != null ? await FirebaseService.getUserProfile(uid) : null;
        return {
          'email': cred?.user?.email ?? email,
          'username': normalizedUsername,
          'name': profile?['name'] ?? '',
          'role': profile?['role'] ?? '',
          'gradeLevel': profile?['gradeLevel'] ?? '',
        };
      }

      final cred = await FirebaseService.signInWithEmail(candidateEmail, password);
      final uid = cred?.user?.uid;
      final profile = uid != null ? await FirebaseService.getUserProfile(uid) : null;
      return {
        'email': cred?.user?.email ?? candidateEmail,
        'username': normalizedUsername,
        'name': profile?['name'] ?? '',
        'role': profile?['role'] ?? '',
        'gradeLevel': profile?['gradeLevel'] ?? '',
      };
    } catch (e) {
      rethrow;
    }
  }

  static String _normalizeUsername(String input) {
    final s = input.trim().toLowerCase();
    // keep letters, numbers, hyphen and underscore
    return s.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
  }

  static String _normalizeEmail(String input) {
    return input.trim().toLowerCase();
  }
}
