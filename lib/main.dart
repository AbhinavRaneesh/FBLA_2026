import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'models/fbla_models.dart';

// FBLA Colors
const fblaNavy = Color(0xFF00274D);
const fblaGold = Color(0xFFFDB913);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Denver'));
  
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class AppState extends ChangeNotifier {
  final SharedPreferences prefs;
  String userEmail;
  String displayName;
  List<Event> events;
  List<NewsItem> news;
  List<Competition> competitions;
  List<ChatThread> threads;
  Set<String> savedEventIds = {};
  bool hasSeenOnboarding;

  // Firebase integration
  User? firebaseUser;
  FBLAUser? userProfile;
  Chapter? userChapter;
  bool _firebaseInitialized = false;

  AppState({required this.prefs})
      : userEmail = prefs.getString('userEmail') ?? '',
        displayName = prefs.getString('displayName') ?? '',
        events = sampleEvents,
        news = sampleNews,
        competitions = sampleCompetitions,
        threads = sampleThreads,
        hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false {
    savedEventIds = prefs.getStringList('savedEvents')?.toSet() ?? {};
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    if (_firebaseInitialized) return;
    
    try {
      await Firebase.initializeApp();
      print('🔥 Firebase initialized successfully');
      _firebaseInitialized = true;
      
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

  bool get loggedIn => firebaseUser != null || userEmail.isNotEmpty;

  Future<void> login(String email, String name) async {
    userEmail = email;
    displayName = name;
    await prefs.setString('userEmail', userEmail);
    await prefs.setString('displayName', displayName);
    notifyListeners();
  }

  Future<void> logout() async {
    if (firebaseUser != null) {
      await FirebaseService.signOut();
    }
    userEmail = '';
    displayName = '';
    firebaseUser = null;
    userProfile = null;
    userChapter = null;
    await prefs.remove('userEmail');
    await prefs.remove('displayName');
    notifyListeners();
  }

  Future<void> skipOnboarding() async {
    hasSeenOnboarding = true;
    await prefs.setBool('hasSeenOnboarding', true);
    notifyListeners();
  }

  Future<void> setFirebaseUser(User user) async {
    firebaseUser = user;
    userEmail = user.email ?? '';
    displayName = user.displayName ?? '';
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
    notifyListeners();
  }

  void postMessage(String threadId, ChatMessage message) {
    final t = threads.firstWhere((th) => th.id == threadId);
    t.messages.add(message);
    notifyListeners();
  }

  void addThread(ChatThread thread) {
    threads.add(thread);
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
    id: 'e1',
    title: 'National Conference Opening Session',
    start: DateTime.now().add(Duration(days: 3, hours: 9)),
    end: DateTime.now().add(Duration(days: 3, hours: 11)),
    location: 'Main Hall',
    description: 'Join delegates for the opening keynote and announcements.',
  ),
  Event(
    id: 'e2',
    title: 'Resume Workshop',
    start: DateTime.now().add(Duration(days: 4, hours: 14)),
    end: DateTime.now().add(Duration(days: 4, hours: 16)),
    location: 'Room B12',
    description: 'Hands-on resume & career prep workshop.',
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

Future<void> initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );
}

Future<void> scheduleEventReminder(Event e) async {
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
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
      child: MaterialApp(
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
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        routes: {
          '/login': (_) => const LoginScreen(),
          '/signup': (_) => const SignupScreen(),
          '/onboarding': (_) => const OnboardingScreen(),
          '/firebase_auth': (_) => const FirebaseAuthScreen(),
        },
        home: AuthGate(),
      ),
    );
  }
}

