import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ai/models/chat_message_model.dart';

/// Local persistence for AI Coach conversations.
///
/// Chat messages were previously held only in [ChatBloc] memory and lost the
/// moment the screen closed. This store serializes them to SharedPreferences so
/// a member's conversation with the AI Coach survives navigation and app
/// restarts — making the assistant feel personal and continuous.
class ChatHistoryStore {
  ChatHistoryStore._();

  static String _key(String threadId) => 'chat_history_$threadId';

  /// Persists [messages] for [threadId]. System messages are dropped — only the
  /// visible user/assistant turns are worth restoring.
  static Future<void> save(
    String threadId,
    List<ChatMessageModel> messages,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final visible =
          messages.where((m) => m.role != 'system').toList(growable: false);
      final encoded = jsonEncode(visible.map((m) => m.toJson()).toList());
      await prefs.setString(_key(threadId), encoded);
    } catch (_) {
      // Persistence is best-effort; a failed cache write must never break chat.
    }
  }

  /// Restores the saved conversation for [threadId]. Returns an empty list when
  /// there is no history or the stored data can't be parsed.
  static Future<List<ChatMessageModel>> load(String threadId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(threadId));
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) =>
              ChatMessageModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  /// Clears the saved conversation for [threadId].
  static Future<void> clear(String threadId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(threadId));
    } catch (_) {
      // No-op on failure.
    }
  }
}
