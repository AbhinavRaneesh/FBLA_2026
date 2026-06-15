import 'package:flutter/material.dart';

import '../../main.dart' show AppState, fblaGold, fblaNavy;
import 'package:provider/provider.dart';

import '../models/social_models.dart';
import '../providers/social_provider.dart';
import '../theme/bluewave_theme.dart';

class BlueWaveComposeScreen extends StatefulWidget {
  const BlueWaveComposeScreen({super.key});

  @override
  State<BlueWaveComposeScreen> createState() => _BlueWaveComposeScreenState();
}

class _BlueWaveComposeScreenState extends State<BlueWaveComposeScreen> {
  final _textController = TextEditingController();
  final _tagsController = TextEditingController();
  BlueWavePostKind _kind = BlueWavePostKind.standard;

  @override
  void dispose() {
    _textController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final app = context.read<AppState>();
    final social = context.read<SocialProvider>();
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .map((t) => t.startsWith('#') ? t : '#$t')
        .toList();

    final post = BlueWavePostData(
      id: 'bw_${DateTime.now().millisecondsSinceEpoch}',
      author: SocialAuthor(
        id: app.firebaseUser?.uid ?? 'local',
        name: app.displayName.isNotEmpty ? app.displayName : 'Member',
        photoUrl: app.userProfile?.photoUrl,
        role: app.userProfile?.officerPosition ?? 'Member',
      ),
      text: text,
      kind: _kind,
      createdAt: DateTime.now(),
      tags: tags,
    );

    await social.addBlueWavePost(post);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlueWaveTheme.surface,
      appBar: AppBar(
        backgroundColor: BlueWaveTheme.deep,
        foregroundColor: Colors.white,
        title: const Text(
          'Create BlueWave Post',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: _publish,
            child: const Text(
              'Post',
              style: TextStyle(
                color: fblaGold,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 8,
            children: BlueWavePostKind.values.map((kind) {
              final selected = _kind == kind;
              return ChoiceChip(
                label: Text(_kindLabel(kind)),
                selected: selected,
                onSelected: (_) => setState(() => _kind = kind),
                selectedColor: BlueWaveTheme.primary,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _textController,
            maxLines: 6,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Share an update with your chapter...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _tagsController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Tags (Competition, Event, Tips)',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _publish,
              icon: const Icon(Icons.waves_rounded),
              label: const Text('Publish to BlueWave'),
              style: ElevatedButton.styleFrom(
                backgroundColor: fblaGold,
                foregroundColor: fblaNavy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _kindLabel(BlueWavePostKind kind) {
    switch (kind) {
      case BlueWavePostKind.reel:
        return 'Reel';
      case BlueWavePostKind.announcement:
        return 'Announcement';
      case BlueWavePostKind.memberHighlight:
        return 'Highlight';
      case BlueWavePostKind.photo:
        return 'Photo';
      case BlueWavePostKind.video:
        return 'Video';
      default:
        return 'Post';
    }
  }
}
