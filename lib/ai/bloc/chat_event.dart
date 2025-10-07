class ChatEvent {}

class SendMessageEvent extends ChatEvent {
  final String message;
  final String? threadId;

  SendMessageEvent({
    required this.message,
    this.threadId,
  });
}

class ClearChatEvent extends ChatEvent {}

class LoadChatHistoryEvent extends ChatEvent {
  final String threadId;

  LoadChatHistoryEvent({required this.threadId});
}