class RootScreen extends StatefulWidget {
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  final _pages = [
    HomeScreen(),
    EventsScreen(),
    const ResourcesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    initLocalNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
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
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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
        backgroundColor: fblaGold,
        child: Icon(
          Icons.smart_toy,
          color: fblaNavy,
          size: 28,
        ),
        elevation: 8,
        tooltip: 'AI Assistant',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
    if (!app.hasSeenOnboarding) {
      return const OnboardingScreen();
    }
    // Use Firebase authentication
    return const FirebaseAuthScreen();
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

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final Color fblaBlue = const Color(0xFF1D4E89);
    final Color fblaGold = const Color(0xFFF6C500);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with gradient
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: fblaBlue,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      fblaBlue,
                      fblaBlue.withOpacity(0.8),
                      fblaNavy,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getGreeting(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    app.displayName.isNotEmpty
                                        ? app.displayName
                                        : 'FBLA Member',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: fblaGold.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: fblaGold.withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 14,
                                          color: fblaGold,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Active Member',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: fblaGold,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Hero(
                              tag: 'profile_avatar',
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: fblaGold.withOpacity(0.4),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 35,
                                  backgroundColor: fblaGold,
                                  child: Text(
                                    app.displayName.isNotEmpty
                                        ? app.displayName[0].toUpperCase()
                                        : 'F',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: fblaBlue,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
                  // Stats Cards Row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.event,
                              label: 'Events',
                              value: '${app.events.length}',
                              color: fblaBlue,
                              gradient: LinearGradient(
                                colors: [fblaBlue, fblaBlue.withOpacity(0.7)],
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.bookmark,
                              label: 'Saved',
                              value: '${app.savedEventIds.length}',
                              color: fblaGold,
                              gradient: LinearGradient(
                                colors: [fblaGold, fblaGold.withOpacity(0.7)],
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.campaign,
                              label: 'News',
                              value: '${app.news.length}',
                              color: Color(0xFF6C63FF),
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF6C63FF),
                                  Color(0xFF6C63FF).withOpacity(0.7)
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 28),

                  // Quick Access Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quick Access',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : fblaNavy,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.more_horiz, size: 20),
                        label: Text('More'),
                        style: TextButton.styleFrom(
                          foregroundColor: fblaBlue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.4,
                        children: [
                          _ModernQuickButton(
                            icon: Icons.calendar_month,
                            label: 'Events',
                            subtitle: '${app.events.length} upcoming',
                            color: fblaBlue,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => EventsScreen())),
                          ),
                          _ModernQuickButton(
                            icon: Icons.school,
                            label: 'Resources',
                            subtitle: 'Study materials',
                            color: Color(0xFFFF6B6B),
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => ResourcesScreen())),
                          ),
                          _ModernQuickButton(
                            icon: Icons.group,
                            label: 'Chapter',
                            subtitle: 'Connect',
                            color: fblaGold,
                            onTap: () async {
                              final url = Uri.parse('https://connect.fbla.org/');
                              if (await canLaunchUrl(url)) launchUrl(url);
                            },
                          ),
                          _ModernQuickButton(
                            icon: Icons.notifications,
                            label: 'Notifications',
                            subtitle: 'Stay updated',
                            color: Color(0xFF4CAF50),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Notifications coming soon!')),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 28),

                  // Upcoming Events Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Upcoming Events',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : fblaNavy,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => EventsScreen())),
                        icon: Icon(Icons.arrow_forward, size: 18),
                        label: Text('View All'),
                        style: TextButton.styleFrom(
                          foregroundColor: fblaBlue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: app.events.length,
                          itemBuilder: (context, index) {
                            final event = app.events[index];
                            return Container(
                              width: constraints.maxWidth > 400 ? 320 : 280,
                              margin: EdgeInsets.only(right: 16),
                              child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: fblaGold.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _formatEventDate(event.start),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: fblaBlue,
                                  ),
                                ),
                              ),
                              Spacer(),
                              IconButton(
                                icon: Icon(
                                  app.savedEventIds.contains(event.id)
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: fblaGold,
                                ),
                                onPressed: () {
                                  app.toggleSaveEvent(event.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        app.savedEventIds.contains(event.id)
                                            ? 'Event saved'
                                            : 'Event removed',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            event.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            event.location,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              SizedBox(width: 4),
                              Text(
                                _formatTime(event.start),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Expanded(child: SizedBox()),
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: Text(event.title),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(event.description),
                                          SizedBox(height: 8),
                                          Text(
                                              'Date: ${_formatEventDate(event.start)}'),
                                          Text(
                                              'Time: ${_formatTime(event.start)}'),
                                          Text('Location: ${event.location}'),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Text(
                                  'Details',
                                  style: TextStyle(color: fblaBlue),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      SizedBox(height: 24),

                  // Recent Announcements Section
                  SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Announcements',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : fblaNavy,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.arrow_forward, size: 18),
                        label: Text('View All'),
                        style: TextButton.styleFrom(
                          foregroundColor: fblaBlue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ...app.news.take(3).map((n) => Container(
                        margin: EdgeInsets.only(bottom: 12),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            onTap: () => showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: Text(n.title),
                                      content: Text(n.body),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text('Close'))
                                      ],
                                    )),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: fblaBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.campaign,
                                      color: fblaBlue,
                                      size: 24,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          n.body,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Column(
                                    children: [
                                      Text(
                                        '${n.date.month}/${n.date.day}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: fblaBlue,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14,
                                        color: Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatEventDate(DateTime date) {
    final months = [
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
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} $ampm';
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
  final Color color;
  final VoidCallback onTap;

  const _ModernQuickButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8),
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
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

class _EventsScreenState extends State<EventsScreen>
    with TickerProviderStateMixin {
  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'Meetings',
    'Competitions',
    'Social',
    'Workshops'
  ];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final upcoming = app.events..sort((a, b) => a.start.compareTo(b.start));
    final Color fblaBlue = const Color(0xFF1D4E89);
    final Color fblaGold = const Color(0xFFF6C500);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Events & Schedule'),
        backgroundColor: fblaBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: fblaGold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Calendar'),
            Tab(text: 'List'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedFilter = filter);
                      },
                      backgroundColor:
                          isDark ? Colors.grey.shade700 : Colors.white,
                      selectedColor: fblaBlue,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : fblaBlue,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? fblaBlue : Colors.grey.shade400,
                        width: 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCalendarView(context, upcoming),
                _buildListView(context, upcoming),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(BuildContext context, List<Event> events) {
    final Color fblaBlue = const Color(0xFF1D4E89);

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Calendar header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: fblaBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DateTime.now().month}/${DateTime.now().year}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: fblaBlue,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.today, color: fblaBlue),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Calendar navigation coming soon'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Calendar grid placeholder
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Calendar View',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Interactive calendar coming soon',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(BuildContext context, List<Event> events) {
    final Color fblaBlue = const Color(0xFF1D4E89);
    final Color fblaGold = const Color(0xFFF6C500);

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, idx) {
        final e = events[idx];
        final saved = Provider.of<AppState>(context, listen: false)
            .savedEventIds
            .contains(e.id);
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: fblaGold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getEventType(e.title),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: fblaBlue,
                        ),
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_border,
                        color: fblaGold,
                      ),
                      onPressed: () {
                        final app =
                            Provider.of<AppState>(context, listen: false);
                        app.toggleSaveEvent(e.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                saved ? 'Removed from saved' : 'Event saved'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  e.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 16, color: Colors.grey.shade600),
                    SizedBox(width: 4),
                    Text(
                      '${_shortDateTime(e.start)} — ${_shortDateTime(e.end)}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 16, color: Colors.grey.shade600),
                    SizedBox(width: 4),
                    Text(
                      e.location,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  e.description,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (_) => _RsvpSheet(event: e),
                          );
                        },
                        icon: Icon(Icons.rsvp, size: 16),
                        label: Text('RSVP'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: fblaBlue,
                          side: BorderSide(color: fblaBlue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await scheduleEventReminder(e);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Reminder scheduled'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: Icon(Icons.notifications, size: 16),
                        label: Text('Remind'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: fblaBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getEventType(String title) {
    if (title.toLowerCase().contains('meeting')) return 'Meeting';
    if (title.toLowerCase().contains('competition')) return 'Competition';
    if (title.toLowerCase().contains('workshop')) return 'Workshop';
    if (title.toLowerCase().contains('social')) return 'Social';
    return 'Event';
  }
}

class _RsvpSheet extends StatelessWidget {
  final Event event;
  const _RsvpSheet({required this.event});
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context, listen: false);
    return Padding(
      padding: EdgeInsets.all(12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('RSVP for "${event.title}"',
            style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          ElevatedButton(
              onPressed: () {
                app.rsvpEvent(event.id, 'Yes');
                Navigator.pop(context);
              },
              child: Text('Yes')),
          ElevatedButton(
              onPressed: () {
                app.rsvpEvent(event.id, 'Maybe');
                Navigator.pop(context);
              },
              child: Text('Maybe')),
          ElevatedButton(
              onPressed: () {
                app.rsvpEvent(event.id, 'No');
                Navigator.pop(context);
              },
              child: Text('No')),
        ]),
      ]),
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
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final Color fblaBlue = const Color(0xFF1D4E89);
    final Color fblaGold = const Color(0xFFF6C500);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Modern Profile Header
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: fblaBlue,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      fblaBlue,
                      fblaBlue.withOpacity(0.8),
                      Color(0xFF00274D),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 40),
                      // Avatar with edit button
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
                                child: Text(
                                  app.displayName.isNotEmpty
                                      ? app.displayName[0].toUpperCase()
                                      : 'F',
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: fblaBlue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
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
                                Icons.edit,
                                size: 20,
                                color: fblaBlue,
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
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings coming soon'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
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
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification settings coming soon'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    ),
                  ),
                  _buildModernActionCard(
                    context,
                    'Help & Support',
                    'Get help or contact support',
                    Icons.help_outline,
                    Color(0xFF9C27B0),
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Help center coming soon'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Logout Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade600],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          app.logout();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Logged out successfully'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Log Out',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // App Info
                  Center(
                    child: Text(
                      'FBLA Member App v1.0.0',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
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
