import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message_model.dart';
import '../utils/constants.dart';

class GeminiRepo {
  static const String _apiBase = 'https://generativelanguage.googleapis.com/v1beta';

  static List<String> _candidateModels() {
    final candidates = <String>[];

    void addModel(String model) {
      final trimmed = model.trim();
      if (trimmed.isNotEmpty && !candidates.contains(trimmed)) {
        candidates.add(trimmed);
      }
    }

    addModel(geminiModel);
    addModel('gemini-1.5-flash-latest');
    addModel('gemini-1.5-pro-latest');
    addModel('gemini-2.0-flash');

    return candidates;
  }

  static Future<String> chatTextGenerationRepo(
    List<ChatMessageModel> previousMessages,
  ) async {
    if (geminiApiKey.trim().isEmpty) {
      return 'Gemini is selected, but no API key is set yet. Add --dart-define=GEMINI_API_KEY=your_key when you are ready.';
    }

    if (kIsWeb) {
      return 'Gemini chat is not configured for web in this build yet.';
    }

    final messages = previousMessages.map((message) {
      final role = message.role == 'assistant' ? 'model' : 'user';
      return {
        'role': role,
        'parts': [
          {'text': message.content}
        ],
      };
    }).toList();

    if (messages.isEmpty || messages.first['role'] != 'user') {
      messages.insert(0, {
        'role': 'user',
        'parts': [
          {
            'text':
                'You are a helpful AI assistant for FBLA (Future Business Leaders of America) students. Keep answers practical and concise, but complete.'
          }
        ],
      });
    }

    final requestBody = {
      'contents': messages,
      'generationConfig': {
        'temperature': 0.4,
        // Increase output budget so replies are less likely to truncate.
        'maxOutputTokens': 1024,
      },
    };
    String? lastError;

    for (final model in _candidateModels()) {
      final endpoint = '$_apiBase/models/$model:generateContent?key=$geminiApiKey';
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        lastError = 'Gemini model "$model" failed: HTTP ${response.statusCode}';
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
}
