import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/practice_record.dart';

/// Local persistence for AI Coach practice sessions.
///
/// Stores every [PracticeRecord] as a single JSON list in SharedPreferences so
/// members can revisit past AI feedback and self-assessments, and see how many
/// times they've practiced each event. Newest records are returned first.
class PracticeHistoryStore {
  PracticeHistoryStore._();

  static const String _key = 'practice_history';

  /// Appends [record] to the saved history.
  static Future<void> add(PracticeRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _read(prefs);
      existing.add(record);
      final encoded = jsonEncode(existing.map((r) => r.toJson()).toList());
      await prefs.setString(_key, encoded);
    } catch (_) {
      // Best-effort; a failed write must not break the practice flow.
    }
  }

  /// All saved records, newest first.
  static Future<List<PracticeRecord>> all() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final records = await _read(prefs);
      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return records;
    } catch (_) {
      return [];
    }
  }

  /// Records for a single event, newest first.
  static Future<List<PracticeRecord>> allForEvent(String eventName) async {
    final records = await all();
    return records
        .where((r) => r.eventName == eventName)
        .toList(growable: false);
  }

  /// How many times [eventName] has been practiced.
  static Future<int> countForEvent(String eventName) async {
    final records = await allForEvent(eventName);
    return records.length;
  }

  static Future<List<PracticeRecord>> _read(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) =>
            PracticeRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
