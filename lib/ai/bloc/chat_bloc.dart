import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/chat_history_store.dart';
import '../models/chat_message_model.dart';
import '../repos/gemini_repo.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  // The conversation currently in view. Persistence is keyed on this so the
  // AI Coach can restore the right history when the screen reopens.
  String _threadId = 'main_thread';

  ChatBloc() : super(ChatInitial()) {
    // Legacy Ollama warm-up kept below for reference.
    // Future(() => ChatRepo.preloadModel());

    on<SendMessageEvent>(_onSendMessage);
    on<ClearChatEvent>(_onClearChat);
    on<LoadChatHistoryEvent>(_onLoadChatHistory);
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (event.threadId != null && event.threadId!.isNotEmpty) {
      _threadId = event.threadId!;
    }
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

      // Get AI response from Gemini. The old Ollama path is kept in
      // chat_repo.dart as commented legacy code.
      final aiResponse = await GeminiRepo.chatTextGenerationRepo(messagesWithUser);

      // Add AI response
      final aiMessage = ChatMessageModel.assistant(aiResponse);
      final fullConversation = [...messagesWithUser, aiMessage];

      emit(ChatLoaded(
        messages: fullConversation,
        isLoading: false,
      ));

      // Persist so the conversation survives screen close / app restart.
      await ChatHistoryStore.save(_threadId, fullConversation);
    } catch (e) {
      emit(ChatError(message: 'Failed to send message: $e'));
    }
  }

  Future<void> _onClearChat(
    ClearChatEvent event,
    Emitter<ChatState> emit,
  ) async {
    await ChatHistoryStore.clear(_threadId);
    emit(ChatInitial());
  }

  Future<void> _onLoadChatHistory(
    LoadChatHistoryEvent event,
    Emitter<ChatState> emit,
  ) async {
    _threadId = event.threadId;
    try {
      emit(ChatLoading());
      final saved = await ChatHistoryStore.load(_threadId);
      if (saved.isEmpty) {
        // No prior conversation — show the welcome state.
        emit(ChatInitial());
      } else {
        emit(ChatLoaded(messages: saved));
      }
    } catch (e) {
      emit(ChatError(message: 'Failed to load chat history: $e'));
    }
  }
}
