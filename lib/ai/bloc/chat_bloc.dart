import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/chat_history_store.dart';
import '../models/chat_message_model.dart';
import '../repos/gemini_repo.dart';
import '../utils/assistant_fallbacks.dart';
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

  Future<void> _emitAssistantReply({
    required Emitter<ChatState> emit,
    required List<ChatMessageModel> messagesWithUser,
    required String replyText,
  }) async {
    final aiMessage = ChatMessageModel.assistant(replyText);
    final fullConversation = [...messagesWithUser, aiMessage];
    emit(ChatLoaded(messages: fullConversation, isLoading: false));
    await ChatHistoryStore.save(_threadId, fullConversation);
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (event.threadId != null && event.threadId!.isNotEmpty) {
      _threadId = event.threadId!;
    }
    final useAssistantFallbacks =
        AssistantFallbacks.isAppAssistantThread(_threadId);

    List<ChatMessageModel> currentMessages = [];
    if (state is ChatLoaded) {
      currentMessages = (state as ChatLoaded).messages;
    }

    final userMessage = ChatMessageModel.user(event.message);
    final messagesWithUser = [...currentMessages, userMessage];

    emit(ChatLoaded(
      messages: messagesWithUser,
      isLoading: true,
    ));

    try {
      var aiResponse =
          await GeminiRepo.chatTextGenerationRepo(messagesWithUser);

      if (useAssistantFallbacks &&
          AssistantFallbacks.looksLikeError(aiResponse)) {
        aiResponse = AssistantFallbacks.resolve(event.message);
      }

      await _emitAssistantReply(
        emit: emit,
        messagesWithUser: messagesWithUser,
        replyText: aiResponse,
      );
    } catch (_) {
      if (useAssistantFallbacks) {
        await _emitAssistantReply(
          emit: emit,
          messagesWithUser: messagesWithUser,
          replyText: AssistantFallbacks.resolve(event.message),
        );
        return;
      }
      emit(ChatError(message: 'Failed to send message. Please try again.'));
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
        emit(ChatInitial());
      } else {
        emit(ChatLoaded(messages: saved));
      }
    } catch (_) {
      if (AssistantFallbacks.isAppAssistantThread(_threadId)) {
        emit(ChatInitial());
      } else {
        emit(ChatError(message: 'Failed to load chat history. Please try again.'));
      }
    }
  }
}
