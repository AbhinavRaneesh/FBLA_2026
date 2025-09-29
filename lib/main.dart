import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';

// FBLA Colors
const fblaNavy = Color(0xFF00274D);
const fblaGold = Color(0xFFFDB913);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(
      tz.getLocation('America/Denver')); // <-- set to your local tz
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
  AppState({required this.prefs})
      : userEmail = prefs.getString('userEmail') ?? '',
        displayName = prefs.getString('displayName') ?? '',
        events = sampleEvents,
        news = sampleNews,
        competitions = sampleCompetitions,
        threads = sampleThreads {
    savedEventIds = prefs.getStringList('savedEvents')?.toSet() ?? {};
  }

  bool get loggedIn => userEmail.isNotEmpty;

  Future<void> login(String email, String name) async {
    userEmail = email;
    displayName = name;
    await prefs.setString('userEmail', userEmail);
    await prefs.setString('displayName', displayName);
    notifyListeners();
  }

  Future<void> logout() async {
    userEmail = '';
    displayName = '';
    await prefs.remove('userEmail');
    await prefs.remove('displayName');
    notifyListeners();
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
        debugShowCheckedModeBanner: false,
        routes: {
          '/login': (_) => const LoginScreen(),
          '/signup': (_) => const SignupScreen(),
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
    CompetitionsScreen(),
    CommunityScreen(),
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
          BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events), label: 'Competitions'),
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _index == 3
          ? FloatingActionButton(
              backgroundColor: fblaGold,
              child: Icon(Icons.add, color: Colors.black),
              onPressed: () {
                // quick new thread (demo)
                final app = Provider.of<AppState>(context, listen: false);
                final t = ChatThread(
                    id: 't${app.threads.length + 1}',
                    title: 'New thread ${app.threads.length + 1}',
                    messages: []);
                app.addThread(t);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Created new thread')));
              },
            )
          : null,
    );
  }
}

class AuthGate extends StatelessWidget {
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

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [fblaNavy, fblaNavy.withOpacity(0.85)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('FBLA Member App',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                if (!app.loggedIn)
                  TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      child: Text('Log in', style: TextStyle(color: fblaGold)))
                else
                  TextButton(
                      onPressed: () {
                        app.logout();
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Logged out')));
                      },
                      child: Text('Log out', style: TextStyle(color: fblaGold)))
              ],
            ),
          ),
          SizedBox(height: 16),
          SectionHeader(title: 'Announcements'),
          ...app.news.map((n) => Card(
                child: ListTile(
                  title: Text(n.title,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(n.body,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text('${n.date.month}/${n.date.day}'),
                  onTap: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                            title: Text(n.title),
                            content: Text(n.body),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Close'))
                            ],
                          )),
                ),
              )),
          SizedBox(height: 16),
          SectionHeader(title: 'Quick Links'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _QuickButton(
                icon: Icons.schedule,
                label: 'Full Schedule',
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => EventsScreen())),
              ),
              _QuickButton(
                icon: Icons.school,
                label: 'Resources',
                onTap: () async {
                  final url = Uri.parse('https://connect.fbla.org/');
                  if (await canLaunchUrl(url)) launchUrl(url);
                },
              ),
              _QuickButton(
                icon: Icons.map,
                label: 'Venue Map',
                onTap: () =>
                    launchUrl(Uri.parse('https://www.google.com/maps')),
              ),
            ],
          ),
          SizedBox(height: 16),
          SectionHeader(title: 'Your Saved Events'),
          ...app.events
              .where((e) => app.savedEventIds.contains(e.id))
              .map((e) => Card(
                    child: ListTile(
                      title: Text(e.title),
                      subtitle:
                          Text('${_shortDateTime(e.start)} • ${e.location}'),
                      trailing: IconButton(
                        icon: Icon(Icons.notifications_active, color: fblaGold),
                        onPressed: () async {
                          await scheduleEventReminder(e);
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Reminder scheduled')));
                        },
                      ),
                    ),
                  )),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickButton(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: fblaNavy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// Login screen moved to lib/screens/login_screen.dart

/* ------------------------
   Events Screen
   ------------------------ */

class EventsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final upcoming = app.events..sort((a, b) => a.start.compareTo(b.start));
    return Scaffold(
      appBar: AppBar(title: Text('Events & Schedule')),
      body: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: upcoming.length,
          itemBuilder: (context, idx) {
            final e = upcoming[idx];
            final saved = app.savedEventIds.contains(e.id);
            return Card(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: ListTile(
                  title: Text(e.title,
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${_shortDateTime(e.start)} • ${e.location}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border,
                          color: fblaGold),
                      onPressed: () {
                        app.toggleSaveEvent(e.id);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(saved ? 'Removed' : 'Saved')));
                      },
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'rsvp') {
                          showModalBottomSheet(
                              context: context,
                              builder: (_) => _RsvpSheet(event: e));
                        } else if (value == 'map') {
                          final url = Uri.parse(
                              'https://www.google.com/maps/search/${Uri.encodeComponent(e.location)}');
                          launchUrl(url);
                        } else if (value == 'reminder') {
                          scheduleEventReminder(e);
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Reminder scheduled')));
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'rsvp', child: Text('RSVP')),
                        PopupMenuItem(
                            value: 'reminder',
                            child: Text('Schedule reminder')),
                        PopupMenuItem(value: 'map', child: Text('Open map')),
                      ],
                    )
                  ]),
                  onTap: () {
                    showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                              title: Text(e.title),
                              content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(e.description),
                                    SizedBox(height: 8),
                                    Text(
                                        '${_shortDateTime(e.start)} — ${_shortDateTime(e.end)}'),
                                    Text(e.location),
                                  ]),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Close'))
                              ],
                            ));
                  },
                ),
              ),
            );
          }),
    );
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
    return Scaffold(
      appBar: AppBar(title: Text('Profile & Resources')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
                radius: 28,
                child: Text(
                    app.displayName.isNotEmpty ? app.displayName[0] : 'U')),
            SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.displayName.isNotEmpty ? app.displayName : 'Guest',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(app.userEmail.isNotEmpty ? app.userEmail : 'Not signed in'),
            ])
          ]),
          SizedBox(height: 12),
          ElevatedButton.icon(
              onPressed: () {
                // In production link to membership / renew page
                final url = Uri.parse('https://www.fbla-pbl.org/');
                launchUrl(url);
              },
              icon: Icon(Icons.payment, color: Colors.white),
              label: Text('Membership / Renew')),
          SizedBox(height: 12),
          SectionHeader(title: 'Resources'),
          ListTile(
            leading: Icon(Icons.book, color: fblaGold),
            title: Text('Competition Study Guides'),
            onTap: () {
              launchUrl(Uri.parse('https://connect.fbla.org/'));
            },
          ),
          ListTile(
            leading: Icon(Icons.work, color: fblaGold),
            title: Text('Career Center'),
            onTap: () {
              launchUrl(Uri.parse('https://connect.fbla.org/'));
            },
          ),
          Spacer(),
          Text('App Demo Notes (for judges):',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text(
              'This starter app demonstrates core flows: news, events, competitions, community, notifications, and local persistence.'),
        ]),
      ),
    );
  }
}
