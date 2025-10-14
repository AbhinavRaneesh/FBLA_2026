import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/chat_message_model.dart';
import '../repos/chat_repo.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  List<ChatMessageModel> messages = [];
  bool generating = false;

  ChatBloc() : super(ChatInitial()) {
    on<SendMessageEvent>(_sendMessageEvent);
    on<ClearChatEvent>(_clearChatEvent);
  }

  void _clearChatEvent(
      ClearChatEvent event, Emitter<ChatState> emit) {
    messages = [];
    emit(ChatLoaded(messages: messages));
  }

  Future<void> _sendMessageEvent(
      SendMessageEvent event, Emitter<ChatState> emit) async {
    if (generating) return;

    messages.add(ChatMessageModel.user(event.message));
    generating = true;
    emit(ChatLoaded(messages: messages, isLoading: true));
    try {
      // Get AI response
      final generatedText = await ChatRepo.chatTextGenerationRepo(messages);

      if (generatedText.isEmpty) {
        throw Exception("Empty response from AI");
      }

      // Add AI response
      messages.add(ChatMessageModel.assistant(generatedText));

      generating = false;
      emit(ChatLoaded(messages: messages, isLoading: false));
    } catch (e) {
      generating = false;
      // Add error message to chat
      messages.add(ChatMessageModel.assistant("Sorry, I encountered an error: ${e.toString()}"));
      emit(ChatLoaded(messages: messages, isLoading: false));
    }
  }
}