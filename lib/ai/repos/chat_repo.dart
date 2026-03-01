import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message_model.dart';
import '../utils/constants.dart';

class _ApiCallResult {
  final String? content;
  final String? error;
  final String? endpoint;

  const _ApiCallResult({this.content, this.error, this.endpoint});
}

class ChatRepo {
  static const int _maxHistoryMessages = 8;
  static String? _activeBaseUrl;

  static String _normalizeBaseUrl(String url) {
    var normalized = url.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    normalized = normalized.replaceFirst(RegExp(r'/api/chat$'), '');
    normalized = normalized.replaceFirst(RegExp(r'/api/tags$'), '');
    return normalized;
  }

  static List<String> _buildCandidateBaseUrls() {
    final candidates = <String>{};

    void addCandidate(String value) {
      final normalized = _normalizeBaseUrl(value);
      if (normalized.isNotEmpty) {
        candidates.add(normalized);
      }
    }

    addCandidate(ollamaBaseUrl);

    if (!kIsWeb) {
      addCandidate('http://127.0.0.1:11434');
      addCandidate('http://localhost:11434');
      if (Platform.isAndroid) {
        addCandidate('http://10.0.2.2:11434');
      }
    }

    return candidates.toList(growable: false);
  }

  static Future<String?> _discoverWorkingBaseUrl() async {
    if (_activeBaseUrl != null) {
      return _activeBaseUrl;
    }

    final baseUrls = _buildCandidateBaseUrls();
    for (final baseUrl in baseUrls) {
      final tagsUrl = '$baseUrl/api/tags';
      try {
        final response = await http
            .get(Uri.parse(tagsUrl))
            .timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          _activeBaseUrl = baseUrl;
          log('✅ Discovered Ollama endpoint: $_activeBaseUrl');
          return _activeBaseUrl;
        }
      } catch (e) {
        log('Endpoint check failed for $tagsUrl: $e');
      }
    }

