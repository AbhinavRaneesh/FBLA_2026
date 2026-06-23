import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart'
    show
        AppState,
        appBackgroundGradient,
        fblaBlue,
        fblaGold,
        fblaLightBackground,
        fblaLightBorder,
        fblaLightPrimaryText,
        fblaLightSecondaryText,
        fblaLightSurface;
import '../services/text_to_speech_service.dart';

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  static const Color _accent = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF07111F) : fblaLightBackground,
      appBar: AppBar(
        title: const Text('Accessibility'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : fblaLightPrimaryText,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? appBackgroundGradient : null,
          color: isDark ? null : fblaLightBackground,
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafe + 24),
          children: [
            _heroCard(isDark),
            const SizedBox(height: 22),
            _groupHeader(context, 'Display', Icons.text_fields_rounded),
            _textSizeTile(context, app, isDark),
            _toggle(
              context,
              title: 'Bold text',
              subtitle: 'Makes body text easier to read',
              icon: Icons.format_bold_rounded,
              value: app.accessibilityBoldText,
              onChanged: app.setAccessibilityBoldText,
            ),
            _toggle(
              context,
              title: 'High contrast',
              subtitle: 'Stronger text and border contrast',
              icon: Icons.contrast_rounded,
              value: app.accessibilityHighContrast,
              onChanged: app.setAccessibilityHighContrast,
            ),
            _toggle(
              context,
              title: 'Larger tap targets',
              subtitle: 'Bigger buttons and switches for easier tapping',
              icon: Icons.touch_app_rounded,
              value: app.accessibilityLargeTapTargets,
              onChanged: app.setAccessibilityLargeTapTargets,
            ),
            const SizedBox(height: 22),
            _groupHeader(context, 'Motion & sound', Icons.accessibility_new_rounded),
            _toggle(
              context,
              title: 'Reduce motion',
              subtitle: 'Limits animations across the app',
              icon: Icons.motion_photos_off_rounded,
              value: app.accessibilityReduceMotion,
              onChanged: app.setAccessibilityReduceMotion,
            ),
            _toggle(
              context,
              title: 'Read aloud',
              subtitle: 'Enable text-to-speech for on-screen content',
              icon: Icons.record_voice_over_rounded,
              value: app.accessibilityReadAloudEnabled,
              onChanged: (enabled) async {
                await app.setAccessibilityReadAloudEnabled(enabled);
                if (enabled && context.mounted) {
                  await TextToSpeechService.speak(
                    'Read aloud is on. Use Speak sample below to hear text.',
                  );
                } else {
                  await TextToSpeechService.stop();
                }
              },
            ),
            if (app.accessibilityReadAloudEnabled) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => TextToSpeechService.speak(
                    'FBLA Member App accessibility preview. '
                    'You can increase text size, enable bold text, high contrast, '
                    'larger tap targets, reduce motion, and read content aloud.',
                  ),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('Speak sample'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    side: BorderSide(color: _accent.withValues(alpha: 0.55)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            _groupHeader(context, 'System', Icons.settings_accessibility_rounded),
            _navTile(
              context,
              title: 'Device accessibility settings',
              subtitle: 'Open your phone\'s built-in accessibility options',
              icon: Icons.open_in_new_rounded,
              onTap: () => _openSystemAccessibility(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSystemAccessibility(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse('app-settings:'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open system settings on this device.'),
        ),
      );
    }
  }

  Widget _heroCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1624) : fblaLightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : fblaLightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.accessibility_rounded,
              color: _accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Make the app easier to use',
                  style: TextStyle(
                    color: isDark ? Colors.white : fblaLightPrimaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Adjust text size, contrast, motion, and read-aloud options.',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.68)
                        : fblaLightSecondaryText,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupHeader(BuildContext context, String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _accent, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? Colors.white.withValues(alpha: 0.85) : fblaBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _textSizeTile(BuildContext context, AppState app, bool isDark) {
    final pct = (app.accessibilityTextScale * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : fblaBlue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : fblaBlue.withValues(alpha: 0.16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.format_size_rounded,
                      color: Colors.white, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Text size',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : fblaLightPrimaryText,
                        ),
                      ),
                      Text(
                        '$pct% — preview below',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.62)
                              : fblaLightSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Slider(
              value: app.accessibilityTextScale,
              min: 0.85,
              max: 1.6,
              divisions: 15,
              label: '$pct%',
              activeColor: fblaGold,
              onChanged: app.setAccessibilityTextScale,
            ),
            Text(
              'The quick brown fox jumps over the lazy dog.',
              style: TextStyle(
                fontSize: 16 * app.accessibilityTextScale,
                fontWeight: app.accessibilityBoldText
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: isDark ? Colors.white : fblaLightPrimaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : fblaBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : fblaBlue.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : fblaLightPrimaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.62)
                              : fblaLightSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: fblaGold,
                  activeTrackColor: fblaGold.withValues(alpha: 0.34),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : fblaBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : fblaBlue.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : fblaLightPrimaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.62)
                              : fblaLightSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white38 : fblaBlue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
