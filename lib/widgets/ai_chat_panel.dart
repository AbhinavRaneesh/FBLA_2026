import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ai/bloc/chat_bloc.dart';
import '../ai/bloc/chat_event.dart';
import '../ai/bloc/chat_state.dart';
import '../ai/models/chat_message_model.dart';

const fblaNavy = Color(0xFF00274D);
const fblaGold = Color(0xFFFDB913);
const chatBlueGlow = Color(0xFF1D4E89);
const chatSurfaceDark = Color(0xFF0D1117);
const chatSurfaceDarker = Color(0xFF090C12);

/// Reusable AI chat body — full screen or embedded in the overlay panel.
class AiChatPanel extends StatefulWidget {
  final String threadId;
  final bool compact;
  final VoidCallback? onClose;

  const AiChatPanel({
    super.key,
    this.threadId = 'app_assistant',
    this.compact = false,
    this.onClose,
  });

  @override
  State<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends State<AiChatPanel> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _historyLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  void _loadHistory() {
    if (_historyLoaded || !mounted) return;
    _historyLoaded = true;
    context.read<ChatBloc>().add(LoadChatHistoryEvent(threadId: widget.threadId));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    context.read<ChatBloc>().add(
          SendMessageEvent(message: message, threadId: widget.threadId),
        );
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    context.read<ChatBloc>().add(ClearChatEvent());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: BlocConsumer<ChatBloc, ChatState>(
            listener: (context, state) {
              if (state is ChatLoaded) _scrollToBottom();
            },
            builder: (context, state) {
              if (state is ChatInitial) return _buildWelcome();
              if (state is ChatLoading) return _buildLoading();
              if (state is ChatLoaded) {
                return _buildMessages(state.messages, state.isLoading);
              }
              if (state is ChatError) return _buildError(state.message);
              return _buildWelcome();
            },
          ),
        ),
        _buildInput(bottomInset),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: chatSurfaceDarker,
        border: Border(
          bottom: BorderSide(color: chatBlueGlow.withValues(alpha: 0.45)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: fblaGold,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: fblaGold.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: fblaNavy, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FBLA AI Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Ask anything about the app',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _clearChat,
            icon: Icon(Icons.refresh_rounded,
                color: Colors.white.withValues(alpha: 0.75), size: 20),
          ),
          if (widget.onClose != null)
            IconButton(
              tooltip: 'Close',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(widget.compact ? 16 : 20),
      child: Column(
        children: [
          SizedBox(height: widget.compact ? 8 : 24),
          Container(
            width: widget.compact ? 56 : 72,
            height: widget.compact ? 56 : 72,
            decoration: BoxDecoration(
              color: fblaGold,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: fblaGold.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.smart_toy_rounded,
                color: fblaNavy, size: widget.compact ? 28 : 36),
          ),
          SizedBox(height: widget.compact ? 12 : 20),
          Text(
            widget.compact ? 'How can I help?' : 'Welcome to FBLA AI!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: widget.compact ? 18 : 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask about events, resources, Social, competitions, or how to use the app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: widget.compact ? 13 : 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _suggestionChip('How do I upload a video?'),
              _suggestionChip('What events are coming up?'),
              _suggestionChip('Where is the resource library?'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: chatSurfaceDark,
      labelStyle: const TextStyle(color: Colors.white),
      side: BorderSide(color: chatBlueGlow.withValues(alpha: 0.45)),
      onPressed: () {
        _messageController.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(fblaGold),
          ),
          SizedBox(height: 12),
          Text('Loading chat…', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 40, color: Colors.red.shade400),
            const SizedBox(height: 10),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 14),
            TextButton(onPressed: _clearChat, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages(List<ChatMessageModel> messages, bool isLoading) {
    if (messages.isEmpty) return _buildWelcome();

    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < messages.length) {
          return _messageBubble(messages[index]);
        }
        return _typingIndicator();
      },
    );
  }

  Widget _messageBubble(ChatMessageModel message) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: fblaGold,
              child: const Icon(Icons.smart_toy_rounded,
                  color: fblaNavy, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? fblaNavy : chatSurfaceDark,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: chatBlueGlow.withValues(alpha: isUser ? 0.35 : 0.5),
                ),
              ),
              child: Text(
                message.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: fblaGold,
              child: const Icon(Icons.person_rounded, color: fblaNavy, size: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: fblaGold,
            child:
                const Icon(Icons.smart_toy_rounded, color: fblaNavy, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: chatSurfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: chatBlueGlow.withValues(alpha: 0.5)),
            ),
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(fblaGold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(double bottomSafeInset) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + (keyboard > 0 ? 0 : bottomSafeInset)),
      decoration: BoxDecoration(
        color: chatSurfaceDarker,
        border: Border(
          top: BorderSide(color: chatBlueGlow.withValues(alpha: 0.45)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: fblaGold,
              decoration: InputDecoration(
                hintText: 'Ask about the app…',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                filled: true,
                fillColor: chatSurfaceDark,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide:
                      BorderSide(color: chatBlueGlow.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide:
                      BorderSide(color: chatBlueGlow.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: fblaGold, width: 1.4),
                ),
              ),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: fblaGold,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Send',
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_rounded, color: fblaNavy, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
