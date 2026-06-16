import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/resources_screen.dart';
import 'screens/nlc_detail_screen.dart';
import 'screens/firebase_auth_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/find_members_screen.dart';
import 'social/screens/social_screen.dart';
import 'screens/instagram_feed_screen.dart';
import 'screens/rank_screen.dart';
import 'screens/feature_tour.dart';
import 'models/fbla_rank.dart';
import 'ai/bloc/chat_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'services/firebase_service.dart';
import 'services/mongodb_service.dart';
import 'models/fbla_models.dart';
import 'models/video_model.dart';
import 'screens/video_player_screen.dart';
import 'services/youtube_service.dart';

// FBLA Colors Added
const fblaNavy = Color(0xFF00274D);
const fblaBlue = Color(0xFF1D4E89);
const fblaGold = Color(0xFFFDB913);
const fblaLightBackground = Color(0xFFEFF3F6);
const fblaLightSurface = Color(0xFFFFFFFF);
const fblaLightPrimaryText = Color(0xFF0A192F);
const fblaLightSecondaryText = Color(0xFF475569);
const fblaLightDisabledText = Color(0xFF94A3B8);
const fblaLightBorder = Color(0xFFD5DEE6);
const fblaLightSelectedNav = Color(0xFFDCEEFF);
const fblaLightSuccessBackground = Color(0xFFDCFCE7);
const fblaLightSuccessText = Color(0xFF15803D);
const fblaLightDestructive = Color(0xFFDC2626);

