

/**
 * A data model representing a chat message for OpenAI/OpenRouter API.
 * 
 * This class encapsulates a single message in a chat conversation using
 * the standard OpenAI format with role and content fields.
 * 
 * @param role The role of the message sender ("user", "assistant", or "system")
 * @param content The text content of the message
 */
class ChatMessageModel {
  /** The role of the message sender ("user", "assistant", or "system") */
  final String role;
  /** The text content of the message */
  final String content;

  /**
   * Creates a new ChatMessageModel instance.
   * 
   * @param role The role of the message sender
   * @param content The text content of the message
   */
  ChatMessageModel({
    required this.role,
    required this.content,
  });

  /**
   * Converts the ChatMessageModel to OpenAI API format.
   * 
   * @return A Map containing the JSON representation for OpenAI/OpenRouter API
   */
  Map<String, dynamic> toJson() {
    return {
      'role': role == "model" ? "assistant" : role, // Convert Gemini "model" to OpenAI "assistant"
      'content': content,
    };
  }

  /**
   * Creates a ChatMessageModel from OpenAI API JSON response.
   * 
   * @param json A Map containing the JSON representation from OpenAI/OpenRouter API
   * @return A new ChatMessageModel instance
   */
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }

  /**
   * Creates a ChatMessageModel from the old Gemini format for backward compatibility.
   * This helps when converting old Gemini-style messages.
   */
  factory ChatMessageModel.fromGeminiFormat(Map<String, dynamic> json) {
    final parts = json['parts'] as List?;
    final content = parts != null && parts.isNotEmpty 
        ? parts.map((part) => part['text'] ?? '').join(' ').trim()
        : '';
    
    return ChatMessageModel(
      role: json['role'] as String,
      content: content,
    );
  }

  /**
   * Convenience constructor for creating user messages
   */
  factory ChatMessageModel.user(String content) {
    return ChatMessageModel(role: "user", content: content);
  }

  /**
   * Convenience constructor for creating assistant messages
   */
  factory ChatMessageModel.assistant(String content) {
    return ChatMessageModel(role: "assistant", content: content);
  }

  /**
   * Convenience constructor for creating system messages
   */
  factory ChatMessageModel.system(String content) {
    return ChatMessageModel(role: "system", content: content);
  }
}
