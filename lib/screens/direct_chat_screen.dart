import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/firebase_service.dart';
import '../utils/shared_post_launcher.dart';
import '../widgets/app_snackbar.dart';

class DirectChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const DirectChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final app = Provider.of<AppState>(context, listen: false);
    final currentUserId = app.firebaseUser?.uid;
    final currentUserName = app.resolvedDisplayName;

    if (currentUserId == null) return;

    _messageController.clear();

    try {
      await FirebaseService.sendDirectMessage(
        fromUserId: currentUserId,
        toUserId: widget.otherUserId,
        text: text,
        fromUserName: currentUserName,
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Failed to send message: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final isDark = app.isDarkMode;
    final currentUserId = app.firebaseUser?.uid ?? '';

    final backgroundColor = isDark ? appBackgroundColor : fblaLightBackground;
    final primaryText = isDark ? Colors.white : fblaLightPrimaryText;
    final surfaceColor = isDark ? const Color(0xFF101827) : fblaLightSurface;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : fblaLightBorder;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: fblaGold,
              radius: 16,
              child: Text(
                widget.otherUserName.isNotEmpty
                    ? widget.otherUserName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: fblaNavy,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: fblaNavy,
        foregroundColor: Colors.white,
        elevation: 0,
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
                stream: FirebaseService.getDirectMessages(
                    currentUserId, widget.otherUserId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: fblaGold),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(color: primaryText),
                      ),
                    );
                  }

                  final messages = snapshot.data ?? [];

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 64,
                            color: isDark ? Colors.white24 : Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet.\nSay hi to ${widget.otherUserName}!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['senderId'] == currentUserId;
                      final type = (msg['type'] ?? 'text').toString();
                      if (type == 'event_invite' || type == 'post_share') {
                        return DirectChatMessageCard(
                          message: msg,
                          isMe: isMe,
                          isDark: isDark,
                          app: app,
                        );
                      }
                      return _buildTextBubble(msg, isMe, isDark);
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(
                isDark, surfaceColor, borderColor, primaryText),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBubble(Map<String, dynamic> msg, bool isMe, bool isDark) {
    final timestamp = msg['timestamp'] as Timestamp?;
    final timeStr = timestamp != null
        ? '${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
              msg['text'] ?? '',
              style: TextStyle(
                color: isMe || isDark ? Colors.white : fblaLightPrimaryText,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                color: isMe || isDark ? Colors.white60 : fblaLightDisabledText,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color primaryText,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(color: primaryText),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle:
                    TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.1),
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

class DirectChatMessageCard extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isDark;
  final AppState app;
  final bool showSenderName;

  const DirectChatMessageCard({
    super.key,
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.app,
    this.showSenderName = false,
  });

  @override
  Widget build(BuildContext context) {
    final type = (message['type'] ?? 'text').toString();
    final payload = (message['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    final senderName = (message['senderName'] ?? 'Member').toString();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showSenderName && !isMe)
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1C31) : fblaLightSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: fblaGold.withValues(alpha: 0.45),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: type == 'event_invite'
                  ? _EventInviteContent(
                      payload: payload,
                      senderName: senderName,
                      isMe: isMe,
                      isDark: isDark,
                      app: app,
                    )
                  : _PostShareContent(
                      payload: payload,
                      senderName: senderName,
                      isMe: isMe,
                      isDark: isDark,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventInviteContent extends StatelessWidget {
  final Map<String, dynamic> payload;
  final String senderName;
  final bool isMe;
  final bool isDark;
  final AppState app;

  const _EventInviteContent({
    required this.payload,
    required this.senderName,
    required this.isMe,
    required this.isDark,
    required this.app,
  });

  void _join(BuildContext context) {
    final eventId = (payload['eventId'] ?? '').toString();
    final title = (payload['eventTitle'] ?? 'Event').toString();
    final location = (payload['eventLocation'] ?? 'TBD').toString();
    final description =
        (payload['eventDescription'] ?? 'Joined from chat invite').toString();
    final startRaw = payload['eventStart']?.toString();
    final endRaw = payload['eventEnd']?.toString();

    DateTime start = DateTime.now();
    DateTime end = start.add(const Duration(hours: 1));
    if (startRaw != null) start = DateTime.tryParse(startRaw) ?? start;
    if (endRaw != null) end = DateTime.tryParse(endRaw) ?? end;

    final existing = app.events.any((e) => e.id == eventId);
    if (!existing) {
      app.addUserEvent(Event(
        id: eventId,
        title: title,
        start: start,
        end: end,
        location: location,
        description: description,
      ));
    }
    app.toggleParticipatingEvent(eventId);
    app.rsvpEvent(eventId, 'going');

    AppSnackBar.success(context, 'Joined "$title"', icon: Icons.event_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final title = (payload['eventTitle'] ?? 'Event').toString();
    final when = (payload['eventWhen'] ?? '').toString();
    final location = (payload['eventLocation'] ?? 'TBD').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fblaBlue.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.event_rounded, color: fblaBlue, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isMe ? 'Event invitation sent' : '$senderName invited you',
                style: TextStyle(
                  color: isDark ? Colors.white70 : fblaLightSecondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : fblaLightPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (when.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            when,
            style: TextStyle(
              color: isDark ? Colors.white60 : fblaLightSecondaryText,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          location,
          style: TextStyle(
            color: isDark ? Colors.white60 : fblaLightSecondaryText,
            fontSize: 13,
          ),
        ),
        if (!isMe) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _join(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: fblaGold,
                foregroundColor: fblaNavy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Join',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PostShareContent extends StatelessWidget {
  final Map<String, dynamic> payload;
  final String senderName;
  final bool isMe;
  final bool isDark;

  const _PostShareContent({
    required this.payload,
    required this.senderName,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final text = (payload['postText'] ?? '').toString();
    final presentation = SharedPostPresentation.fromPayload(payload);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              presentation.icon,
              color: fblaGold,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isMe
                    ? 'You shared a ${presentation.typeLabel}'
                    : '$senderName shared a ${presentation.typeLabel}',
                style: TextStyle(
                  color: isDark ? Colors.white70 : fblaLightSecondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : fblaLightPrimaryText,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => openSharedPost(context, payload),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(presentation.actionLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: fblaGold,
              side: BorderSide(color: fblaGold.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