// Shared app background (matches home screen)
const Color appBackgroundColor = Color(0xFF07111F);
const LinearGradient appBackgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF07111F),
    Color(0xFF0A1830),
    Color(0xFF07111F),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Denver'));

  // Secrets are injected at build time, never committed to source.
  // Pass with: flutter run --dart-define=MONGODB_URI=mongodb+srv://...
  const defineMongoUri = String.fromEnvironment('MONGODB_URI');
  final resolvedMongoUri = defineMongoUri.trim();

  if (resolvedMongoUri.isNotEmpty) {
    MongoDbService.configureUri(resolvedMongoUri);
    debugPrint('🍃 MongoDB URI configured from --dart-define');
  } else {
    debugPrint(
      '🍃 MongoDB URI not set. Pass --dart-define=MONGODB_URI=... to enable '
      'Mongo-backed features (app runs normally on Firebase without it).',
    );
  }

  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class AppState extends ChangeNotifier {
  final SharedPreferences prefs;
  String userEmail;
  String displayName;
  String signupRole;
  String gradeLevel;
  List<Event> events;
  List<NewsItem> news;
  List<Competition> competitions;
  List<ChatThread> threads;
  Set<String> savedEventIds = {};
  Set<String> participatingEventIds = {};
  bool hasSeenOnboarding;
  bool isDarkMode = true;

  // Firebase integration
  User? firebaseUser;
  FBLAUser? userProfile;
  Chapter? userChapter;
  Uint8List? localProfileImageBytes;
  bool _firebaseInitialized = false;

  AppState({required this.prefs})
      : userEmail = '',
        displayName = '',
        signupRole = '',
        gradeLevel = '',
        events = sampleEvents,
        news = sampleNews,
        competitions = sampleCompetitions,
        threads = sampleThreads,
        hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false,
        isDarkMode = prefs.getBool('isDarkMode') ?? true {
    savedEventIds = prefs.getStringList('savedEvents')?.toSet() ?? {};
    participatingEventIds =
        prefs.getStringList('participatingEvents')?.toSet() ?? {};
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    if (_firebaseInitialized) return;

    try {
      await Firebase.initializeApp();
      print('🔥 Firebase initialized successfully');
      _firebaseInitialized = true;

      await _loadAppDataFromFirestore();
      unawaited(_retryPendingSignup());

      // Firebase auth state listener
      FirebaseService.authStateChanges.listen((User? user) async {
        firebaseUser = user;
        if (user != null) {
          userEmail = user.email ?? '';
          final authDisplayName = user.displayName?.trim() ?? '';
          displayName =
              _isGenericDisplayName(authDisplayName) ? '' : authDisplayName;
          await _loadUserProfile(user.uid);
        } else {
          userProfile = null;
          userChapter = null;
        }
        notifyListeners();
      });
    } catch (e) {
      print('🔥 Firebase initialization failed: $e');
    }
  }

  Future<void> _loadAppDataFromFirestore() async {
    try {
      await FirebaseService.ensureAppDataSeeded(
        events: _sampleEventsToFirestore(),
        news: _sampleNewsToFirestore(),
        competitions: _sampleCompetitionsToFirestore(),
        threads: _sampleThreadsToFirestore(),
      );

      final results = await Future.wait([
        FirebaseService.getEvents(),
        FirebaseService.getNews(),
        FirebaseService.getCompetitions(),
        FirebaseService.getThreads(),
      ]);

      events = (results[0] as List<Map<String, dynamic>>)
          .map(_eventFromFirestore)
          .toList();
      news = (results[1] as List<Map<String, dynamic>>)
          .map(_newsFromFirestore)
          .toList();
      competitions = (results[2] as List<Map<String, dynamic>>)
          .map(_competitionFromFirestore)
          .toList();
      threads = (results[3] as List<Map<String, dynamic>>)
          .map(_threadFromFirestore)
          .toList();

      // Cache the freshly-loaded data so the app still shows content if the
      // network is unavailable on a later launch (e.g. unreliable venue WiFi).
      await _cacheAppData();

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load Firestore app data: $e');
      // Offline / fetch failed: fall back to the last-known-good cache so the
      // home screen isn't blank during a demo. Sample data remains the final
      // fallback if no cache exists yet.
      _loadCachedAppData();
    }
  }

  /// Persists the current events and news to SharedPreferences as JSON.
  Future<void> _cacheAppData() async {
    try {
      final eventsJson = jsonEncode(events
          .map((e) => {
                'id': e.id,
                'title': e.title,
                'start': e.start.toIso8601String(),
                'end': e.end.toIso8601String(),
                'location': e.location,
                'description': e.description,
                'rsvps': e.rsvps,
              })
          .toList());
      final newsJson = jsonEncode(news
          .map((n) => {
                'id': n.id,
                'title': n.title,
                'body': n.body,
                'date': n.date.toIso8601String(),
              })
          .toList());
      await prefs.setString('cachedEvents', eventsJson);
      await prefs.setString('cachedNews', newsJson);
      await prefs.setString('cacheTimestamp', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Failed to cache app data: $e');
    }
  }

  /// Restores events and news from the cache. Returns false if no usable cache.
  bool _loadCachedAppData() {
    try {
      final eventsJson = prefs.getString('cachedEvents');
      final newsJson = prefs.getString('cachedNews');
      if (eventsJson == null && newsJson == null) return false;

      if (eventsJson != null) {
        final decoded = jsonDecode(eventsJson) as List;
        events = decoded
            .map((e) => _eventFromFirestore(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (newsJson != null) {
        final decoded = jsonDecode(newsJson) as List;
        news = decoded
            .map((n) => _newsFromFirestore(Map<String, dynamic>.from(n)))
            .toList();
      }
      debugPrint('📦 Loaded app data from offline cache');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to load cached app data: $e');
      return false;
    }
  }

  /// Timestamp of the last successful data cache, for an "offline" UI hint.
  DateTime? get lastCacheTime {
    final raw = prefs.getString('cacheTimestamp');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  DateTime _toDateTime(dynamic value, DateTime fallback) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? fallback;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return fallback;
  }

  Event _eventFromFirestore(Map<String, dynamic> data) {
    final now = DateTime.now();
    final event = Event(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      start: _toDateTime(data['start'], now),
      end: _toDateTime(data['end'], now.add(const Duration(hours: 1))),
      location: (data['location'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
    );

    final rawRsvps = data['rsvps'];
    if (rawRsvps is Map) {
      event.rsvps.addAll(rawRsvps.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ));
    }

    return event;
  }

  NewsItem _newsFromFirestore(Map<String, dynamic> data) {
    return NewsItem(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      date: _toDateTime(data['date'], DateTime.now()),
    );
  }

  Competition _competitionFromFirestore(Map<String, dynamic> data) {
    final rawLeaderboard = data['leaderboard'];
    final leaderboard = <LeaderboardEntry>[];

    if (rawLeaderboard is List) {
      for (final entry in rawLeaderboard) {
        if (entry is Map<String, dynamic>) {
          leaderboard.add(
            LeaderboardEntry(
              user: (entry['user'] ?? '').toString(),
              points: (entry['points'] is int)
                  ? entry['points'] as int
                  : int.tryParse((entry['points'] ?? '0').toString()) ?? 0,
            ),
          );
        } else if (entry is Map) {
          leaderboard.add(
            LeaderboardEntry(
              user: (entry['user'] ?? '').toString(),
              points: int.tryParse((entry['points'] ?? '0').toString()) ?? 0,
            ),
          );
        }
      }
    }

    return Competition(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      leaderboard: leaderboard,
    );
  }

  ChatThread _threadFromFirestore(Map<String, dynamic> data) {
    final rawMessages = data['messages'];
    final messages = <ChatMessage>[];

    if (rawMessages is List) {
      for (final item in rawMessages) {
        if (item is Map<String, dynamic>) {
          messages.add(
            ChatMessage(
              author: (item['author'] ?? '').toString(),
              text: (item['text'] ?? '').toString(),
              time: _toDateTime(item['time'], DateTime.now()),
            ),
          );
        } else if (item is Map) {
          messages.add(
            ChatMessage(
              author: (item['author'] ?? '').toString(),
              text: (item['text'] ?? '').toString(),
              time: _toDateTime(item['time'], DateTime.now()),
            ),
          );
        }
      }
    }

    return ChatThread(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      messages: messages,
    );
  }

  List<Map<String, dynamic>> _sampleEventsToFirestore() {
    return sampleEvents
        .map(
          (event) => {
            'id': event.id,
            'title': event.title,
            'start': Timestamp.fromDate(event.start),
            'end': Timestamp.fromDate(event.end),
            'location': event.location,
            'description': event.description,
            'rsvps': event.rsvps,
          },
        )
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _sampleNewsToFirestore() {
    return sampleNews
        .map(
          (item) => {
            'id': item.id,
            'title': item.title,
            'body': item.body,
            'date': Timestamp.fromDate(item.date),
          },
        )
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _sampleCompetitionsToFirestore() {
    return sampleCompetitions
        .map(
          (competition) => {
            'id': competition.id,
            'name': competition.name,
            'description': competition.description,
            'leaderboard': competition.leaderboard
                .map((entry) => {
                      'user': entry.user,
                      'points': entry.points,
                    })
                .toList(growable: false),
          },
        )
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _sampleThreadsToFirestore() {
    return sampleThreads
        .map(
          (thread) => {
            'id': thread.id,
            'title': thread.title,
            'messages': thread.messages
                .map((message) => {
                      'author': message.author,
                      'text': message.text,
                      'time': Timestamp.fromDate(message.time),
                    })
                .toList(growable: false),
          },
        )
        .toList(growable: false);
  }

  bool get loggedIn => userEmail.isNotEmpty;

  String get userRank {
    final stored = userProfile?.rank ?? FBLARankSystem.defaultRank;
    final coins = userProfile?.points ?? 0;
    final coinRank = FBLARankSystem.rankForCoins(coins).name;
    final storedIndex = FBLARankSystem.indexForRank(stored);
    final coinIndex = FBLARankSystem.indexForRank(coinRank);
    return coinIndex >= storedIndex ? coinRank : stored;
  }

  String get resolvedDisplayName {
    final candidates = [
      userProfile?.name ?? '',
      displayName,
      firebaseUser?.displayName ?? '',
    ];

    for (final candidate in candidates) {
      final value = candidate.trim();
      if (!_isGenericDisplayName(value)) {
        return value;
      }
    }

    final emailName = _nameFromEmail(userEmail);
    return emailName.isNotEmpty ? emailName : 'Member';
  }

  String get profileInitial {
    final name = resolvedDisplayName.trim();
    if (name.isNotEmpty) return name[0].toUpperCase();
    if (userEmail.isNotEmpty) return userEmail[0].toUpperCase();
    return 'F';
  }

  String _nameFromEmail(String email) {
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) return '';
    return localPart
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) {
      final value = part.trim();
      return value[0].toUpperCase() + value.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> login(String email, String name,
      {String role = '', String grade = ''}) async {
    userEmail = email;
    displayName = name;
    signupRole = role;
    gradeLevel = grade;
    await prefs.setString('userEmail', userEmail);
    await prefs.setString('displayName', displayName);
    await prefs.setString('signupRole', signupRole);
    await prefs.setString('gradeLevel', gradeLevel);
    notifyListeners();
  }

  Future<void> signUpWithMongo({
    required String email,
    required String password,
    required String name,
    required String role,
    required String grade,
  }) async {
    await MongoDbService.createUser(
      email: email,
      password: password,
      name: name,
      role: role,
      gradeLevel: grade,
    );
  }

  Future<void> signInWithMongo({
    required String email,
    required String password,
  }) async {
    final account = await MongoDbService.loginUser(
      email: email,
      password: password,
    );

    await login(
      (account['email'] ?? email).toString(),
      (account['name'] ?? '').toString(),
      role: (account['role'] ?? '').toString(),
      grade: (account['gradeLevel'] ?? '').toString(),
    );
  }

  Future<void> logout() async {
    try {
      await FirebaseService.signOut();
    } catch (_) {
      // Proceed with local logout even if remote sign-out fails.
    }
    userEmail = '';
    displayName = '';
    signupRole = '';
    gradeLevel = '';
    firebaseUser = null;
    userProfile = null;
    userChapter = null;
    localProfileImageBytes = null;
    await prefs.remove('lastRootTabIndex');
    await prefs.remove('lastRootTabSavedAt');
    await prefs.remove('userEmail');
    await prefs.remove('displayName');
    await prefs.remove('signupRole');
    await prefs.remove('gradeLevel');
    notifyListeners();
  }

  Future<void> updateProfileImage(Uint8List imageBytes) async {
    localProfileImageBytes = imageBytes;
    notifyListeners();

    if (firebaseUser == null) {
      return;
    }

    final photoUrl = await FirebaseService.uploadProfileImage(
      firebaseUser!.uid,
      imageBytes,
    );

    if (photoUrl != null) {
      await FirebaseService.updateUserProfile(
        firebaseUser!.uid,
        {'photoUrl': photoUrl},
      );
      await _loadUserProfile(firebaseUser!.uid);
      notifyListeners();
    }
  }

  // ---- Offline signup queue --------------------------------------------------

  /// Stores a signup that failed due to no network so it can be retried
  /// automatically the next time Firebase is reachable.
  Future<void> savePendingSignup({
    required String name,
    required String email,
    required String password,
    required String school,
    required String role,
  }) async {
    await prefs.setString(
      'pendingSignup',
      jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'school': school,
        'role': role,
      }),
    );
    debugPrint('📦 Pending signup saved for $email');
  }

  /// Called after Firebase initialises successfully. Completes any pending
  /// offline signup silently so the user gets a real Firebase account.
  Future<void> _retryPendingSignup() async {
    final raw = prefs.getString('pendingSignup');
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final email = (data['email'] ?? '').toString();
      final password = (data['password'] ?? '').toString();
      final name = (data['name'] ?? '').toString();
      final school = (data['school'] ?? '').toString();
      if (email.isEmpty || password.isEmpty) return;

      debugPrint('🔄 Retrying pending signup for $email');
      final result = await FirebaseService.signUpWithEmail(email, password);
      if (result?.user != null) {
        final user = result!.user!;
        await user.updateDisplayName(name);
        await FirebaseService.createUserProfile(
          userId: user.uid,
          name: name,
          email: email,
          school: school,
          points: 0,
          streak: 0,
        );
        await prefs.remove('pendingSignup');
        debugPrint('✅ Pending signup completed for $email');
        // Refresh in-app profile if this is the current user
        if (userEmail.toLowerCase() == email.toLowerCase()) {
          await setFirebaseUser(user);
        }
      }
    } catch (e) {
      // Account may already exist (e.g. created on another device) — clear it.
      final msg = e.toString();
      if (msg.contains('email-already-in-use')) {
        await prefs.remove('pendingSignup');
        debugPrint('✅ Pending signup account already exists; cleared queue');
      } else {
        debugPrint('⚠️  Pending signup retry failed: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------

  Future<void> skipOnboarding() async {
    hasSeenOnboarding = true;
    await prefs.setBool('hasSeenOnboarding', true);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    isDarkMode = value;
    await prefs.setBool('isDarkMode', value);
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    await setDarkMode(!isDarkMode);
  }

  Future<void> setFirebaseUser(User user) async {
    firebaseUser = user;
    userEmail = user.email ?? '';
    final authDisplayName = user.displayName?.trim() ?? '';
    displayName = _isGenericDisplayName(authDisplayName) ? '' : authDisplayName;
    signupRole = '';
    gradeLevel = '';
    await _loadUserProfile(user.uid);
    notifyListeners();
  }

  bool _isGenericDisplayName(String name) {
    final normalized = name.trim().toLowerCase();
    return normalized.isEmpty || normalized == 'fbla member';
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final profileData = await FirebaseService.getUserProfile(userId);
      if (profileData != null) {
        userProfile = FBLAUser.fromFirestore(profileData);
        final profileName = userProfile?.name.trim() ?? '';
        if (!_isGenericDisplayName(profileName)) {
          displayName = profileName;
          await prefs.setString('displayName', displayName);
        }
        final profileEmail = userProfile?.email.trim() ?? '';
        if (profileEmail.isNotEmpty) {
          userEmail = profileEmail;
          await prefs.setString('userEmail', userEmail);
        }
        if (userProfile?.chapter != null) {
          final chapterData =
              await FirebaseService.getChapter(userProfile!.chapter!);
          if (chapterData != null) {
            userChapter = Chapter.fromFirestore(chapterData);
          }
        }

        final coins = userProfile?.points ?? 0;
        final effectiveRank = FBLARankSystem.rankForCoins(coins).name;
        final storedRank = userProfile?.rank ?? FBLARankSystem.defaultRank;
        if (FBLARankSystem.indexForRank(effectiveRank) >
            FBLARankSystem.indexForRank(storedRank)) {
          await FirebaseService.updateUserProfile(userId, {
            'rank': effectiveRank,
          });
          profileData['rank'] = effectiveRank;
          userProfile = FBLAUser.fromFirestore(profileData);
        }
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> refreshUserProfile() async {
    if (firebaseUser != null) {
      await _loadUserProfile(firebaseUser!.uid);
      notifyListeners();
    }
  }

  void toggleSaveEvent(String eventId) {
    if (savedEventIds.contains(eventId)) {
      savedEventIds.remove(eventId);
    } else {
      savedEventIds.add(eventId);
    }
    prefs.setStringList('savedEvents', savedEventIds.toList());
    notifyListeners();
  }

  // First-run feature tour gating.
  bool get hasSeenFeatureTour => prefs.getBool('hasSeenFeatureTour') ?? false;

  Future<void> markFeatureTourSeen() async {
    await prefs.setBool('hasSeenFeatureTour', true);
  }

  Future<void> resetFeatureTour() async {
    await prefs.setBool('hasSeenFeatureTour', false);
  }

  void toggleParticipatingEvent(String eventId) {
    if (participatingEventIds.contains(eventId)) {
      participatingEventIds.remove(eventId);
    } else {
      participatingEventIds.add(eventId);
    }
    prefs.setStringList('participatingEvents', participatingEventIds.toList());
    notifyListeners();
  }

  void rsvpEvent(String eventId, String response) {
    final e = events.firstWhere((ev) => ev.id == eventId);
    e.rsvps[userEmail] = response;

    final userKey = (firebaseUser?.uid ?? userEmail).trim();
    if (userKey.isNotEmpty) {
      unawaited(
        FirebaseService.updateEventRsvp(
          eventId: eventId,
          userKey: userKey,
          response: response,
        ),
      );
    }

    notifyListeners();
  }

  void postMessage(String threadId, ChatMessage message) {
    final t = threads.firstWhere((th) => th.id == threadId);
    t.messages.add(message);

    unawaited(
      FirebaseService.appendThreadMessage(
        threadId: threadId,
        message: {
          'author': message.author,
          'text': message.text,
          'time': Timestamp.fromDate(message.time),
        },
      ),
    );

    notifyListeners();
  }

  void addThread(ChatThread thread) {
    threads.add(thread);

    unawaited(
      FirebaseService.createThread({
        'id': thread.id,
        'title': thread.title,
        'messages': thread.messages
            .map(
              (message) => {
                'author': message.author,
                'text': message.text,
                'time': Timestamp.fromDate(message.time),
              },
            )
            .toList(growable: false),
      }),
    );

    notifyListeners();
  }

  void addUserEvent(Event event) {
    events.add(event);
    events.sort((a, b) => a.start.compareTo(b.start));
    notifyListeners();
  }

  void removeUserEvent(String eventId) {
    events.removeWhere((e) => e.id == eventId);
    if (savedEventIds.remove(eventId)) {
      prefs.setStringList('savedEvents', savedEventIds.toList());
    }
    notifyListeners();
  }
}

/* ------------------------
   Data classes
   ------------------------ */

class Event {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String location;
  final String description;
  final Map<String, String> rsvps = {}; // email -> response
  Event({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.location,
    required this.description,
  });
}

class NewsItem {
  final String id;
  final String title;
  final String body;
  final DateTime date;
  NewsItem(
      {required this.id,
      required this.title,
      required this.body,
      required this.date});
}

class Competition {
  final String id;
  final String name;
  final String description;
  final List<LeaderboardEntry> leaderboard;
  Competition(
      {required this.id,
      required this.name,
      required this.description,
      required this.leaderboard});
}

class LeaderboardEntry {
  final String user;
  final int points;
  LeaderboardEntry({required this.user, required this.points});
}

class ChatThread {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  ChatThread({required this.id, required this.title, required this.messages});
}

class ChatMessage {
  final String author;
  final String text;
  final DateTime time;
  ChatMessage({required this.author, required this.text, required this.time});
}

/* ------------------------
   Sample seed data
   ------------------------ */

final sampleEvents = [
  Event(
    id: 'e_ga_2026',
    title: 'Georgia State Leadership Conference',
    start: DateTime(2026, 3, 13, 8, 0),
    end: DateTime(2026, 3, 14, 17, 0),
    location: 'Hyatt Regency, Atlanta',
    description: 'Georgia SLC hosted at Hyatt Regency in Atlanta.',
  ),
  Event(
    id: 'e_fl_2026',
    title: 'Florida State Leadership Conference',
    start: DateTime(2026, 3, 12, 8, 0),
    end: DateTime(2026, 3, 15, 17, 0),
    location: 'Hilton Orlando, Orlando',
    description: 'Florida SLC hosted at Hilton Orlando in Orlando.',
  ),
  Event(
    id: 'e_ut_2026',
    title: 'Utah State Leadership Conference',
    start: DateTime(2026, 3, 10, 8, 0),
    end: DateTime(2026, 3, 11, 17, 0),
    location: 'Davis Conference Center, Layton',
    description: 'Utah SLC hosted at Davis Conference Center in Layton.',
  ),
  Event(
    id: 'e_wy_2026',
    title: 'Wyoming State Leadership Conference',
    start: DateTime(2026, 3, 18, 8, 0),
    end: DateTime(2026, 3, 20, 17, 0),
    location: 'University of Wyoming, Laramie',
    description: 'Wyoming SLC hosted at University of Wyoming in Laramie.',
  ),
  Event(
    id: 'e_tn_2026',
    title: 'Tennessee State Leadership Conference',
    start: DateTime(2026, 4, 6, 8, 0),
    end: DateTime(2026, 4, 9, 17, 0),
    location: 'Chattanooga Convention Center',
    description: 'Tennessee SLC hosted at Chattanooga Convention Center.',
  ),
  Event(
    id: 'e_pa_2026',
    title: 'Pennsylvania State Leadership Conference',
    start: DateTime(2026, 4, 13, 8, 0),
    end: DateTime(2026, 4, 15, 17, 0),
    location: 'Hershey Lodge, Hershey',
    description: 'Pennsylvania SLC hosted at Hershey Lodge in Hershey.',
  ),
  Event(
    id: 'e_wa_2026',
    title: 'Washington State Leadership Conference',
    start: DateTime(2026, 4, 21, 8, 0),
    end: DateTime(2026, 4, 24, 17, 0),
    location: 'Spokane Convention Center',
    description: 'Washington SLC hosted at Spokane Convention Center.',
  ),
  Event(
    id: 'e_officer_jun',
    title: 'Chapter Officer Meeting',
    start: DateTime(2026, 6, 9, 15, 30),
    end: DateTime(2026, 6, 9, 16, 30),
    location: 'Room 204',
    description:
        'Monthly officer sync to plan summer outreach and finalize NLC logistics.',
  ),
  Event(
    id: 'e_madpractice_jun',
    title: 'Mobile App Dev Practice Run',
    start: DateTime(2026, 6, 12, 16, 0),
    end: DateTime(2026, 6, 12, 18, 0),
    location: 'Computer Lab B',
    description:
        'Dry-run of the 7-minute presentation with Q&A. Bring laptops and demo devices.',
  ),
  Event(
    id: 'e_nlc_reg_deadline',
    title: 'NLC Registration Deadline',
    start: DateTime(2026, 6, 19, 23, 59),
    end: DateTime(2026, 6, 19, 23, 59),
    location: 'Online',
    description:
        'Final day to confirm National Leadership Conference registration and housing.',
  ),
  Event(
    id: 'e_awards_banquet_jun',
    title: 'Chapter Awards Banquet (Social)',
    start: DateTime(2026, 6, 26, 18, 0),
    end: DateTime(2026, 6, 26, 21, 0),
    location: 'School Cafeteria',
    description:
        'End-of-year celebration recognizing competitors and graduating seniors.',
  ),
  Event(
    id: 'e_nlc_2026',
    title: 'FBLA National Leadership Conference',
    start: DateTime(2026, 6, 29, 8, 0),
    end: DateTime(2026, 7, 2, 17, 0),
    location: 'San Antonio, TX',
    description:
        'Compete at the national level, attend workshops, and network with members nationwide.',
  ),
];

final sampleNews = [
  NewsItem(
    id: 'n1',
    title: 'Welcome to FBLA National Conference',
    body: 'Check the schedule and pickup your badge at registration.',
    date: DateTime.now().subtract(Duration(days: 1)),
  ),
  NewsItem(
    id: 'n2',
    title: 'New Resources Available',
    body: 'A set of study guides for competitions has been posted.',
    date: DateTime.now().subtract(Duration(days: 2)),
  ),
  NewsItem(
    id: 'n3',
    title: 'Chapter Meeting This Friday',
    body:
        'Join us for our weekly chapter meeting to discuss upcoming events and competitions.',
    date: DateTime.now().subtract(Duration(days: 3)),
  ),
  NewsItem(
    id: 'n4',
    title: 'State Leadership Conference Registration Open',
    body:
        'Registration for the State Leadership Conference is now open. Early bird pricing available.',
    date: DateTime.now().subtract(Duration(days: 4)),
  ),
  NewsItem(
    id: 'n5',
    title: 'National FBLA Competition Results',
    body:
        'Congratulations to all participants! Check out the results from this year\'s national competitions.',
    date: DateTime.now().subtract(Duration(days: 5)),
  ),
];

final sampleCompetitions = [
  Competition(
    id: 'c1',
    name: 'Intro to Business',
    description: 'Multiple choice skills test.',
    leaderboard: [
      LeaderboardEntry(user: 'Alice J.', points: 98),
      LeaderboardEntry(user: 'Ben C.', points: 92),
    ],
  ),
];

final sampleThreads = [
  ChatThread(
    id: 't1',
    title: 'General Discussion',
    messages: [
      ChatMessage(
          author: 'Moderator',
          text: 'Welcome everyone!',
          time: DateTime.now().subtract(Duration(hours: 3))),
    ],
  ),
];

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
bool _localNotificationsReady = false;

Future<void> ensureLocalNotificationsReady() async {
  if (!_localNotificationsReady) {
    await initLocalNotifications();
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

Future<void> initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  _localNotificationsReady = true;
}

Future<void> scheduleEventReminder(Event e) async {
  await ensureLocalNotificationsReady();

  final androidDetails = AndroidNotificationDetails(
    'events',
    'Event reminders',
    channelDescription: 'Reminders for saved events',
    importance: Importance.max,
    priority: Priority.high,
  );
  final iOSDetails = DarwinNotificationDetails();
  final details = NotificationDetails(android: androidDetails, iOS: iOSDetails);

  final scheduled = e.start.subtract(Duration(hours: 1));
  if (scheduled.isAfter(DateTime.now())) {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      e.id.hashCode,
      'Upcoming: ${e.title}',
      '${e.location} • ${_shortDateTime(e.start)}',
      tz.TZDateTime.from(scheduled, tz.local), // ✅ convert to TZDateTime
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}

DateTime? _nearEventReminderTime(DateTime eventStart) {
  final now = DateTime.now();

  final oneDayBefore = eventStart.subtract(const Duration(days: 1));
  final oneDayBeforeEvening = DateTime(
    oneDayBefore.year,
    oneDayBefore.month,
    oneDayBefore.day,
    18,
    0,
  );

  if (oneDayBeforeEvening.isAfter(now)) {
    return oneDayBeforeEvening;
  }

  final oneHourBefore = eventStart.subtract(const Duration(hours: 1));
  if (oneHourBefore.isAfter(now)) {
    return oneHourBefore;
  }

  return null;
}

int _autoReminderIdForEvent(Event e) {
  return e.id.hashCode ^ 0x5F3759DF;
}

Future<void> scheduleNearEventReminder(Event e) async {
  await ensureLocalNotificationsReady();

  final androidDetails = AndroidNotificationDetails(
    'events_near',
    'Upcoming event alerts',
    channelDescription: 'Alerts when event days are near',
    importance: Importance.max,
    priority: Priority.high,
  );
  const iOSDetails = DarwinNotificationDetails();
  final details = NotificationDetails(android: androidDetails, iOS: iOSDetails);

  final scheduled = _nearEventReminderTime(e.start);
  final id = _autoReminderIdForEvent(e);

  await flutterLocalNotificationsPlugin.cancel(id);

  if (scheduled == null) {
    return;
  }

  await flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    'Event coming up: ${e.title}',
    '${e.location} • ${_shortDateTime(e.start)}',
    tz.TZDateTime.from(scheduled, tz.local),
    details,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );
}

Future<void> sendDeveloperTestNotification() async {
  await ensureLocalNotificationsReady();

  const androidDetails = AndroidNotificationDetails(
    'developer_tools',
    'Developer tools',
    channelDescription: 'Developer test notifications',
    importance: Importance.max,
    priority: Priority.high,
  );
  const iOSDetails = DarwinNotificationDetails();
  const details = NotificationDetails(android: androidDetails, iOS: iOSDetails);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'FBLA',
    'Hi this is FBLA',
    details,
  );
}

/* ------------------------
   Utility helpers
   ------------------------ */

String _shortDateTime(DateTime d) {
  return '${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

/* ------------------------
   App widget tree
   ------------------------ */

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  const MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(prefs: prefs),
      child: Consumer<AppState>(
        builder: (context, app, child) => MaterialApp(
          title: 'FBLA Member App',
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: fblaLightBackground,
            primaryColor: fblaNavy,
            colorScheme: const ColorScheme.light(
              primary: fblaNavy,
              secondary: fblaGold,
              surface: fblaLightSurface,
              error: fblaLightDestructive,
            ),
            textTheme: const TextTheme(
              headlineLarge: TextStyle(color: fblaLightPrimaryText),
              headlineMedium: TextStyle(color: fblaLightPrimaryText),
              headlineSmall: TextStyle(color: fblaLightPrimaryText),
              titleLarge: TextStyle(color: fblaLightPrimaryText),
              titleMedium: TextStyle(color: fblaLightPrimaryText),
              titleSmall: TextStyle(color: fblaLightPrimaryText),
              bodyLarge: TextStyle(color: fblaLightPrimaryText),
              bodyMedium: TextStyle(color: fblaLightSecondaryText),
              bodySmall: TextStyle(color: fblaLightSecondaryText),
              labelLarge: TextStyle(color: fblaLightPrimaryText),
              labelMedium: TextStyle(color: fblaLightSecondaryText),
              labelSmall: TextStyle(color: fblaLightDisabledText),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: fblaLightBackground,
              foregroundColor: fblaLightPrimaryText,
              elevation: 0,
              titleTextStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: fblaLightPrimaryText),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: fblaNavy,
                foregroundColor: Colors.white,
                disabledBackgroundColor: fblaLightBorder,
                disabledForegroundColor: fblaLightDisabledText,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: fblaNavy,
                side: const BorderSide(color: fblaNavy, width: 1.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: fblaNavy,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: fblaLightSurface,
              labelStyle: const TextStyle(color: fblaLightSecondaryText),
              hintStyle: const TextStyle(color: fblaLightDisabledText),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: fblaLightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: fblaNavy, width: 1.4),
              ),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return fblaGold;
                return fblaLightDisabledText;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return fblaGold.withValues(alpha: 0.34);
                }
                return fblaLightBorder;
              }),
            ),
            cardTheme: CardThemeData(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 2,
              color: fblaLightSurface,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black.withValues(alpha: 0.16),
              margin: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: fblaNavy,
            colorScheme: ColorScheme.dark(
              primary: fblaNavy,
              secondary: fblaGold,
              surface: Colors.grey.shade900,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: fblaNavy,
              titleTextStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: fblaNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            cardTheme: CardThemeData(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              margin: EdgeInsets.symmetric(vertical: 8),
              color: Colors.grey.shade800,
            ),
          ),
          themeMode: app.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          debugShowCheckedModeBanner: false,
          routes: {
            '/login': (_) => const LoginScreen(),
            '/signup': (_) => const SignupScreen(),
            '/onboarding': (_) => const OnboardingScreen(),
            '/firebase_auth': (_) => const FirebaseAuthScreen(),
            '/home': (_) => RootScreen(),
          },
          home: AuthGate(),
        ),
      ),
    );
  }
}

class RootScreen extends StatefulWidget {
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with WidgetsBindingObserver {
  static const _lastTabIndexKey = 'lastRootTabIndex';
  static const _lastTabSavedAtKey = 'lastRootTabSavedAt';
  static const _sessionRestoreWindow = Duration(hours: 2);

  int _index = 0;
  DateTime? _lastBackPressedAt;
  AppState? _appState;
  bool _notificationsInitialized = false;
  bool _tourChecked = false;
  String _eventsScheduleSignature = '';

  // Order: 0=Home, 1=Events, 2=Resources, 3=Social, 4=More
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pages = [
      HomeScreen(onSelectRootTab: _selectTab),
      EventsScreen(),
      const ResourcesScreen(),
      const SocialScreen(),
      const MoreScreen(),
    ];
    _restoreLastTab();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(_saveLastTab());
        break;
      case AppLifecycleState.detached:
        unawaited(_clearLastTab());
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = Provider.of<AppState>(context);

    if (!identical(_appState, app)) {
      _appState?.removeListener(_onAppStateChanged);
      _appState = app;
      _appState?.addListener(_onAppStateChanged);
    }

    if (!_notificationsInitialized) {
      _notificationsInitialized = true;
      _initializeAndScheduleNotifications();
    }

    // Show the first-run guided tour once, after the home screen is painted.
    if (!_tourChecked) {
      _tourChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final app = _appState;
        if (app != null && !app.hasSeenFeatureTour) {
          FeatureTour.show(context);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  Future<void> _restoreLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_lastTabIndexKey);
    final savedAtRaw = prefs.getString(_lastTabSavedAtKey);
    final savedAt = savedAtRaw == null ? null : DateTime.tryParse(savedAtRaw);

    if (savedIndex == null ||
        savedAt == null ||
        savedIndex < 0 ||
        savedIndex >= _pages.length ||
        DateTime.now().difference(savedAt) > _sessionRestoreWindow) {
      await _clearLastTab();
      return;
    }

    if (!mounted) return;
    setState(() => _index = savedIndex);
  }

  Future<void> _saveLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastTabIndexKey, _index);
    await prefs.setString(_lastTabSavedAtKey, DateTime.now().toIso8601String());
  }

  Future<void> _clearLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastTabIndexKey);
    await prefs.remove(_lastTabSavedAtKey);
  }

  void _selectTab(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    unawaited(_saveLastTab());
  }

  Future<void> _initializeAndScheduleNotifications() async {
    await initLocalNotifications();
    await _scheduleNearEventRemindersForCurrentEvents();
  }

  void _onAppStateChanged() {
    _scheduleNearEventRemindersForCurrentEvents();
  }

  Future<void> _scheduleNearEventRemindersForCurrentEvents() async {
    final app = _appState;
    if (app == null) return;

    final sortedEvents = [...app.events]
      ..sort((a, b) => a.start.compareTo(b.start));
    final signature = sortedEvents
        .map((e) => '${e.id}|${e.start.millisecondsSinceEpoch}')
        .join(';');

    if (signature == _eventsScheduleSignature) {
      return;
    }

    _eventsScheduleSignature = signature;

    for (final event in sortedEvents) {
      await scheduleNearEventReminder(event);
    }
  }

  Widget _navIcon(IconData icon) {
    return Icon(icon, size: 28);
  }

  Widget _activeNavIcon(IconData icon) {
    return Icon(icon, size: 28, color: fblaGold);
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final isDark = app.isDarkMode;
    return WillPopScope(
      onWillPop: () async {
        if (_index != 0) {
          _selectTab(0);
          return false;
        }

        final now = DateTime.now();
        if (_lastBackPressedAt == null ||
            now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
          _lastBackPressedAt = now;
          return false;
        }

        unawaited(_clearLastTab());
        return true;
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark ? appBackgroundGradient : null,
            color: isDark ? null : fblaLightBackground,
          ),
          child: _pages[_index],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A1626) : fblaLightSurface,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                blurRadius: 18,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: _selectTab,
            type: BottomNavigationBarType.fixed,
            iconSize: 28,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedFontSize: 11.5,
            unselectedFontSize: 11,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
            elevation: 0,
            selectedItemColor: fblaGold,
            unselectedItemColor:
                isDark ? Colors.white60 : fblaLightDisabledText,
            backgroundColor: Colors.transparent,
            items: [
              BottomNavigationBarItem(
                icon: _navIcon(Icons.home_outlined),
                activeIcon: _activeNavIcon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: _navIcon(Icons.event_outlined),
                activeIcon: _activeNavIcon(Icons.event_rounded),
                label: 'Events',
              ),
              BottomNavigationBarItem(
                icon: _navIcon(Icons.school_outlined),
                activeIcon: _activeNavIcon(Icons.school_rounded),
                label: 'Resources',
              ),
              BottomNavigationBarItem(
                icon: _navIcon(Icons.people_outline_rounded),
                activeIcon: _activeNavIcon(Icons.people_alt_rounded),
                label: 'Social',
              ),
              BottomNavigationBarItem(
                icon: _navIcon(Icons.more_horiz),
                activeIcon: _activeNavIcon(Icons.more_horiz_rounded),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    if (app.loggedIn) {
      return RootScreen();
    }
    return const LoginScreen();
  }
}

/* ------------------------
  Section Header Widget & Home Screen
  ------------------------ */

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 5, height: 22, color: fblaGold),
          SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: fblaNavy)),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onSelectRootTab;

  const HomeScreen({super.key, this.onSelectRootTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _refreshHome() async {
    setState(() {});
  }

  void _openEventsTab() {
    if (widget.onSelectRootTab != null) {
      widget.onSelectRootTab!(1);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventsScreen()),
    );
  }

  void _openResourcesTab() {
    if (widget.onSelectRootTab != null) {
      widget.onSelectRootTab!(2);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ResourcesScreen()),
    );
  }

  Future<void> _toggleReminder(AppState app, Event event) async {
    final isSaved = app.savedEventIds.contains(event.id);
    app.toggleSaveEvent(event.id);

    if (isSaved) {
      await flutterLocalNotificationsPlugin.cancel(event.id.hashCode);
    } else {
      await scheduleEventReminder(event);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSaved
              ? 'Reminder removed for ${event.title}'
              : 'Reminder saved for ${event.title}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAnnouncementDialog(NewsItem post) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(post.title),
        content: Text(post.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompact = screenHeight < 720;
    final EdgeInsets listPadding = EdgeInsets.fromLTRB(
      16,
      isCompact ? 6 : 8,
      16,
      isCompact ? 18 : 28,
    );
    final double sectionSpacing = isCompact ? 18 : 24;
    final double smallSpacing = isCompact ? 10 : 12;
    final upcomingEvents = [...app.events]
      ..sort((a, b) => a.start.compareTo(b.start));
    final nextEvents = upcomingEvents
        .where((event) => event.end.isAfter(DateTime.now()))
        .take(3)
        .toList();
    final latestNews = [...app.news]..sort((a, b) => b.date.compareTo(a.date));
    final featuredNews = latestNews.take(3).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildHomeTopBar(app, isDark),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshHome,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: listPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNlcConferenceCard(isDark),
                          SizedBox(height: sectionSpacing),
                          _buildStatsRow(app, nextEvents, featuredNews),
                          SizedBox(height: sectionSpacing),
                          _buildSectionTitle(
                            title: 'Quick Actions',
                          ),
                          SizedBox(height: smallSpacing),
                          _buildQuickActions(),
                          SizedBox(height: sectionSpacing),
                          _buildSectionTitle(
                            title: 'Upcoming Events',
                          ),
                          SizedBox(height: smallSpacing),
                          if (nextEvents.isEmpty)
                            _buildEmptyStateCard(
                              icon: Icons.event_busy,
                              title: 'No upcoming events',
                              subtitle:
                                  'New events will show up here as they are added.',
                            )
                          else
                            ...nextEvents
                                .map((event) => _buildEventCard(app, event)),
                          SizedBox(height: sectionSpacing),
                          _buildSectionTitle(
                            title: 'Latest Updates',
                          ),
                          SizedBox(height: smallSpacing),
                          if (featuredNews.isEmpty)
                            _buildEmptyStateCard(
                              icon: Icons.campaign_outlined,
                              title: 'No announcements yet',
                              subtitle:
                                  'Check back soon for chapter and national updates.',
                            )
                          else
                            ...featuredNews.map(_buildAnnouncementCard),
                          SizedBox(height: sectionSpacing),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTopBar(AppState app, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? appBackgroundColor : fblaLightBackground,
        border: Border(
          bottom: BorderSide(
            color:
                isDark ? Colors.white.withValues(alpha: 0.08) : fblaLightBorder,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFD75E),
                fblaGold,
                Color(0xFFE09A00),
              ],
            ).createShader(rect),
            child: const Text(
              'FBLA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                height: 1.0,
              ),
            ),
          ),
          const Spacer(),
          _buildHeroCircleButton(
            icon: Icons.chat_bubble_outline_rounded,
            tooltip: 'AI Assistant',
            onTap: _openChatbot,
          ),
          const SizedBox(width: 10),
          _buildHeroCircleButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications are coming soon.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          _buildHeroProfileButton(app),
        ],
      ),
    );
  }

  Widget _buildNlcConferenceCard(bool isDark) {
    final daysUntilNlc = _daysUntilNlc();
    final titleColor = isDark ? Colors.white : fblaLightPrimaryText;
    final accentColor = isDark ? fblaGold : const Color(0xFFB7791F);
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: 0.78) : fblaLightSecondaryText;
    final cardBorderColor = isDark
        ? fblaGold.withValues(alpha: 0.28)
        : fblaGold.withValues(alpha: 0.34);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF102A4E),
                  Color(0xFF0A192F),
                  Color(0xFF1B2A44),
                ]
              : const [
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFBEB),
                  Color(0xFFEFF6FF),
                ],
        ),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: (isDark ? fblaGold : fblaBlue).withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              left: -34,
              bottom: -44,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? Colors.white : fblaBlue)
                      .withValues(alpha: isDark ? 0.06 : 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'NLC 2026',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 25,
                                  height: 1.08,
                                  fontWeight: FontWeight.w900,
                                ),
                                children: [
                                  const TextSpan(
                                    text:
                                        'FBLA National Leadership Conference ',
                                  ),
                                  TextSpan(
                                    text: '2026',
                                    style: TextStyle(color: accentColor),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Get ready for the biggest FBLA event of the year.',
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      _buildNlcCountdownBox(daysUntilNlc, isDark),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNlcInfoChip(
                          icon: Icons.calendar_month_outlined,
                          label: 'June 29 - July 2',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildNlcInfoChip(
                          icon: Icons.location_on_outlined,
                          label: 'San Antonio, TX',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openNlcDetails,
                          icon:
                              const Icon(Icons.info_outline_rounded, size: 19),
                          label: const Text('Learn More'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? fblaGold : fblaBlue,
                            foregroundColor: isDark ? fblaNavy : Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openCompetitions,
                          icon:
                              const Icon(Icons.emoji_events_outlined, size: 19),
                          label: const Text('Competitions'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: isDark ? fblaGold : fblaBlue,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            side: BorderSide(
                              color: isDark ? fblaGold : fblaBlue,
                              width: 1.4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _daysUntilNlc() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nlcStart = DateTime(2026, 6, 29);
    final days = nlcStart.difference(today).inDays;
    return days < 0 ? 0 : days;
  }

  Widget _buildNlcCountdownBox(int daysUntilNlc, bool isDark) {
    final label = daysUntilNlc == 1 ? 'day to go' : 'days to go';

    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? fblaGold.withValues(alpha: 0.32)
              : fblaGold.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: fblaGold.withValues(alpha: isDark ? 0.18 : 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '$daysUntilNlc',
            style: TextStyle(
              color: isDark ? fblaGold : fblaBlue,
              fontSize: 31,
              height: 0.95,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.76)
                  : fblaLightSecondaryText,
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNlcInfoChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : fblaLightBackground.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              isDark ? Colors.white.withValues(alpha: 0.10) : fblaLightBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isDark ? fblaGold : fblaBlue,
            size: 17,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : fblaLightPrimaryText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  void _openCompetitions() {
    if (widget.onSelectRootTab != null) {
      widget.onSelectRootTab!(1);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventsScreen()),
    );
  }

  void _openNlcDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NlcDetailScreen(
          onViewCompetitions: () {
            Navigator.pop(context);
            _openCompetitions();
          },
        ),
      ),
    );
  }

  Widget _buildHeroCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF102A4E), Color(0xFF1D4E89)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: fblaGold.withValues(alpha: 0.34)),
              boxShadow: [
                BoxShadow(
                  color: fblaBlue.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: fblaGold, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroProfileButton(AppState app) {
    final imageProvider = app.localProfileImageBytes != null
        ? MemoryImage(app.localProfileImageBytes!)
        : (app.userProfile?.photoUrl != null &&
                app.userProfile!.photoUrl!.isNotEmpty
            ? NetworkImage(app.userProfile!.photoUrl!)
            : null) as ImageProvider<Object>?;
    final initial = app.profileInitial;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF102A4E), Color(0xFF1D4E89)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: fblaGold.withValues(alpha: 0.34)),
            boxShadow: [
              BoxShadow(
                color: fblaBlue.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: CircleAvatar(
            backgroundColor: fblaGold.withValues(alpha: 0.18),
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: fblaGold,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  void _openChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (context) => ChatBloc(),
          child: ChatbotScreen(),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildHeroCard(String firstName, Event? nextEvent) {
    final isCompact = MediaQuery.of(context).size.height < 720;
    final heroPadding = isCompact ? 18.0 : 22.0;
    final titleSize = isCompact ? 26.0 : 28.0;
    final titleSpacing = isCompact ? 10.0 : 14.0;
    final bodySpacing = isCompact ? 8.0 : 10.0;
    final eventSpacing = isCompact ? 12.0 : 16.0;
    final buttonSpacing = isCompact ? 14.0 : 18.0;
    return Container(
      padding: EdgeInsets.all(heroPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF133A72),
            Color(0xFF0B2341),
            Color(0xFF101B32),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4E89).withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'FBLA Member Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: titleSpacing),
          Text(
            'Good to see you, $firstName.',
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          SizedBox(height: bodySpacing),
          Text(
            nextEvent == null
                ? 'Use your home page to stay informed, manage events, access resources, and keep up with FBLA social channels.'
                : 'Your next event is ${nextEvent.title} on ${_formatLongDate(nextEvent.start)}. Use this dashboard to stay informed, prepared, and connected.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.84),
              fontSize: isCompact ? 13 : 14,
              height: 1.45,
            ),
          ),
          if (nextEvent != null) ...[
            SizedBox(height: eventSpacing),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDB913).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.event_available,
                      color: Color(0xFFFDB913),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nextEvent.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_formatLongDate(nextEvent.start)} • ${nextEvent.location}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.74),
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: buttonSpacing),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openEventsTab,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.30)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: const Text('View Schedule'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openResourcesTab,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.30)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book, size: 18),
                  label: const Text('Resources'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    AppState app,
    List<Event> nextEvents,
    List<NewsItem> featuredNews,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.event,
            label: 'Upcoming',
            value: '${nextEvents.length}',
            color: const Color(0xFF1D4E89),
            gradient: const LinearGradient(
              colors: [Color(0xFF1D4E89), Color(0xFF163B6B)],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.notifications_active,
            label: 'Saved',
            value: '${app.savedEventIds.length}',
            color: const Color(0xFFFDB913),
            gradient: const LinearGradient(
              colors: [Color(0xFFD39A0B), Color(0xFFB87F05)],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.campaign,
            label: 'Updates',
            value: '${featuredNews.length}',
            color: const Color(0xFF6C63FF),
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF4C44D6)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.0,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _ModernQuickButton(
          icon: Icons.event_note,
          label: 'Events',
          subtitle: 'Schedule & reminders',
          gradient: const LinearGradient(
            colors: [Color(0xFF1D4E89), Color(0xFF2B6CB0)],
          ),
          onTap: _openEventsTab,
        ),
        _ModernQuickButton(
          icon: Icons.menu_book,
          label: 'Resources',
          subtitle: 'Guides & documents',
          gradient: const LinearGradient(
            colors: [Color(0xFF0A8F7A), Color(0xFF0DB39E)],
          ),
          onTap: _openResourcesTab,
        ),
        _ModernQuickButton(
          icon: Icons.business_center_outlined,
          label: 'Official FBLA',
          subtitle: 'Programs & NLC',
          gradient: const LinearGradient(
            colors: [Color(0xFF1D4E89), Color(0xFFFDB913)],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FBLAOfficialHubScreen()),
            );
          },
        ),
        _ModernQuickButton(
          icon: Icons.person_outline,
          label: 'Profile',
          subtitle: 'Member details',
          gradient: const LinearGradient(
            colors: [Color(0xFF8E44AD), Color(0xFF6C3483)],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle({
    required String title,
    String? subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : fblaLightPrimaryText,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.66)
                  : fblaLightSecondaryText,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEventCard(AppState app, Event event) {
    final saved = app.savedEventIds.contains(event.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : fblaLightPrimaryText;
    final secondaryText = isDark ? Colors.white70 : fblaLightSecondaryText;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B2D) : fblaLightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              isDark ? Colors.white.withValues(alpha: 0.07) : fblaLightBorder,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4E89).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.event, color: Color(0xFF6FA8FF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatLongDate(event.start)} • ${event.location}',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (saved)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDB913).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Saved',
                    style: TextStyle(
                      color: Color(0xFFFDB913),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event.description,
            style: TextStyle(
              color: secondaryText,
              fontSize: 14,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _toggleReminder(app, event),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : fblaNavy,
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : fblaNavy.withValues(alpha: 0.28),
                    ),
                  ),
                  icon: Icon(
                      saved ? Icons.notifications_off : Icons.notifications),
                  label: Text(saved ? 'Remove Reminder' : 'Set Reminder'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openEventsTab,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4E89),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open Events'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(NewsItem post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : fblaLightPrimaryText;
    final secondaryText = isDark ? Colors.white70 : fblaLightSecondaryText;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _showAnnouncementDialog(post),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1B2D) : fblaLightSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : fblaLightBorder,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E44AD).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child:
                          const Icon(Icons.campaign, color: Color(0xFFCB9FFF)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        post.title,
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _formatPostDate(post.date),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : fblaLightSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  post.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Tap to read more',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.62)
                            : fblaNavy,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward,
                      color: Color(0xFFFDB913),
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B2D) : fblaLightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              isDark ? Colors.white.withValues(alpha: 0.07) : fblaLightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : fblaLightSelectedNav,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon,
                color: isDark ? Colors.white70 : fblaLightPrimaryText),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : fblaLightPrimaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.68)
                        : fblaLightSecondaryText,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLongDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames[date.month - 1];
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month ${date.day} • $hour:$minute $suffix';
  }

  String _formatPostDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
  }
}

