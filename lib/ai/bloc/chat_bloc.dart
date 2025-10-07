import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/chat_message_model.dart';
import '../repos/chat_repo.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  
  ChatBloc() : super(ChatInitial()) {
    on<SendMessageEvent>(_onSendMessage);
    on<ClearChatEvent>(_onClearChat);
    on<LoadChatHistoryEvent>(_onLoadChatHistory);
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      // Get current messages
      List<ChatMessageModel> currentMessages = [];
      if (state is ChatLoaded) {
        currentMessages = (state as ChatLoaded).messages;
      }

      // Add user message using our new model format
      final userMessage = ChatMessageModel.user(event.message);
      final messagesWithUser = [...currentMessages, userMessage];

      // Show loading state
      emit(ChatLoaded(
        messages: messagesWithUser,
        isLoading: true,
      ));

      // Get AI response using our ChatRepo static method
      final aiResponse = await ChatRepo.chatTextGenerationRepo(messagesWithUser);

      // Add AI response
      final aiMessage = ChatMessageModel.assistant(aiResponse);

      emit(ChatLoaded(
        messages: [...messagesWithUser, aiMessage],
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
