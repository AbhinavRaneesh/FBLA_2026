import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
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

  static Future<String> chatTextGenerationRepo(List<ChatMessageModel> previousMessage) async {
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

    // Try each model from our constants
    for (final model in availableModels) {
      try {
        log('Trying model: $model');
        
        final result = await _makeApiCall(model, messages);
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

  static Future<_ApiCallResult> _makeApiCall(String model, List<Map<String, dynamic>> messages) async {
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

    final endpointErrors = <String>[];

    for (final endpoint in apiEndpoints) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(request),
        ).timeout(Duration(seconds: 90));

        log('Response status for $model on $endpoint: ${response.statusCode}');
        log('Response body for $model on $endpoint: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final content = data['message']?['content'];
          if (content != null && content.toString().trim().isNotEmpty) {
            log('✅ Success with $model on $endpoint: ${content.toString().trim()}');
            return _ApiCallResult(content: content.toString().trim(), endpoint: endpoint);
          }

          endpointErrors.add('$endpoint: Model returned empty content');
          continue;
        }

        endpointErrors.add('$endpoint: HTTP ${response.statusCode}');
      } on TimeoutException {
        endpointErrors.add('$endpoint: Request timed out waiting for Ollama response');
      } on SocketException {
        endpointErrors.add('$endpoint: Cannot connect to Ollama server');
      } catch (e) {
        endpointErrors.add('$endpoint: $e');
      }
    }

    return _ApiCallResult(error: endpointErrors.join(' | '));
  }

  static Future<void> preloadModel() async {
    await _makeApiCall(defaultModel, const [
      {
        "role": "user",
        "content": "Hi"
      }
    ]);
  }

  static Future<String> testApiConnection() async {
    try {
      final testMessages = [
        {"role": "user", "content": "Hello"}
      ];

        final result = await _makeApiCall(defaultModel, testMessages);
        return result.content != null 
          ? "✅ API Connection Successful: ${result.content}"
          : "❌ API Connection Failed - Check Ollama server and selected model";
    } catch (e) {
      return "❌ Connection Error: $e";
    }
  }

  static Future<String> simpleTest() async {
    for (final model in availableModels) {
      final result = await _makeApiCall(model, [
        {"role": "user", "content": "Say hi"}
      ]);
      
      if (result.content != null) {
        return "✅ $model: ${result.content}";
      }
    }
    return "❌ All models failed";
  }

  static Future<String> validateOllamaConnection() async {
    final endpointErrors = <String>[];

    for (final endpoint in ollamaTagsEndpoints) {
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
      final result = await _makeApiCall(defaultModel, [
        {"role": "user", "content": "Hi"}
      ]);
      
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
    for (final model in availableModels) {
      try {
        final result = await _makeApiCall(model, [
          {"role": "user", "content": "Test"}
        ]);
        results.add('  • $model: ${result.content != null ? '✅ Working' : '❌ ${result.error ?? 'Failed'}'}');
      } catch (e) {
        results.add('  • $model: ❌ Error - $e');
      }
    }
    
    return results.join('\n');
  }
}
