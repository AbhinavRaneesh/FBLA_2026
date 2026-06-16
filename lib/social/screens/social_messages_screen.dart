import 'package:flutter/material.dart';

import '../../main.dart';
import '../../screens/chat_inbox_screen.dart';
import '../../screens/find_members_screen.dart';

/// Entry point for DMs and member discovery from the Social tab.
class SocialMessagesScreen extends StatelessWidget {
  const SocialMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatInboxScreen();
  }
}

/// Legacy tiles kept for reuse if needed elsewhere.
class SocialMessagesHub extends StatelessWidget {
  const SocialMessagesHub({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? appBackgroundColor : fblaLightBackground,
      appBar: AppBar(
        backgroundColor: fblaNavy,
        foregroundColor: Colors.white,
        title: const Text('Messages'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ActionTile(
            icon: Icons.chat_bubble_rounded,
            title: 'Open Chats',
            subtitle: 'Messages, friends, and group conversations',
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatInboxScreen()),
              );
            },
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.people_alt_rounded,
            title: 'Find Members',
            subtitle: 'Search the member directory',
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FindMembersScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF0F1C31) : fblaLightSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: fblaGold, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : fblaLightPrimaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : fblaLightSecondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : fblaLightDisabledText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
