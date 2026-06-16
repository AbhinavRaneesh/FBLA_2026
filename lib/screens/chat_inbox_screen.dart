import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../screens/direct_chat_screen.dart';
import '../screens/find_members_screen.dart';
import '../screens/group_chat_screen.dart';
import '../services/firebase_service.dart';
import '../widgets/friend_picker_sheet.dart';

/// Google Chat–style inbox: friends, direct threads, and group chats.
class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  int _tabIndex = 0;
  List<Map<String, dynamic>> _friends = const [];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final friends = await FirebaseService.getFriendsForUser(userId);
    if (!mounted) return;
    setState(() => _friends = friends);
  }

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  String _friendName(Map<String, dynamic> friend) {
    final name = (friend['name'] ?? friend['displayName'] ?? '').toString().trim();
    return name.isEmpty ? 'Member' : name;
  }

  String _otherParticipantName(
    Map<String, dynamic> conversation,
    String currentUserId,
  ) {
    final participants =
        (conversation['participants'] as List?)?.cast<String>() ?? const [];
    final otherId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    if (otherId.isEmpty) return 'Member';

    final friend = _friends.cast<Map<String, dynamic>?>().firstWhere(
          (f) => (f?['id'] ?? '').toString() == otherId,
          orElse: () => null,
        );
    if (friend != null) return _friendName(friend);
    return 'Member';
  }

  String _otherParticipantId(
    Map<String, dynamic> conversation,
    String currentUserId,
  ) {
    final participants =
        (conversation['participants'] as List?)?.cast<String>() ?? const [];
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  Future<void> _startGroupChat() async {
    final picked = await FriendPickerSheet.show(
      context,
      friends: _friends,
      title: 'Start Group Chat',
      confirmLabel: 'Create Group',
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    final app = context.read<AppState>();
    final userId = app.firebaseUser?.uid;
    if (userId == null) return;

    final names = picked.map(_friendName).join(', ');
    final groupName = names.length > 28 ? '${names.substring(0, 28)}…' : names;
    final memberIds =
        picked.map((f) => (f['id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();

    final groupId = await FirebaseService.createGroupChat(
      creatorId: userId,
      creatorName: app.resolvedDisplayName,
      memberIds: memberIds,
      name: groupName,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(
          groupId: groupId,
          groupName: groupName,
        ),
      ),
    );
  }

  Future<void> _messageFriend() async {
    final picked = await FriendPickerSheet.show(
      context,
      friends: _friends,
      title: 'Message a Friend',
      confirmLabel: 'Open Chat',
      allowMultiple: false,
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final friend = picked.first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectChatScreen(
          otherUserId: (friend['id'] ?? '').toString(),
          otherUserName: _friendName(friend),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final isDark = app.isDarkMode;
    final userId = _currentUserId ?? '';
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    final secondary = isDark ? Colors.white70 : fblaLightSecondaryText;

    return Scaffold(
      backgroundColor: isDark ? appBackgroundColor : fblaLightBackground,
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: fblaNavy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Member Directory',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FindMembersScreen()),
              );
            },
            icon: const Icon(Icons.people_outline_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tabIndex == 2 ? _startGroupChat : _messageFriend,
        backgroundColor: fblaBlue,
        foregroundColor: Colors.white,
        icon: Icon(_tabIndex == 2 ? Icons.group_add_rounded : Icons.edit_rounded),
        label: Text(_tabIndex == 2 ? 'New Group' : 'New Chat'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? appBackgroundGradient : null,
          color: isDark ? null : fblaLightBackground,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: _InboxTabBar(
                index: _tabIndex,
                isDark: isDark,
                onChanged: (i) => setState(() => _tabIndex = i),
              ),
            ),
            Expanded(
              child: _tabIndex == 0
                  ? _buildChatsTab(userId, isDark, primary, secondary)
                  : _tabIndex == 1
                      ? _buildFriendsTab(isDark, primary, secondary)
                      : _buildGroupsTab(userId, isDark, primary, secondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatsTab(
    String userId,
    bool isDark,
    Color primary,
    Color secondary,
  ) {
    if (userId.isEmpty) {
      return _emptyState(isDark, 'Sign in to view your messages.');
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.getUserConversations(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: fblaGold));
        }
        final conversations = snapshot.data ?? [];
        if (conversations.isEmpty) {
          return _emptyState(
            isDark,
            'No conversations yet.\nTap New Chat to message a friend.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final chat = conversations[index];
            final otherName = _otherParticipantName(chat, userId);
            final otherId = _otherParticipantId(chat, userId);
            final lastMessage = (chat['lastMessage'] ?? '').toString();
            final ts = chat['lastTimestamp'];
            final timeLabel = ts is Timestamp ? _formatTime(ts.toDate()) : '';

            return _ConversationTile(
              isDark: isDark,
              title: otherName,
              subtitle: lastMessage,
              time: timeLabel,
              icon: Icons.chat_bubble_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DirectChatScreen(
                      otherUserId: otherId,
                      otherUserName: otherName,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsTab(bool isDark, Color primary, Color secondary) {
    if (_friends.isEmpty) {
      return _emptyState(
        isDark,
        'No friends yet.\nFind members and send friend requests.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
      itemCount: _friends.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final friend = _friends[index];
        final name = _friendName(friend);
        final school = (friend['school'] ?? '').toString().trim();
        return _ConversationTile(
          isDark: isDark,
          title: name,
          subtitle: school.isEmpty ? 'FBLA Member' : school,
          time: '',
          icon: Icons.person_rounded,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DirectChatScreen(
                  otherUserId: (friend['id'] ?? '').toString(),
                  otherUserName: name,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGroupsTab(
    String userId,
    bool isDark,
    Color primary,
    Color secondary,
  ) {
    if (userId.isEmpty) {
      return _emptyState(isDark, 'Sign in to view group chats.');
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.getUserGroupChats(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: fblaGold));
        }
        final groups = snapshot.data ?? [];
        if (groups.isEmpty) {
          return _emptyState(
            isDark,
            'No group chats yet.\nTap New Group to start one.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final group = groups[index];
            final name = (group['name'] ?? 'Group').toString();
            final lastMessage = (group['lastMessage'] ?? '').toString();
            final ts = group['lastTimestamp'];
            final timeLabel = ts is Timestamp ? _formatTime(ts.toDate()) : '';

            return _ConversationTile(
              isDark: isDark,
              title: name,
              subtitle: lastMessage,
              time: timeLabel,
              icon: Icons.groups_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupChatScreen(
                      groupId: (group['id'] ?? '').toString(),
                      groupName: name,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _emptyState(bool isDark, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white70 : fblaLightSecondaryText,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }
    return '${date.month}/${date.day}';
  }
}

class _InboxTabBar extends StatelessWidget {
  final int index;
  final bool isDark;
  final ValueChanged<int> onChanged;

  const _InboxTabBar({
    required this.index,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['Messages', 'Friends', 'Groups'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1C31) : fblaLightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : fblaLightBorder,
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = index == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? fblaBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.white70 : fblaLightSecondaryText),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF0F1C31) : fblaLightSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : fblaLightBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: fblaBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: fblaBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : fblaLightPrimaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : fblaLightSecondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (time.isNotEmpty)
                Text(
                  time,
                  style: TextStyle(
                    color: isDark ? Colors.white38 : fblaLightDisabledText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