    return null;
  }

  static Future<List<String>> _resolveModelsToTry(String baseUrl) async {
    final available = <String>[];

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/tags'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final models = data['models'] as List<dynamic>? ?? [];

        for (final model in models) {
          if (model is Map<String, dynamic>) {
            final name = (model['name'] ?? '').toString();
            if (name.isNotEmpty) {
              available.add(name);
            }
          }
        }
      }
    } catch (e) {
      log('Failed to fetch installed models: $e');
    }

    if (available.isEmpty) {
      return availableModels;
    }

    final ordered = <String>[];
    for (final preferred in availableModels) {
      if (available.contains(preferred)) {
        ordered.add(preferred);
      }
    }
    for (final installed in available) {
      if (!ordered.contains(installed)) {
        ordered.add(installed);
      }
    }

    return ordered;
  }

  static Future<String> chatTextGenerationRepo(List<ChatMessageModel> previousMessage) async {
    if (kIsWeb) {
      return "AI chat is not configured for web with local Ollama (browser CORS/network restrictions). Run on Windows desktop or Android, or expose Ollama through a CORS-enabled backend URL and set OLLAMA_BASE_URL.";
    }

    final trimmedMessages = previousMessage.length > _maxHistoryMessages
        ? previousMessage.sublist(previousMessage.length - _maxHistoryMessages)
        : previousMessage;

    final messages = trimmedMessages.map((msg) => msg.toJson()).toList();
    final failures = <String>[];

    if (messages.isEmpty || messages.first['role'] != 'system') {
      messages.insert(0, {
        "role": "system",
        "content": "You are a helpful AI assistant for FBLA (Future Business Leaders of America) students. Keep answers practical and concise, but complete the response fully without cutting off important details."
      });
    }

    log('Attempting API call with ${messages.length} messages');

    final baseUrl = await _discoverWorkingBaseUrl();
    if (baseUrl == null) {
      final attempted = _buildCandidateBaseUrls().join(', ');
      return "I couldn't reach Ollama. Tried: $attempted. Start Ollama, then set OLLAMA_BASE_URL (Android emulator: http://10.0.2.2:11434, desktop: http://127.0.0.1:11434, real phone: your PC LAN IP or use adb reverse tcp:11434 tcp:11434).";
    }

    final modelsToTry = await _resolveModelsToTry(baseUrl);

    for (final model in modelsToTry) {
      try {
        log('Trying model: $model');
        
        final result = await _makeApiCall(
          model,
          messages,
          endpoint: '$baseUrl/api/chat',
        );
        if (result.content != null) {
          log('Success with model: $model');
          return result.content!;
        }
        failures.add('$model: ${result.error ?? 'Unknown error'}');
      } catch (e) {
        log('Model $model failed: $e');
        failures.add('$model: $e');
        continue;
      }
    }

    final reason = failures.isNotEmpty ? failures.first : 'Unknown issue';
    return "I couldn't reach Ollama right now. $reason. If you're on Android emulator use 10.0.2.2, and if you're on a real phone use your PC LAN IP.";
  }

  static Future<_ApiCallResult> _makeApiCall(
    String model,
    List<Map<String, dynamic>> messages, {
    required String endpoint,
  }) async {
    final request = {
      "model": model,
      "messages": messages,
      "stream": false,
      "keep_alive": "30m",
      "options": {
        "num_predict": 320,
        "num_ctx": 2048,
        "temperature": 0.4,
      }
    };

    log('Making request to $model...');
    log('Request body: ${jsonEncode(request)}');

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request),
      ).timeout(const Duration(seconds: 45));

      log('Response status for $model on $endpoint: ${response.statusCode}');
      log('Response body for $model on $endpoint: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['message']?['content'];
        if (content != null && content.toString().trim().isNotEmpty) {
          log('✅ Success with $model on $endpoint: ${content.toString().trim()}');
          return _ApiCallResult(content: content.toString().trim(), endpoint: endpoint);
        }

        return _ApiCallResult(error: '$endpoint: Model returned empty content');
      }

      return _ApiCallResult(error: '$endpoint: HTTP ${response.statusCode}');
    } on TimeoutException {
      return _ApiCallResult(error: '$endpoint: Request timed out waiting for Ollama response');
    } on SocketException {
      _activeBaseUrl = null;
      return _ApiCallResult(error: '$endpoint: Cannot connect to Ollama server');
    } catch (e) {
      return _ApiCallResult(error: '$endpoint: $e');
    }
  }

  static Future<void> preloadModel() async {
    final baseUrl = await _discoverWorkingBaseUrl();
    if (baseUrl == null) return;

    await _makeApiCall(defaultModel, const [
      {
        "role": "user",
        "content": "Hi"
      }
    ], endpoint: '$baseUrl/api/chat');
  }

  static Future<String> testApiConnection() async {
    try {
      final testMessages = [
        {"role": "user", "content": "Hello"}
      ];

        final baseUrl = await _discoverWorkingBaseUrl();
        if (baseUrl == null) {
          return "❌ API Connection Failed - could not find a working Ollama endpoint";
        }

        final result = await _makeApiCall(defaultModel, testMessages, endpoint: '$baseUrl/api/chat');
        return result.content != null 
          ? "✅ API Connection Successful: ${result.content}"
          : "❌ API Connection Failed - ${result.error ?? 'Check Ollama server and selected model'}";
    } catch (e) {
      return "❌ Connection Error: $e";
    }
  }

  static Future<String> simpleTest() async {
    final baseUrl = await _discoverWorkingBaseUrl();
    if (baseUrl == null) {
      return "❌ No working Ollama endpoint found";
    }

    for (final model in availableModels) {
      final result = await _makeApiCall(model, [
        {"role": "user", "content": "Say hi"}
      ], endpoint: '$baseUrl/api/chat');
      
      if (result.content != null) {
        return "✅ $model: ${result.content}";
      }
    }
    return "❌ All models failed";
  }

  static Future<String> validateOllamaConnection() async {
    final endpointErrors = <String>[];
    for (final baseUrl in _buildCandidateBaseUrls()) {
      final endpoint = '$baseUrl/api/tags';
      try {
        final response = await http.get(
          Uri.parse(endpoint),
        ).timeout(Duration(seconds: 10));

        log('Ollama connection validation status on $endpoint: ${response.statusCode}');
        log('Ollama connection validation response on $endpoint: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final models = data['models'] as List<dynamic>?;
          if (models != null) {
            return '✅ Ollama connected via $endpoint - ${models.length} models found';
          }
          return '✅ Ollama connected via $endpoint';
        }
        endpointErrors.add('$endpoint: Status ${response.statusCode}');
      } catch (e) {
        log('Ollama connection validation error on $endpoint: $e');
        endpointErrors.add('$endpoint: $e');
      }
    }

    return '❌ Error: ${endpointErrors.join(' | ')}';
  }

  static Future<String> debugApiConnection() async {
    log('🔍 Starting Ollama API debugging...');

    try {
      log('🧪 Testing with $defaultModel...');
      final baseUrl = await _discoverWorkingBaseUrl();
      if (baseUrl == null) {
        return '❌ No reachable Ollama endpoint found';
      }

      final result = await _makeApiCall(defaultModel, [
        {"role": "user", "content": "Hi"}
      ], endpoint: '$baseUrl/api/chat');
      
      if (result.content != null) {
        return '✅ Ollama API Working! Response: ${result.content}';
      } else {
        return '❌ API call failed: ${result.error ?? 'Unknown error'}';
      }
    } catch (e) {
      return '❌ API test failed: $e';
    }
  }

  static Future<String> troubleshootApi() async {
    final results = <String>[];

    final connectionValidation = await validateOllamaConnection();
    results.add('🔌 Ollama Connection: $connectionValidation');

    results.add('\n📋 Model Tests:');
    final baseUrl = await _discoverWorkingBaseUrl();
    if (baseUrl == null) {
      results.add('  • ❌ No reachable endpoint');
      return results.join('\n');
    }

    for (final model in availableModels) {
      try {
        final result = await _makeApiCall(model, [
          {"role": "user", "content": "Test"}
        ], endpoint: '$baseUrl/api/chat');
        results.add('  • $model: ${result.content != null ? '✅ Working' : '❌ ${result.error ?? 'Failed'}'}');
      } catch (e) {
        results.add('  • $model: ❌ Error - $e');
      }
    }
    
    return results.join('\n');
  }
}
