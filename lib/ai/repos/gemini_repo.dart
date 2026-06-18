import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message_model.dart';
import '../utils/constants.dart';
import 'firebase_ai_repo.dart';

class GeminiRepo {
  static const String _openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';
  static const int _maxHistoryMessages = 20;
  static const String _systemPrompt =
      'You are a helpful AI assistant for the FBLA Member App and FBLA students. '
      'Help users navigate the app and answer FBLA questions. Keep answers practical and concise. '
      'For emphasis, wrap important words in **double asterisks** — the app renders them as bold text.';

  static List<String> _candidateModels() {
    final candidates = <String>[];

    void addModel(String model) {
      final trimmed = model.trim();
      if (trimmed.isNotEmpty && !candidates.contains(trimmed)) {
        candidates.add(trimmed);
      }
    }

    addModel(openRouterModel);
    addModel('meta-llama/llama-3.1-8b-instruct');
    addModel('google/gemini-2.5-flash');

    return candidates;
  }

  /// Production path: Firebase Cloud Function (OpenRouter key in secrets).
  /// Dev fallback: direct OpenRouter when `OPENROUTER_API_KEY` is passed via --dart-define.
  static Future<String> chatTextGenerationRepo(
    List<ChatMessageModel> previousMessages,
  ) async {
    try {
      final viaFirebase = await FirebaseAiRepo.tryChat(previousMessages);
      if (viaFirebase != null) {
        return viaFirebase;
      }
    } catch (e) {
      if (openRouterApiKey.trim().isEmpty) {
        return 'AI assistant error: $e';
      }
      if (kDebugMode) {
        print('Firebase AI failed, falling back to local OpenRouter key: $e');
      }
    }

    if (openRouterApiKey.trim().isEmpty) {
      return 'Sign in to use the AI assistant. Your chapter stores the OpenRouter key securely in Firebase.';
    }

    if (kIsWeb) {
      return 'Sign in to use the AI assistant on web, or configure the Firebase chat function.';
    }

    return _chatDirectOpenRouter(previousMessages);
  }

  static Future<String> _chatDirectOpenRouter(
    List<ChatMessageModel> previousMessages,
  ) async {
    final trimmed = previousMessages.length > _maxHistoryMessages
        ? previousMessages.sublist(
            previousMessages.length - _maxHistoryMessages,
          )
        : previousMessages;

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
    ];
    for (final message in trimmed) {
      final role = message.role == 'assistant' ? 'assistant' : 'user';
      messages.add({'role': role, 'content': message.content});
    }

    String? lastError;

    for (final model in _candidateModels()) {
      final response = await http
          .post(
            Uri.parse(_openRouterUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $openRouterApiKey',
              'HTTP-Referer': 'https://fbla-2026-kushal.web.app',
              'X-Title': 'FBLA Member App',
            },
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'temperature': 0.6,
              'max_tokens': 768,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        lastError = _parseOpenRouterFailure(model, response);
        continue;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['choices']?[0]?['message']?['content']?.toString().trim();
      if (text != null && text.isNotEmpty) {
        final finishReason = data['choices']?[0]?['finish_reason']?.toString();
        if (finishReason == 'length') {
          return '$text\n\n(Reply truncated by token limit. Ask "continue" for the rest.)';
        }
        return text;
      }

      lastError = 'OpenRouter model "$model" returned no text content.';
    }

    return lastError ?? 'OpenRouter request failed.';
  }

  static String _parseOpenRouterFailure(String model, http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final message = data['error']?['message']?.toString() ?? '';
      if (message.toLowerCase().contains('quota') ||
          response.statusCode == 429) {
        return 'The AI is temporarily busy (quota limit). Wait a minute and try again.';
      }
      if (message.isNotEmpty) {
        return 'OpenRouter model "$model" failed: $message';
      }
    } catch (_) {
      // ignore
    }
    return 'OpenRouter model "$model" failed: HTTP ${response.statusCode}';
  }
}
