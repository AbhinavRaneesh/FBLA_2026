import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:typed_data';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Auth methods
  static Future<UserCredential?> signInWithEmail(
      String email, String password) async {
    try {
      print('FirebaseService: Attempting sign in with email: $email');
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      print('FirebaseService: Sign in successful for UID: ${result.user?.uid}');
      return result;
    } on FirebaseAuthException catch (e) {
      print('FirebaseService: Auth error code: ${e.code}');
      print('FirebaseService: Auth error message: ${e.message}');
      if (e.code == 'user-not-found') {
        throw Exception('No account found with this email address.');
      } else if (e.code == 'wrong-password') {
        throw Exception('Incorrect password. Please try again.');
      } else if (e.code == 'invalid-email') {
        throw Exception('The email address is invalid.');
      } else if (e.code == 'user-disabled') {
        throw Exception('This account has been disabled.');
      } else if (e.code == 'too-many-requests') {
        throw Exception('Too many failed attempts. Please try again later.');
      } else if (e.code == 'operation-not-allowed') {
        throw Exception('Email/Password authentication is not enabled in Firebase Console.');
      } else if (e.code == 'network-request-failed') {
        throw Exception('Network error. Please check your internet connection.');
      }
      rethrow;
    } catch (e) {
      print('FirebaseService: Sign in error: $e');
      if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }

  static Future<UserCredential?> signUpWithEmail(
      String email, String password) async {
    try {
      print('FirebaseService: Attempting to create user with email: $email');
      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      print(
          'FirebaseService: User created successfully with UID: ${result.user?.uid}');
      return result;
    } on FirebaseAuthException catch (e) {
      print('FirebaseService: Auth error code: ${e.code}');
      print('FirebaseService: Auth error message: ${e.message}');
      if (e.code == 'operation-not-allowed') {
        throw Exception(
            'Email/Password authentication is not enabled in Firebase Console. Please enable it.');
      } else if (e.code == 'weak-password') {
        throw Exception('The password is too weak. Use at least 6 characters.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('An account already exists with this email.');
      } else if (e.code == 'invalid-email') {
        throw Exception('The email address is invalid.');
      } else if (e.code == 'network-request-failed') {
        throw Exception('Network error. Please check your internet connection.');
      }
      rethrow;
    } catch (e) {
      print('FirebaseService: Sign up error: $e');
      rethrow;
    }
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Sign out first to avoid cached credentials issues
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Google sign in cancelled by user');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Google auth tokens are null');
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Google sign in error: $e');
      // Don't rethrow - return null to allow graceful handling
      return null;
    }
  }

  static Future<void> signOutGoogle() async {
    await _googleSignIn.signOut();
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    await signOutGoogle();
  }

  // Firestore methods
  static Future<void> createUserProfile({
    required String userId,
    required String name,
    required String email,
    String? photoUrl,
    String? chapter,
    String? school,
    String? officerPosition,
    String? biography,
  }) async {
    try {
      print('FirebaseService: Creating user profile for UID: $userId');
      await _firestore.collection('users').doc(userId).set({
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'chapter': chapter,
        'school': school,
        'officerPosition': officerPosition,
        'biography': biography,
        'achievements': <String>[],
        'badges': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('FirebaseService: User profile created successfully');
    } on FirebaseException catch (e) {
      print('FirebaseService: Firestore error code: ${e.code}');
      print('FirebaseService: Firestore error message: ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception(
            'Permission denied. Firestore security rules may be blocking this operation.');
      } else if (e.code == 'unavailable') {
        throw Exception(
            'Firestore is currently unavailable. Please check if Firestore is enabled in Firebase Console.');
      }
      rethrow;
    } catch (e) {
      print('FirebaseService: Create user profile error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Get user profile error: $e');
      return null;
    }
  }

  static Future<void> updateUserProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      print('Update user profile error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getChapter(String chapterId) async {
    try {
      final doc = await _firestore.collection('chapters').doc(chapterId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Get chapter error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _getCollectionDocuments(
    String collection, {
    String? orderBy,
    bool descending = false,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(collection);
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> getEvents() async {
    return _getCollectionDocuments('events', orderBy: 'start');
  }

  static Future<List<Map<String, dynamic>>> getNews() async {
    return _getCollectionDocuments('news', orderBy: 'date', descending: true);
  }

  static Future<List<Map<String, dynamic>>> getCompetitions() async {
    return _getCollectionDocuments('competitions');
  }

  static Future<List<Map<String, dynamic>>> getThreads() async {
    return _getCollectionDocuments('threads');
  }

  static Future<void> ensureAppDataSeeded({
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> news,
    required List<Map<String, dynamic>> competitions,
    required List<Map<String, dynamic>> threads,
  }) async {
    final collections = {
      'events': events,
      'news': news,
      'competitions': competitions,
      'threads': threads,
    };

    for (final entry in collections.entries) {
      final collectionRef = _firestore.collection(entry.key);
      final batch = _firestore.batch();
      var hasWrites = false;
      for (final item in entry.value) {
        final data = Map<String, dynamic>.from(item);
        final id = (data.remove('id') ?? '').toString();
        if (id.isEmpty) continue;
        final docRef = collectionRef.doc(id);
        final existingDoc = await docRef.get();
        if (!existingDoc.exists) {
          batch.set(docRef, data);
          hasWrites = true;
        }
      }

      if (hasWrites) {
        await batch.commit();
      }
    }
  }

  static Future<void> updateEventRsvp({
    required String eventId,
    required String userKey,
    required String response,
  }) async {
    await _firestore.collection('events').doc(eventId).set({
      'rsvps': {userKey: response},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> appendThreadMessage({
    required String threadId,
    required Map<String, dynamic> message,
  }) async {
    await _firestore.collection('threads').doc(threadId).set({
      'messages': FieldValue.arrayUnion([message]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> createThread(Map<String, dynamic> thread) async {
    final data = Map<String, dynamic>.from(thread);
    final id = (data.remove('id') ?? '').toString();
    if (id.isEmpty) return;
    await _firestore.collection('threads').doc(id).set(data, SetOptions(merge: true));
  }

  // Storage methods
  static Future<String?> uploadProfileImage(
      String userId, Uint8List imageBytes) async {
    try {
      final ref = _storage.ref().child('profile_images/$userId.jpg');
      await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      print('Upload profile image error: $e');
      return null;
    }
  }

  // Auth state stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Connectivity and configuration check
  static Future<bool> checkFirebaseConnection() async {
    try {
      // Try to read from Firestore to test connectivity
      await _firestore.collection('test').doc('connection').get();
      print('FirebaseService: Connection test successful');
      return true;
    } catch (e) {
      print('FirebaseService: Connection test failed: $e');
      return false;
    }
  }

  // Check if Firebase is properly configured
  static Future<Map<String, bool>> checkFirebaseConfiguration() async {
    Map<String, bool> results = {
      'firebase_initialized': false,
      'firestore_accessible': false,
      'auth_enabled': false,
    };

    try {
      // Check if Firebase is initialized
      results['firebase_initialized'] = true; // Firebase is initialized if we can access _auth
      
      // Check Firestore connectivity
      results['firestore_accessible'] = await checkFirebaseConnection();
      
      // Check if auth is enabled (try to get current user)
      try {
        await _auth.currentUser;
        results['auth_enabled'] = true;
      } catch (e) {
        results['auth_enabled'] = false;
      }
      
      print('FirebaseService: Configuration check results: $results');
    } catch (e) {
      print('FirebaseService: Configuration check error: $e');
    }
    
    return results;
  }
}
