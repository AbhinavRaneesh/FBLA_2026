import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../main.dart' show AppState, appBackgroundGradient, fblaGold;
import '../ai/models/chat_message_model.dart';
import '../ai/repos/gemini_repo.dart';
import '../models/nlc_practice_scenarios.dart';
import '../models/nlc_rubric_result.dart';
import '../models/practice_record.dart';
import '../services/firebase_service.dart';
import '../services/nlc_demo_mode.dart';
import '../services/nlc_prep_service.dart';
import '../services/practice_history_store.dart';
import '../social/screens/bluewave_compose_screen.dart';

/// Practice experience for performance-based events (roleplay & presentation).
/// Two modes: an AI Coach (scenario + rubric feedback) and self-record
/// (camera + rubric self-assessment).
class EventPracticeScreen extends StatefulWidget {
  final String eventName;
  final String category;
  final Color color;
  final int initialTab;

  const EventPracticeScreen({
    super.key,
    required this.eventName,
    required this.category,
    this.color = const Color(0xFF64B5F6),
    this.initialTab = 0,
  });

  static Future<void> open(BuildContext context,
      {required String eventName,
      required String category,
      Color? color,
      int initialTab = 0}) {
    return Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => EventPracticeScreen(
        eventName: eventName,
        category: category,
        color: color ?? const Color(0xFF64B5F6),
        initialTab: initialTab,
      ),
    ));
  }

  bool get _isRoleplay => category.toLowerCase().contains('roleplay');

  @override
  State<EventPracticeScreen> createState() => _EventPracticeScreenState();
}

class _EventPracticeScreenState extends State<EventPracticeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // Bumped whenever a practice session is saved, so the History tab reloads.
  final ValueNotifier<int> _historyVersion = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    _historyVersion.dispose();
    super.dispose();
  }

  void _onSessionSaved() => _historyVersion.value++;

  NlcCuratedPractice get _practice =>
      nlcPracticeForEvent(widget.eventName, category: widget.category);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.eventName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            Text(widget._isRoleplay ? 'Roleplay practice' : 'Presentation practice',
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _CoachTab(
                        practice: _practice,
                        eventName: widget.eventName,
                        category: widget.category,
                        color: widget.color,
                        isRoleplay: widget._isRoleplay,
                        onSaved: _onSessionSaved),
                    _RecordTab(
                        practice: _practice,
                        eventName: widget.eventName,
                        category: widget.category,
                        color: widget.color,
                        onSaved: _onSessionSaved),
                    _HistoryTab(
                        eventName: widget.eventName,
                        color: widget.color,
                        refresh: _historyVersion),
                    _LiveSimTab(
                        practice: _practice,
                        eventName: widget.eventName,
                        category: widget.category,
                        color: widget.color,
                        isRoleplay: widget._isRoleplay,
                        onSaved: _onSessionSaved),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
            color: widget.color, borderRadius: BorderRadius.circular(10)),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade400,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        tabs: const [
          Tab(height: 42, child: Text('AI Coach')),
          Tab(height: 42, child: Text('Record')),
          Tab(height: 42, child: Text('History')),
          Tab(height: 42, child: Text('Live Sim')),
        ],
      ),
    );
  }
}

/* ----------------------------- Coach tab ----------------------------- */

class _CoachTab extends StatefulWidget {
  final NlcCuratedPractice practice;
  final String eventName;
  final String category;
  final Color color;
  final bool isRoleplay;
  final VoidCallback onSaved;

  const _CoachTab({
    required this.practice,
    required this.eventName,
    required this.category,
    required this.color,
    required this.isRoleplay,
    required this.onSaved,
  });

  @override
  State<_CoachTab> createState() => _CoachTabState();
}

class _CoachTabState extends State<_CoachTab> {
  final TextEditingController _response = TextEditingController();
  bool _loading = false;
  String? _feedback;
  bool _aiUnavailable = false;

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  Future<void> _getFeedback() async {
    final answer = _response.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Write your response first, then get feedback.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() {
      _loading = true;
      _feedback = null;
      _aiUnavailable = false;
    });

