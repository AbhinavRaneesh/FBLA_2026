import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/firebase_service.dart';
import 'direct_chat_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final app = Provider.of<AppState>(context, listen: false);
    final userId = app.firebaseUser?.uid;
    if (userId == null) return;

    _messageController.clear();
    try {
      await FirebaseService.sendGroupMessage(
        groupId: widget.groupId,
        fromUserId: userId,
        fromUserName: app.resolvedDisplayName,
        text: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final isDark = app.isDarkMode;
    final userId = app.firebaseUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? appBackgroundColor : fblaLightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const Text(
              'Group chat',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: fblaNavy,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? appBackgroundGradient : null,
          color: isDark ? null : fblaLightBackground,
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseService.getGroupMessages(widget.groupId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: fblaGold),
                    );
                  }
                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'Start the group conversation.',
                        style: TextStyle(
                          color:
                              isDark ? Colors.white54 : fblaLightSecondaryText,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['senderId'] == userId;
                      return _GroupMessageBubble(
                        message: msg,
                        isMe: isMe,
                        isDark: isDark,
                        app: app,
                      );
                    },
                  );
                },
              ),
            ),
            _buildInput(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(bool isDark) {
    final surface = isDark ? const Color(0xFF101827) : fblaLightSurface;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : fblaLightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(
                color: isDark ? Colors.white : fblaLightPrimaryText,
              ),
              decoration: InputDecoration(
                hintText: 'Message the group...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : fblaLightDisabledText,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : fblaLightBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: fblaGold,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: fblaNavy),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isDark;
  final AppState app;

  const _GroupMessageBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.app,
  });

  @override
  Widget build(BuildContext context) {
    final type = (message['type'] ?? 'text').toString();
    if (type == 'event_invite' || type == 'post_share') {
      return DirectChatMessageCard(
        message: message,
        isMe: isMe,
        isDark: isDark,
        app: app,
        showSenderName: true,
      );
    }

    final senderName = (message['senderName'] ?? 'Member').toString();
    final timestamp = message['timestamp'] as Timestamp?;
    final timeStr = timestamp != null
        ? '${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  senderName,
                  style: TextStyle(
                    color: isDark ? fblaGold : fblaBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? fblaBlue
                    : (isDark ? const Color(0xFF1F2937) : fblaLightSurface),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border.all(
                  color: isMe
                      ? Colors.transparent
                      : (isDark ? Colors.white12 : fblaLightBorder),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['text'] ?? '',
                    style: TextStyle(
                      color:
                          isMe || isDark ? Colors.white : fblaLightPrimaryText,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: isMe || isDark
                          ? Colors.white60
                          : fblaLightDisabledText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
