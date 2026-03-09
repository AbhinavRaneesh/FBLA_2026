import 'dart:async';
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
import 'package:webview_flutter/webview_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/resources_screen.dart';
import 'screens/firebase_auth_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/chatbot_screen.dart';
import 'ai/bloc/chat_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'services/firebase_service.dart';
import 'services/mongodb_service.dart';
import 'models/fbla_models.dart';
import 'models/video_model.dart';
import 'screens/video_player_screen.dart ';
import 'services/youtube_service.dart';

// FBLA Colors Added
const fblaNavy = Color(0xFF00274D);
const fblaGold = Color(0xFFFDB913);

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

// Optional fallback URI for local testing only.
// Leave empty to require --dart-define=MONGODB_URI=...
const hardcodedMongoUri = 'mongodb+srv://kushal:KushalNarkhede@fbla.ig6iamr.mongodb.net/?appName=FBLA';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Denver'));

  const defineMongoUri = String.fromEnvironment('MONGODB_URI');
  final resolvedMongoUri = defineMongoUri.trim().isNotEmpty
      ? defineMongoUri.trim()
      : hardcodedMongoUri.trim();

  if (resolvedMongoUri.isNotEmpty) {
    MongoDbService.configureUri(resolvedMongoUri);
    print('🍃 MongoDB URI configured (no startup Mongo init)');
  } else {
    print(
      '🍃 MongoDB URI not set at startup. '
      'Set --dart-define=MONGODB_URI=... or hardcodedMongoUri in main.dart',
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
        isDarkMode = true {
    savedEventIds = prefs.getStringList('savedEvents')?.toSet() ?? {};
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    if (_firebaseInitialized) return;
    
    try {
      await Firebase.initializeApp();
      print('🔥 Firebase initialized successfully');
      _firebaseInitialized = true;

      await _loadAppDataFromFirestore();
      
      // Firebase auth state listener
      FirebaseService.authStateChanges.listen((User? user) {
        firebaseUser = user;
        if (user != null) {
          _loadUserProfile(user.uid);
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

      notifyListeners();
    } catch (e) {
      print('Failed to load Firestore app data: $e');
    }
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
    final account = await MongoDbService.createUser(
      email: email,
      password: password,
      name: name,
      role: role,
      gradeLevel: grade,
    );

    await login(
      (account['email'] ?? email).toString(),
      (account['name'] ?? name).toString(),
      role: (account['role'] ?? role).toString(),
      grade: (account['gradeLevel'] ?? grade).toString(),
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

  Future<void> skipOnboarding() async {
    hasSeenOnboarding = true;
    await prefs.setBool('hasSeenOnboarding', true);
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    isDarkMode = true;
    await prefs.setBool('isDarkMode', true);
    notifyListeners();
  }

  Future<void> setFirebaseUser(User user) async {
    firebaseUser = user;
    userEmail = user.email ?? '';
    displayName = user.displayName ?? '';
    signupRole = '';
    gradeLevel = '';
    await _loadUserProfile(user.uid);
    notifyListeners();
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final profileData = await FirebaseService.getUserProfile(userId);
      if (profileData != null) {
        userProfile = FBLAUser.fromFirestore(profileData);
        if (userProfile?.chapter != null) {
          final chapterData =
              await FirebaseService.getChapter(userProfile!.chapter!);
          if (chapterData != null) {
            userChapter = Chapter.fromFirestore(chapterData);
          }
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
          primaryColor: fblaNavy,
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.indigo)
              .copyWith(secondary: fblaGold),
          appBarTheme: AppBarTheme(
            backgroundColor: fblaNavy,
            titleTextStyle: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            margin: EdgeInsets.symmetric(vertical: 8),
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
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            margin: EdgeInsets.symmetric(vertical: 8),
            color: Colors.grey.shade800,
          ),
        ),
        themeMode: ThemeMode.dark,
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

class AiAssistantFab extends StatelessWidget {
  final String heroTag;
  final bool mini;

  const AiAssistantFab({
    super.key,
    this.heroTag = 'ai_assistant_fab',
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      mini: mini,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (context) => ChatBloc(),
              child: ChatbotScreen(),
            ),
          ),
        );
      },
      backgroundColor: const Color(0xFF0F1623),
      foregroundColor: Colors.white,
      elevation: 0,
      highlightElevation: 0,
      shape: const CircleBorder(),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1D4E89), Color(0xFF0B223E)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1D4E89).withOpacity(0.45),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.smart_toy,
            color: Colors.white,
            size: mini ? 22 : 26,
          ),
        ),
      ),
      tooltip: 'AI Assistant',
    );
  }
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;
  DateTime? _lastBackPressedAt;
  AppState? _appState;
  bool _notificationsInitialized = false;
  String _eventsScheduleSignature = '';

  // Order: 0=Home, 1=Events, 2=Resources, 3=More (profile is via app bar avatar on Home)
  final _pages = [
    HomeScreen(),
    EventsScreen(),
    const ResourcesScreen(),
    const MoreScreen(), // 4th tab = More (settings, FAQ, Social Wall, etc.)
  ];

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_index != 0) {
          setState(() => _index = 0);
          return false;
        }

        final now = DateTime.now();
        if (_lastBackPressedAt == null ||
            now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
          _lastBackPressedAt = now;
          return false;
        }

        return true;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: appBackgroundGradient),
          child: _pages[_index],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: fblaGold,
          unselectedItemColor: Colors.grey,
          backgroundColor: fblaNavy,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
            BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Resources'),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
          ],
        ),
        floatingActionButton: const AiAssistantFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Video>> _youtubeVideosFuture;
  static const String _instagramProfileUrl = 'https://www.instagram.com/fbla_national/';
  static const String _youtubeChannelUrl = 'https://www.youtube.com/@fbla_national';
  static const String _facebookUrl = 'https://www.facebook.com/FBLAPBL/';
  static const String _linkedinUrl = 'https://www.linkedin.com/company/fbla-pbl/';
  static const String _xUrl = 'https://x.com/FBLA_National';
  static const String _linktreeUrl = 'https://linktr.ee/FBLA_National';

  @override
  void initState() {
    super.initState();
    _youtubeVideosFuture = YouTubeService().fetchVideos(maxResults: 8);
  }

  Future<void> _refreshYouTubeVideos() async {
    setState(() {
      _youtubeVideosFuture = YouTubeService().fetchVideos(maxResults: 8);
    });
    await _youtubeVideosFuture;
  }

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link right now.')),
      );
    }
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
    final Color fblaBlue = const Color(0xFF1D4E89);
    final upcomingEvents = [...app.events]
      ..sort((a, b) => a.start.compareTo(b.start));
    final nextEvents = upcomingEvents
        .where((event) => event.end.isAfter(DateTime.now()))
        .take(3)
        .toList();
    final latestNews = [...app.news]
      ..sort((a, b) => b.date.compareTo(a.date));
    final featuredNews = latestNews.take(3).toList();
    final firstName = app.displayName.trim().isEmpty
        ? 'Member'
        : app.displayName.trim().split(' ').first;
    final nextEvent = nextEvents.isNotEmpty ? nextEvents.first : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        titleSpacing: 20,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $firstName',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Your FBLA home base',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.78),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 26),
            iconSize: 28,
            onPressed: () {
              showSearch(
                context: context,
                delegate: _PostSearchDelegate(app.news),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, size: 26),
            iconSize: 28,
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 6, bottom: 6, left: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(999),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white12,
                  backgroundImage: app.localProfileImageBytes != null
                      ? MemoryImage(app.localProfileImageBytes!)
                      : (app.userProfile?.photoUrl != null &&
                              app.userProfile!.photoUrl!.isNotEmpty
                          ? NetworkImage(app.userProfile!.photoUrl!)
                          : null) as ImageProvider<Object>?,
                  child: app.localProfileImageBytes == null &&
                          (app.userProfile?.photoUrl == null ||
                              app.userProfile!.photoUrl!.isEmpty)
                      ? Text(
                          app.displayName.isNotEmpty
                              ? app.displayName[0].toUpperCase()
                              : 'F',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshYouTubeVideos,
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _buildHeroCard(firstName, nextEvent),
              const SizedBox(height: 18),
              _buildStatsRow(app, nextEvents, featuredNews),
              const SizedBox(height: 22),
              _buildSectionTitle(
                title: 'Quick Actions',
                subtitle: 'Jump into the areas members use most',
              ),
              const SizedBox(height: 12),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildSectionTitle(
                title: 'Upcoming Events',
                subtitle: 'Keep track of deadlines, meetings, and reminders',
              ),
              const SizedBox(height: 12),
              if (nextEvents.isEmpty)
                _buildEmptyStateCard(
                  icon: Icons.event_busy,
                  title: 'No upcoming events',
                  subtitle: 'New events will show up here as they are added.',
                )
              else
                ...nextEvents.map((event) => _buildEventCard(app, event)),
              const SizedBox(height: 24),
              _buildSectionTitle(
                title: 'Latest Updates',
                subtitle: 'Announcements and chapter news at a glance',
              ),
              const SizedBox(height: 12),
              if (featuredNews.isEmpty)
                _buildEmptyStateCard(
                  icon: Icons.campaign_outlined,
                  title: 'No announcements yet',
                  subtitle: 'Check back soon for chapter and national updates.',
                )
              else
                ...featuredNews.map(_buildAnnouncementCard),
              const SizedBox(height: 24),
              _buildSectionTitle(
                title: 'Stay Connected',
                subtitle:
                    'Official FBLA social channels',
              ),
              const SizedBox(height: 12),
              _buildSocialLinksCard(),
              const SizedBox(height: 14),
              _buildInstagramPreviewCard(fblaBlue),
              const SizedBox(height: 14),
              _buildYouTubePreviewSection(fblaBlue),
            ],
          ),
        ),
    );
  }

  Widget _buildHeroCard(String firstName, Event? nextEvent) {
    return Container(
      padding: const EdgeInsets.all(22),
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
          const SizedBox(height: 14),
          Text(
            'Good to see you, $firstName.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            nextEvent == null
                ? 'Use your home page to stay informed, manage events, access resources, and keep up with FBLA social channels.'
                : 'Your next event is ${nextEvent.title} on ${_formatLongDate(nextEvent.start)}. Use this dashboard to stay informed, prepared, and connected.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.84),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (nextEvent != null) ...[
            const SizedBox(height: 16),
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
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EventsScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.30)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ResourcesScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.30)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EventsScreen()),
            );
          },
        ),
        _ModernQuickButton(
          icon: Icons.menu_book,
          label: 'Resources',
          subtitle: 'Guides & documents',
          gradient: const LinearGradient(
            colors: [Color(0xFF0A8F7A), Color(0xFF0DB39E)],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ResourcesScreen()),
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
              MaterialPageRoute(builder: (_) => ProfileScreen()),
            );
          },
        ),
        _ModernQuickButton(
          icon: Icons.smart_toy,
          label: 'AI Assistant',
          subtitle: 'Ask questions fast',
          gradient: const LinearGradient(
            colors: [Color(0xFFF39C12), Color(0xFFD68910)],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                  create: (context) => ChatBloc(),
                  child: ChatbotScreen(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.66),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(AppState app, Event event) {
    final saved = app.savedEventIds.contains(event.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B2D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatLongDate(event.start)} • ${event.location}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.68),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (saved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              color: Colors.white.withOpacity(0.78),
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
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.12)),
                  ),
                  icon: Icon(saved ? Icons.notifications_off : Icons.notifications),
                  label: Text(saved ? 'Remove Reminder' : 'Set Reminder'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EventsScreen()),
                    );
                  },
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
              color: const Color(0xFF0F1B2D),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
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
                      child: const Icon(Icons.campaign, color: Color(0xFFCB9FFF)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        post.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _formatPostDate(post.date),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
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
                    color: Colors.white.withOpacity(0.76),
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
                        color: Colors.white.withOpacity(0.62),
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

  Widget _buildSocialLinksCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B2D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Official Channels',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Follow official FBLA channels to catch announcements, leadership content, event highlights, and national updates.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildSocialLinkTile(
                label: 'Instagram',
                handle: '@fbla_national',
                icon: Icons.camera_alt,
                color: const Color(0xFFE1306C),
                onTap: () => _openExternalLink(_instagramProfileUrl),
              ),
              _buildSocialLinkTile(
                label: 'YouTube',
                handle: '@fbla_national',
                icon: Icons.play_circle_fill,
                color: const Color(0xFFFF0000),
                onTap: () => _openExternalLink(_youtubeChannelUrl),
              ),
              _buildSocialLinkTile(
                label: 'Facebook',
                handle: 'FBLA-PBL',
                icon: Icons.facebook,
                color: const Color(0xFF1877F2),
                onTap: () => _openExternalLink(_facebookUrl),
              ),
              _buildSocialLinkTile(
                label: 'LinkedIn',
                handle: 'FBLA-PBL',
                icon: Icons.business,
                color: const Color(0xFF0A66C2),
                onTap: () => _openExternalLink(_linkedinUrl),
              ),
              _buildSocialLinkTile(
                label: 'X',
                handle: '@FBLA_National',
                icon: Icons.alternate_email,
                color: const Color(0xFF9AA0A6),
                onTap: () => _openExternalLink(_xUrl),
              ),
              _buildSocialLinkTile(
                label: 'Link Hub',
                handle: '@FBLA_National',
                icon: Icons.hub_outlined,
                color: const Color(0xFFFDB913),
                onTap: () => _openExternalLink(_linktreeUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinkTile({
    required String label,
    required String handle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const Spacer(),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              handle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.76),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstagramPreviewCard(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B2D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.photo_camera,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Instagram Preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openExternalLink(_instagramProfileUrl),
                child: const Text('Open Profile'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Embedded preview of the official national FBLA Instagram page.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 340,
              child: _InstagramFeedEmbed(profileUrl: _instagramProfileUrl),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYouTubeInlineError(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.orangeAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'YouTube feed unavailable: $message',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYouTubePreviewSection(Color accentColor) {
    return FutureBuilder<List<Video>>(
      future: _youtubeVideosFuture,
      builder: (context, snapshot) {
        final youtubeVideos = snapshot.data ?? [];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1B2D),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Official FBLA Videos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _openExternalLink(_youtubeChannelUrl),
                    child: const Text('Open Channel'),
                  ),
                ],
              ),
              Text(
                'Recent uploads from the official FBLA channel keep the media feed relevant to conferences, leadership, and member engagement.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  youtubeVideos.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError && youtubeVideos.isEmpty)
                _buildYouTubeInlineError(snapshot.error.toString())
              else if (youtubeVideos.isEmpty)
                _buildEmptyStateCard(
                  icon: Icons.ondemand_video_outlined,
                  title: 'No official videos available',
                  subtitle:
                      'Open the FBLA YouTube channel directly to view the latest uploads.',
                )
              else ...[
                ...youtubeVideos
                    .take(4)
                    .map((video) => _buildYouTubePostCard(context, video, accentColor))
                    .toList(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildYouTubePostCard(BuildContext context, Video video, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: video)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'YouTube',
                        style: TextStyle(
                          color: Colors.grey.shade200,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _formatPostDate(video.publishedAt),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    video.thumbnailUrl,
                    width: double.infinity,
                    height: 190,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 190,
                      color: Colors.grey.shade800,
                      alignment: Alignment.center,
                      child: Icon(Icons.broken_image, color: Colors.grey.shade500),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _shorten(video.description, 170),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.play_circle_outline, color: Colors.grey.shade300, size: 18),
                    const SizedBox(width: 6),
                    Text('Watch', style: TextStyle(color: Colors.grey.shade300, fontSize: 12)),
                    const Spacer(),
                    Icon(Icons.open_in_new, color: accentColor, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shorten(String text, int maxLength) {
    if (text.isEmpty) return 'No description available.';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength).trim()}...';
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B2D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white70),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
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

class _InstagramFeedEmbed extends StatefulWidget {
  final String profileUrl;

  const _InstagramFeedEmbed({required this.profileUrl});

  @override
  State<_InstagramFeedEmbed> createState() => _InstagramFeedEmbedState();
}

class _InstagramFeedEmbedState extends State<_InstagramFeedEmbed> {
  static const List<String> _allowedHandles = ['fbla_national', 'fbla'];
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_isAllowedInstagramUrl(request.url)) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (_) {
            _removeInstagramSignupOverlay();
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.profileUrl));
  }

  Future<void> _removeInstagramSignupOverlay() async {
    try {
      await _controller.runJavaScript('''
        (function() {
          const selectors = [
            'div[role="dialog"]',
            'div[aria-label="Sign up"]',
            'section main + div',
            'div._a9_1',
            'div.xixxii4',
            'div.x1n2onr6'
          ];

          selectors.forEach((selector) => {
            document.querySelectorAll(selector).forEach((el) => {
              el.style.display = 'none';
              el.remove();
            });
          });

          document.body.style.overflow = 'auto';
        })();
      ''');
    } catch (_) {
      // Ignore JavaScript failures if Instagram changes its DOM.
    }
  }

  bool _isAllowedInstagramUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    if (!host.contains('instagram.com')) {
      return false;
    }

    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments.isEmpty) {
      return true;
    }

    final first = segments.first.toLowerCase();
    if (_allowedHandles.contains(first)) {
      return true;
    }

    if (first == 'p' || first == 'reel' || first == 'tv') {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: const Color(0xFF0F0F0F),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Instagram preview could not be loaded right now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Container(
            color: const Color(0x99000000),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          ),
      ],
    );
  }
}

class _PostSearchDelegate extends SearchDelegate {
  final List<NewsItem> posts;

  _PostSearchDelegate(this.posts);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
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
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: gradient,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.9),
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
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withOpacity(0.1),
                primaryColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryColor.withOpacity(0.3),
              width: 1.5,
            ),
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
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
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
   Events Screen
   ------------------------ */

