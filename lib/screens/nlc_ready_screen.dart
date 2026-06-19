import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/fbla_events.dart';
import '../models/nlc_practice_scenarios.dart';
import '../services/nlc_prep_service.dart';
import '../services/practice_history_store.dart';
import 'event_practice_screen.dart';

class _DailyTask {
  final String id;
  final String label;
  const _DailyTask(this.id, this.label);
}

class NlcReadyScreen extends StatefulWidget {
  final VoidCallback? onOpenResourcesTab;

  const NlcReadyScreen({super.key, this.onOpenResourcesTab});

  @override
  State<NlcReadyScreen> createState() => _NlcReadyScreenState();
}

class _NlcReadyScreenState extends State<NlcReadyScreen> {
  bool _loading = true;
  List<String> _selectedEvents = [];
  int _prepStreak = 0;
  Set<String> _dailyTasks = {};
  Map<String, int> _sessionCounts = {};

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final events = await NlcPrepService.loadNlcEvents(userId);
    final streak = await NlcPrepService.loadPrepStreak(userId);
    final tasks = await NlcPrepService.loadCompletedDailyTasks();
    final counts = <String, int>{};
    for (final event in events) {
      counts[event] = await PracticeHistoryStore.countForEvent(event);
    }

    if (!mounted) return;
    setState(() {
      _selectedEvents = events;
      _prepStreak = streak;
      _dailyTasks = tasks;
      _sessionCounts = counts;
      _loading = false;
    });
  }

  Future<void> _pickEvents() async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NlcEventPickerSheet(initial: _selectedEvents),
    );
    if (picked == null || _userId == null) return;

    await NlcPrepService.saveNlcEvents(_userId!, picked);
    if (!mounted) return;
    setState(() => _selectedEvents = picked);
    await _load();
    if (!mounted) return;
    await context.read<AppState>().refreshUserProfile();
  }

  Future<void> _toggleTask(String id) async {
    final next = !_dailyTasks.contains(id);
    await NlcPrepService.toggleDailyTask(id, next);
    if (!mounted) return;
    setState(() {
      if (next) {
        _dailyTasks = {..._dailyTasks, id};
      } else {
        _dailyTasks = {..._dailyTasks}..remove(id);
      }
    });

    if (_userId != null && _dailyTasks.length >= 3) {
      final awarded = await NlcPrepService.claimDailyRewardIfEligible(_userId!);
      if (awarded && mounted) {
        await context.read<AppState>().refreshUserProfile();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Daily prep complete! +25 F-Bucks'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _startLiveSim(String eventName) {
    final option = fblaEventCatalog.firstWhere(
      (e) => e.name == eventName,
      orElse: () => FblaEventOption(eventName, 'Roleplay Events'),
    );
    EventPracticeScreen.open(
      context,
      eventName: eventName,
      category: option.category,
      initialTab: 3,
    ).then((_) => _load());
  }

  Future<void> _openStudyResources(String eventName) async {
    await NlcPrepService.pinCourseForResources(eventName);
    if (!mounted) return;
    widget.onOpenResourcesTab?.call();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Added $eventName to Resources — open the Resources tab to study.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDarkMode;
    final days = NlcPrepService.daysUntilNlc();

    return Scaffold(
      backgroundColor: isDark ? appBackgroundColor : fblaLightBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? appBackgroundGradient : null,
          color: isDark ? null : fblaLightBackground,
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: fblaGold))
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(isDark, days)),
                    if (_userId == null)
                      SliverFillRemaining(
                        child: _buildSignInPrompt(isDark),
                      )
                    else if (_selectedEvents.isEmpty)
                      SliverFillRemaining(
                        child: _buildEmptyState(isDark),
                      )
                    else ...[
                      SliverToBoxAdapter(child: _buildDailyPrep(isDark)),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final event = _selectedEvents[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildEventCard(isDark, event),
                              );
                            },
                            childCount: _selectedEvents.length,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, int days) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0B1624), const Color(0xFF1D4E89)]
              : [fblaBlue, const Color(0xFF2563A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: fblaBlue.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: fblaGold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: fblaGold.withValues(alpha: 0.45)),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: fblaGold, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NLC Ready',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Competition Command Center',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit events',
                onPressed: _pickEvents,
                icon: const Icon(Icons.tune_rounded, color: fblaGold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statChip(
                  Icons.timer_outlined,
                  days > 0 ? '$days days to NLC' : 'NLC is here!',
                ),
                _statChip(
                  Icons.local_fire_department_rounded,
                  '$_prepStreak-day streak',
                ),
                _statChip(
                  Icons.fitness_center_rounded,
                  '${_selectedEvents.length} event${_selectedEvents.length == 1 ? '' : 's'}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Personalized prep for San Antonio — practice with a live simulator and AI rubric judge.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fblaGold, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyPrep(bool isDark) {
    const tasks = [
      _DailyTask('vocab', 'Review 10 vocab or study terms'),
      _DailyTask('sim', 'Complete 1 Live Sim practice'),
      _DailyTask('rubric', 'Review judges\' rubric indicators'),
    ];
    final surface = isDark ? const Color(0xFF101827) : fblaLightSurface;
    final border = isDark ? Colors.white12 : fblaLightBorder;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded,
                  color: isDark ? fblaGold : fblaBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Today\'s prep plan',
                style: TextStyle(
                  color: isDark ? Colors.white : fblaLightPrimaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${_dailyTasks.length}/3',
                style: TextStyle(
                  color: isDark ? fblaGold : fblaBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tasks.map((task) {
            final checked = _dailyTasks.contains(task.id);
            return CheckboxListTile(
              value: checked,
              onChanged: (_) => _toggleTask(task.id),
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: fblaGold,
              title: Text(
                task.label,
                style: TextStyle(
                  color: isDark ? Colors.white70 : fblaLightSecondaryText,
                  fontSize: 14,
                  decoration: checked ? TextDecoration.lineThrough : null,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
          if (_dailyTasks.length >= 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'All tasks done — +25 F-Bucks when claimed once today.',
                style: TextStyle(
                  color: fblaGold.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventCard(bool isDark, String eventName) {
    final option = fblaEventCatalog.firstWhere(
      (e) => e.name == eventName,
      orElse: () => FblaEventOption(eventName, 'Roleplay Events'),
    );
    final sessions = _sessionCounts[eventName] ?? 0;
    final liveSim = nlcSupportsLiveSim(eventName, option.category);
    final surface = isDark ? const Color(0xFF101827) : fblaLightSurface;
    final border = isDark ? Colors.white12 : fblaLightBorder;
    final titleColor = isDark ? Colors.white : fblaLightPrimaryText;
    final subtitleColor = isDark ? Colors.white60 : fblaLightSecondaryText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eventName,
              style: TextStyle(
                  color: titleColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            '${option.category} · $sessions practice session${sessions == 1 ? '' : 's'}',
            style: TextStyle(color: subtitleColor, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (liveSim)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startLiveSim(eventName),
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: const Text('Start Live Simulation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: fblaGold,
                  foregroundColor: fblaNavy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ),
          if (liveSim) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openStudyResources(eventName),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Study pack'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? fblaGold : fblaBlue,
                    side: BorderSide(
                        color: (isDark ? fblaGold : fblaBlue)
                            .withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    EventPracticeScreen.open(
                      context,
                      eventName: eventName,
                      category: option.category,
                      initialTab: 0,
                    ).then((_) => _load());
                  },
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: const Text('AI Coach'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? fblaGold : fblaBlue,
                    side: BorderSide(
                        color: (isDark ? fblaGold : fblaBlue)
                            .withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 56,
                color: isDark ? fblaGold : fblaBlue),
            const SizedBox(height: 16),
            Text(
              'Which events are you competing in at NLC?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : fblaLightPrimaryText,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Select your events to unlock a personalized prep dashboard with Live Sim, AI coaching, and daily tasks.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : fblaLightSecondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickEvents,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Choose My NLC Events'),
              style: ElevatedButton.styleFrom(
                backgroundColor: fblaGold,
                foregroundColor: fblaNavy,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInPrompt(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Sign in to personalize your NLC prep dashboard.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white70 : fblaLightSecondaryText,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class NlcEventPickerSheet extends StatefulWidget {
  final List<String> initial;

  const NlcEventPickerSheet({super.key, required this.initial});

  @override
  State<NlcEventPickerSheet> createState() => NlcEventPickerSheetState();
}

class NlcEventPickerSheetState extends State<NlcEventPickerSheet> {
  late Set<String> _picked;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _picked = widget.initial.toSet();
  }

  List<FblaEventOption> get _filtered {
    if (_filter == 'All') return fblaEventCatalog;
    return fblaEventCatalog.where((e) => e.category == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF0B1624),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'My NLC Events',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _picked.toList()),
                  child: const Text('Done',
                      style: TextStyle(
                          color: fblaGold, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: fblaEventCategories.map((cat) {
                final selected = _filter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = cat),
                    selectedColor: fblaGold.withValues(alpha: 0.25),
                    checkmarkColor: fblaGold,
                    labelStyle: TextStyle(
                      color: selected ? fblaGold : Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final event = _filtered[index];
                final checked = _picked.contains(event.name);
                return CheckboxListTile(
                  value: checked,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _picked.add(event.name);
                      } else {
                        _picked.remove(event.name);
                      }
                    });
                  },
                  title: Text(event.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text(event.category,
                      style: const TextStyle(color: Colors.white54)),
                  activeColor: fblaGold,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
