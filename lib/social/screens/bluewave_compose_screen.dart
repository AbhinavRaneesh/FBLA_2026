import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart'
    show
        AppState,
        appBackgroundColor,
        appBackgroundGradient,
        fblaBlue,
        fblaGold,
        fblaLightBackground,
        fblaLightBorder,
        fblaLightPrimaryText,
        fblaLightSecondaryText,
        fblaLightSurface,
        fblaNavy;
import '../models/social_models.dart';
import '../providers/social_provider.dart';

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

  BoxDecoration _panelDecoration(bool isDark) => BoxDecoration(
        color: isDark ? null : fblaLightSurface,
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0F1C31), Color(0xFF0A1628)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : fblaLightBorder,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? appBackgroundColor : fblaLightBackground,
      appBar: AppBar(
        backgroundColor: fblaNavy,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? appBackgroundGradient : null,
          color: isDark ? null : fblaLightBackground,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: _panelDecoration(isDark),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: fblaBlue.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.waves_rounded, color: fblaBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share with your chapter',
                          style: TextStyle(
                            color: isDark ? Colors.white : fblaLightPrimaryText,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Posts appear on the BlueWave social feed.',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.68)
                                : fblaLightSecondaryText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: _panelDecoration(isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Post Type',
                    style: TextStyle(
                      color: isDark ? Colors.white : fblaLightPrimaryText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: BlueWavePostKind.values.map((kind) {
                      final selected = _kind == kind;
                      return ChoiceChip(
                        label: Text(_kindLabel(kind)),
                        selected: selected,
                        onSelected: (_) => setState(() => _kind = kind),
                        selectedColor: fblaBlue,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : fblaLightBackground,
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : (isDark
                                  ? Colors.white70
                                  : fblaLightSecondaryText),
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(
                          color: selected
                              ? fblaBlue
                              : (isDark ? Colors.white12 : fblaLightBorder),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _textController,
                    maxLines: 6,
                    style: TextStyle(
                      color: isDark ? Colors.white : fblaLightPrimaryText,
                    ),
                    decoration: InputDecoration(
                      labelText: 'What do you want to share?',
                      hintText: 'Share an update with your chapter...',
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : fblaLightBackground,
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
                          color: isDark ? fblaGold : fblaNavy,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _tagsController,
                    style: TextStyle(
                      color: isDark ? Colors.white : fblaLightPrimaryText,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Tags',
                      hintText: 'Competition, Event, Tips',
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : fblaLightBackground,
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
                          color: isDark ? fblaGold : fblaNavy,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _publish,
                icon: const Icon(Icons.waves_rounded),
                label: const Text(
                  'Publish to BlueWave',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
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
