import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../models/chat_message_model.dart';
import '../utils/constants.dart';

class ChatRepo {
  /**
   * Main method to generate AI responses using OpenRouter API
   */
  static Future<String> chatTextGenerationRepo(List<ChatMessageModel> previousMessage) async {
    // Convert messages to OpenAI format
    final messages = previousMessage.map((msg) => msg.toJson()).toList();

    // Add a system message for better context
    if (messages.isEmpty || messages.first['role'] != 'system') {
      messages.insert(0, {
        "role": "system",
        "content": "You are a helpful AI assistant for FBLA (Future Business Leaders of America) students. Provide clear, concise, and helpful responses."
      });
    }

    log('Attempting API call with ${messages.length} messages');

    // Try each model from our constants
    for (final model in availableModels) {
      try {
        log('Trying model: $model');
        
        final response = await _makeApiCall(model, messages);
        if (response != null) {
          log('Success with model: $model');
          return response;
        }
      } catch (e) {
        log('Model $model failed: $e');
        continue;
      }
    }

    return "I'm sorry, but I'm currently unable to process your request. Please try again later or check your internet connection.";
  }

  /**
   * Makes the actual API call to OpenRouter
   */
  static Future<String?> _makeApiCall(String model, List<Map<String, dynamic>> messages) async {
    try {
      final request = {
        "model": model,
        "messages": messages,
        "max_tokens": 300,
        "temperature": 0.7,
        "stream": false
      };

      log('Making request to $model...');
      log('Request body: ${jsonEncode(request)}');
      
      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'User-Agent': 'FBLA-App/1.0',
          'HTTP-Referer': 'https://fbla-app.com',
        },
        body: jsonEncode(request),
      ).timeout(Duration(seconds: 20));

      log('Response status for $model: ${response.statusCode}');
      log('Response body for $model: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content != null && content.toString().trim().isNotEmpty) {
          log('✅ Success with $model: ${content.toString().trim()}');
          return content.toString().trim();
        } else {
          log('❌ $model returned empty content');
        }
      } else {
        log('❌ $model API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      log('Request failed for $model: $e');
    }
    return null;
  }

  /**
   * Tests API connectivity with a simple request
   */
  static Future<String> testApiConnection() async {
    try {
      final testMessages = [
        {"role": "user", "content": "Hello"}
      ];

      final result = await _makeApiCall(defaultModel, testMessages);
      return result != null 
          ? "✅ API Connection Successful: $result"
          : "❌ API Connection Failed - Check API key";
    } catch (e) {
      return "❌ Connection Error: $e";
    }
  }

  /**
   * Quick test of individual models
   */
  static Future<String> simpleTest() async {
    for (final model in availableModels) {
      final result = await _makeApiCall(model, [
        {"role": "user", "content": "Say hi"}
      ]);
      
      if (result != null) {
        return "✅ $model: $result";
      }
    }
    return "❌ All models failed";
  }

  /**
   * Validates the API key by checking authentication
   */
  static Future<String> validateApiKey() async {
    try {
      final response = await http.get(
        Uri.parse("https://openrouter.ai/api/v1/auth/key"),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ).timeout(Duration(seconds: 10));

      log('API Key validation status: ${response.statusCode}');
      log('API Key validation response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          return '✅ Valid - ${data['data']['label'] ?? 'Unknown'}';
        }
        return '✅ Valid API Key';
      } else if (response.statusCode == 401) {
        return '❌ Invalid API Key';
      } else {
        return '⚠️ Status ${response.statusCode}';
      }
    } catch (e) {
      log('API Key validation error: $e');
      return '❌ Error: $e';
    }
  }

  /**
   * Comprehensive API debugging method
   */
  static Future<String> debugApiConnection() async {
    log('🔍 Starting comprehensive API debugging...');
    
    // Test 1: Check API key format
    if (!apiKey.startsWith('sk-or-v1-')) {
      return '❌ Invalid API key format. Should start with sk-or-v1-';
    }
    
    log('✅ API key format is correct');
    
    // Test 2: Try a simple request with the most reliable model
    try {
      log('🧪 Testing with $defaultModel...');
      final result = await _makeApiCall(defaultModel, [
        {"role": "user", "content": "Hi"}
      ]);
      
      if (result != null) {
        return '✅ API Working! Response: $result';
      } else {
        return '❌ API call succeeded but returned null content';
      }
    } catch (e) {
      return '❌ API test failed: $e';
    }
  }

  /**
   * Complete troubleshooting with multiple checks
   */
  static Future<String> troubleshootApi() async {
    final results = <String>[];
    
    // Check 1: API Key format
    results.add('🔑 API Key Format: ${apiKey.startsWith('sk-or-v1-') ? '✅ Valid' : '❌ Invalid'}');
    
    // Check 2: API Key validation
    final keyValidation = await validateApiKey();
    results.add('🔐 API Key Auth: $keyValidation');
    
    // Check 3: Test each model
    results.add('\n📋 Model Tests:');
    for (final model in availableModels) {
      try {
        final result = await _makeApiCall(model, [
          {"role": "user", "content": "Test"}
        ]);
        results.add('  • $model: ${result != null ? '✅ Working' : '❌ Failed'}');
      } catch (e) {
        results.add('  • $model: ❌ Error - $e');
      }
    }
    
    return results.join('\n');
  }
}