class EventsScreen extends StatefulWidget {
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  DateTime _selectedDate = DateTime.now();
  late int _selectedYear;
  bool _showDayEvents = false;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final upcoming = app.events..sort((a, b) => a.start.compareTo(b.start));
    final dateFilteredEvents = upcoming.where((event) {
      return event.start.year == _selectedDate.year &&
          event.start.month == _selectedDate.month &&
          event.start.day == _selectedDate.day;
    }).toList();
    final Color fblaBlue = const Color(0xFF1D4E89);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: _showDayEvents
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to calendar',
                onPressed: () {
                  setState(() => _showDayEvents = false);
                },
              )
            : null,
        title: Text(_showDayEvents 
            ? 'Events on ${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}'
            : 'Events & Schedule'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: const AiAssistantFab(heroTag: 'events_ai_assistant_fab'),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _showDayEvents
          ? _buildDayEventsView(context, dateFilteredEvents)
          : _buildCalendarView(context, upcoming, fblaBlue),
    );
  }

  Widget _buildCalendarView(BuildContext context, List<Event> allEvents, Color fblaBlue) {
    final selectedCount = _eventsForDay(allEvents, _selectedDate).length;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F1C31), Color(0xFF0A1628)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _showYearPicker,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: fblaBlue.withOpacity(0.8)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.calendar_month, size: 16),
                label: Text('$_selectedYear'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${selectedCount} event${selectedCount == 1 ? '' : 's'} on ${_selectedDate.month}/${_selectedDate.day}',
                  style: TextStyle(
                    color: Colors.grey.shade200,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: _showAddEventDialog,
                tooltip: 'Add event',
                icon: const Icon(Icons.add_circle, color: Color(0xFFF6C500)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildScrollableYearMonths(allEvents, fblaBlue),
        ),
      ],
    );
  }

  Widget _buildScrollableYearMonths(List<Event> allEvents, Color fblaBlue) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      itemCount: 12,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final month = index + 1;
        return _buildMonthCard(_selectedYear, month, allEvents, fblaBlue);
      },
    );
  }

  Widget _buildMonthCard(int year, int month, List<Event> allEvents, Color fblaBlue) {
    final monthDate = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekdayOffset = monthDate.weekday - DateTime.monday;
    final totalCells = (((firstWeekdayOffset + daysInMonth) / 7).ceil()) * 7;
    final now = DateTime.now();
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1B2D), Color(0xFF152744)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: fblaBlue.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6C500),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _monthYearLabel(monthDate),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: weekdayLabels
                .map((label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 7),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.04,
            ),
            itemCount: totalCells,
            itemBuilder: (context, cellIndex) {
              final dayNumber = cellIndex - firstWeekdayOffset + 1;
              final isInMonth = dayNumber >= 1 && dayNumber <= daysInMonth;
              if (!isInMonth) return const SizedBox.shrink();

              final dayDate = DateTime(year, month, dayNumber);
              final isSelected = _isSameDate(dayDate, _selectedDate);
              final isToday = _isSameDate(dayDate, now);
              final dayEvents = _eventsForDay(allEvents, dayDate);
              final hasEvents = dayEvents.isNotEmpty;

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() {
                    _selectedDate = dayDate;
                    _showDayEvents = true;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? fblaBlue
                        : (isToday ? fblaBlue.withOpacity(0.2) : const Color(0xFF1A2943)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? fblaBlue
                          : (isToday ? fblaBlue.withOpacity(0.9) : Colors.white10),
                      width: isToday ? 1.4 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (hasEvents)
                        Positioned(
                          right: 3,
                          top: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6C500),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${dayEvents.length}',
                              style: const TextStyle(
                                color: Color(0xFF0A1422),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showYearPicker() {
    final currentYear = DateTime.now().year;
    final years = List<int>.generate(16, (i) => currentYear - 5 + i);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1623),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: years.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2,
            ),
            itemBuilder: (context, i) {
              final y = years[i];
              final selected = y == _selectedYear;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() => _selectedYear = y);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF1D4E89) : const Color(0xFF1A2640),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? const Color(0xFFF6C500) : Colors.white10,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$y',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDayEventsView(BuildContext context, List<Event> events) {
    final Color fblaBlue = const Color(0xFF1D4E89);
    final Color fblaGold = const Color(0xFFF6C500);

    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF13243D),
                  border: Border.all(color: Colors.white12),
                ),
                child: Icon(Icons.event_busy, size: 42, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 16),
              Text(
                'No events on this day',
                style: TextStyle(
                  color: Colors.grey.shade200,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create one now and set a reminder in seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _showAddEventDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add New Event'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: fblaBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: events.length,
      itemBuilder: (context, idx) {
        final e = events[idx];
        final eventType = _getEventType(e.title);
        final typeColor = _eventTypeColor(eventType);
        final saved = Provider.of<AppState>(context, listen: false)
            .savedEventIds
            .contains(e.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF0F1B2D), const Color(0xFF162236)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: fblaBlue.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: fblaBlue.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with type badge and save button
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: typeColor.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_filterIcon(eventType), size: 14, color: typeColor),
                          const SizedBox(width: 6),
                          Text(
                            eventType,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_outline,
                        color: fblaGold,
                      ),
                      onPressed: () {
                        Provider.of<AppState>(context, listen: false).toggleSaveEvent(e.id);
                      },
                    ),
                  ],
                ),
              ),
              
              // Event Title
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  e.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              
              // Time and Location
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _buildEventInfoChip(
                      icon: Icons.schedule,
                      text: '${_shortDateTime(e.start)} - ${_shortDateTime(e.end)}',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    _buildEventInfoChip(
                      icon: Icons.location_on_outlined,
                      text: e.location,
                    ),
                  ],
                ),
              ),
              
              // Description
              if (e.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    e.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              
              // Action Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
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
                    icon: const Icon(Icons.notifications_active_outlined, size: 18),
                    label: const Text('Set Reminder'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fblaBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventInfoChip({required IconData icon, required String text}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddEventDialog() async {
    final app = Provider.of<AppState>(context, listen: false);
    final initialDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final createdEvent = await Navigator.push<Event>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEventScreen(initialDate: initialDate),
      ),
    );

    if (createdEvent == null) {
      return;
    }

    app.addUserEvent(createdEvent);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(
        createdEvent.start.year,
        createdEvent.start.month,
        createdEvent.start.day,
      );
      _selectedYear = createdEvent.start.year;
      _showDayEvents = true;
    });
  }

  IconData _filterIcon(String filter) {
    switch (filter) {
      case 'Meetings':
        return Icons.groups_2_outlined;
      case 'Competitions':
        return Icons.emoji_events_outlined;
      case 'Social':
        return Icons.celebration_outlined;
      case 'Workshops':
        return Icons.school_outlined;
      default:
        return Icons.grid_view_rounded;
    }
  }

  String _monthYearLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Event> _eventsForDay(List<Event> allEvents, DateTime day) {
    return allEvents.where((event) => _isSameDate(event.start, day)).toList();
  }

  Color _eventTypeColor(String eventType) {
    switch (eventType) {
      case 'Meeting':
        return const Color(0xFF64B5F6);
      case 'Competition':
        return const Color(0xFFFFD54F);
      case 'Workshop':
        return const Color(0xFF81C784);
      case 'Social':
        return const Color(0xFFBA68C8);
      default:
        return const Color(0xFF90CAF9);
    }
  }

  String _getEventType(String title) {
    if (title.toLowerCase().contains('meeting')) return 'Meeting';
    if (title.toLowerCase().contains('competition')) return 'Competition';
    if (title.toLowerCase().contains('workshop')) return 'Workshop';
    if (title.toLowerCase().contains('social')) return 'Social';
    return 'Event';
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
                side: BorderSide(color: Colors.white.withOpacity(0.35), width: 1.4),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.35), width: 1.4),
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  Future<TimeOfDay?> _showStyledTimePicker(TimeOfDay initialTime) async {
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
                side: BorderSide(color: Colors.white.withOpacity(0.35), width: 1.4),
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final fblaBlue = const Color(0xFF1D4E89);
    final fblaGold = const Color(0xFFF6C500);

    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _submit,
            child: Text(
              'Save',
              style: TextStyle(
                color: fblaGold,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
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
                  child: const Icon(Icons.event_note, color: Colors.white, size: 40),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2640),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.grey.shade400, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Set specific time',
                        style: TextStyle(
                          color: Colors.grey.shade300,
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
                                value: _startTime?.format(context) ?? 'Set time',
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
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFF6C500), size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2640),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey.shade400),
          hintStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            color: const Color(0xFF1A2640),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3)),
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
                        color: Colors.grey.shade500,
                        fontSize: compact ? 11 : 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 14 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade500,
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(colors: [fblaBlue, fblaBlue.withOpacity(0.7)])
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
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                        ? LinearGradient(colors: [fblaBlue, fblaBlue.withOpacity(0.7)])
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
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                widget.onDateSelected(DateTime(_selectedYear, _selectedMonth, 1));
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
      appBar: AppBar(title: Text('Competitions')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: app.competitions
            .map((c) => Card(
                  child: ListTile(
                    title: Text(c.name,
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(c.description),
                    trailing: Icon(Icons.chevron_right, color: fblaGold),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CompetitionDetail(c))),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class CompetitionDetail extends StatelessWidget {
  final Competition competition;
  CompetitionDetail(this.competition);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(competition.name),
      ),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(competition.description),
          SizedBox(height: 12),
          Text('Leaderboard', style: Theme.of(context).textTheme.titleMedium),
          ...competition.leaderboard.map((l) => ListTile(
                leading: CircleAvatar(child: Text(l.user[0])),
                title: Text(l.user),
                trailing: Text('${l.points} pts'),
              ))
        ]),
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
   Profile / Resources Screen
   ------------------------ */

class ProfileScreen extends StatelessWidget {
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
                              backgroundImage: app.localProfileImageBytes != null
                                  ? MemoryImage(app.localProfileImageBytes!)
                                  : (app.userProfile?.photoUrl != null &&
                                          app.userProfile!.photoUrl!.isNotEmpty
                                      ? NetworkImage(app.userProfile!.photoUrl!)
                                      : null) as ImageProvider<Object>?,
                              child: app.localProfileImageBytes == null &&
                                      (app.userProfile?.photoUrl == null ||
                                          app.userProfile!.photoUrl!.isEmpty)
                                  ? Text(
                                      app.displayName.isNotEmpty
                                          ? app.displayName[0].toUpperCase()
                                          : 'F',
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
                                  border: Border.all(color: Colors.white, width: 3),
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
                      app.userEmail.isNotEmpty ? app.userEmail : 'Not signed in',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  _buildModernSectionHeader('Achievements', Icons.emoji_events, isDark, fblaBlue),
                  SizedBox(height: 16),
                  SizedBox(
                    height: 140,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildModernBadge('First Event', 'Attended first event', Icons.star, fblaGold),
                        _buildModernBadge('Active', 'Participated 5+ events', Icons.group, Color(0xFF2196F3)),
                        _buildModernBadge('Competitor', 'Joined competition', Icons.emoji_events, Color(0xFF4CAF50)),
                        _buildModernBadge('Leader', 'Led chapter activity', Icons.leaderboard, Color(0xFF9C27B0)),
                        _buildModernBadge('Scholar', 'Completed materials', Icons.school, Color(0xFFFF9800)),
                      ],
                    ),
                  ),
                  SizedBox(height: 28),

                  // Quick Actions
                  _buildModernSectionHeader('Quick Actions', Icons.bolt, isDark, fblaBlue),
                  SizedBox(height: 16),
                  _buildModernActionCard(
                    context,
                    'Edit Profile',
                    'Update your information',
                    Icons.edit_outlined,
                    fblaBlue,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
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

  Widget _buildModernStatCard(String value, String label, IconData icon, Color color) {
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

  Widget _buildModernSectionHeader(String title, IconData icon, bool isDark, Color fblaBlue) {
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

  Widget _buildModernBadge(String title, String description, IconData icon, Color color) {
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
        padding: const EdgeInsets.all(16),
        children: [
          _buildGroupHeader(context, 'Community & Connection', Icons.groups_outlined),
          _buildMoreTile(
            context,
            title: 'Find Members',
            subtitle: 'Search local members and officers',
            icon: Icons.badge_outlined,
          ),
          _buildMoreTile(
            context,
            title: 'Social Wall',
            subtitle: 'Instagram, LinkedIn, and X feeds',
            icon: Icons.public_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ResourcesScreen()),
              );
            },
          ),
          _buildMoreTile(
            context,
            title: 'Message Center',
            subtitle: 'Connect with chapter officers or advisers',
            icon: Icons.mark_chat_unread_outlined,
          ),
          const SizedBox(height: 20),

          _buildGroupHeader(context, 'Leadership & Growth', Icons.emoji_events_outlined),
          _buildMoreTile(
            context,
            title: 'BAA Progress Tracker',
            subtitle: 'Track Business Achievement Awards checklist',
            icon: Icons.checklist_outlined,
          ),
          _buildMoreTile(
            context,
            title: 'Scholarship Hub',
            subtitle: 'FBLA scholarships and deadlines',
            icon: Icons.school_outlined,
          ),
          _buildMoreTile(
            context,
            title: 'Officer Corner',
            subtitle: 'Resources for current or aspiring officers',
            icon: Icons.workspace_premium_outlined,
          ),
          const SizedBox(height: 20),

          _buildGroupHeader(context, 'Administration', Icons.admin_panel_settings_outlined),
          _buildMoreTile(
            context,
            title: 'Attendance Tracker',
            subtitle: 'Scan QR code to check in at meetings',
            icon: Icons.qr_code_scanner_outlined,
          ),
          _buildMoreTile(
            context,
            title: 'Dues & Payments',
            subtitle: 'Check membership status and payment portal',
            icon: Icons.payments_outlined,
          ),
          _buildMoreTile(
            context,
            title: 'Document Library',
            subtitle: 'Bylaws, Robert’s Rules, and meeting minutes',
            icon: Icons.folder_open_outlined,
          ),
          const SizedBox(height: 20),

          _buildGroupHeader(context, 'Support', Icons.support_agent_outlined),
          _buildMoreTile(
            context,
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
            const SizedBox(height: 20),
            _buildGroupHeader(
              context,
              'Extra Developer Options',
              Icons.developer_mode_outlined,
            ),
            _buildMoreTile(
              context,
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

  Widget _buildGroupHeader(BuildContext context, String title, IconData icon) {
    final Color fblaBlue = const Color(0xFF1D4E89);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: fblaBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: fblaBlue, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : fblaBlue,
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
    VoidCallback? onTap,
  }) {
    final Color fblaBlue = const Color(0xFF1D4E89);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ??
              () {
                return;
              },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: fblaBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: fblaBlue.withOpacity(0.18), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: fblaBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: fblaBlue),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
      'a': 'Ask your chapter adviser about local membership steps and dues payment deadlines.'
    },
    {
      'q': 'Where do I see upcoming chapter events?',
      'a': 'Open the Events tab to view monthly and weekly schedules with event details.'
    },
    {
      'q': 'How do I RSVP to an event?',
      'a': 'Open an event card and tap RSVP, then choose Yes, Maybe, or No.'
    },
    {
      'q': 'Can I set reminders for competitions?',
      'a': 'Yes, tap Remind on an event card to schedule a local notification reminder.'
    },
    {
      'q': 'How do I update my profile photo?',
      'a': 'Go to Profile and tap the camera icon on your avatar to pick a new image.'
    },
    {
      'q': 'Why is dark mode always on?',
      'a': 'The app currently uses a fixed dark theme to keep the interface consistent.'
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
      'a': 'AI requires a running Ollama server endpoint reachable from your device.'
    },
    {
      'q': 'How do I sign out of the app?',
      'a': 'Open Profile and tap Log Out at the bottom of the page.'
    },
    {
      'q': 'Where are chapter documents stored?',
      'a': 'Use More > Document Library for bylaws, minutes, and chapter resources.'
    },
    {
      'q': 'Can I use the app offline?',
      'a': 'Some local content may remain visible, but most live features require internet.'
    },
    {
      'q': 'How do I report incorrect event information?',
      'a': 'Share details with your chapter officer or adviser to update official data.'
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
      'a': 'Start with your chapter adviser or officer team for account and access help.'
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
              border: Border.all(color: fblaBlue.withOpacity(0.35), width: 1.1),
            ),
            child: ExpansionTile(
              collapsedIconColor: Colors.white70,
              iconColor: Colors.white,
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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

    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
          // General Settings Section
          _buildSectionHeader('General Settings', Icons.settings_outlined, fblaBlue),
          SizedBox(height: 16),
          
          // Dark Mode Toggle
          _buildSettingsCard(
            context,
            'Dark Mode',
            'Dark theme is always enabled',
            Icons.dark_mode_outlined,
            Switch(
              value: app.isDarkMode,
              onChanged: null,
              activeColor: fblaBlue,
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
              activeColor: fblaBlue,
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
              activeColor: fblaBlue,
            ),
          ),
          
          SizedBox(height: 32),
          
          // Privacy & Security Section
          _buildSectionHeader('Privacy & Security', Icons.security_outlined, fblaBlue),
          SizedBox(height: 16),
          
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
          
          SizedBox(height: 32),
          
          // App Information Section
          _buildSectionHeader('App Information', Icons.info_outline, fblaBlue),
          SizedBox(height: 16),
          
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
                  title: Text('About FBLA Member App'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Version: 1.0.0'),
                      SizedBox(height: 8),
                      Text('The official FBLA Member App for staying connected with your chapter, events, and resources.'),
                      SizedBox(height: 8),
                      Text('Built with Flutter for the best mobile experience.'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
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
          
          SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color fblaBlue) {
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: fblaBlue.withOpacity(0.35), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: fblaBlue,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: fblaBlue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
