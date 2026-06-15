import 'package:flutter/material.dart';

import '../../screens/find_members_screen.dart';
import '../theme/bluewave_theme.dart';

/// Entry point for DMs and member discovery from the Social tab.
class SocialMessagesScreen extends StatelessWidget {
  const SocialMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlueWaveTheme.surface,
      appBar: AppBar(
        backgroundColor: BlueWaveTheme.deep,
        foregroundColor: Colors.white,
        title: const Text('Messages'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ActionTile(
            icon: Icons.people_alt_rounded,
            title: 'Find Members',
            subtitle: 'Search the member directory and send friend requests',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FindMembersScreen()),
              );
            },
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.chat_bubble_rounded,
            title: 'Direct Messages',
            subtitle: 'Open a chat from your Friends list in Find Members',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FindMembersScreen()),
              );
            },
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.groups_rounded,
            title: 'Group Chats',
            subtitle: 'Event and committee group conversations',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Group chats are coming soon.'),
                ),
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
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: BlueWaveTheme.waveGlow, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
