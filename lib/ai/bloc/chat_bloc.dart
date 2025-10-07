import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message_model.dart';
import '../repos/chat_repo.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _chatRepository;
  final Uuid _uuid = Uuid();

  ChatBloc({required ChatRepository chatRepository})
      : _chatRepository = chatRepository,
        super(ChatInitial()) {
    on<SendMessageEvent>(_onSendMessage);
    on<ClearChatEvent>(_onClearChat);
    on<LoadChatHistoryEvent>(_onLoadChatHistory);
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      // Add user message
      final userMessage = ChatMessageModel(
        id: _uuid.v4(),
        text: event.message,
        isUser: true,
        timestamp: DateTime.now(),
        threadId: event.threadId,
      );

      List<ChatMessageModel> currentMessages = [];
      if (state is ChatLoaded) {
        currentMessages = (state as ChatLoaded).messages;
      }

      emit(ChatLoaded(
        messages: [...currentMessages, userMessage],
        isLoading: true,
      ));

      // Get AI response
      final aiResponse = await _chatRepository.sendMessage(
        event.message,
        threadId: event.threadId,
      );

      // Add AI response
      final aiMessage = ChatMessageModel(
        id: _uuid.v4(),
        text: aiResponse,
        isUser: false,
        timestamp: DateTime.now(),
        threadId: event.threadId,
      );

      emit(ChatLoaded(
        messages: [...currentMessages, userMessage, aiMessage],
        isLoading: false,
      ));
    } catch (e) {
      emit(ChatError(message: 'Failed to send message: $e'));
    }
  }

  Future<void> _onClearChat(
    ClearChatEvent event,
    Emitter<ChatState> emit,
  ) async {
    emit(ChatInitial());
  }

  Future<void> _onLoadChatHistory(
    LoadChatHistoryEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      emit(ChatLoading());
      // In a real implementation, you would load chat history from storage
      // For now, we'll just emit an empty loaded state
      emit(ChatLoaded(messages: []));
    } catch (e) {
      emit(ChatError(message: 'Failed to load chat history: $e'));
    }
  }
}
