import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart'
    show
        appBackgroundGradient,
        fblaBlue,
        fblaGold,
        fblaLightBackground,
        fblaLightBorder,
        fblaLightPrimaryText,
        fblaLightSecondaryText;
import '../widgets/app_snackbar.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  static const List<String> _supportEmails = [
    'kushalnarkhede09@gmail.com',
    'abhinav.raneesh@gmail.com',
  ];
  static const String _phoneDisplay = '385 589 9654';
  static const String _phoneDial = '+13855899654';

  Future<void> _launchEmail(BuildContext context, String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      AppSnackBar.warning(context, 'Could not open your email app.');
    }
  }

  Future<void> _launchPhone(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: _phoneDial);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      AppSnackBar.warning(context, 'Could not open your phone app.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF07111F) : fblaLightBackground,
      appBar: AppBar(
        title: const Text('Contact Us'),
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
            _buildHeroCard(isDark),
            const SizedBox(height: 22),
            _buildSectionLabel(context, 'Email Support'),
            const SizedBox(height: 10),
            ..._supportEmails.map(
              (email) => _ContactTile(
                isDark: isDark,
                icon: Icons.email_outlined,
                accent: const Color(0xFF6D5BD0),
                title: email,
                subtitle: 'Tap to send an email',
                onTap: () => _launchEmail(context, email),
              ),
            ),
            const SizedBox(height: 22),
            _buildSectionLabel(context, 'Phone Support'),
            const SizedBox(height: 10),
            _ContactTile(
              isDark: isDark,
              icon: Icons.phone_outlined,
              accent: const Color(0xFF1AA39A),
              title: _phoneDisplay,
              subtitle: 'Tap to call support',
              onTap: () => _launchPhone(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1624) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : fblaLightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: fblaGold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: fblaGold.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: fblaGold,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We are here to help',
                  style: TextStyle(
                    color: isDark ? Colors.white : fblaLightPrimaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reach out by email or phone for app support and chapter questions.',
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

  Widget _buildSectionLabel(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark ? Colors.white.withValues(alpha: 0.85) : fblaBlue,
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactTile({
    required this.isDark,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent,
                        Color.lerp(accent, Colors.black, 0.22)!,
                      ],
                    ),
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
                          color: isDark ? Colors.white : fblaLightPrimaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
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
