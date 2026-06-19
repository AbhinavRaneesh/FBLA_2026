import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

/// A first-run guided tour shown the first time a member reaches the home
/// screen after signing in. Distinct from the pre-login onboarding carousel:
/// this orients the user to the five main areas of the app so the interface is
/// intuitive AND clear instructions are provided.
///
/// Gated by `AppState.hasSeenFeatureTour`; can be replayed from More → Help.
class FeatureTour {
  /// Shows the tour as a modal overlay. Resolves when finished or skipped.
  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'App feature tour',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => const _FeatureTourView(),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    );
  }
}

class _TourStep {
  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  const _TourStep({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
  });
}

const List<_TourStep> _steps = [
  _TourStep(
    icon: Icons.waving_hand_rounded,
    accent: fblaGold,
    title: 'Welcome to FBLA',
    body:
        'A quick tour of your member app. Replay anytime from More → Help.',
  ),
  _TourStep(
    icon: Icons.emoji_events_rounded,
    accent: fblaGold,
    title: 'NLC Ready',
    body:
        'Your Competition Command Center: pick your NLC events, run Live Sim roleplay with an AI rubric judge, and earn Credits for daily prep.',
  ),
  _TourStep(
    icon: Icons.home_rounded,
    accent: Color(0xFF2E6BC6),
    title: 'Home',
    body:
        'Your dashboard: NLC Ready prep, quick actions, upcoming events, and the latest announcements at a glance.',
  ),
  _TourStep(
    icon: Icons.calendar_month_rounded,
    accent: Color(0xFF1AA39A),
    title: 'Events',
    body:
        'Browse the calendar, filter by type, RSVP, and set reminders so you never miss an event or competition deadline.',
  ),
  _TourStep(
    icon: Icons.menu_book_rounded,
    accent: Color(0xFF6D5BD0),
    title: 'Resources',
    body:
        'Open FBLA documents in-app, and work through guided courses that track your progress level by level.',
  ),
  _TourStep(
    icon: Icons.waves_rounded,
    accent: Color(0xFF0EA5E9),
    title: 'Social',
    body:
        'BlueWave, Instagram, YouTube, forums, and news — one personalized feed powered by your interests.',
  ),
  _TourStep(
    icon: Icons.workspace_premium_rounded,
    accent: fblaGold,
    title: 'More & your profile',
    body:
        'Find the AI Coach, member directory, and your profile — earn Credits, keep streaks, and climb the career ranks.',
  ),
];

class _FeatureTourView extends StatefulWidget {
  const _FeatureTourView();

  @override
  State<_FeatureTourView> createState() => _FeatureTourViewState();
}

class _FeatureTourViewState extends State<_FeatureTourView> {
  int _i = 0;

  bool get _isLast => _i == _steps.length - 1;

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      setState(() => _i++);
    }
  }

  void _back() {
    if (_i > 0) setState(() => _i--);
  }

  void _finish() {
    final app = Provider.of<AppState>(context, listen: false);
    app.markFeatureTourSeen();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_i];
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF13315F), Color(0xFF0C1E3C)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Step ${_i + 1} of ${_steps.length}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (!_isLast)
                        TextButton(
                          onPressed: _finish,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withValues(alpha: 0.7),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text('Skip'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Column(
                      key: ValueKey(_i),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: [
                                step.accent,
                                Color.lerp(step.accent, Colors.black, 0.28)!,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: step.accent.withValues(alpha: 0.4),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: Icon(step.icon, color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          step.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          step.body,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 14.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      _Dots(count: _steps.length, index: _i),
                      const Spacer(),
                      if (_i > 0)
                        TextButton(
                          onPressed: _back,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withValues(alpha: 0.8),
                          ),
                          child: const Text('Back'),
                        ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: fblaGold,
                          foregroundColor: fblaNavy,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _isLast ? 'Get started' : 'Next',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(right: 6),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? fblaGold : Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
