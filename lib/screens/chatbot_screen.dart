import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../ai/bloc/chat_bloc.dart';
import '../ai/bloc/chat_event.dart';
import '../ai/bloc/chat_state.dart';
import '../ai/models/chat_message_model.dart';

// FBLA Colors
const fblaNavy = Color(0xFF00274D);
const fblaGold = Color(0xFFFDB913);
const chatBlueGlow = Color(0xFF1D4E89);
const chatSurfaceDark = Color(0xFF0D1117);
const chatSurfaceDarker = Color(0xFF090C12);

class ChatbotScreen extends StatefulWidget {
  @override
  _ChatbotScreenState createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentThreadId = 'main_thread';

  @override
  void initState() {
    super.initState();
    // Load chat history when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<ChatBloc>()
            .add(LoadChatHistoryEvent(threadId: _currentThreadId));
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(BuildContext context) {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      context.read<ChatBloc>().add(
            SendMessageEvent(
              message: message,
              threadId: _currentThreadId,
            ),
          );
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat(BuildContext context) {
    context.read<ChatBloc>().add(ClearChatEvent());
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final bottomSafeInset = mediaQuery.viewPadding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          'FBLA AI Assistant',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.black,
        shape: Border(
          bottom: BorderSide(
            color: chatBlueGlow.withOpacity(0.45),
            width: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _clearChat(context),
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border(
              left: BorderSide(color: chatBlueGlow.withOpacity(0.22), width: 1),
              right: BorderSide(color: chatBlueGlow.withOpacity(0.22), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: chatBlueGlow.withOpacity(0.18),
                blurRadius: 18,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: BlocBuilder<ChatBloc, ChatState>(
                  builder: (context, state) {
                    if (state is ChatInitial) {
                      return _buildWelcomeMessage();
                    }

                    if (state is ChatLoading) {
                      return _buildLoadingState();
                    }

                    if (state is ChatLoaded) {
                      return _buildChatMessages(state.messages, state.isLoading);
                    }

                    if (state is ChatError) {
                      return _buildErrorState(state.message);
                    }

                    return _buildWelcomeMessage();
                  },
                ),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: _buildMessageInput(bottomSafeInset),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: fblaGold,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: fblaGold.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              Icons.smart_toy,
              color: fblaNavy,
              size: 40,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Welcome to FBLA AI Assistant!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'I can help you with FBLA information,\ncompetitions, events, and more!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 32),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: chatSurfaceDark,
              border: Border.all(
                color: chatBlueGlow.withOpacity(0.45),
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: chatBlueGlow.withOpacity(0.15),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Text(
              'Try asking: "What is FBLA?" or "Tell me about competitions"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(fblaGold),
          ),
          SizedBox(height: 16),
          Text(
            'AI is thinking...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.read<ChatBloc>().add(ClearChatEvent());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: fblaNavy,
              foregroundColor: Colors.white,
            ),
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessages(List<ChatMessageModel> messages, bool isLoading) {
    if (messages.isEmpty) {
      return _buildWelcomeMessage();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < messages.length) {
          return _buildMessageBubble(messages[index]);
        } else {
          return _buildTypingIndicator();
        }
      },
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message) {
    final isUser = message.role == "user";
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: fblaGold,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy,
                color: fblaNavy,
                size: 18,
              ),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? fblaNavy : chatSurfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUser
                      ? chatBlueGlow.withOpacity(0.85)
                      : chatBlueGlow.withOpacity(0.55),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: chatBlueGlow.withOpacity(0.22),
                    blurRadius: 9,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Just now", // Remove timestamp for now
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: fblaGold,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: fblaNavy,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: fblaGold,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy,
              color: fblaNavy,
              size: 18,
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: chatSurfaceDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: chatBlueGlow.withOpacity(0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: chatBlueGlow.withOpacity(0.2),
                  blurRadius: 9,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Thinking',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(fblaGold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(double bottomSafeInset) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomSafeInset),
      decoration: BoxDecoration(
        color: chatSurfaceDarker,
        border: Border(
          top: BorderSide(color: chatBlueGlow.withOpacity(0.55), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: chatBlueGlow.withOpacity(0.25),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: chatSurfaceDark,
                border: Border.all(
                  color: chatBlueGlow.withOpacity(0.7),
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: chatBlueGlow.withOpacity(0.16),
                    blurRadius: 9,
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                cursorColor: fblaGold,
                decoration: InputDecoration(
                  hintText: 'Ask me anything about FBLA...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(context),
              ),
            ),
          ),
          SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: fblaNavy,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: () => _sendMessage(context),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
