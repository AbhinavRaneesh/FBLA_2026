import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../ai/bloc/chat_bloc.dart';
import '../ai/models/chat_message_model.dart';
import '../ai/repos/chat_repo.dart';

// FBLA Colors
const fblaNavy = Color(0xFF00274D);
const fblaGold = Color(0xFFFDB913);

class ChatbotScreen extends StatefulWidget {
  @override
  _ChatbotScreenState createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _sendMessage(ChatBloc chatBloc) {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      chatBloc.add(ChatGenerationNewTextMessageEvent(inputMessage: message));
      _messageController.clear();
      _scrollToBottom();
    }
  }

  List<ChatMessageModel> _getMessages(ChatState state) {
    if (state is ChatGeneratingState) {
      return state.messages;
    } else if (state is ChatSuccessState) {
      return state.messages;
    }
    return [];
  }

  bool _isLoading(ChatState state) {
    return state is ChatGeneratingState;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatBloc(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'FBLA AI Assistant',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: fblaNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.science),
              onPressed: () async {
                final result = await ChatRepo.debugApiConnection();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('🔍 API Debug Results'),
                    content: SelectableText(result),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Debug API Connection',
            ),
            IconButton(
              icon: Icon(Icons.healing),
              onPressed: () async {
                final result = await ChatRepo.troubleshootApi();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('🔧 API Troubleshooting'),
                    content: SingleChildScrollView(
                      child: Text(result, style: TextStyle(fontFamily: 'monospace')),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Troubleshoot API',
            ),
            IconButton(
              icon: Icon(Icons.key),
              onPressed: () async {
                final result = await ChatRepo.validateApiKey();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$result'),
                    duration: Duration(seconds: 5),
                  ),
                );
              },
              tooltip: 'Validate API Key',
            ),
            IconButton(
              icon: Icon(Icons.clear_all),
              onPressed: () {
                final chatBloc = BlocProvider.of<ChatBloc>(context);
                chatBloc.add(ChatClearHistoryEvent());
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Chat messages area
            Expanded(
              child: BlocConsumer<ChatBloc, ChatState>(
                listener: (context, state) {
                  if (state is ChatErrorState) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  _scrollToBottom();
                },
                builder: (context, state) {
                  final messages = _getMessages(state);
                  final isLoading = _isLoading(state);
                  
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          fblaNavy.withOpacity(0.05),
                          Colors.white,
                        ],
                      ),
                    ),
                    child: messages.isEmpty && !isLoading
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.all(16),
                            itemCount: messages.length + (isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Show loading indicator
                              if (index == messages.length && isLoading) {
                                return _buildLoadingMessage();
                              }
                              
                              final message = messages[index];
                              return _buildMessageBubble(message);
                            },
                          ),
                  );
                },
              ),
            ),
            // Input area
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  final chatBloc = BlocProvider.of<ChatBloc>(context);
                  final isLoading = _isLoading(state);
                  
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: !isLoading,
                          decoration: InputDecoration(
                            hintText: 'Ask me anything about FBLA...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: fblaNavy.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: fblaNavy, width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(chatBloc),
                          maxLines: null,
                        ),
                      ),
                      SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: isLoading ? Colors.grey : fblaNavy,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: isLoading ? null : () => _sendMessage(chatBloc),
                          icon: Icon(
                            isLoading ? Icons.hourglass_empty : Icons.send,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 80,
            color: fblaNavy.withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Text(
            'FBLA AI Assistant',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: fblaNavy,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ask me anything about FBLA!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 32),
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: fblaNavy.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Try asking:\n• "What is FBLA?"\n• "Tell me about FBLA competitions"\n• "How can I join FBLA?"',
              style: TextStyle(
                color: fblaNavy,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message) {
    final isUser = message.role == "user";
    final messageText = message.content;
    final isError = messageText.startsWith('Error:') || messageText.startsWith('API Error:');
    
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 20,
              backgroundColor: isError ? Colors.red : fblaNavy,
              child: Icon(
                isError ? Icons.error : Icons.smart_toy,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser 
                    ? fblaNavy 
                    : isError 
                        ? Colors.red[50] 
                        : Colors.white,
                border: isError 
                    ? Border.all(color: Colors.red[300]!, width: 1) 
                    : null,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isError) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.red,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Error',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                  ],
                  Text(
                    messageText,
                    style: TextStyle(
                      color: isUser 
                          ? Colors.white 
                          : isError 
                              ? Colors.red[800] 
                              : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 20,
              backgroundColor: fblaGold,
              child: Icon(
                Icons.person,
                color: fblaNavy,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: fblaNavy,
            child: Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 20,
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(fblaNavy),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'AI is thinking...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
