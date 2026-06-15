import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:typed_data';

class FirebaseService {
  // Use getters to avoid accessing Firebase instances before
  // Firebase.initializeApp() has been called (avoids core/no-app).
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  static FirebaseStorage get _storage => FirebaseStorage.instance;
  static GoogleSignIn get _googleSignIn => GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId:
            '1023723280371-7o7ocf59j4iod547576cmonp6lgoncfb.apps.googleusercontent.com',
      );

  static Future<void> _ensureInitialized() async {
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('FirebaseService: Firebase.initializeApp() completed');
      } catch (e) {
        print('FirebaseService: Firebase.initializeApp() error: $e');
        rethrow;
      }
    }
  }

  static Future<void> logAuthEvent({
    required String event,
    String? userId,
    String? email,
    String? provider,
    String? details,
  }) async {
    try {
      await _firestore.collection('auth_logs').add({
        'event': event,
        'userId': userId,
        'email': email,
        'provider': provider,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('FirebaseService: Auth log write failed: $e');
    }
  }

  // Auth methods
  static Future<UserCredential?> signInWithEmail(
      String email, String password) async {
    await _ensureInitialized();
    try {
      print('FirebaseService: Attempting sign in with email: $email');
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      print('FirebaseService: Sign in successful for UID: ${result.user?.uid}');
      await logAuthEvent(
        event: 'login',
        userId: result.user?.uid,
        email: result.user?.email ?? email,
        provider: 'email',
      );
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
        throw Exception(
            'Email/Password authentication is not enabled in Firebase Console.');
      } else if (e.code == 'network-request-failed') {
        // If we already have a locally-persisted token for this email (common
        // after a prior successful login), skip the network call and use it.
        final cached = _auth.currentUser;
        if (cached != null &&
            cached.email?.toLowerCase() == email.toLowerCase()) {
          return null; // caller checks firebaseUser via authStateChanges
        }
        throw Exception('[offline] Network unavailable');
      }
      rethrow;
    } catch (e) {
      print('FirebaseService: Sign in error: $e');
      if (e.toString().contains('[offline]')) rethrow;
      if (e.toString().contains('network')) {
        final cached = _auth.currentUser;
        if (cached != null &&
            cached.email?.toLowerCase() == email.toLowerCase()) {
          return null;
        }
        throw Exception('[offline] Network unavailable');
      }
      rethrow;
    }
  }

  static Future<UserCredential?> signUpWithEmail(
      String email, String password) async {
    await _ensureInitialized();
    try {
      print('FirebaseService: Attempting to create user with email: $email');
      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      print(
          'FirebaseService: User created successfully with UID: ${result.user?.uid}');
      await logAuthEvent(
        event: 'signup',
        userId: result.user?.uid,
        email: result.user?.email ?? email,
        provider: 'email',
      );
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
        throw Exception('[offline] Network unavailable');
      }
      rethrow;
    } catch (e) {
      print('FirebaseService: Sign up error: $e');
      rethrow;
    }
  }

  static Future<UserCredential?> signInWithGoogle() async {
    await _ensureInitialized();
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

      final hasAccessToken = googleAuth.accessToken != null;
      final hasIdToken = googleAuth.idToken != null;
      if (!hasAccessToken && !hasIdToken) {
        print(
            'Google auth tokens are null: accessToken=$hasAccessToken idToken=$hasIdToken');
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      await logAuthEvent(
        event: 'login',
        userId: result.user?.uid,
        email: result.user?.email,
        provider: 'google',
      );
      return result;
    } catch (e) {
      print('Google sign in error: $e');
      // Don't rethrow - return null to allow graceful handling
      return null;
    }
  }

  static Future<void> signOutGoogle() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
  }

  static Future<void> signOut() async {
    await _ensureInitialized();
    final currentUser = _auth.currentUser;
    await logAuthEvent(
      event: 'logout',
      userId: currentUser?.uid,
      email: currentUser?.email,
      provider: currentUser?.providerData.isNotEmpty == true
          ? currentUser?.providerData.first.providerId
          : null,
    );
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
    int points = 0,
    int streak = 0,
    String rank = 'Intern',
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
        'points': points,
        'streak': streak,
        'rank': rank,
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

  static Future<Map<String, int>> getUserProgress(String userId) async {
    final profile = await getUserProfile(userId);
    return {
      'points': int.tryParse((profile?['points'] ?? 0).toString()) ?? 0,
      'streak': int.tryParse((profile?['streak'] ?? 0).toString()) ?? 0,
    };
  }

  static Future<Map<String, int>> getCurrentUserProgress() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return {'points': 0, 'streak': 0};
    }
    return getUserProgress(userId);
  }

  static Future<void> ensureUserProgressDefaults(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      if (profile == null) return;

      final updates = <String, dynamic>{};
      if (!profile.containsKey('points')) {
        updates['points'] = 0;
      }
      if (!profile.containsKey('streak')) {
        updates['streak'] = 0;
      }
      if (!profile.containsKey('rank')) {
        updates['rank'] = 'Intern';
      }

      if (updates.isNotEmpty) {
        await updateUserProfile(userId, updates);
      }
    } catch (e) {
      print('Ensure user progress defaults error: $e');
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

  static Future<List<Map<String, dynamic>>> getUsers() async {
    return _getCollectionDocuments('users');
  }

  static String? get currentUserId => _auth.currentUser?.uid;

  static String _friendRequestId(String fromUserId, String toUserId) =>
      '${fromUserId}_$toUserId';

  static String _friendshipId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  static Future<bool> areFriends(String userId1, String userId2) async {
    final doc = await _firestore
        .collection('friendships')
        .doc(_friendshipId(userId1, userId2))
        .get();
    return doc.exists;
  }

  static Future<String?> getFriendRelationStatus({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (currentUserId == otherUserId) return 'self';
    if (await areFriends(currentUserId, otherUserId)) return 'friends';

    final outgoing = await _firestore
        .collection('friend_requests')
        .doc(_friendRequestId(currentUserId, otherUserId))
        .get();
    if (outgoing.exists && outgoing.data()?['status'] == 'pending') {
      return 'outgoing';
    }

    final incoming = await _firestore
        .collection('friend_requests')
        .doc(_friendRequestId(otherUserId, currentUserId))
        .get();
    if (incoming.exists && incoming.data()?['status'] == 'pending') {
      return 'incoming';
    }

    return null;
  }

  static Future<Map<String, String>> getFriendRelationStatuses(
    String currentUserId,
    List<String> otherUserIds,
  ) async {
    final statuses = <String, String>{};
    if (currentUserId.isEmpty) return statuses;

    final friendships = await _firestore
        .collection('friendships')
        .where('userIds', arrayContains: currentUserId)
        .get();
    final friendIds = <String>{};
    for (final doc in friendships.docs) {
      for (final id in List<String>.from(doc.data()['userIds'] ?? const [])) {
        if (id != currentUserId) friendIds.add(id);
      }
    }

    final outgoingSnapshot = await _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .get();
    final outgoingIds = outgoingSnapshot.docs
        .map((doc) => (doc.data()['toUserId'] ?? '').toString())
        .toSet();

    final incomingSnapshot = await _firestore
        .collection('friend_requests')
        .where('toUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .get();
    final incomingIds = incomingSnapshot.docs
        .map((doc) => (doc.data()['fromUserId'] ?? '').toString())
        .toSet();

    for (final otherUserId in otherUserIds) {
      if (otherUserId == currentUserId) {
        statuses[otherUserId] = 'self';
      } else if (friendIds.contains(otherUserId)) {
        statuses[otherUserId] = 'friends';
      } else if (outgoingIds.contains(otherUserId)) {
        statuses[otherUserId] = 'outgoing';
      } else if (incomingIds.contains(otherUserId)) {
        statuses[otherUserId] = 'incoming';
      }
    }

    return statuses;
  }

  static Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
    required String fromUserName,
    required String toUserName,
  }) async {
    if (fromUserId == toUserId) {
      throw Exception('You cannot send a friend request to yourself.');
    }
    if (await areFriends(fromUserId, toUserId)) {
      throw Exception('You are already friends with this member.');
    }

    final outgoingDoc = await _firestore
        .collection('friend_requests')
        .doc(_friendRequestId(fromUserId, toUserId))
        .get();
    if (outgoingDoc.exists && outgoingDoc.data()?['status'] == 'pending') {
      throw Exception('Friend request already sent.');
    }

    final incomingDoc = await _firestore
        .collection('friend_requests')
        .doc(_friendRequestId(toUserId, fromUserId))
        .get();
    if (incomingDoc.exists && incomingDoc.data()?['status'] == 'pending') {
      throw Exception(
          'This member already sent you a request. Check the Requests tab.');
    }

    await _firestore
        .collection('friend_requests')
        .doc(_friendRequestId(fromUserId, toUserId))
        .set({
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'fromUserName': fromUserName,
      'toUserName': toUserName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<Map<String, dynamic>>> getOutgoingFriendRequests(
      String userId) async {
    final snapshot = await _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> getIncomingFriendRequests(
      String userId) async {
    final snapshot = await _firestore
        .collection('friend_requests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }

  static Future<void> acceptFriendRequest(String requestId) async {
    final doc =
        await _firestore.collection('friend_requests').doc(requestId).get();
    if (!doc.exists) {
      throw Exception('Friend request not found.');
    }

    final data = doc.data()!;
    final fromUserId = (data['fromUserId'] ?? '').toString();
    final toUserId = (data['toUserId'] ?? '').toString();
    if (fromUserId.isEmpty || toUserId.isEmpty) {
      throw Exception('Friend request is missing user information.');
    }

    final batch = _firestore.batch();
    batch.update(doc.reference, {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _firestore
          .collection('friendships')
          .doc(_friendshipId(fromUserId, toUserId)),
      {
        'userIds': [fromUserId, toUserId],
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  static Future<void> declineFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  static Future<List<Map<String, dynamic>>> getFriendsForUser(
      String userId) async {
    final snapshot = await _firestore
        .collection('friendships')
        .where('userIds', arrayContains: userId)
        .get();

    final friendIds = <String>{};
    for (final doc in snapshot.docs) {
      for (final id in List<String>.from(doc.data()['userIds'] ?? const [])) {
        if (id != userId) friendIds.add(id);
      }
    }

    if (friendIds.isEmpty) return const [];

    final users = await getUsers();
    final friends = users
        .where((user) => friendIds.contains((user['id'] ?? '').toString()))
        .toList(growable: false);
    friends.sort((left, right) {
      final leftName =
          (left['name'] ?? left['displayName'] ?? '').toString().toLowerCase();
      final rightName = (right['name'] ?? right['displayName'] ?? '')
          .toString()
          .toLowerCase();
      return leftName.compareTo(rightName);
    });
    return friends;
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
    await _firestore
        .collection('threads')
        .doc(id)
        .set(data, SetOptions(merge: true));
  }

  static Future<String> queueDiscordMessage({
    required String title,
    required String body,
    String channel = 'announcements',
    String type = 'announcement',
    String? sourceId,
    String? authorName,
  }) async {
    await _ensureInitialized();

    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty || trimmedBody.isEmpty) {
      throw Exception('Discord posts need both a title and message.');
    }

    final docRef = await _firestore.collection('discord_outbox').add({
      'title': trimmedTitle,
      'body': trimmedBody,
      'channel': channel,
      'type': type,
      'sourceId': sourceId,
      'authorName': authorName,
      'createdBy': _auth.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    return docRef.id;
  }

  // Direct Messaging Methods
  static String _chatId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return 'chat_${sorted[0]}_${sorted[1]}';
  }

  static Stream<List<Map<String, dynamic>>> getDirectMessages(
      String userId1, String userId2) {
    final chatId = _chatId(userId1, userId2);
    return _firestore
        .collection('direct_messages')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  static Future<void> sendDirectMessage({
    required String fromUserId,
    required String toUserId,
    required String text,
    required String fromUserName,
  }) async {
    final chatId = _chatId(fromUserId, toUserId);
    final timestamp = FieldValue.serverTimestamp();

    await _firestore
        .collection('direct_messages')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': fromUserId,
      'senderName': fromUserName,
      'text': text,
      'timestamp': timestamp,
    });

    await _firestore.collection('direct_messages').doc(chatId).set({
      'lastMessage': text,
      'lastTimestamp': timestamp,
      'participants': [fromUserId, toUserId],
    }, SetOptions(merge: true));
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
      results['firebase_initialized'] =
          true; // Firebase is initialized if we can access _auth

      // Check Firestore connectivity
      results['firestore_accessible'] = await checkFirebaseConnection();

      // Check if auth is enabled (try to get current user)
      try {
        _auth.currentUser;
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
