/**
 * ChatMessageModel for OpenAI/OpenRouter API compatibility
 */
class ChatMessageModel {
  final String role;
  final String content;

  ChatMessageModel({
    required this.role,
    required this.content,
  });

  /**
   * Convert to OpenAI API format
   */
  Map<String, dynamic> toJson() {
    return {
      'role': role == "model" ? "assistant" : role,
      'content': content,
    };
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }

  /**
   * Convenience constructors
   */
  factory ChatMessageModel.user(String content) {
    return ChatMessageModel(role: "user", content: content);
  }

  factory ChatMessageModel.assistant(String content) {
    return ChatMessageModel(role: "assistant", content: content);
  }

  factory ChatMessageModel.system(String content) {
    return ChatMessageModel(role: "system", content: content);
  }

  /**
   * Copy with new content
   */
  ChatMessageModel copyWith({
    String? role,
    String? content,
  }) {
    return ChatMessageModel(
      role: role ?? this.role,
      content: content ?? this.content,
    );
  }
}
