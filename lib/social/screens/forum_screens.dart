import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart' show AppState, ChatMessage, ChatThread, ThreadScreen, fblaGold;
import '../models/social_models.dart';
import '../theme/bluewave_theme.dart';

class ForumThreadDetailScreen extends StatelessWidget {
  final ForumThreadData thread;

  const ForumThreadDetailScreen({super.key, required this.thread});

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final existing = app.threads.where((t) => t.id == thread.id).toList();

    if (existing.isNotEmpty) {
      return ThreadScreen(thread: existing.first);
    }

    return Scaffold(
      backgroundColor: BlueWaveTheme.surface,
      appBar: AppBar(
        backgroundColor: BlueWaveTheme.deep,
        foregroundColor: Colors.white,
        title: Text(thread.title, style: const TextStyle(fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              thread.preview,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 20),
            Text(
              'Started by ${thread.author.name}',
              style: TextStyle(color: fblaGold.withValues(alpha: 0.9)),
            ),
            const Spacer(),
            const Text(
              'Replies will sync when this thread is connected to Firestore.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class StartForumScreen extends StatefulWidget {
  const StartForumScreen({super.key});

  @override
  State<StartForumScreen> createState() => _StartForumScreenState();
}

class _StartForumScreenState extends State<StartForumScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  ForumCategory _category = ForumCategory.general;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _create() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) return;

    final app = context.read<AppState>();
    final thread = ChatThread(
      id: 'forum_${DateTime.now().millisecondsSinceEpoch}',
      title: '[$_category] $title',
      messages: [
        ChatMessage(
          author: app.displayName.isNotEmpty ? app.displayName : 'Member',
          text: body,
          time: DateTime.now(),
        ),
      ],
    );
    app.addThread(thread);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Forum thread created')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlueWaveTheme.surface,
      appBar: AppBar(
        backgroundColor: BlueWaveTheme.deep,
        foregroundColor: Colors.white,
        title: const Text('Start a Forum'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<ForumCategory>(
            initialValue: _category,
            dropdownColor: BlueWaveTheme.deep,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: ForumCategory.values
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.name[0].toUpperCase() + c.name.substring(1)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Thread title'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _bodyController,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('First message'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _create,
            style: ElevatedButton.styleFrom(
              backgroundColor: fblaGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Create Thread'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}
