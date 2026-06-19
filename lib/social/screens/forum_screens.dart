import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart'
    show
        AppState,
        ChatMessage,
        ChatThread,
        ThreadScreen,
        appBackgroundColor,
        appBackgroundGradient,
        fblaGold,
        fblaLightBackground,
        fblaLightBorder,
        fblaLightPrimaryText,
        fblaLightSecondaryText,
        fblaLightSurface,
        fblaNavy;
import '../../widgets/app_snackbar.dart';
import '../models/social_models.dart';
import '../theme/bluewave_theme.dart';

// ════════════════════════════════════════════════════════════════════════════
// Forum Thread Detail
// ════════════════════════════════════════════════════════════════════════════

class ForumThreadDetailScreen extends StatelessWidget {
  final ForumThreadData thread;

  const ForumThreadDetailScreen({super.key, required this.thread});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = Provider.of<AppState>(context);
    final existing = app.threads.where((t) => t.id == thread.id).toList();

    if (existing.isNotEmpty) {
      return ThreadScreen(thread: existing.first);
    }

    final bg = isDark ? appBackgroundColor : fblaLightBackground;
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    final secondary = isDark ? Colors.white60 : fblaLightSecondaryText;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: fblaNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          thread.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? appBackgroundGradient : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: BlueWaveTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: BlueWaveTheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_rounded,
                        size: 14, color: BlueWaveTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      thread.author.name,
                      style: const TextStyle(
                        color: BlueWaveTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Thread preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : fblaLightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : fblaLightBorder,
                  ),
                ),
                child: Text(
                  thread.preview,
                  style: TextStyle(
                    color: primary,
                    height: 1.55,
                    fontSize: 15,
                  ),
                ),
              ),
              const Spacer(),
              // Info note
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14,
                      color: isDark ? Colors.white30 : Colors.black26),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Replies will sync when this thread is connected to Firestore.',
                      style: TextStyle(
                        color: secondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Start Forum Thread
// ════════════════════════════════════════════════════════════════════════════

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
    if (title.isEmpty || body.isEmpty) {
      AppSnackBar.warning(
        context,
        'Please fill in the title and first message.',
      );
      return;
    }

    final app = context.read<AppState>();
    final thread = ChatThread(
      id: 'forum_${DateTime.now().millisecondsSinceEpoch}',
      title: '[${_category.name[0].toUpperCase()}${_category.name.substring(1)}] $title',
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
    AppSnackBar.success(context, 'Forum thread created!');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? appBackgroundColor : fblaLightBackground;
    final primary = isDark ? Colors.white : fblaLightPrimaryText;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: fblaNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Start a Forum',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _create,
            child: const Text(
              'Post',
              style: TextStyle(
                color: fblaGold,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? appBackgroundGradient : null,
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Category picker
            Text(
              'Category',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : fblaLightSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white12 : fblaLightBorder,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ForumCategory>(
                  value: _category,
                  dropdownColor:
                      isDark ? const Color(0xFF0F1C31) : Colors.white,
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  icon: Icon(
                    Icons.expand_more_rounded,
                    color: isDark ? Colors.white54 : fblaLightSecondaryText,
                  ),
                  isExpanded: true,
                  items: ForumCategory.values.map((c) {
                    final label =
                        c.name[0].toUpperCase() + c.name.substring(1);
                    return DropdownMenuItem(value: c, child: Text(label));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Title
            Text(
              'Thread title',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            _inputField(
              controller: _titleController,
              hint: 'What do you want to discuss?',
              isDark: isDark,
              primary: primary,
            ),

            const SizedBox(height: 18),

            // Body
            Text(
              'First message',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            _inputField(
              controller: _bodyController,
              hint: 'Share your thoughts…',
              isDark: isDark,
              primary: primary,
              maxLines: 6,
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: fblaGold,
                  foregroundColor: fblaNavy,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Create Thread',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    required Color primary,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: primary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? Colors.white38 : fblaLightSecondaryText,
          fontSize: 14,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : fblaLightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : fblaLightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : fblaLightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: BlueWaveTheme.primary,
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