// ignore: unused_element
class _PostSearchDelegate extends SearchDelegate {
  final List<NewsItem> posts;

  _PostSearchDelegate(this.posts);

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    final isDark = base.brightness == Brightness.dark;
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: isDark ? appBackgroundColor : fblaLightBackground,
        foregroundColor: isDark ? Colors.white : fblaLightPrimaryText,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: fblaLightDisabledText),
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: TextStyle(
          color: isDark ? Colors.white : fblaLightPrimaryText,
          fontSize: 18,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        tooltip: 'Clear search',
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildMatches();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildMatches();
  }

  Widget _buildMatches() {
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? posts
        : posts
            .where(
              (post) =>
                  post.title.toLowerCase().contains(q) ||
                  post.body.toLowerCase().contains(q),
            )
            .toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No matching posts'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final post = filtered[index];
        return ListTile(
          title: Text(post.title),
          subtitle: Text(
            post.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => close(context, null),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Gradient gradient;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? null : fblaLightSurface,
        gradient: isDark ? gradient : null,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? null : Border.all(color: fblaLightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
            blurRadius: isDark ? 8 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isDark ? Colors.white : color, size: 24),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : fblaLightPrimaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : fblaLightSecondaryText,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ModernQuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ModernQuickButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Extract the primary color from gradient for text and borders
    final primaryColor = gradient.colors.first;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : primaryColor;
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: 0.84) : fblaLightPrimaryText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withValues(alpha: isDark ? 0.32 : 0.18),
                primaryColor.withValues(alpha: isDark ? 0.18 : 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryColor.withValues(alpha: isDark ? 0.70 : 0.50),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: isDark ? 0.18 : 0.12),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.40),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: subtitleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Login screen moved to lib/screens/login_screen.dart

/* ------------------------
   Events Screen (calendar)
   ------------------------ */

/// Visual classification for an event, derived from its title.
class _EventKind {
  final String label;
  final Color color;
  final IconData icon;
  const _EventKind(this.label, this.color, this.icon);
}

const _EventKind _kindDeadline =
    _EventKind('Deadline', Color(0xFFFF6B6B), Icons.flag_rounded);
const _EventKind _kindCompetition =
    _EventKind('Competition', Color(0xFFF6C500), Icons.emoji_events_rounded);
const _EventKind _kindMeeting =
    _EventKind('Meeting', Color(0xFF64B5F6), Icons.groups_2_rounded);
const _EventKind _kindWorkshop =
    _EventKind('Workshop', Color(0xFF81C784), Icons.school_rounded);
const _EventKind _kindSocial =
    _EventKind('Social', Color(0xFFBA68C8), Icons.celebration_rounded);
const _EventKind _kindGeneral =
    _EventKind('Event', Color(0xFF7CB6F2), Icons.event_rounded);

_EventKind _kindForEvent(Event e) {
  final t = e.title.toLowerCase();
  if (t.contains('deadline') ||
      t.contains('due') ||
      t.contains('registration') ||
      t.contains('dues') ||
      t.contains('rsvp')) {
    return _kindDeadline;
  }
  if (t.contains('conference') ||
      t.contains('slc') ||
      t.contains('nlc') ||
      t.contains('competition') ||
      t.contains('competitive') ||
      t.contains('compete') ||
      t.contains('regional') ||
      t.contains('nationals')) {
    return _kindCompetition;
  }
  if (t.contains('meeting') || t.contains('officer')) {
    return _kindMeeting;
  }
  if (t.contains('workshop') ||
      t.contains('training') ||
      t.contains('practice') ||
      t.contains('session') ||
      t.contains('prep') ||
      t.contains('study')) {
    return _kindWorkshop;
  }
  if (t.contains('social') ||
      t.contains('party') ||
      t.contains('celebration') ||
      t.contains('banquet') ||
      t.contains('mixer') ||
      t.contains('fundrais')) {
    return _kindSocial;
  }
  return _kindGeneral;
}

/// Seeded FBLA events use stable ids; user-created ones are prefixed `custom_`.
bool _isOfficialEvent(Event e) => !e.id.startsWith('custom_');

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  static const Color _fblaBlue = Color(0xFF1D4E89);
  static const Color _fblaGold = Color(0xFFF6C500);

  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _format = CalendarFormat.month;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = now;
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  // ---- data helpers ----

  bool _passesFilter(Event e) {
    switch (_filter) {
      case 'official':
        return _isOfficialEvent(e);
      case 'mine':
        return !_isOfficialEvent(e);
      case 'competition':
        return identical(_kindForEvent(e), _kindCompetition);
      case 'deadline':
        return identical(_kindForEvent(e), _kindDeadline);
      default:
        return true;
    }
  }

  List<Event> _visibleEvents(AppState app) =>
      app.events.where(_passesFilter).toList();

  bool _occursOn(Event e, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(e.start.year, e.start.month, e.start.day);
    final en = DateTime(e.end.year, e.end.month, e.end.day);
    return !d.isBefore(s) && !d.isAfter(en);
  }

  List<Event> _eventsForDay(List<Event> source, DateTime day) =>
      source.where((e) => _occursOn(e, day)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  String _eventTimeText(Event e) {
    if (isSameDay(e.start, e.end)) {
      return '${DateFormat('h:mm a').format(e.start)} – ${DateFormat('h:mm a').format(e.end)}';
    }
    return '${DateFormat('MMM d').format(e.start)} – ${DateFormat('MMM d').format(e.end)}';
  }

  // ---- decorations ----

  BoxDecoration _panelDecoration(bool isDark) => BoxDecoration(
        color: isDark ? null : fblaLightSurface,
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0F1C31), Color(0xFF0A1628)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isDark ? Colors.white12 : fblaLightBorder.withValues(alpha: 0.85),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visible = _visibleEvents(app);
    final dayEvents = _eventsForDay(visible, _selectedDay);

    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : fblaLightBackground,
      resizeToAvoidBottomInset: false,
      floatingActionButton: FloatingActionButton(
        heroTag: 'events_fab',
        onPressed: () => _addEvent(app),
        backgroundColor: _fblaBlue,
        foregroundColor: Colors.white,
        tooltip: 'Add event',
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(isDark, visible),
            const SizedBox(height: 2),
            _buildFilterChips(isDark),
            _buildCalendarCard(isDark, visible),
            const SizedBox(height: 2),
            Expanded(child: _buildAgenda(isDark, app, dayEvents)),
          ],
        ),
      ),
    );
  }

  // ---- header ----

  Widget _buildHeader(bool isDark, List<Event> visible) {
    final now = DateTime.now();
    final upcoming = visible.where((e) => e.end.isAfter(now)).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      decoration: _panelDecoration(isDark),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM').format(_focusedDay),
                      style: TextStyle(
                        color: isDark ? Colors.white : fblaLightPrimaryText,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('yyyy').format(_focusedDay)}  •  $upcoming upcoming',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : fblaLightSecondaryText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _circleNavButton(
                  Icons.chevron_left, isDark, () => _shiftMonth(-1)),
              const SizedBox(width: 6),
              _circleNavButton(
                  Icons.chevron_right, isDark, () => _shiftMonth(1)),
              const SizedBox(width: 8),
              _todayButton(isDark),
            ],
          ),
          const SizedBox(height: 12),
          _buildFormatToggle(isDark),
        ],
      ),
    );
  }

  Widget _circleNavButton(IconData icon, bool isDark, VoidCallback onTap) {
    return Material(
      color:
          isDark ? Colors.white.withValues(alpha: 0.06) : fblaLightBackground,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? Colors.white : fblaLightPrimaryText,
          ),
        ),
      ),
    );
  }

  Widget _todayButton(bool isDark) {
    return OutlinedButton(
      onPressed: () {
        final now = DateTime.now();
        setState(() {
          _focusedDay = now;
          _selectedDay = DateTime(now.year, now.month, now.day);
          _format = CalendarFormat.month;
        });
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? _fblaGold : _fblaBlue,
        side: BorderSide(
            color: (isDark ? _fblaGold : _fblaBlue).withValues(alpha: 0.7)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: const Text('Today',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
    );
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + delta, 1);
    });
  }

  Widget _buildFormatToggle(bool isDark) {
    const formats = <CalendarFormat, String>{
      CalendarFormat.month: 'Month',
      CalendarFormat.twoWeeks: '2 Weeks',
      CalendarFormat.week: 'Week',
    };
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withValues(alpha: 0.06) : fblaLightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : fblaLightBorder),
      ),
      child: Row(
        children: formats.entries.map((entry) {
          final selected = _format == entry.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _format = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _fblaBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : (isDark
                            ? Colors.grey.shade400
                            : fblaLightSecondaryText),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---- filter chips ----

  Widget _buildFilterChips(bool isDark) {
    const chips = <List<String>>[
      ['all', 'All'],
      ['official', 'FBLA Official'],
      ['mine', 'My Events'],
      ['competition', 'Competitions'],
      ['deadline', 'Deadlines'],
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final id = chips[i][0];
          final label = chips[i][1];
          final selected = _filter == id;
          return Center(
            child: GestureDetector(
              onTap: () => setState(() => _filter = id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? _fblaBlue
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : fblaLightSurface),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: selected
                        ? _fblaBlue
                        : (isDark ? Colors.white12 : fblaLightBorder),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : (isDark
                            ? Colors.grey.shade300
                            : fblaLightPrimaryText),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---- calendar ----

  Widget _buildCalendarCard(bool isDark, List<Event> visible) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      decoration: _panelDecoration(isDark),
      child: TableCalendar<Event>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _format,
        availableGestures: AvailableGestures.horizontalSwipe,
        headerVisible: false,
        daysOfWeekHeight: 26,
        rowHeight: 48,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
        eventLoader: (day) => _eventsForDay(visible, day),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
        },
        onPageChanged: (focused) => setState(() => _focusedDay = focused),
        onFormatChanged: (f) => setState(() => _format = f),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : fblaLightSecondaryText,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          weekendStyle: TextStyle(
            color: isDark ? _fblaGold.withValues(alpha: 0.85) : _fblaBlue,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        calendarBuilders: CalendarBuilders<Event>(
          defaultBuilder: (c, day, focused) => _dayCell(day, isDark,
              selected: false, today: false, outside: false),
          outsideBuilder: (c, day, focused) => _dayCell(day, isDark,
              selected: false, today: false, outside: true),
          todayBuilder: (c, day, focused) => _dayCell(day, isDark,
              selected: false, today: true, outside: false),
          selectedBuilder: (c, day, focused) => _dayCell(day, isDark,
              selected: true, today: false, outside: false),
          markerBuilder: (c, day, events) {
            if (events.isEmpty) return null;
            final onSelected = isSameDay(_selectedDay, day);
            return Positioned(
              bottom: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: events.take(3).map((e) {
                  final k = _kindForEvent(e);
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1.3),
                    decoration: BoxDecoration(
                      color: onSelected ? Colors.white : k.color,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _dayCell(
    DateTime day,
    bool isDark, {
    required bool selected,
    required bool today,
    required bool outside,
  }) {
    Color bg;
    Color border;
    Color text;
    FontWeight weight;

    if (selected) {
      bg = _fblaBlue;
      border = _fblaBlue;
      text = Colors.white;
      weight = FontWeight.w800;
    } else if (today) {
      bg = _fblaBlue.withValues(alpha: isDark ? 0.22 : 0.12);
      border = _fblaGold;
      text = isDark ? Colors.white : fblaLightPrimaryText;
      weight = FontWeight.w800;
    } else {
      bg = Colors.transparent;
      border = Colors.transparent;
      weight = FontWeight.w600;
      text = outside
          ? (isDark ? Colors.white24 : fblaLightDisabledText)
          : (isDark ? Colors.white : fblaLightPrimaryText);
    }

    return Container(
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: border, width: today ? 1.5 : 1),
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(color: text, fontWeight: weight, fontSize: 13.5),
      ),
    );
  }

  // ---- agenda ----

  Widget _buildAgenda(bool isDark, AppState app, List<Event> dayEvents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Icon(Icons.event_note_rounded,
                  size: 18, color: isDark ? _fblaGold : _fblaBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMMM d').format(_selectedDay),
                  style: TextStyle(
                    color: isDark ? Colors.white : fblaLightPrimaryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '${dayEvents.length} event${dayEvents.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : fblaLightSecondaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: dayEvents.isEmpty
              ? _emptyDay(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                  itemCount: dayEvents.length,
                  itemBuilder: (c, i) => _eventCard(isDark, app, dayEvents[i]),
                ),
        ),
      ],
    );
  }

  Widget _emptyDay(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF13243D) : fblaLightSurface,
                border: Border.all(
                    color: isDark ? Colors.white12 : fblaLightBorder),
              ),
              child: Icon(Icons.event_available_outlined,
                  size: 38,
                  color:
                      isDark ? Colors.grey.shade400 : fblaLightSecondaryText),
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing scheduled',
              style: TextStyle(
                color: isDark ? Colors.grey.shade200 : fblaLightPrimaryText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the + button to schedule something\nand set a reminder in seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade500 : fblaLightSecondaryText,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventCard(bool isDark, AppState app, Event e) {
    final kind = _kindForEvent(e);
    final official = _isOfficialEvent(e);
    final saved = app.savedEventIds.contains(e.id);
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    final secondary = isDark ? Colors.grey.shade300 : fblaLightSecondaryText;
    final hasDescription =
        e.description.isNotEmpty && e.description != 'User-created event';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? null : fblaLightSurface,
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0F1B2D), Color(0xFF162236)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : fblaLightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: kind.color,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(18)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _kindBadge(kind),
                        const SizedBox(width: 8),
                        if (official) _officialTag(isDark),
                        const Spacer(),
                        _iconBtn(
                          saved ? Icons.bookmark : Icons.bookmark_outline,
                          _fblaGold,
                          () async {
                            app.toggleSaveEvent(e.id);
                            if (!saved) {
                              await scheduleEventReminder(e);
                            } else {
                              await flutterLocalNotificationsPlugin
                                  .cancel(e.id.hashCode);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      e.title,
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _infoRow(Icons.schedule_rounded, _eventTimeText(e), isDark),
                    const SizedBox(height: 6),
                    _infoRow(Icons.location_on_outlined, e.location, isDark),
                    if (hasDescription) ...[
                      const SizedBox(height: 10),
                      Text(
                        e.description,
                        style: TextStyle(
                          color: secondary,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await scheduleEventReminder(e);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Reminder set for ${e.title}'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(
                                Icons.notifications_active_outlined,
                                size: 16),
                            label: const Text('Remind me'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  isDark ? Colors.white : _fblaBlue,
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white24
                                    : _fblaBlue.withValues(alpha: 0.5),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        if (!official) ...[
                          const SizedBox(width: 8),
                          _iconBtn(
                            Icons.delete_outline_rounded,
                            isDark ? Colors.red.shade300 : fblaLightDestructive,
                            () => _confirmDelete(app, e),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kindBadge(_EventKind k) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: k.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: k.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(k.icon, size: 13, color: k.color),
          const SizedBox(width: 5),
          Text(
            k.label,
            style: TextStyle(
                color: k.color, fontWeight: FontWeight.w700, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _officialTag(bool isDark) {
    final c = isDark ? const Color(0xFF7CB6F2) : _fblaBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _fblaBlue.withValues(alpha: isDark ? 0.25 : 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 12, color: c),
          const SizedBox(width: 4),
          Text('FBLA',
              style: TextStyle(
                  color: c, fontWeight: FontWeight.w800, fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon,
            size: 15,
            color: isDark ? Colors.grey.shade400 : fblaLightSecondaryText),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : fblaLightPrimaryText,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // ---- actions ----

  Future<void> _addEvent(AppState app) async {
    final created = await Navigator.push<Event>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEventScreen(initialDate: _selectedDay),
      ),
    );
    if (created == null || !mounted) return;
    app.addUserEvent(created);
    setState(() {
      _selectedDay =
          DateTime(created.start.year, created.start.month, created.start.day);
      _focusedDay = _selectedDay;
    });
    await scheduleNearEventReminder(created);
  }

  Future<void> _confirmDelete(AppState app, Event e) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF12203A) : Colors.white,
        title: Text('Delete event?',
            style:
                TextStyle(color: isDark ? Colors.white : fblaLightPrimaryText)),
        content: Text(
          'Remove "${e.title}" from your calendar? This cannot be undone.',
          style: TextStyle(
              color: isDark ? Colors.grey.shade300 : fblaLightSecondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(
                    color: isDark ? Colors.red.shade300 : fblaLightDestructive,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await flutterLocalNotificationsPlugin.cancel(e.id.hashCode);
    app.removeUserEvent(e.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Event deleted'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class AddEventScreen extends StatefulWidget {
  final DateTime initialDate;

  const AddEventScreen({super.key, required this.initialDate});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _pickedDate;
  bool _includeTime = false;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _pickedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await _showStyledDatePicker();
    if (date == null) return;
    setState(() => _pickedDate = date);
  }

  Future<DateTime?> _showStyledDatePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      return showDatePicker(
        context: context,
        initialDate: _pickedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );
    }

    return showDatePicker(
      context: context,
      initialDate: _pickedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.black,
              headerBackgroundColor: Colors.black,
              headerForegroundColor: Colors.white,
              dayStyle: const TextStyle(color: Colors.white),
              weekdayStyle: const TextStyle(color: Colors.white70),
              yearStyle: const TextStyle(color: Colors.white),
              todayBorder: BorderSide(color: Colors.white.withOpacity(0.7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: Colors.white.withOpacity(0.35), width: 1.4),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: Colors.white.withOpacity(0.35), width: 1.4),
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  Future<TimeOfDay?> _showStyledTimePicker(TimeOfDay initialTime) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      return showTimePicker(
        context: context,
        initialTime: initialTime,
      );
    }

    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.black,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              dialHandColor: Colors.white,
              dialBackgroundColor: const Color(0xFF090909),
              hourMinuteColor: Colors.black,
              hourMinuteTextColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.black;
                }
                return Colors.white;
              }),
              dayPeriodTextColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.black;
                }
                return Colors.white;
              }),
              dayPeriodColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                return Colors.black;
              }),
              entryModeIconColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: Colors.white.withOpacity(0.35), width: 1.4),
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  Future<void> _pickStartTime() async {
    final selected = await _showStyledTimePicker(
      _startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (selected == null) return;
    setState(() => _startTime = selected);
  }

  Future<void> _pickEndTime() async {
    final selected = await _showStyledTimePicker(
      _endTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (selected == null) return;
    setState(() => _endTime = selected);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    DateTime startDateTime;
    DateTime endDateTime;

    if (_includeTime && _startTime != null) {
      startDateTime = DateTime(
        _pickedDate.year,
        _pickedDate.month,
        _pickedDate.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      if (_endTime != null) {
        endDateTime = DateTime(
          _pickedDate.year,
          _pickedDate.month,
          _pickedDate.day,
          _endTime!.hour,
          _endTime!.minute,
        );

        if (!endDateTime.isAfter(startDateTime)) {
          endDateTime = startDateTime.add(const Duration(hours: 1));
        }
      } else {
        endDateTime = startDateTime.add(const Duration(hours: 1));
      }
    } else {
      startDateTime =
          DateTime(_pickedDate.year, _pickedDate.month, _pickedDate.day, 9, 0);
      endDateTime = startDateTime.add(const Duration(hours: 1));
    }

    final event = Event(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      title: _titleController.text.trim(),
      start: startDateTime,
      end: endDateTime,
      location: _locationController.text.trim().isEmpty
          ? 'TBD'
          : _locationController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? 'User-created event'
          : _descriptionController.text.trim(),
    );

    Navigator.pop(context, event);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final fblaBlue = const Color(0xFF1D4E89);
    final fblaGold = const Color(0xFFF6C500);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? appBackgroundColor : fblaLightBackground,
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: isDark ? Colors.transparent : fblaLightBackground,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : fblaLightPrimaryText,
        actions: [
          TextButton(
            onPressed: _submit,
            child: Text(
              'Save',
              style: TextStyle(
                color: isDark ? fblaGold : fblaBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? appBackgroundGradient : null,
          color: isDark ? null : fblaLightBackground,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              // Header Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [fblaBlue, fblaBlue.withOpacity(0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: fblaBlue.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.event_note,
                      color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 24),

              // Event Name Section
              _buildSectionLabel('Event Details', Icons.edit_note),
              const SizedBox(height: 12),
              _buildStyledTextField(
                controller: _titleController,
                label: 'Event Name',
                hint: 'Enter event name',
                icon: Icons.title,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Event name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildStyledTextField(
                controller: _locationController,
                label: 'Location',
                hint: 'Where will this take place?',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),
              _buildStyledTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Add event details...',
                icon: Icons.notes,
                maxLines: 3,
              ),

              const SizedBox(height: 28),

              // Date & Time Section
              _buildSectionLabel('Date & Time', Icons.schedule),
              const SizedBox(height: 12),

              // Date Picker Card
              _buildDateTimeCard(
                icon: Icons.calendar_today,
                label: 'Date',
                value: _formatDate(_pickedDate),
                onTap: _pickDate,
                color: fblaBlue,
              ),

              const SizedBox(height: 12),

              // Time Toggle
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2640) : fblaLightSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : fblaLightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        color: isDark
                            ? Colors.grey.shade400
                            : fblaLightSecondaryText,
                        size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Set specific time',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade300
                              : fblaLightPrimaryText,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Switch(
                      value: _includeTime,
                      activeColor: fblaBlue,
                      activeTrackColor: fblaBlue.withOpacity(0.4),
                      onChanged: (value) {
                        setState(() {
                          _includeTime = value;
                          if (!_includeTime) {
                            _startTime = null;
                            _endTime = null;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Time Pickers (animated)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _includeTime
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildDateTimeCard(
                                icon: Icons.play_arrow_rounded,
                                label: 'Start',
                                value:
                                    _startTime?.format(context) ?? 'Set time',
                                onTap: _pickStartTime,
                                color: const Color(0xFF4CAF50),
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDateTimeCard(
                                icon: Icons.stop_rounded,
                                label: 'End',
                                value: _endTime?.format(context) ?? 'Set time',
                                onTap: _pickEndTime,
                                color: const Color(0xFFFF5722),
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 32),

              // Create Button
              Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [fblaBlue, fblaBlue.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: fblaBlue.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.add_circle_outline, size: 24),
                  label: const Text(
                    'Create Event',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon,
            color: isDark ? const Color(0xFFF6C500) : fblaNavy, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: isDark ? Colors.white : fblaLightPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2640) : fblaLightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : fblaLightBorder,
        ),
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(
          color: isDark ? Colors.white : fblaLightPrimaryText,
          fontSize: 15,
        ),
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : fblaLightSecondaryText,
          ),
          hintStyle: TextStyle(
            color: isDark ? Colors.grey.shade600 : fblaLightDisabledText,
          ),
          prefixIcon: Icon(
            icon,
            color: isDark ? Colors.grey.shade400 : fblaLightSecondaryText,
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDateTimeCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required Color color,
    bool compact = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 14 : 16,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2640) : fblaLightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.3 : 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: compact ? 18 : 22),
              ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade500
                            : fblaLightSecondaryText,
                        fontSize: compact ? 11 : 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: isDark ? Colors.white : fblaLightPrimaryText,
                        fontSize: compact ? 14 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? Colors.grey.shade500 : fblaLightDisabledText,
                size: compact ? 20 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthYearPickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const _MonthYearPickerSheet({
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<_MonthYearPickerSheet> createState() => _MonthYearPickerSheetState();
}

class _MonthYearPickerSheetState extends State<_MonthYearPickerSheet> {
  late int _selectedYear;
  late int _selectedMonth;
  final Color fblaBlue = const Color(0xFF1D4E89);

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(11, (i) => currentYear - 2 + i);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Select Month & Year',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Year Selector
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: years.length,
              itemBuilder: (context, index) {
                final year = years[index];
                final isSelected = year == _selectedYear;
                return GestureDetector(
                  onTap: () => setState(() => _selectedYear = year),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [fblaBlue, fblaBlue.withOpacity(0.7)])
                          : null,
                      color: isSelected ? null : const Color(0xFF1A2640),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? fblaBlue : Colors.white12,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$year',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Month Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.0,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final isSelected = month == _selectedMonth;
              return GestureDetector(
                onTap: () => setState(() => _selectedMonth = month),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [fblaBlue, fblaBlue.withOpacity(0.7)])
                        : null,
                    color: isSelected ? null : const Color(0xFF1A2640),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? fblaBlue : Colors.white12,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      months[index],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget
                    .onDateSelected(DateTime(_selectedYear, _selectedMonth, 1));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: fblaBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Go to Month',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 10),
        ],
      ),
    );
  }
}

/* ------------------------
   Competitions Screen
   ------------------------ */

class CompetitionsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Competitions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: app.competitions.isEmpty
            ? const Center(
                child: Text('No competitions yet.',
                    style: TextStyle(color: Colors.white70)),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: app.competitions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _competitionCard(context, app.competitions[i]),
              ),
      ),
    );
  }

  Widget _competitionCard(BuildContext context, Competition c) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => CompetitionDetail(c))),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [fblaGold, Color(0xFFFFD54F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: fblaNavy, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(c.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13, height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

class CompetitionDetail extends StatelessWidget {
  final Competition competition;
  const CompetitionDetail(this.competition, {super.key});

  @override
  Widget build(BuildContext context) {
    final board = competition.leaderboard;
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: Text(competition.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(competition.description,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14, height: 1.4)),
            ),
            const SizedBox(height: 20),
            Row(
              children: const [
                Icon(Icons.leaderboard_rounded, color: fblaGold, size: 20),
                SizedBox(width: 8),
                Text('Leaderboard',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < board.length; i++) _leaderRow(i + 1, board[i]),
          ],
        ),
      ),
    );
  }

  Widget _leaderRow(int rank, dynamic entry) {
    final Color medal = rank == 1
        ? const Color(0xFFFFD54F)
        : rank == 2
            ? const Color(0xFFB0BEC5)
            : rank == 3
                ? const Color(0xFFFF8A65)
                : Colors.white30;
    final String user = '${entry.user}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: rank <= 3 ? medal.withValues(alpha: 0.5) : Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medal.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: medal),
            ),
            child: Text('$rank',
                style: TextStyle(
                    color: rank <= 3 ? medal : Colors.white70,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 16,
            backgroundColor: fblaBlue,
            child: Text(user.isEmpty ? '?' : user[0],
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(user,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          Text('${entry.points} pts',
              style: const TextStyle(
                  color: fblaGold, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/* ------------------------
   Community Screen
   ------------------------ */

class CommunityScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Community')),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: app.threads.length,
        itemBuilder: (context, idx) {
          final t = app.threads[idx];
          return Card(
            child: ListTile(
              title:
                  Text(t.title, style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${t.messages.length} messages'),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ThreadScreen(thread: t))),
            ),
          );
        },
      ),
    );
  }
}

class ThreadScreen extends StatefulWidget {
  final ChatThread thread;
  ThreadScreen({required this.thread});
  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final t = app.threads.firstWhere((th) => th.id == widget.thread.id);
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              reverse: true,
              children: t.messages.reversed
                  .map((m) => ListTile(
                        title: Text(m.author),
                        subtitle: Text(m.text),
                        trailing: Text(
                            '${m.time.hour}:${m.time.minute.toString().padLeft(2, '0')}'),
                      ))
                  .toList(),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: _controller,
                      decoration:
                          InputDecoration(hintText: 'Write a message'))),
              IconButton(
                  tooltip: 'Send message',
                  onPressed: () {
                    if (_controller.text.trim().isEmpty) return;
                    final app = Provider.of<AppState>(context, listen: false);
                    final author = app.loggedIn ? app.displayName : 'Guest';
                    final msg = ChatMessage(
                        author: author,
                        text: _controller.text.trim(),
                        time: DateTime.now());
                    app.postMessage(t.id, msg);
                    _controller.clear();
                  },
                  icon: Icon(Icons.send))
            ]),
          )
        ],
      ),
    );
  }
}

/* ------------------------
   Feeds Screen
   ------------------------ */

class FeedsScreen extends StatefulWidget {
  const FeedsScreen({super.key});

  @override
  State<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _fblaBlue = Color(0xFF1D4E89);
  static const Color _fblaGold = Color(0xFFF6C500);

  static const List<_SocialPlatform> _platforms = [
    _SocialPlatform('Instagram', Icons.camera_alt_rounded, Color(0xFFE1306C),
        'https://www.instagram.com/fbla_national/',
        inApp: true),
    _SocialPlatform('YouTube', Icons.smart_display_rounded, Color(0xFFFF0000),
        'https://www.youtube.com/@fbla_national'),
    _SocialPlatform('Facebook', Icons.facebook_rounded, Color(0xFF1877F2),
        'https://www.facebook.com/FBLAPBL/'),
    _SocialPlatform('LinkedIn', Icons.business_center_rounded,
        Color(0xFF0A66C2), 'https://www.linkedin.com/company/fbla-pbl/'),
    _SocialPlatform('X', Icons.alternate_email_rounded, Color(0xFF1DA1F2),
        'https://twitter.com/FBLA_National'),
    _SocialPlatform('Links', Icons.link_rounded, Color(0xFFFDB913),
        'https://linktr.ee/FBLA_National'),
  ];

  late final TabController _tab;
  late Future<List<Video>> _videosFuture;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _videosFuture = YouTubeService().fetchVideos(maxResults: 15);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _refreshVideos() async {
    setState(() {
      _videosFuture = YouTubeService().fetchVideos(maxResults: 15);
    });
    await _videosFuture;
  }

  Future<void> _openPlatform(_SocialPlatform p) async {
    if (p.inApp) {
      InstagramFeedScreen.open(context);
      return;
    }
    final launched =
        await launchUrl(Uri.parse(p.url), mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open ${p.name} right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _playVideo(Video video) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: video)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : fblaLightBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? appBackgroundGradient : null,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(isDark),
              _buildConnectRow(isDark),
              const SizedBox(height: 4),
              _buildTabBar(isDark),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _buildVideosTab(isDark),
                    _buildNewsTab(isDark, app),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    final secondary = isDark ? Colors.grey.shade400 : fblaLightSecondaryText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FBLA Feed',
            style: TextStyle(
              color: primary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Watch, read, and connect with FBLA',
            style: TextStyle(
              color: secondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectRow(bool isDark) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _platforms.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final p = _platforms[i];
          return GestureDetector(
            onTap: () => _openPlatform(p),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [p.color, p.color.withValues(alpha: 0.72)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: p.color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(p.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  p.name,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade300 : fblaLightPrimaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : fblaLightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : fblaLightBorder),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          color: _fblaBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor:
            isDark ? Colors.grey.shade400 : fblaLightSecondaryText,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        tabs: const [
          Tab(text: 'Videos', height: 40),
          Tab(text: 'News', height: 40),
        ],
      ),
    );
  }

  // ---- Videos tab ----

  Widget _buildVideosTab(bool isDark) {
    return FutureBuilder<List<Video>>(
      future: _videosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _fblaBlue),
          );
        }
        if (snapshot.hasError) {
          return _videosError(isDark);
        }
        final videos = snapshot.data ?? const <Video>[];
        if (videos.isEmpty) {
          return _videosError(isDark);
        }
        final featured = videos.first;
        final rest = videos.skip(1).toList();
        return RefreshIndicator(
          onRefresh: _refreshVideos,
          color: _fblaBlue,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _featuredVideoCard(isDark, featured),
              if (rest.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'More from FBLA',
                  style: TextStyle(
                    color: isDark ? Colors.white : fblaLightPrimaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ...rest.map((v) => _videoRow(isDark, v)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _featuredVideoCard(bool isDark, Video v) {
    return GestureDetector(
      onTap: () => _playVideo(v),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: v.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.black26),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.black26,
                    child:
                        const Icon(Icons.broken_image, color: Colors.white54),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: Center(child: _PlayBadge(size: 64)),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _fblaGold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'LATEST',
                    style: TextStyle(
                      color: Color(0xFF0A1422),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.smart_display_rounded,
                            color: Color(0xFFFF5252), size: 14),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'FBLA National  •  ${_relativeDate(v.publishedAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoRow(bool isDark, Video v) {
    return GestureDetector(
      onTap: () => _playVideo(v),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              isDark ? Colors.white.withValues(alpha: 0.04) : fblaLightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : fblaLightBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: v.thumbnailUrl,
                    width: 132,
                    height: 78,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        width: 132, height: 78, color: Colors.black26),
                    errorWidget: (_, __, ___) => Container(
                      width: 132,
                      height: 78,
                      color: Colors.black26,
                      child:
                          const Icon(Icons.broken_image, color: Colors.white54),
                    ),
                  ),
                  const Positioned.fill(
                    child: Center(child: _PlayBadge(size: 34)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : fblaLightPrimaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _relativeDate(v.publishedAt),
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : fblaLightSecondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videosError(bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 360,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 40,
                      color: isDark
                          ? Colors.grey.shade500
                          : fblaLightSecondaryText),
                  const SizedBox(height: 12),
                  Text(
                    'Couldn\'t load videos',
                    style: TextStyle(
                      color: isDark ? Colors.white : fblaLightPrimaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Check your connection and pull to retry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade500
                          : fblaLightSecondaryText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _refreshVideos,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _fblaBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---- News tab ----

  Widget _buildNewsTab(bool isDark, AppState app) {
    final news = [...app.news]..sort((a, b) => b.date.compareTo(a.date));
    if (news.isEmpty) {
      return Center(
        child: Text(
          'No announcements yet.',
          style: TextStyle(
              color: isDark ? Colors.grey.shade400 : fblaLightSecondaryText),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: news.length,
      itemBuilder: (context, i) => _newsCard(isDark, news[i], featured: i == 0),
    );
  }

  Widget _newsCard(bool isDark, NewsItem n, {required bool featured}) {
    return GestureDetector(
      onTap: () => _showNews(isDark, n),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isDark ? Colors.white.withValues(alpha: 0.04) : fblaLightSurface,
          gradient: featured && isDark
              ? LinearGradient(
                  colors: [
                    _fblaBlue.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: featured
                ? _fblaGold.withValues(alpha: 0.5)
                : (isDark ? Colors.white10 : fblaLightBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: (featured ? _fblaGold : _fblaBlue)
                        .withValues(alpha: isDark ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        featured
                            ? Icons.campaign_rounded
                            : Icons.article_rounded,
                        size: 13,
                        color: featured ? _fblaGold : _fblaBlue,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        featured ? 'Announcement' : 'Update',
                        style: TextStyle(
                          color: featured
                              ? (isDark ? _fblaGold : const Color(0xFF8A6D00))
                              : _fblaBlue,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _relativeDate(n.date),
                  style: TextStyle(
                    color:
                        isDark ? Colors.grey.shade500 : fblaLightSecondaryText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              n.title,
              style: TextStyle(
                color: isDark ? Colors.white : fblaLightPrimaryText,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              n.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : fblaLightSecondaryText,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Read more',
                  style: TextStyle(
                    color: _fblaBlue,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded,
                    size: 14, color: _fblaBlue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNews(bool isDark, NewsItem n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF11203A) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _relativeDate(n.date),
                style: TextStyle(
                  color: isDark ? _fblaGold : _fblaBlue,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                n.title,
                style: TextStyle(
                  color: isDark ? Colors.white : fblaLightPrimaryText,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                n.body,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade300 : fblaLightSecondaryText,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- helpers ----

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) {
      final y = (diff.inDays / 365).floor();
      return '$y year${y == 1 ? '' : 's'} ago';
    }
    if (diff.inDays >= 30) {
      final m = (diff.inDays / 30).floor();
      return '$m month${m == 1 ? '' : 's'} ago';
    }
    if (diff.inDays >= 1) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inMinutes >= 1) {
      return '${diff.inMinutes} min ago';
    }
    return 'Just now';
  }
}

class _SocialPlatform {
  final String name;
  final IconData icon;
  final Color color;
  final String url;
  final bool inApp;
  const _SocialPlatform(this.name, this.icon, this.color, this.url,
      {this.inApp = false});
}

class _PlayBadge extends StatelessWidget {
  final double size;
  const _PlayBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2),
      ),
      child:
          Icon(Icons.play_arrow_rounded, color: Colors.white, size: size * 0.6),
    );
  }
}

/* ------------------------
   Profile / Resources Screen
   ------------------------ */

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _selectProfileImage(BuildContext context) async {
    final picker = ImagePicker();
    final selectedImage = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );

    if (selectedImage == null || !context.mounted) {
      return;
    }

    final imageBytes = await selectedImage.readAsBytes();
    if (!context.mounted) {
      return;
    }

    final app = Provider.of<AppState>(context, listen: false);
    await app.updateProfileImage(imageBytes);
    if (!context.mounted) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildRedesignedProfile(context);
  }

  Widget _buildRedesignedProfile(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final Color fblaBlue = const Color(0xFF1D4E89);
    final Color fblaGold = const Color(0xFFF6C500);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? appBackgroundColor : fblaLightBackground;
    final primaryText = isDark ? Colors.white : fblaLightPrimaryText;
    final secondaryText = isDark ? Colors.white70 : fblaLightSecondaryText;
    final userStreak = app.userProfile?.streak ?? 0;
    final coinBalance = app.userProfile?.points ?? 0;
    final participatingEvents = app.events
        .where((event) => app.participatingEventIds.contains(event.id))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? appBackgroundGradient : null,
          color: isDark ? null : fblaLightBackground,
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: 24 + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileTabHeader(
                  context,
                  app,
                  fblaBlue,
                  fblaGold,
                  isDark,
                  primaryText,
                  secondaryText,
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : fblaLightBorder,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileSectionTitle(
                        'Events',
                        Icons.event_available_outlined,
                        fblaBlue,
                        primaryText,
                      ),
                      const SizedBox(height: 14),
                      _buildProfileEventsSection(
                        context,
                        app,
                        participatingEvents,
                        isDark,
                        fblaBlue,
                        fblaGold,
                        primaryText,
                        secondaryText,
                      ),
                      const SizedBox(height: 28),
                      _buildProfileSectionTitle(
                        'Monthly Badges',
                        Icons.workspace_premium_outlined,
                        fblaBlue,
                        primaryText,
                      ),
                      const SizedBox(height: 14),
                      _buildMonthlyBadges(app, isDark, fblaBlue, fblaGold),
                      const SizedBox(height: 28),
                      _buildProfileSectionTitle(
                        'Achievements',
                        Icons.emoji_events_outlined,
                        fblaBlue,
                        primaryText,
                      ),
                      const SizedBox(height: 14),
                      _buildAchievements(
                        app,
                        userStreak,
                        coinBalance,
                        isDark,
                        fblaBlue,
                        fblaGold,
                      ),
                      const SizedBox(height: 28),
                      _buildProfileSectionTitle(
                        'Socials',
                        Icons.public_outlined,
                        fblaBlue,
                        primaryText,
                      ),
                      const SizedBox(height: 14),
                      _buildProfileSocials(context, isDark),
                      const SizedBox(height: 28),
                      _buildProfileSectionTitle(
                        'Quick Actions',
                        Icons.bolt_outlined,
                        fblaBlue,
                        primaryText,
                      ),
                      const SizedBox(height: 14),
                      _buildQuickActions(context, app, isDark, fblaBlue),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolvedProfileDisplayName(AppState app) {
    return app.resolvedDisplayName;
  }

  Widget _buildProfileTabHeader(
    BuildContext context,
    AppState app,
    Color fblaBlue,
    Color fblaGold,
    bool isDark,
    Color primaryText,
    Color secondaryText,
  ) {
    final displayName = _resolvedProfileDisplayName(app);
    final email = app.userEmail.isNotEmpty ? app.userEmail : 'Not signed in';
    final rankLabel = FBLARankSystem.shortLabelFor(app.userRank);
    final streak = app.userProfile?.streak ?? 0;
    final coins = app.userProfile?.points ?? 0;

    final headerGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF17386E), Color(0xFF0A1A33)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF1FB), Color(0xFFF7FAFC)],
          );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: headerGradient),
      child: Stack(
        children: [
          Positioned(
            top: -48,
            right: -36,
            child: IgnorePointer(
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      fblaGold.withValues(alpha: isDark ? 0.18 : 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    if (Navigator.canPop(context))
                      _buildHeaderIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        tooltip: 'Back',
                        color: primaryText,
                        isDark: isDark,
                        onPressed: () => Navigator.pop(context),
                      )
                    else
                      const SizedBox(width: 40),
                    const Spacer(),
                    _buildHeaderIconButton(
                      icon: Icons.settings_outlined,
                      tooltip: 'Settings',
                      color: primaryText,
                      isDark: isDark,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildProfileAvatar(
                        context, app, fblaBlue, fblaGold, isDark),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: primaryText,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 11),
                          _buildHeaderChip(
                            icon: Icons.verified_rounded,
                            label: 'Active Member',
                            iconColor: fblaGold,
                            textColor: isDark ? fblaGold : fblaBlue,
                            fillColor: fblaGold.withValues(
                                alpha: isDark ? 0.16 : 0.22),
                            borderColor:
                                fblaGold.withValues(alpha: isDark ? 0.45 : 0.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildHeaderStatStrip(
                  context,
                  streak: streak,
                  coins: coins,
                  rankLabel: rankLabel,
                  isDark: isDark,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  fblaGold: fblaGold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatStrip(
    BuildContext context, {
    required int streak,
    required int coins,
    required String rankLabel,
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required Color fblaGold,
  }) {
    final divider = Container(
      width: 1,
      height: 44,
      color: isDark ? Colors.white.withValues(alpha: 0.10) : fblaLightBorder,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isDark ? Colors.white.withValues(alpha: 0.10) : fblaLightBorder,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildHeaderStat(
              value: '$streak',
              label: 'Day Streak',
              icon: Icons.local_fire_department_rounded,
              color: const Color(0xFFFF7043),
              isDark: isDark,
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
          ),
          divider,
          Expanded(
            child: _buildHeaderStat(
              value: '$coins',
              label: 'FBLA Coins',
              assetPath: 'assets/coins.png',
              color: fblaGold,
              isDark: isDark,
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
          ),
          divider,
          Expanded(
            child: _buildHeaderStat(
              value: rankLabel,
              label: 'Rank',
              icon: Icons.leaderboard_rounded,
              color: const Color(0xFF66BB6A),
              isDark: isDark,
              primaryText: primaryText,
              secondaryText: secondaryText,
              onTap: () => RankScreen.open(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat({
    required String value,
    required String label,
    required Color color,
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    IconData? icon,
    String? assetPath,
    VoidCallback? onTap,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: assetPath != null
              ? Padding(
                  padding: const EdgeInsets.all(7),
                  child: Image.asset(assetPath),
                )
              : Icon(icon, color: color, size: 21),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: secondaryText,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: content,
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required bool isDark,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.04),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderChip({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color textColor,
    required Color fillColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(
    BuildContext context,
    AppState app,
    Color fblaBlue,
    Color fblaGold,
    bool isDark,
  ) {
    final imageProvider = _profileImageProvider(app);
    final initial = app.profileInitial;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Hero(
          tag: 'profile_avatar',
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fblaGold,
              boxShadow: [
                BoxShadow(
                  color: fblaBlue.withValues(alpha: isDark ? 0.35 : 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 42,
              backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? Text(
                      initial,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: fblaBlue,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _selectProfileImage(context),
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: fblaGold,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF0B1728) : Colors.white,
                    width: 3,
                  ),
                ),
                child:
                    Icon(Icons.camera_alt_outlined, color: fblaBlue, size: 17),
              ),
            ),
          ),
        ),
      ],
    );
  }

  ImageProvider<Object>? _profileImageProvider(AppState app) {
    if (app.localProfileImageBytes != null) {
      return MemoryImage(app.localProfileImageBytes!);
    }

    final photoUrl = app.userProfile?.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }

    return null;
  }

  Widget _buildProfileSectionTitle(
    String title,
    IconData icon,
    Color fblaBlue,
    Color textColor,
  ) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: fblaBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: fblaBlue, size: 19),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileEventsSection(
    BuildContext context,
    AppState app,
    List<Event> participatingEvents,
    bool isDark,
    Color fblaBlue,
    Color fblaGold,
    Color primaryText,
    Color secondaryText,
  ) {
    final cardColor = isDark ? const Color(0xFF101827) : fblaLightSurface;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : fblaLightBorder;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: fblaGold.withValues(alpha: isDark ? 0.16 : 0.22),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  color: isDark ? fblaGold : fblaBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participatingEvents.isEmpty
                          ? 'Track your competitions'
                          : '${participatingEvents.length} event${participatingEvents.length == 1 ? '' : 's'} added',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      participatingEvents.isEmpty
                          ? 'Add the FBLA events you are participating in.'
                          : 'Keep your active FBLA events visible here.',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Add events',
                onPressed: () => _showParticipatingEventsSheet(
                  context,
                  isDark,
                  fblaBlue,
                  fblaGold,
                  primaryText,
                  secondaryText,
                ),
                icon: Icon(
                  Icons.add_circle_rounded,
                  color: isDark ? fblaGold : fblaBlue,
                  size: 30,
                ),
              ),
            ],
          ),
          if (participatingEvents.isEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showParticipatingEventsSheet(
                context,
                isDark,
                fblaBlue,
                fblaGold,
                primaryText,
                secondaryText,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Event'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? fblaGold : fblaBlue,
                side: BorderSide(color: isDark ? fblaGold : fblaBlue),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            ...participatingEvents.map(
              (event) => _buildProfileEventCard(
                app,
                event,
                isDark,
                fblaBlue,
                fblaGold,
                primaryText,
                secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileEventCard(
    AppState app,
    Event event,
    bool isDark,
    Color fblaBlue,
    Color fblaGold,
    Color primaryText,
    Color secondaryText,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : fblaLightBackground.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isDark ? Colors.white.withValues(alpha: 0.08) : fblaLightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: fblaBlue.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.event_note_outlined, color: fblaBlue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatProfileEventDate(event.start)} • ${event.location}',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 12,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove event',
            onPressed: () => app.toggleParticipatingEvent(event.id),
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white70 : fblaLightSecondaryText,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  void _showParticipatingEventsSheet(
    BuildContext context,
    bool isDark,
    Color fblaBlue,
    Color fblaGold,
    Color primaryText,
    Color secondaryText,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer<AppState>(
          builder: (context, app, _) {
            final events = [...app.events]
              ..sort((a, b) => a.start.compareTo(b.start));
            final sheetBackground =
                isDark ? const Color(0xFF101827) : fblaLightSurface;

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.72,
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: sheetBackground,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.18)
                              : fblaLightBorder,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Events',
                                style: TextStyle(
                                  color: primaryText,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap events to add or remove them from your profile.',
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: Icon(Icons.close_rounded, color: primaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          final selected =
                              app.participatingEventIds.contains(event.id);
                          return _buildEventPickerTile(
                            app,
                            event,
                            selected,
                            isDark,
                            fblaBlue,
                            fblaGold,
                            primaryText,
                            secondaryText,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventPickerTile(
    AppState app,
    Event event,
    bool selected,
    bool isDark,
    Color fblaBlue,
    Color fblaGold,
    Color primaryText,
    Color secondaryText,
  ) {
    final accent = selected ? fblaGold : fblaBlue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => app.toggleParticipatingEvent(event.id),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: isDark ? 0.14 : 0.12)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : fblaLightBackground.withValues(alpha: 0.72)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.55)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : fblaLightBorder),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: selected ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatProfileEventDate(event.start)} • ${event.location}',
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 12,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatProfileEventDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildMonthlyBadges(
    AppState app,
    bool isDark,
    Color fblaBlue,
    Color fblaGold,
  ) {
    final unlockedBadges = app.userProfile?.badges ?? const <String>[];

    return SizedBox(
      height: 132,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildMonthlyBadge(
            name: 'Momentum',
            icon: Icons.trending_up_rounded,
            color: fblaGold,
            unlocked: unlockedBadges.contains('monthly_momentum'),
            isDark: isDark,
          ),
          _buildMonthlyBadge(
            name: 'Connector',
            icon: Icons.groups_2_outlined,
            color: fblaBlue,
            unlocked: unlockedBadges.contains('chapter_connector'),
            isDark: isDark,
          ),
          _buildMonthlyBadge(
            name: 'Study Sprint',
            icon: Icons.menu_book_outlined,
            color: const Color(0xFF16A34A),
            unlocked: unlockedBadges.contains('study_sprint'),
            isDark: isDark,
          ),
          _buildMonthlyBadge(
            name: 'Event Ready',
            icon: Icons.event_available_outlined,
            color: const Color(0xFF7C3AED),
            unlocked: unlockedBadges.contains('event_ready'),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyBadge({
    required String name,
    required IconData icon,
    required Color color,
    required bool unlocked,
    required bool isDark,
  }) {
    final cardColor = isDark ? const Color(0xFF101827) : fblaLightSurface;
    final lockedColor = isDark ? Colors.white38 : fblaLightDisabledText;

    return Container(
      width: 112,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked
              ? color.withValues(alpha: 0.45)
              : lockedColor.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: unlocked
                  ? color.withValues(alpha: 0.15)
                  : lockedColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              unlocked ? icon : Icons.lock_outline_rounded,
              color: unlocked ? color : lockedColor,
              size: 25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: TextStyle(
              color: isDark ? Colors.white : fblaLightPrimaryText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            unlocked ? 'Unlocked' : 'Locked',
            style: TextStyle(
              color: unlocked ? color : lockedColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements(
    AppState app,
    int userStreak,
    int coinBalance,
    bool isDark,
    Color fblaBlue,
    Color fblaGold,
  ) {
    return Column(
      children: [
        _buildAchievementCard(
          title: 'Event Starter',
          description: 'Save and attend FBLA events to stay involved.',
          icon: Icons.event_note_outlined,
          color: fblaBlue,
          progress: (app.savedEventIds.length / 5).clamp(0.0, 1.0).toDouble(),
          progressLabel: '${app.savedEventIds.length}/5 events',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildAchievementCard(
          title: 'Streak Builder',
          description: 'Keep learning and checking in with the app.',
          icon: Icons.local_fire_department_outlined,
          color: const Color(0xFFFF7043),
          progress: (userStreak / 7).clamp(0.0, 1.0).toDouble(),
          progressLabel: '$userStreak/7 days',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildAchievementCard(
          title: 'Coin Collector',
          description: 'Earn FBLA Coins by completing activities.',
          icon: Icons.savings_outlined,
          color: fblaGold,
          progress: (coinBalance / 250).clamp(0.0, 1.0).toDouble(),
          progressLabel: '$coinBalance/250 coins',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildAchievementCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required double progress,
    required String progressLabel,
    required bool isDark,
  }) {
    final cardColor = isDark ? const Color(0xFF101827) : fblaLightSurface;
    final primaryText = isDark ? Colors.white : fblaLightPrimaryText;
    final secondaryText = isDark ? Colors.white70 : fblaLightSecondaryText;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isDark ? Colors.white.withValues(alpha: 0.08) : fblaLightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      progressLabel,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 12,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: color.withValues(alpha: 0.14),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProfileSocial(BuildContext context, String url) async {
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open social link right now.')),
      );
    }
  }

  Widget _buildProfileSocials(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 520;
        return GridView.count(
          crossAxisCount: isWide ? 2 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 3.2 : 2.05,
          children: [
            _buildSocialButton(
              context,
              label: 'YouTube',
              icon: Icons.play_circle_fill_rounded,
              color: const Color(0xFFFF0000),
              isDark: isDark,
              onTap: () => _openProfileSocial(
                context,
                'https://www.youtube.com/@fbla_national',
              ),
            ),
            _buildSocialButton(
              context,
              label: 'Instagram',
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFFE1306C),
              isDark: isDark,
              onTap: () => InstagramFeedScreen.open(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSocialButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final cardColor = isDark ? const Color(0xFF101827) : fblaLightSurface;
    final textColor = isDark ? Colors.white : fblaLightPrimaryText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.26 : 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.17 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    AppState app,
    bool isDark,
    Color fblaBlue,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 520 ? 3 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 3 ? 2.7 : 2.2,
          children: [
            _buildQuickActionButton(
              context,
              label: 'Edit Profile',
              icon: Icons.edit_outlined,
              color: fblaBlue,
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
            ),
            _buildQuickActionButton(
              context,
              label: 'View Leaderboard',
              icon: Icons.leaderboard_outlined,
              color: const Color(0xFF7C3AED),
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CompetitionsScreen()),
              ),
            ),
            _buildQuickActionButton(
              context,
              label: 'Redeem Coins',
              icon: Icons.card_giftcard_outlined,
              color: const Color(0xFFF59E0B),
              isDark: isDark,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Coin redemption rewards are coming soon.'),
                  ),
                );
              },
            ),
            _buildQuickActionButton(
              context,
              label: 'Settings',
              icon: Icons.settings_outlined,
              color: const Color(0xFF0EA5E9),
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            _buildQuickActionButton(
              context,
              label: 'Help & Support',
              icon: Icons.help_outline_rounded,
              color: const Color(0xFF16A34A),
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FaqScreen()),
              ),
            ),
            _buildQuickActionButton(
              context,
              label: 'Log Out',
              icon: Icons.logout_rounded,
              color: fblaLightDestructive,
              isDark: isDark,
              onTap: () async {
                await app.logout();
                if (!context.mounted) return;
                Navigator.of(context, rootNavigator: true)
                    .popUntil((route) => route.isFirst);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final cardColor = isDark ? const Color(0xFF101827) : fblaLightSurface;
    final textColor = isDark ? Colors.white : fblaLightPrimaryText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : fblaLightBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLegacyProfile(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final Color fblaBlue = const Color(0xFF1D4E89);
    final Color fblaGold = const Color(0xFFF6C500);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: appBackgroundColor,
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: CustomScrollView(
          slivers: [
            // Compact top bar
            SliverAppBar(
              expandedHeight: 56,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Profile'),
              actions: [
                IconButton(
                  tooltip: 'Settings',
                  icon: Icon(Icons.settings_outlined, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(color: Colors.transparent),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 24),
                      Stack(
                        children: [
                          Hero(
                            tag: 'profile_avatar',
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: fblaGold.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: fblaGold,
                                backgroundImage: app.localProfileImageBytes !=
                                        null
                                    ? MemoryImage(app.localProfileImageBytes!)
                                    : (app.userProfile?.photoUrl != null &&
                                            app.userProfile!.photoUrl!
                                                .isNotEmpty
                                        ? NetworkImage(
                                            app.userProfile!.photoUrl!)
                                        : null) as ImageProvider<Object>?,
                                child: app.localProfileImageBytes == null &&
                                        (app.userProfile?.photoUrl == null ||
                                            app.userProfile!.photoUrl!.isEmpty)
                                    ? Text(
                                        app.profileInitial,
                                        style: TextStyle(
                                          fontSize: 42,
                                          fontWeight: FontWeight.bold,
                                          color: fblaBlue,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _selectProfileImage(context),
                                customBorder: const CircleBorder(),
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: fblaGold,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: fblaBlue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        app.displayName.isNotEmpty
                            ? app.displayName
                            : 'FBLA Member',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        app.userEmail.isNotEmpty
                            ? app.userEmail
                            : 'Not signed in',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: fblaGold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: fblaGold.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 16, color: fblaGold),
                            SizedBox(width: 6),
                            Text(
                              'Active Member',
                              style: TextStyle(
                                fontSize: 13,
                                color: fblaGold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Row
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Row(
                          children: [
                            Expanded(
                              child: _buildModernStatCard(
                                '${app.savedEventIds.length}',
                                'Events',
                                Icons.event,
                                fblaBlue,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _buildModernStatCard(
                                '12',
                                'Posts',
                                Icons.post_add,
                                Color(0xFF6C63FF),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _buildModernStatCard(
                                '5',
                                'Badges',
                                Icons.emoji_events,
                                fblaGold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: 28),

                    // Badges Section
                    _buildModernSectionHeader(
                        'Achievements', Icons.emoji_events, isDark, fblaBlue),
                    SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildModernBadge('First Event',
                              'Attended first event', Icons.star, fblaGold),
                          _buildModernBadge('Active', 'Participated 5+ events',
                              Icons.group, Color(0xFF2196F3)),
                          _buildModernBadge('Competitor', 'Joined competition',
                              Icons.emoji_events, Color(0xFF4CAF50)),
                          _buildModernBadge('Leader', 'Led chapter activity',
                              Icons.leaderboard, Color(0xFF9C27B0)),
                          _buildModernBadge('Scholar', 'Completed materials',
                              Icons.school, Color(0xFFFF9800)),
                        ],
                      ),
                    ),
                    SizedBox(height: 28),

                    // Quick Actions
                    _buildModernSectionHeader(
                        'Quick Actions', Icons.bolt, isDark, fblaBlue),
                    SizedBox(height: 16),
                    _buildModernActionCard(
                      context,
                      'Edit Profile',
                      'Update your information',
                      Icons.edit_outlined,
                      fblaBlue,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EditProfileScreen()),
                      ),
                    ),
                    _buildModernActionCard(
                      context,
                      'Membership Status',
                      'View and renew membership',
                      Icons.card_membership_outlined,
                      Color(0xFF4CAF50),
                      () {
                        final url = Uri.parse('https://www.fbla-pbl.org/');
                        launchUrl(url);
                      },
                    ),
                    _buildModernActionCard(
                      context,
                      'Notification Settings',
                      'Manage your preferences',
                      Icons.notifications_outlined,
                      Color(0xFFFF9800),
                      () {},
                    ),
                    _buildModernActionCard(
                      context,
                      'Help & Support',
                      'Get help or contact support',
                      Icons.help_outline,
                      Color(0xFF9C27B0),
                      () {},
                    ),
                    SizedBox(height: 24),

                    // Logout Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF7A1D1D),
                            const Color(0xFF4A0F0F),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFF6B6B).withOpacity(0.55),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB71C1C).withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            await app.logout();
                            if (!context.mounted) return;
                            Navigator.of(context, rootNavigator: true)
                                .popUntil((route) => route.isFirst);
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 18,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.logout_rounded,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Log Out',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernStatCard(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModernSectionHeader(
      String title, IconData icon, bool isDark, Color fblaBlue) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: fblaBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: fblaBlue, size: 20),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : fblaBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildModernBadge(
      String title, String description, IconData icon, Color color) {
    return Container(
      width: 110,
      margin: EdgeInsets.only(right: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModernActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: color, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FBLAOfficialHubScreen extends StatelessWidget {
  const FBLAOfficialHubScreen({super.key});

  static const List<_FBLALinkCardData> _divisions = [
    _FBLALinkCardData(
      title: 'FBLA Middle School',
      subtitle: 'Grades 5-9',
      body:
          'Introduces middle and junior high school students to business, career exploration, leadership, teamwork, and technical problem-solving.',
      icon: Icons.school_outlined,
      color: Color(0xFF64B5F6),
      url: 'https://www.fbla.org/middle-school/',
    ),
    _FBLALinkCardData(
      title: 'FBLA High School',
      subtitle: 'Career preparation',
      body:
          'Helps students prepare for careers in business through academic competitions, leadership development, educational programs, and career pathway exposure.',
      icon: Icons.workspace_premium_outlined,
      color: Color(0xFFFDB913),
      url: 'https://www.fbla.org/high-school/',
    ),
    _FBLALinkCardData(
      title: 'FBLA Collegiate',
      subtitle: 'College and postsecondary',
      body:
          'Empowers the next generation of business and industry leaders through networking, skill building, competitive events, scholarships, and career experiences.',
      icon: Icons.business_center_outlined,
      color: Color(0xFF66BB6A),
      url: 'https://www.fbla.org/collegiate/',
    ),
    _FBLALinkCardData(
      title: 'FBLA Network',
      subtitle: 'Alumni and professionals',
      body:
          'Connects alumni and industry professionals with opportunities to mentor, speak, judge events, sponsor programs, and support future business leaders.',
      icon: Icons.hub_outlined,
      color: Color(0xFFBA68C8),
      url: 'https://www.fbla.org/alumni/',
    ),
  ];

  static const List<_FBLALinkCardData> _connectLinks = [
    _FBLALinkCardData(
      title: 'News',
      subtitle: 'Official announcements',
      body: 'Read the latest national FBLA updates, stories, and releases.',
      icon: Icons.newspaper_outlined,
      color: Color(0xFF64B5F6),
      url: 'https://www.fbla.org/news/',
    ),
    _FBLALinkCardData(
      title: 'Brand Center',
      subtitle: 'Logos and brand resources',
      body: 'Access official identity resources for consistent FBLA branding.',
      icon: Icons.palette_outlined,
      color: Color(0xFFFDB913),
      url: 'https://www.fbla.org/brand-center/',
    ),
    _FBLALinkCardData(
      title: 'FBLA Help Desk',
      subtitle: 'Support',
      body: 'Get help with membership, conferences, resources, and questions.',
      icon: Icons.support_agent_outlined,
      color: Color(0xFF66BB6A),
      url: 'https://www.fbla.org/help-desk/',
    ),
  ];

  static const List<_FBLALinkCardData> _getInvolved = [
    _FBLALinkCardData(
      title: 'Volunteer',
      subtitle: 'Support student success',
      body:
          'Help with judging, career networking, resume reviews, scholarships, workshops, and national conference opportunities.',
      icon: Icons.volunteer_activism_outlined,
      color: Color(0xFF66BB6A),
      url: 'https://www.fbla.org/volunteer/',
    ),
    _FBLALinkCardData(
      title: 'Sponsors & Partners',
      subtitle: 'Partner with FBLA',
      body:
          'Support educational programs, scholarships, discount programs, exhibits, and NLC competitive event awards.',
      icon: Icons.handshake_outlined,
      color: Color(0xFFFDB913),
      url: 'https://www.fbla.org/fbla-sponsors/',
    ),
    _FBLALinkCardData(
      title: 'Get Involved',
      subtitle: 'All ways to participate',
      body:
          'Explore volunteering, the FBLA Network, donations, sponsorships, adviser resources, and additional support options.',
      icon: Icons.diversity_3_outlined,
      color: Color(0xFF64B5F6),
      url: 'https://www.fbla.org/get-involved/',
    ),
  ];

  Future<void> _openExternalLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link right now.')),
      );
    }
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.66),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF133A72), Color(0xFF0B2341), Color(0xFF101B32)],
        ),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4E89).withValues(alpha: 0.26),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: fblaGold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: fblaGold.withValues(alpha: 0.36)),
            ),
            child: const Text(
              'Official FBLA Homepage',
              style: TextStyle(
                color: fblaGold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Future Business Leaders of America',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'FBLA is the largest business career and technical student organization in the world. Each year, FBLA helps more than 200,000 middle school, high school, and college students prepare for careers in business.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 14,
              height: 1.48,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  icon: Icons.groups_rounded,
                  value: '200K+',
                  label: 'students helped yearly',
                  color: fblaGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniStat(
                  icon: Icons.school_rounded,
                  value: '3',
                  label: 'student divisions',
                  color: const Color(0xFF64B5F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _openExternalLink(context, 'https://www.fbla.org/'),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open FBLA Website'),
              style: ElevatedButton.styleFrom(
                backgroundColor: fblaGold,
                foregroundColor: fblaNavy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkCard(BuildContext context, _FBLALinkCardData item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: item.color.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(item.icon, color: item.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: item.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 13,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openExternalLink(context, item.url),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('Learn More'),
              style: TextButton.styleFrom(foregroundColor: item.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _conferenceCard({
    required BuildContext context,
    required String division,
    required String date,
    required String location,
    required String venue,
    required String body,
    required String url,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            division,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            date,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$location · $venue',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () => _openExternalLink(context, url),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: const Text('Conference Details'),
            style: TextButton.styleFrom(foregroundColor: color),
          ),
        ],
      ),
    );
  }

  Widget _futureNlcCard() {
    const futures = [
      _FBLAFutureConference('2027', 'Columbus, Ohio', 'June 23-26'),
      _FBLAFutureConference('2028', 'Anaheim, California', 'June 23-26'),
      _FBLAFutureConference('2029', 'Indianapolis, Indiana', 'June 25-28'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          for (final item in futures)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: fblaGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.year,
                      style: const TextStyle(
                        color: fblaGold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.location,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          item.date,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _contactCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send a Message',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The official homepage includes a contact form for full name, email, subject, and message. Use the button below to open the live FBLA contact flow.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _openExternalLink(context, 'https://www.fbla.org/contact/'),
              icon: const Icon(Icons.mail_outline_rounded),
              label: const Text('Contact FBLA'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Official FBLA'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _hero(context),
              const SizedBox(height: 24),
              _sectionTitle(
                'FBLA Divisions',
                'Explore the main pathways highlighted across FBLA: Middle School, High School, Collegiate, and the FBLA Network.',
              ),
              const SizedBox(height: 12),
              for (final division in _divisions) _linkCard(context, division),
              const SizedBox(height: 20),
              _sectionTitle(
                'Save the Date: Upcoming Conferences',
                'National Leadership Conference information from the official FBLA homepage and NLC pages.',
              ),
              const SizedBox(height: 12),
              _conferenceCard(
                context: context,
                division: 'Collegiate NLC',
                date: 'June 6-8, 2026',
                location: 'Las Vegas, Nevada',
                venue: 'Westgate Las Vegas',
                body:
                    'FBLA members convene to compete in leadership events, share successes, attend workshops and exhibits, and learn new ideas for shaping their career future.',
                color: const Color(0xFF66BB6A),
                url: 'https://www.fbla.org/nlc-collegiate/',
              ),
              _conferenceCard(
                context: context,
                division: 'Middle School & High School NLC',
                date: 'June 29 - July 2, 2026',
                location: 'San Antonio, Texas',
                venue: 'Henry B. Gonzalez Convention Center',
                body:
                    'The 2026 Middle School & High School NLC brings members together for competitions, workshops, exhibits, and activities designed to make the most of San Antonio.',
                color: const Color(0xFF64B5F6),
                url: 'https://www.fbla.org/nlc-ms-hs/',
              ),
              const SizedBox(height: 10),
              _sectionTitle(
                'Future NLCs',
                'Official future National Leadership Conference locations and dates.',
              ),
              const SizedBox(height: 12),
              _futureNlcCard(),
              const SizedBox(height: 20),
              _sectionTitle(
                'Connect',
                'The official homepage links members to news, brand resources, and support.',
              ),
              const SizedBox(height: 12),
              for (final link in _connectLinks) _linkCard(context, link),
              const SizedBox(height: 20),
              _sectionTitle(
                'Get Involved',
                'Volunteer, join the FBLA Network, sponsor, partner, donate, or support students as an adviser.',
              ),
              const SizedBox(height: 12),
              for (final item in _getInvolved) _linkCard(context, item),
              const SizedBox(height: 20),
              _contactCard(context),
            ],
          ),
        ),
      ),
    );
  }
}

class _FBLALinkCardData {
  final String title;
  final String subtitle;
  final String body;
  final IconData icon;
  final Color color;
  final String url;

  const _FBLALinkCardData({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.icon,
    required this.color,
    required this.url,
  });
}

class _FBLAFutureConference {
  final String year;
  final String location;
  final String date;

  const _FBLAFutureConference(this.year, this.location, this.date);
}

/* ------------------------
   More Screen
   ------------------------ */

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDeveloperMode =
        app.signupRole.trim().toLowerCase() == 'developer' ||
            app.userEmail.trim().toLowerCase() == 'demo@fbla.app';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildProfileHeader(context, app),
          const SizedBox(height: 24),
          _buildGroupHeader(context, 'Community & Connection',
              Icons.groups_outlined, _MoreAccent.blue),
          _buildMoreTile(
            context,
            accent: _MoreAccent.blue,
            title: 'Find Members',
            subtitle: 'Search local members and officers',
            icon: Icons.badge_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FindMembersScreen()),
              );
            },
          ),
          _buildMoreTile(
            context,
            accent: _MoreAccent.blue,
            title: 'Social Wall',
            subtitle: 'Instagram, LinkedIn, and X feeds',
            icon: Icons.public_outlined,
            onTap: () {
              context
                  .findAncestorStateOfType<_RootScreenState>()
                  ?._selectTab(3);
            },
          ),
          _buildMoreTile(
            context,
            accent: _MoreAccent.blue,
            title: 'Message Center',
            subtitle: 'Connect with chapter officers or advisers',
            icon: Icons.mark_chat_unread_outlined,
          ),
          _buildMoreTile(
            context,
            accent: _MoreAccent.blue,
            title: 'Official FBLA Hub',
            subtitle: 'Divisions, NLC, network, and get involved',
            icon: Icons.business_center_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const FBLAOfficialHubScreen()),
              );
            },
          ),
          const SizedBox(height: 22),
          _buildGroupHeader(context, 'Leadership & Growth',
              Icons.emoji_events_outlined, _MoreAccent.gold),
          _buildMoreTile(
            context,
            accent: _MoreAccent.gold,
            title: 'BAA Progress Tracker',
            subtitle: 'Track Business Achievement Awards checklist',
            icon: Icons.checklist_outlined,
          ),
          _buildMoreTile(
            context,
            accent: _MoreAccent.gold,
            title: 'Scholarship Hub',
            subtitle: 'FBLA scholarships and deadlines',
            icon: Icons.school_outlined,
          ),
          _buildMoreTile(
            context,
            accent: _MoreAccent.gold,
            title: 'Officer Corner',
            subtitle: 'Resources for current or aspiring officers',
            icon: Icons.workspace_premium_outlined,
          ),
          const SizedBox(height: 22),
          _buildGroupHeader(context, 'Administration',
              Icons.admin_panel_settings_outlined, _MoreAccent.teal),
          _buildMoreTile(
            context,
            accent: _MoreAccent.teal,
            title: 'Attendance Tracker',
            subtitle: 'Scan QR code to check in at meetings',
            icon: Icons.qr_code_scanner_outlined,
          ),
          _buildMoreTile(
            context,
            accent: _MoreAccent.teal,
            title: 'Dues & Payments',
            subtitle: 'Check membership status and payment portal',
            icon: Icons.payments_outlined,
          ),
          _buildMoreTile(
            context,
            accent: _MoreAccent.teal,
            title: 'Document Library',
            subtitle: 'Bylaws, Robert’s Rules, and meeting minutes',
            icon: Icons.folder_open_outlined,
          ),
          const SizedBox(height: 22),
          _buildGroupHeader(context, 'Support', Icons.support_agent_outlined,
              _MoreAccent.violet),
          _buildMoreTile(
            context,
            accent: _MoreAccent.violet,
            title: 'Help / FAQ',
            subtitle: 'Answers about dress code, events, and troubleshooting',
            icon: Icons.help_outline,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FaqScreen()),
              );
            },
          ),
          _buildMoreTile(
            context,
            accent: _MoreAccent.violet,
            title: 'Replay App Tour',
            subtitle: 'Take the guided walkthrough of the app again',
            icon: Icons.tips_and_updates_outlined,
            onTap: () async {
              final app = Provider.of<AppState>(context, listen: false);
              await app.resetFeatureTour();
              if (context.mounted) {
                FeatureTour.show(context);
              }
            },
          ),
          _buildMoreTile(
            context,
            accent: _MoreAccent.violet,
            title: 'Settings',
            subtitle: 'Notifications, privacy, and account logout',
            icon: Icons.settings_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          if (isDeveloperMode) ...[
            const SizedBox(height: 22),
            _buildGroupHeader(context, 'Extra Developer Options',
                Icons.developer_mode_outlined, _MoreAccent.red),
            _buildMoreTile(
              context,
              accent: _MoreAccent.red,
              title: 'Extra Developer Options',
              subtitle: 'Developer-only testing utilities',
              icon: Icons.build_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExtraDeveloperOptionsScreen(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AppState app) {
    final name = app.resolvedDisplayName;
    final initial = app.profileInitial;
    final points = app.userProfile?.points ?? 0;
    final rank = app.userRank;
    final role = app.signupRole.trim();
    final subtitle = role.isNotEmpty ? '$role  ·  $rank' : rank;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF13315F), Color(0xFF0C1E3C)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [fblaGold, Color(0xFFE39A00)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: fblaGold.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: fblaNavy,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: fblaGold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: fblaGold.withValues(alpha: 0.30)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/coins.png',
                              width: 16, height: 16),
                          const SizedBox(width: 6),
                          Text(
                            '$points pts',
                            style: const TextStyle(
                              color: fblaGold,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader(
      BuildContext context, String title, IconData icon, Color accent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? Colors.white.withValues(alpha: 0.85) : fblaBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : fblaBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : fblaBlue.withOpacity(0.16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent,
                        Color.lerp(accent, Colors.black, 0.22)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.32),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : fblaLightPrimaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white38 : fblaBlue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreAccent {
  const _MoreAccent._();
  static const Color blue = Color(0xFF2E6BC6);
  static const Color gold = Color(0xFFCB8A14);
  static const Color teal = Color(0xFF1AA39A);
  static const Color violet = Color(0xFF6D5BD0);
  static const Color red = Color(0xFFD9534F);
}

class ExtraDeveloperOptionsScreen extends StatelessWidget {
  const ExtraDeveloperOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color fblaBlue = const Color(0xFF1D4E89);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Extra Developer Options'),
        backgroundColor: fblaBlue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Tests',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                await sendDeveloperTestNotification();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test notification sent.')),
                );
              },
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Test Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: fblaBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const List<Map<String, String>> _faqItems = [
    {
      'q': 'How do I join FBLA at my school?',
      'a':
          'Ask your chapter adviser about local membership steps and dues payment deadlines.'
    },
    {
      'q': 'Where do I see upcoming chapter events?',
      'a':
          'Open the Events tab to view monthly and weekly schedules with event details.'
    },
    {
      'q': 'How do I RSVP to an event?',
      'a': 'Open an event card and tap RSVP, then choose Yes, Maybe, or No.'
    },
    {
      'q': 'Can I set reminders for competitions?',
      'a':
          'Yes, tap Remind on an event card to schedule a local notification reminder.'
    },
    {
      'q': 'How do I update my profile photo?',
      'a':
          'Go to Profile and tap the camera icon on your avatar to pick a new image.'
    },
    {
      'q': 'Why is dark mode always on?',
      'a':
          'The app currently uses a fixed dark theme to keep the interface consistent.'
    },
    {
      'q': 'Where can I find competitive event categories?',
      'a': 'Open Resources > Study Materials > FBLA Competitive Events.'
    },
    {
      'q': 'How do I search competitive events quickly?',
      'a': 'Use the search bar at the top of the Competitive Events page.'
    },
    {
      'q': 'Can I filter only roleplay events?',
      'a': 'Yes, tap Filters and select Roleplay Events.'
    },
    {
      'q': 'What does the circle badge on event cards mean?',
      'a': 'Badge letters indicate category type (for example Pr, Po, R, or V).'
    },
    {
      'q': 'How do I access FBLA Connect?',
      'a': 'Go to Resources and tap FBLA Connect to open it in your browser.'
    },
    {
      'q': 'Can I save events for later?',
      'a': 'Yes, tap the bookmark icon on any event card to save or unsave it.'
    },
    {
      'q': 'Why does AI chat say it cannot connect?',
      'a':
          'AI requires a running Ollama server endpoint reachable from your device.'
    },
    {
      'q': 'How do I sign out of the app?',
      'a': 'Open Profile and tap Log Out at the bottom of the page.'
    },
    {
      'q': 'Where are chapter documents stored?',
      'a':
          'Use More > Document Library for bylaws, minutes, and chapter resources.'
    },
    {
      'q': 'Can I use the app offline?',
      'a':
          'Some local content may remain visible, but most live features require internet.'
    },
    {
      'q': 'How do I report incorrect event information?',
      'a':
          'Share details with your chapter officer or adviser to update official data.'
    },
    {
      'q': 'Where can I review scholarship opportunities?',
      'a': 'Open More > Scholarship Hub to see scholarship-related resources.'
    },
    {
      'q': 'How do I check attendance at meetings?',
      'a': 'Use More > Attendance Tracker when your chapter enables check-in.'
    },
    {
      'q': 'Who should I contact for app support?',
      'a':
          'Start with your chapter adviser or officer team for account and access help.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final Color fblaBlue = const Color(0xFF1D4E89);
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        title: const Text('Help / FAQ'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 20 + bottomSafe + 16),
          itemCount: _faqItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = _faqItems[index];
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: fblaBlue.withOpacity(0.35), width: 1.1),
              ),
              child: ExpansionTile(
                collapsedIconColor: Colors.white70,
                iconColor: Colors.white,
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                title: Text(
                  item['q'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item['a'] ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/* ------------------------
   Settings Screen
   ------------------------ */

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final Color fblaBlue = const Color(0xFF1D4E89);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? appBackgroundColor : fblaLightBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: isDark ? Colors.transparent : fblaLightSurface,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : fblaLightPrimaryText,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? appBackgroundGradient : null,
          color: isDark ? null : fblaLightBackground,
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // General Settings Section
            _buildSectionHeader(
                context, 'General Settings', Icons.settings_outlined, fblaBlue),
            const SizedBox(height: 16),

            // Dark Mode Toggle
            _buildSettingsCard(
              context,
              'Dark Mode',
              app.isDarkMode
                  ? 'Turn off to use the professional FBLA light theme'
                  : 'Turn on to return to the dark FBLA theme',
              Icons.dark_mode_outlined,
              Switch(
                value: app.isDarkMode,
                onChanged: (value) => app.setDarkMode(value),
                activeThumbColor: fblaGold,
                activeTrackColor: fblaGold.withValues(alpha: 0.34),
              ),
            ),

            // Notifications Settings
            _buildSettingsCard(
              context,
              'Push Notifications',
              'Receive notifications for events and updates',
              Icons.notifications_outlined,
              Switch(
                value: true, // Default to enabled
                onChanged: (value) {},
                activeThumbColor: fblaGold,
                activeTrackColor: fblaGold.withValues(alpha: 0.34),
              ),
            ),

            // Email Notifications
            _buildSettingsCard(
              context,
              'Email Notifications',
              'Receive email updates about events',
              Icons.email_outlined,
              Switch(
                value: true, // Default to enabled
                onChanged: (value) {},
                activeThumbColor: fblaGold,
                activeTrackColor: fblaGold.withValues(alpha: 0.34),
              ),
            ),

            const SizedBox(height: 32),

            // Privacy & Security Section
            _buildSectionHeader(context, 'Privacy & Security',
                Icons.security_outlined, fblaBlue),
            const SizedBox(height: 16),

            _buildSettingsCard(
              context,
              'Data Privacy',
              'Manage your data and privacy settings',
              Icons.privacy_tip_outlined,
              Icon(Icons.arrow_forward_ios, color: fblaBlue, size: 16),
              onTap: () {},
            ),

            _buildSettingsCard(
              context,
              'Account Security',
              'Password and security settings',
              Icons.lock_outline,
              Icon(Icons.arrow_forward_ios, color: fblaBlue, size: 16),
              onTap: () {},
            ),

            const SizedBox(height: 32),

            // App Information Section
            _buildSectionHeader(
                context, 'App Information', Icons.info_outline, fblaBlue),
            const SizedBox(height: 16),

            _buildSettingsCard(
              context,
              'About FBLA App',
              'Version 1.0.0 • Learn more about the app',
              Icons.info_outlined,
              Icon(Icons.arrow_forward_ios, color: fblaBlue, size: 16),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('About FBLA Member App'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Version: 1.0.0'),
                        const SizedBox(height: 8),
                        const Text(
                            'The official FBLA Member App for staying connected with your chapter, events, and resources.'),
                        const SizedBox(height: 8),
                        const Text(
                            'Built with Flutter for the best mobile experience.'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),

            _buildSettingsCard(
              context,
              'Help & Support',
              'Get help or contact support',
              Icons.help_outline,
              Icon(Icons.arrow_forward_ios, color: fblaBlue, size: 16),
              onTap: () {},
            ),

            _buildSettingsCard(
              context,
              'Terms of Service',
              'Read our terms and conditions',
              Icons.description_outlined,
              Icon(Icons.arrow_forward_ios, color: fblaBlue, size: 16),
              onTap: () {},
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon, Color fblaBlue) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: fblaBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: fblaBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : fblaLightPrimaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Widget trailing, {
    VoidCallback? onTap,
  }) {
    final Color fblaBlue = const Color(0xFF1D4E89);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF0F0F0F) : fblaLightSurface;
    final primaryText = isDark ? Colors.white : fblaLightPrimaryText;
    final secondaryText = isDark ? Colors.white70 : fblaLightSecondaryText;
    final borderColor =
        isDark ? fblaBlue.withValues(alpha: 0.35) : fblaLightBorder;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: fblaBlue,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: fblaBlue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
