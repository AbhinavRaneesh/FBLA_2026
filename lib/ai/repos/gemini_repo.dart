import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message_model.dart';
import '../utils/constants.dart';
import 'firebase_ai_repo.dart';

class GeminiRepo {
  static const String _apiBase =
      'https://generativelanguage.googleapis.com/v1beta';
  static const int _maxHistoryMessages = 20;

  static List<String> _candidateModels() {
    final candidates = <String>[];

    void addModel(String model) {
      final trimmed = model.trim();
      if (trimmed.isNotEmpty && !candidates.contains(trimmed)) {
        candidates.add(trimmed);
      }
    }

    addModel(geminiModel);
    addModel('gemini-2.5-flash-lite');
    addModel('gemini-2.5-flash');
    addModel('gemini-2.0-flash');

    return candidates;
  }

  /// Production path: Firebase Cloud Function (secret API key).
  /// Dev fallback: direct Gemini API when `GEMINI_API_KEY` is passed via --dart-define.
  static Future<String> chatTextGenerationRepo(
    List<ChatMessageModel> previousMessages,
  ) async {
    try {
      final viaFirebase = await FirebaseAiRepo.tryChat(previousMessages);
      if (viaFirebase != null) {
        return viaFirebase;
      }
    } catch (e) {
      if (geminiApiKey.trim().isEmpty) {
        return 'AI assistant error: $e';
      }
      if (kDebugMode) {
        print('Firebase AI failed, falling back to local Gemini key: $e');
      }
    }

    if (geminiApiKey.trim().isEmpty) {
      return 'Sign in to use the AI assistant. Your chapter stores the Gemini key securely in Firebase.';
    }

    if (kIsWeb) {
      return 'Sign in to use the AI assistant on web, or configure the Firebase chat function.';
    }

    return _chatDirectGemini(previousMessages);
  }

  static Future<String> _chatDirectGemini(
    List<ChatMessageModel> previousMessages,
  ) async {
    final trimmed = previousMessages.length > _maxHistoryMessages
        ? previousMessages.sublist(
            previousMessages.length - _maxHistoryMessages,
          )
        : previousMessages;

    final turns = <Map<String, String>>[];
    for (final message in trimmed) {
      final role = message.role == 'assistant' ? 'model' : 'user';
      turns.add({'role': role, 'text': message.content});
    }

    final contents = _normalizeGeminiTurns(turns);
    if (contents.isEmpty) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': 'Hello'}
        ],
      });
    }

    final requestBody = {
      'systemInstruction': {
        'parts': [
          {
            'text':
                'You are a helpful AI assistant for the FBLA Member App and FBLA students. Help users navigate the app and answer FBLA questions. Keep answers practical and concise.',
          }
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.6,
        'maxOutputTokens': 768,
      },
    };
    String? lastError;

    for (final model in _candidateModels()) {
      final endpoint = '$_apiBase/models/$model:generateContent';
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': geminiApiKey,
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        lastError = _parseGeminiFailure(model, response);
        continue;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final firstCandidate = candidates.first;
        if (firstCandidate is Map<String, dynamic>) {
          final finishReason = firstCandidate['finishReason']?.toString();
          final content = firstCandidate['content'];
          if (content is Map<String, dynamic>) {
            final parts = content['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              final buffer = StringBuffer();
              for (final part in parts) {
                if (part is Map<String, dynamic>) {
                  final text = part['text']?.toString();
                  if (text != null && text.trim().isNotEmpty) {
                    if (buffer.isNotEmpty) {
                      buffer.writeln();
                    }
                    buffer.write(text.trim());
                  }
                }
              }

              final combined = buffer.toString().trim();
              if (combined.isNotEmpty) {
                if (finishReason == 'MAX_TOKENS') {
                  return '$combined\n\n(Reply truncated by token limit. Ask "continue" for the rest.)';
                }
                return combined;
              }
            }
          }
        }
      }

      lastError = 'Gemini model "$model" returned no text content.';
    }

    return lastError ?? 'Gemini request failed.';
  }

  static List<Map<String, dynamic>> _normalizeGeminiTurns(
    List<Map<String, String>> turns,
  ) {
    final merged = <Map<String, dynamic>>[];

    for (final turn in turns) {
      final role = turn['role']!;
      final text = turn['text']!.trim();
      if (text.isEmpty) continue;

      if (merged.isNotEmpty && merged.last['role'] == role) {
        final parts = merged.last['parts'] as List<dynamic>;
        final current = parts.first as Map<String, dynamic>;
        current['text'] = '${current['text']}\n\n$text';
      } else {
        merged.add({
          'role': role,
          'parts': [
            {'text': text}
          ],
        });
      }
    }

    while (merged.isNotEmpty && merged.first['role'] != 'user') {
      merged.removeAt(0);
    }
    while (merged.isNotEmpty && merged.last['role'] != 'user') {
      merged.removeLast();
    }

    return merged;
  }

  static String _parseGeminiFailure(String model, http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final message = data['error']?['message']?.toString() ?? '';
      if (message.toLowerCase().contains('quota') ||
          response.statusCode == 429) {
        return 'The AI is temporarily busy (quota limit). Wait a minute and try again.';
      }
      if (message.isNotEmpty) {
        return 'Gemini model "$model" failed: $message';
      }
    } catch (_) {
      // ignore
    }
    return 'Gemini model "$model" failed: HTTP ${response.statusCode}';
  }
}