    final prompt = '''
You are an experienced FBLA competitive-events judge and coach for the "${widget.eventName}" event (${widget.category}).

TASK / SCENARIO:
${widget.practice.scenario}

PERFORMANCE INDICATORS judges score:
${widget.practice.indicators.map((i) => '- $i').join('\n')}

The student's ${widget.isRoleplay ? 'roleplay response' : 'presentation outline'}:
"""
$answer
"""

Give concise coaching feedback in this format:
✅ Strengths: 2 specific things they did well (tie to the indicators).
🔧 Improve: 2 specific, actionable fixes (tie to the indicators).
🎤 Judge follow-up: one realistic question a judge might ask next.
Keep it under 180 words, encouraging but honest.''';

    try {
      final reply = await GeminiRepo.chatTextGenerationRepo(
          [ChatMessageModel.user(prompt)]);
      if (!mounted) return;
      final unavailable = _isAiUnavailableReply(reply);
      setState(() {
        _loading = false;
        if (unavailable) {
          _aiUnavailable = true;
        } else {
          _feedback = reply;
        }
      });
      if (!unavailable) {
        // Save this coaching session so the member can revisit the feedback.
        await PracticeHistoryStore.add(PracticeRecord(
          eventName: widget.eventName,
          category: widget.category,
          type: 'coach',
          timestamp: DateTime.now(),
          aiFeedback: reply,
        ));
        widget.onSaved();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _aiUnavailable = true;
      });
    }
  }

  /// True when [reply] is one of GeminiRepo's failure/sign-in strings rather
  /// than real coaching feedback — so we never show or save an error as advice.
  static bool _isAiUnavailableReply(String reply) {
    final lower = reply.toLowerCase();
    const signatures = [
      'ai assistant error',
      'sign in to use the ai assistant',
      'openrouter',
      'temporarily busy',
      'quota limit',
      'no api key',
      'api key is set',
    ];
    return signatures.any(lower.contains);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        _sectionCard(
          icon: Icons.assignment_outlined,
          title: widget.isRoleplay ? 'Your Scenario' : 'Your Topic',
          child: Text(widget.practice.scenario,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14.5, height: 1.5)),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          icon: Icons.checklist_rounded,
          title: 'What Judges Look For',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.practice.indicators
                .map((i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.arrow_right_rounded,
                              color: widget.color, size: 20),
                          Expanded(
                            child: Text(i,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13.5,
                                    height: 1.35)),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          icon: Icons.edit_note_rounded,
          title: widget.isRoleplay
              ? 'Draft Your Response'
              : 'Outline Your Key Points',
          child: TextField(
            controller: _response,
            maxLines: 6,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.isRoleplay
                  ? 'Greet the judge, identify the problem, propose your solution, justify it...'
                  : 'Hook, main points, evidence, call to action...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.color, width: 1.4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _getFeedback,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(_loading ? 'Coaching…' : 'Get AI Feedback'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white12,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        if (_feedback != null) ...[
          const SizedBox(height: 16),
          _sectionCard(
            icon: Icons.auto_awesome_rounded,
            title: 'Coach Feedback',
            accent: fblaGold,
            child: Text(_feedback!,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.5)),
          ),
        ],
        if (_aiUnavailable) ...[
          const SizedBox(height: 16),
          _sectionCard(
            icon: Icons.info_outline_rounded,
            title: 'Self-Assess',
            accent: fblaGold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI coaching needs a Gemini API key. In the meantime, score yourself against the indicators above — be honest about what a judge would notice.',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 13.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
    Color? accent,
  }) {
    final c = accent ?? widget.color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: c, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/* ----------------------------- Record tab ----------------------------- */

class _RecordTab extends StatefulWidget {
  final NlcCuratedPractice practice;
  final String eventName;
  final String category;
  final Color color;
  final VoidCallback onSaved;

  const _RecordTab({
    required this.practice,
    required this.eventName,
    required this.category,
    required this.color,
    required this.onSaved,
  });

  @override
  State<_RecordTab> createState() => _RecordTabState();
}

class _RecordTabState extends State<_RecordTab> {
  VideoPlayerController? _controller;
  bool _busy = false;
  final Set<int> _checked = {};

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 7),
      );
      if (file == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      await _controller?.dispose();
      final controller = VideoPlayerController.file(File(file.path));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not record video: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  Future<void> _saveAssessment() async {
    await PracticeHistoryStore.add(PracticeRecord(
      eventName: widget.eventName,
      category: widget.category,
      type: 'record',
      timestamp: DateTime.now(),
      rubricChecked: _checked.length,
      rubricTotal: widget.practice.indicators.length,
    ));
    widget.onSaved();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Saved to your practice history.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        if (c != null && c.value.isInitialized)
          GestureDetector(
            onTap: _togglePlay,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(c),
                    if (!c.value.isPlaying)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 40),
                      ),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_outlined,
                      color: widget.color, size: 40),
                  const SizedBox(height: 10),
                  const Text('Record yourself practicing',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Then play it back and score yourself below.',
                      style: TextStyle(color: Colors.white54, fontSize: 12.5)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _record,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(c == null
                    ? Icons.fiber_manual_record_rounded
                    : Icons.replay_rounded),
            label: Text(c == null ? 'Record' : 'Record Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: c == null ? const Color(0xFFE53935) : widget.color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white12,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.rule_rounded, color: widget.color, size: 18),
            const SizedBox(width: 8),
            const Text('Score Yourself',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('${_checked.length}/${widget.practice.indicators.length}',
                style: TextStyle(
                    color: widget.color, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(widget.practice.indicators.length, (i) {
          final done = _checked.contains(i);
          return GestureDetector(
            onTap: () => setState(() =>
                done ? _checked.remove(i) : _checked.add(i)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: done
                    ? widget.color.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: done
                        ? widget.color
                        : Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: done ? widget.color : Colors.white38,
                      size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.practice.indicators[i],
                        style: TextStyle(
                            color: done ? Colors.white : Colors.white70,
                            fontSize: 13.5,
                            height: 1.35)),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _checked.isEmpty ? null : _saveAssessment,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save to History'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.color,
              disabledForegroundColor: Colors.white24,
              side: BorderSide(
                  color: _checked.isEmpty ? Colors.white12 : widget.color),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

/* ----------------------------- History tab ----------------------------- */

class _HistoryTab extends StatefulWidget {
  final String eventName;
  final Color color;
  final ValueNotifier<int> refresh;

  const _HistoryTab({
    required this.eventName,
    required this.color,
    required this.refresh,
  });

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  late Future<List<PracticeRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = PracticeHistoryStore.allForEvent(widget.eventName);
    widget.refresh.addListener(_reload);
  }

  @override
  void dispose() {
    widget.refresh.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = PracticeHistoryStore.allForEvent(widget.eventName);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PracticeRecord>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: widget.color),
          );
        }
        final records = snapshot.data ?? const [];
        if (records.isEmpty) {
          return _emptyState();
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _headerCard(records.length),
            const SizedBox(height: 14),
            ...records.map(_recordCard),
          ],
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, color: widget.color, size: 44),
            const SizedBox(height: 14),
            const Text('No practice yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Get AI feedback or save a self-assessment, and your sessions will show up here so you can track progress.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCard(int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          widget.color.withValues(alpha: 0.20),
          widget.color.withValues(alpha: 0.06),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: widget.color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Practiced ${count}×',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(widget.eventName,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordCard(PracticeRecord r) {
    final when = DateFormat('MMM d, h:mm a').format(r.timestamp);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(r.isCoach
                      ? Icons.auto_awesome_rounded
                      : r.isLiveSim
                          ? Icons.gavel_rounded
                          : Icons.videocam_rounded,
                  color: r.isCoach || r.isLiveSim ? fblaGold : widget.color,
                  size: 18),
              const SizedBox(width: 8),
              Text(
                  r.isCoach
                      ? 'AI Coach feedback'
                      : r.isLiveSim
                          ? 'Live Sim rubric'
                          : 'Self-assessment',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(when,
                  style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 10),
          if (r.isRecord)
            Text(
              'Scored yourself ${r.rubricChecked ?? 0}/${r.rubricTotal ?? 0} on the rubric.',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13.5, height: 1.4),
            )
          else if (r.isLiveSim)
            Text(
              'Live Sim score: ${r.rubricOverall?.toStringAsFixed(1) ?? '—'}/5',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13.5, height: 1.4),
            )
          else
            Text(
              r.aiFeedback ?? '',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13.5, height: 1.45),
            ),
        ],
      ),
    );
  }
}

