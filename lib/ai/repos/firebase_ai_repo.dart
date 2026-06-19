import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message_model.dart';

/// Calls the `chatWithGemini` Cloud Function (API key stored in Firebase secrets).
/// Uses HTTPS directly so the chat works without the native cloud_functions plugin.
class FirebaseAiRepo {
  static const String _region = 'us-central1';
  static const String _functionName = 'chatWithGemini';
  static const int _maxHistoryMessages = 20;

  static String _callableUrl() {
    final projectId = Firebase.app().options.projectId;
    if (projectId == null || projectId.isEmpty) {
      throw Exception('Firebase project ID is not configured.');
    }
    return 'https://$_region-$projectId.cloudfunctions.net/$_functionName';
  }

  /// Returns a reply when the user is signed in and the function succeeds.
  /// Returns `null` when the user is not signed in (caller may use a local fallback).
  static Future<String?> tryChat(
    List<ChatMessageModel> messages, {
    String? mode,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }

    final trimmed = messages.length > _maxHistoryMessages
        ? messages.sublist(messages.length - _maxHistoryMessages)
        : messages;

    try {
      final idToken = await user.getIdToken();
      final response = await http
          .post(
            Uri.parse(_callableUrl()),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'data': {
                'messages': trimmed.map((m) => m.toJson()).toList(),
                if (mode != null) 'mode': mode,
              },
            }),
          )
          .timeout(const Duration(seconds: 90));

      final body = _decodeBody(response.body);
      if (body == null) {
        throw Exception(
          'AI service returned an invalid response (HTTP ${response.statusCode}).',
        );
      }

      final error = body['error'];
      if (error is Map<String, dynamic>) {
        final status = error['status']?.toString() ?? '';
        final message =
            error['message']?.toString() ?? 'AI assistant request failed.';
        if (status == 'UNAUTHENTICATED') {
          return null;
        }
        throw Exception(message);
      }

      final result = body['result'];
      if (result is Map<String, dynamic>) {
        final text = result['text']?.toString().trim();
        if (text != null && text.isNotEmpty) {
          return text;
        }
      }

      return 'The AI assistant returned an empty response. Please try again.';
    } catch (e, stack) {
      if (kDebugMode) {
        print('FirebaseAiRepo: $e');
        print(stack);
      }
      rethrow;
    }
  }

  static Map<String, dynamic>? _decodeBody(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
