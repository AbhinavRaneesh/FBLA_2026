import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fbla_member_app/main.dart';
import 'package:fbla_member_app/ai/models/chat_message_model.dart';
import 'package:fbla_member_app/models/practice_record.dart';
import 'package:fbla_member_app/services/chat_history_store.dart';
import 'package:fbla_member_app/services/practice_history_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Fresh, empty mock store before each test.
    SharedPreferences.setMockInitialValues({});
  });

  group('ChatHistoryStore', () {
    test('save then load round-trips a conversation', () async {
      final messages = [
        ChatMessageModel.user('What events are at NLC?'),
        ChatMessageModel.assistant('Plenty — let me list a few.'),
      ];
      await ChatHistoryStore.save('main_thread', messages);

      final loaded = await ChatHistoryStore.load('main_thread');
      expect(loaded.length, 2);
      expect(loaded[0].role, 'user');
      expect(loaded[0].content, 'What events are at NLC?');
      expect(loaded[1].role, 'assistant');
    });

    test('drops system messages from persistence', () async {
      await ChatHistoryStore.save('main_thread', [
        ChatMessageModel.system('You are a helpful assistant.'),
        ChatMessageModel.user('Hi'),
      ]);
      final loaded = await ChatHistoryStore.load('main_thread');
      expect(loaded.length, 1);
      expect(loaded.single.role, 'user');
    });

    test('load returns empty when nothing is saved', () async {
      expect(await ChatHistoryStore.load('missing'), isEmpty);
    });

    test('clear removes a saved conversation', () async {
      await ChatHistoryStore.save('main_thread', [ChatMessageModel.user('Hi')]);
      await ChatHistoryStore.clear('main_thread');
      expect(await ChatHistoryStore.load('main_thread'), isEmpty);
    });
  });

  group('PracticeHistoryStore', () {
    test('add then read returns records newest-first, scoped by event', () async {
      await PracticeHistoryStore.add(PracticeRecord(
        eventName: 'Public Speaking',
        category: 'Presentation',
        type: 'coach',
        timestamp: DateTime(2026, 6, 1),
        aiFeedback: 'Good hook.',
      ));
      await PracticeHistoryStore.add(PracticeRecord(
        eventName: 'Public Speaking',
        category: 'Presentation',
        type: 'record',
        timestamp: DateTime(2026, 6, 10),
        rubricChecked: 5,
        rubricTotal: 6,
      ));
      await PracticeHistoryStore.add(PracticeRecord(
        eventName: 'Marketing',
        category: 'Roleplay',
        type: 'coach',
        timestamp: DateTime(2026, 6, 5),
      ));

      final speaking = await PracticeHistoryStore.allForEvent('Public Speaking');
      expect(speaking.length, 2);
      // Newest first: the June 10 record precedes the June 1 coach session.
      expect(speaking.first.timestamp, DateTime(2026, 6, 10));

      expect(await PracticeHistoryStore.countForEvent('Public Speaking'), 2);
      expect(await PracticeHistoryStore.countForEvent('Marketing'), 1);
      expect(await PracticeHistoryStore.countForEvent('Accounting'), 0);
    });

    test('all returns every saved record', () async {
      await PracticeHistoryStore.add(PracticeRecord(
        eventName: 'A',
        category: 'Roleplay',
        type: 'coach',
        timestamp: DateTime(2026, 1, 1),
      ));
      await PracticeHistoryStore.add(PracticeRecord(
        eventName: 'B',
        category: 'Roleplay',
        type: 'coach',
        timestamp: DateTime(2026, 1, 2),
      ));
      expect((await PracticeHistoryStore.all()).length, 2);
    });
  });

  group('AppState offline persistence', () {
    test('savePendingSignup writes the expected JSON payload', () async {
      final prefs = await SharedPreferences.getInstance();
      final app = AppState(prefs: prefs);

      await app.savePendingSignup(
        name: 'Jane Smith',
        email: 'jane@school.org',
        password: 'Strong1!pass',
        school: 'Lincoln High',
        role: 'Student',
      );

      final raw = prefs.getString('pendingSignup');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['name'], 'Jane Smith');
      expect(decoded['email'], 'jane@school.org');
      expect(decoded['school'], 'Lincoln High');
      expect(decoded['role'], 'Student');
    });

    test('login persists identity and flips loggedIn', () async {
      final prefs = await SharedPreferences.getInstance();
      final app = AppState(prefs: prefs);

      expect(app.loggedIn, isFalse);
      await app.login('member@school.org', 'Member One',
          role: 'Officer', grade: '11');

      expect(app.loggedIn, isTrue);
      expect(prefs.getString('userEmail'), 'member@school.org');
      expect(prefs.getString('displayName'), 'Member One');
      expect(prefs.getString('signupRole'), 'Officer');
      expect(prefs.getString('gradeLevel'), '11');
    });
  });
}