/* ----------------------------- Live Sim tab ----------------------------- */

enum _LiveSimPhase { intro, prep, perform, judging, results }

class _LiveSimTab extends StatefulWidget {
  final NlcCuratedPractice practice;
  final String eventName;
  final String category;
  final Color color;
  final bool isRoleplay;
  final VoidCallback onSaved;

  const _LiveSimTab({
    required this.practice,
    required this.eventName,
    required this.category,
    required this.color,
    required this.isRoleplay,
    required this.onSaved,
  });

  @override
  State<_LiveSimTab> createState() => _LiveSimTabState();
}

class _LiveSimTabState extends State<_LiveSimTab> {
  _LiveSimPhase _phase = _LiveSimPhase.intro;
  int _prepSeconds = 600;
  Timer? _timer;
  final TextEditingController _response = TextEditingController();
  bool _demoMode = false;
  bool _judging = false;
  NlcRubricResult? _result;
  double? _previousScore;

  @override
  void initState() {
    super.initState();
    _loadPreviousScore();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _response.dispose();
    super.dispose();
  }

  Future<void> _loadPreviousScore() async {
    final records = await PracticeHistoryStore.allForEvent(widget.eventName);
    for (final r in records) {
      if (r.isLiveSim && r.rubricOverall != null) {
        if (mounted) setState(() => _previousScore = r.rubricOverall);
        break;
      }
    }
  }

