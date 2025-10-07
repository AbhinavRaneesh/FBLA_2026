import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/chat_message_model.dart';
import '../repos/chat_repo.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  List<ChatMessageModel> messages = [];
  bool generating = false;

  ChatBloc() : super(ChatInitialState()) {
    on<ChatGenerateNewTextMessageEvent>(_generateNewTextMessageEvent);
    on<ChatClearHistoryEvent>(_clearHistoryEvent);
  }

  void _clearHistoryEvent(
      ChatClearHistoryEvent event, Emitter<ChatState> emit) {
    messages = [];
    emit(ChatSuccessState(messages: messages));
  }

  Future<void> _generateNewTextMessageEvent(
      ChatGenerateNewTextMessageEvent event, Emitter<ChatState> emit) async {
    if (generating) return;

    messages.add(ChatMessageModel.user(event.inputMessage));
    generating = true;
    emit(ChatGeneratingState(messages: messages));
    try {
      // Get AI response
      final generatedText = await ChatRepo.chatTextGenerationRepo(messages);

      if (generatedText.isEmpty) {
        throw Exception("Empty response from AI");
      }

      // Add AI response
      messages.add(ChatMessageModel.assistant(generatedText));

      generating = false;
      emit(ChatSuccessState(messages: messages));
    } catch (e) {
      generating = false;
      // Add error message to chat
      messages.add(ChatMessageModel.assistant("Sorry, I encountered an error: ${e.toString()}"));
      emit(ChatSuccessState(messages: messages));
    }
  }
}