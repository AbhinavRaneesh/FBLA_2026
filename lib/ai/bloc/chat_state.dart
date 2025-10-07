import '../models/chat_message_model.dart';

abstract class ChatState {}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<ChatMessageModel> messages;
  final bool isLoading;

  ChatLoaded({
    required this.messages,
    this.isLoading = false,
  });

  ChatLoaded copyWith({
    List<ChatMessageModel>? messages,
    bool? isLoading,
  }) {
    return ChatLoaded(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChatError extends ChatState {
  final String message;

  ChatError({required this.message});
}