  void _startPrep() {
    setState(() {
      _phase = _LiveSimPhase.prep;
      _prepSeconds = 600;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_prepSeconds <= 1) {
        t.cancel();
        HapticFeedback.mediumImpact();
        setState(() => _phase = _LiveSimPhase.perform);
      } else {
        setState(() => _prepSeconds--);
        if (_prepSeconds == 60) HapticFeedback.lightImpact();
      }
    });
  }

  Future<void> _submitForJudging() async {
    final answer = _response.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter your response before submitting to the judge.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() {
      _phase = _LiveSimPhase.judging;
      _judging = true;
      _result = null;
    });

    NlcRubricResult? parsed;

    if (_demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      parsed = NlcDemoMode.bundledRubric(widget.eventName);
    } else {
      final prompt = '''
Event: ${widget.eventName} (${widget.category})
Scenario: ${widget.practice.scenario}
Indicators:
${widget.practice.indicators.map((i) => '- $i').join('\n')}

Student response:
"""
$answer
"""''';

      try {
        final raw = await GeminiRepo.rubricJudge(prompt);
        parsed = NlcRubricResult.tryParse(raw);
      } catch (_) {
        parsed = null;
      }

      if (parsed == null && NlcDemoMode.supportsOffline(widget.eventName)) {
        parsed = NlcDemoMode.bundledRubric(widget.eventName);
      }
    }

    if (!mounted) return;

    if (parsed == null) {
      setState(() {
        _judging = false;
        _phase = _LiveSimPhase.perform;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not get rubric scores. Try Demo Mode or check your connection.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final result = parsed;
    await PracticeHistoryStore.add(PracticeRecord(
      eventName: widget.eventName,
      category: widget.category,
      type: 'live_sim',
      timestamp: DateTime.now(),
      rubricOverall: result.overallScore,
      rubricJson: result.toJsonString(),
    ));

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await NlcPrepService.recordPracticeSession(userId);
      await FirebaseService.awardPoints(userId, 15);
      if (!mounted) return;
      await context.read<AppState>().refreshUserProfile();
    }

    widget.onSaved();
    if (!mounted) return;
    setState(() {
      _result = result;
      _judging = false;
      _phase = _LiveSimPhase.results;
    });
  }

  void _reset() {
    _timer?.cancel();
    _response.clear();
    setState(() {
      _phase = _LiveSimPhase.intro;
      _result = null;
      _prepSeconds = 600;
    });
  }

  Future<void> _shareToBlueWave() async {
    final score = _result?.overallScore;
    if (score == null) return;
    final app = context.read<AppState>();
    final name = app.resolvedDisplayName;
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlueWaveComposeScreen(
          initialText:
              '$name completed ${widget.eventName} Live Sim — scored ${score.toStringAsFixed(1)}/5. #NLCReady #FBLA',
          initialTags: const ['NLCReady', 'FBLA'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        if (_demoMode)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fblaGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: fblaGold.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.offline_bolt_rounded, color: fblaGold, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Offline demo — bundled rubric for judges. Live AI when connected.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        SwitchListTile(
          value: _demoMode,
          onChanged: (v) => setState(() => _demoMode = v),
          title: const Text('Demo for judges (offline)',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          subtitle: const Text('Uses bundled rubric — works in airplane mode.',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          activeThumbColor: fblaGold,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        if (_phase == _LiveSimPhase.intro) ...[
          _liveCard(
            icon: Icons.gavel_rounded,
            title: 'Live Simulation',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.practice.scenario,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14.5, height: 1.5)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _startPrep,
                    icon: const Icon(Icons.timer_rounded),
                    label: const Text('Reveal & Start 10:00 Prep'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_phase == _LiveSimPhase.prep) ...[
          _liveCard(
            icon: Icons.timer_rounded,
            title: 'Prep time',
            child: Column(
              children: [
                Text(
                  '${(_prepSeconds ~/ 60).toString().padLeft(2, '0')}:${(_prepSeconds % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: widget.color,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Plan your response. Timer auto-advances when prep ends.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _timer?.cancel();
                    setState(() => _phase = _LiveSimPhase.perform);
                  },
                  child: const Text('Skip to perform early'),
                ),
              ],
            ),
          ),
        ],
        if (_phase == _LiveSimPhase.perform) ...[
          _liveCard(
            icon: Icons.mic_rounded,
            title: widget.isRoleplay ? 'Perform your roleplay' : 'Deliver your presentation',
            child: TextField(
              controller: _response,
              maxLines: 8,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Type your response as you would deliver it to the judge…',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _submitForJudging,
              icon: const Icon(Icons.gavel_rounded),
              label: const Text('Submit to AI Judge'),
              style: ElevatedButton.styleFrom(
                backgroundColor: fblaGold,
                foregroundColor: const Color(0xFF07111F),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
        if (_phase == _LiveSimPhase.judging && _judging)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: fblaGold),
                  SizedBox(height: 12),
                  Text('AI judge scoring your performance…',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        if (_phase == _LiveSimPhase.results && _result != null) ...[
          _buildScoreRing(_result!.overallScore),
          if (_previousScore != null) ...[
            const SizedBox(height: 8),
            Text(
              'Previous best: ${_previousScore!.toStringAsFixed(1)}/5',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          ..._result!.dimensions.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _liveCard(
                icon: Icons.star_rounded,
                title: '${d.indicator} — ${d.score}/5',
                child: Text(d.evidence,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13.5, height: 1.4)),
              ),
            ),
          ),
          _liveCard(
            icon: Icons.build_rounded,
            title: 'Top fix before NLC',
            accent: fblaGold,
            child: Text(_result!.topFix,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.45)),
          ),
          const SizedBox(height: 10),
          _liveCard(
            icon: Icons.question_answer_rounded,
            title: 'Judge follow-up',
            child: Text(_result!.judgeQuestion,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 14, height: 1.45)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareToBlueWave,
                  icon: const Icon(Icons.waves_rounded, size: 18),
                  label: const Text('Share to BlueWave'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: fblaGold,
                    side: BorderSide(color: fblaGold.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _reset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Run again'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildScoreRing(double score) {
    final pct = (score / 5).clamp(0.0, 1.0);
    return Center(
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: pct,
              strokeWidth: 10,
              backgroundColor: Colors.white12,
              color: fblaGold,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text('/ 5',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveCard({
    required IconData icon,
    required String title,
    required Widget child,
    Color? accent,
  }) {
    final c = accent ?? widget.color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: c, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
