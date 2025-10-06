import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:fbla_member_app/ai/models/chat_message_model.dart';
import 'package:fbla_member_app/ai/utils/constants.dart';

/**
 * Repository class for AI chat functionality using OpenRouter API.
 * 
 * Provides robust error handling and multiple model fallbacks for
 * reliable AI text generation.
 */
class ChatRepo {
  /**
   * Simple and reliable AI text generation method
   */
  static Future<String> chatTextGenerationRepo(List<ChatMessageModel> previousMessage) async {
    // Convert messages to OpenAI format - now much simpler since we already use the right format
    final messages = previousMessage.map((msg) => msg.toJson()).toList();

    // Add a concise system message for faster processing
    if (messages.isEmpty || messages.first['role'] != 'system') {
      messages.insert(0, {
        "role": "system",
        "content": "Be helpful and concise. Answer briefly for FBLA students."
      });
    }

    log('Attempting API call with ${messages.length} messages');

    // Try each model until one works
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

    // If all API calls fail, try the fallback
    log('All API models failed, using fallback response');
    final userMessage = previousMessage.isNotEmpty 
        ? previousMessage.last.content
        : 'hello';
    
    final fallbackResponse = await getMockResponse(userMessage);
    return "🤖 Offline Mode: $fallbackResponse\n\n💡 Note: I'm currently using basic responses. Please check your API key or internet connection for full AI features.";
  }

  /**
   * Makes the actual API call to OpenRouter
   */
  static Future<String?> _makeApiCall(String model, List<Map<String, dynamic>> messages) async {
    try {
      final request = {
        "model": model,
        "messages": messages,
        "max_tokens": 300, // Reduced for faster responses
        "temperature": 0.5, // Lower temperature for faster generation
        "stream": false,
        "top_p": 0.9, // Optimize for speed
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
   * Comprehensive API key validation and troubleshooting
   */
  static Future<String> validateApiKey() async {
    try {
      log('Testing API key: ${apiKey.substring(0, 20)}...');
      
      // First, try a simple models list request
      final modelsResponse = await http.get(
        Uri.parse("https://openrouter.ai/api/v1/models"),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ).timeout(Duration(seconds: 10));

      log('Models API status: ${modelsResponse.statusCode}');
      
      if (modelsResponse.statusCode == 401) {
        return '❌ Invalid API Key - Check your OpenRouter account';
      }
      
      if (modelsResponse.statusCode == 200) {
        // Now try the auth endpoint
        try {
          final authResponse = await http.get(
            Uri.parse("https://openrouter.ai/api/v1/auth/key"),
            headers: {
              'Authorization': 'Bearer $apiKey',
            },
          ).timeout(Duration(seconds: 10));

          if (authResponse.statusCode == 200) {
            final data = jsonDecode(authResponse.body);
            final credits = data['data']?['usage']?['credits'] ?? 'Unknown';
            return '✅ API Key Valid - Credits: $credits';
          }
        } catch (e) {
          log('Auth endpoint failed: $e');
        }
        
        return '✅ API Key Valid - Ready to use';
      }
      
      return '⚠️ API Status ${modelsResponse.statusCode} - ${modelsResponse.body}';
    } catch (e) {
      log('API Key validation error: $e');
      return '❌ Connection Error: $e';
    }
  }

  /**
   * Emergency fallback using a mock response for testing
   */
  static Future<String> getMockResponse(String userMessage) async {
    // Simple rule-based responses for testing when API fails
    final message = userMessage.toLowerCase();
    
    if (message.contains('hello') || message.contains('hi')) {
      return "Hello! I'm the FBLA AI Assistant. How can I help you today?";
    } else if (message.contains('fbla')) {
      return "FBLA (Future Business Leaders of America) is a premier career and technical student organization that helps students develop leadership skills and explore business careers.";
    } else if (message.contains('help')) {
      return "I'm here to help! You can ask me questions about FBLA, business concepts, leadership, or general topics. What would you like to know?";
    } else {
      return "I understand you're asking about '$userMessage'. While I'm having some technical difficulties connecting to my main AI service, I'm still here to help with basic questions about FBLA and business topics. Please try again or ask a more specific question.";
    }
  }

  /**
   * Comprehensive troubleshooting for API issues
   */
  static Future<String> troubleshootApi() async {
    final results = <String>[];
    
    // Test 1: Internet connectivity
    try {
      final response = await http.get(Uri.parse('https://www.google.com')).timeout(Duration(seconds: 5));
      results.add(response.statusCode == 200 ? '✅ Internet: Connected' : '❌ Internet: Issue');
    } catch (e) {
      results.add('❌ Internet: No connection');
    }
    
    // Test 2: OpenRouter endpoint
    try {
      final response = await http.get(Uri.parse('https://openrouter.ai')).timeout(Duration(seconds: 5));
      results.add(response.statusCode == 200 ? '✅ OpenRouter: Accessible' : '❌ OpenRouter: Issue');
    } catch (e) {
      results.add('❌ OpenRouter: Not accessible');
    }
    
    // Test 3: API Key format
    if (apiKey.startsWith('sk-or-v1-') && apiKey.length > 20) {
      results.add('✅ API Key: Format looks correct');
    } else {
      results.add('❌ API Key: Format seems wrong');
    }
    
    // Test 4: Models API
    try {
      final response = await http.get(
        Uri.parse('https://openrouter.ai/api/v1/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        results.add('✅ Models API: Working');
      } else if (response.statusCode == 401) {
        results.add('❌ API Key: Invalid/Unauthorized');
      } else {
        results.add('❌ Models API: Error ${response.statusCode}');
      }
    } catch (e) {
      results.add('❌ Models API: Failed - $e');
    }
    
    return results.join('\n');
  }

  /**
   * Detailed API debugging method
   */
  static Future<String> debugApiConnection() async {
    log('🔍 Starting comprehensive API debugging...');
    
    // Test 1: Check API key format
    if (!apiKey.startsWith('sk-or-v1-')) {
      return '❌ Invalid API key format. Should start with sk-or-v1-';
    }
    
    log('✅ API key format is correct');
    
    // Test 2: Try a simple request with the most reliable model
    final testModel = "meta-llama/llama-3.2-3b-instruct:free";
    final testMessages = [
      {"role": "user", "content": "Hi"}
    ];
    
    try {
      log('🧪 Testing with $testModel...');
      final result = await _makeApiCall(testModel, testMessages);
      
      if (result != null) {
        return '✅ API Working! Response: $result';
      } else {
        return '❌ API call succeeded but returned null content';
      }
    } catch (e) {
      return '❌ API test failed: $e';
    }
  }
}
