import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../main.dart' show appBackgroundGradient, fblaGold;
import '../ai/models/chat_message_model.dart';
import '../ai/repos/gemini_repo.dart';
import '../models/practice_record.dart';
import '../services/practice_history_store.dart';

/// Practice experience for performance-based events (roleplay & presentation).
/// Two modes: an AI Coach (scenario + rubric feedback) and self-record
/// (camera + rubric self-assessment).
class EventPracticeScreen extends StatefulWidget {
  final String eventName;
  final String category;
  final Color color;

  const EventPracticeScreen({
    super.key,
    required this.eventName,
    required this.category,
    this.color = const Color(0xFF64B5F6),
  });

  static void open(BuildContext context,
      {required String eventName, required String category, Color? color}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EventPracticeScreen(
        eventName: eventName,
        category: category,
        color: color ?? const Color(0xFF64B5F6),
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
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _historyVersion.dispose();
    super.dispose();
  }

  void _onSessionSaved() => _historyVersion.value++;

  _CuratedPractice get _practice =>
      _curatedPractice[widget.eventName] ??
      (widget._isRoleplay ? _genericRoleplay : _genericPresentation);

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
        ],
      ),
    );
  }
}

/* ----------------------------- Coach tab ----------------------------- */

class _CoachTab extends StatefulWidget {
  final _CuratedPractice practice;
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
      final lower = reply.toLowerCase();
      final noKey =
          lower.contains('no api key') || lower.contains('api key is set');
      setState(() {
        _loading = false;
        if (noKey) {
          _aiUnavailable = true;
        } else {
          _feedback = reply;
        }
      });
      if (!noKey) {
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
  final _CuratedPractice practice;
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
              Icon(r.isCoach ? Icons.auto_awesome_rounded : Icons.videocam_rounded,
                  color: r.isCoach ? fblaGold : widget.color, size: 18),
              const SizedBox(width: 8),
              Text(r.isCoach ? 'AI Coach feedback' : 'Self-assessment',
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

/* ----------------------------- Content ----------------------------- */

class _CuratedPractice {
  final String scenario;
  final List<String> indicators;
  const _CuratedPractice({required this.scenario, required this.indicators});
}

const _genericRoleplay = _CuratedPractice(
  scenario:
      'You are a business professional meeting with a client (the judge). You have 10 minutes to prepare, then present your recommendation and answer their questions. Greet them, identify the core problem, propose a clear solution, and justify it with business reasoning.',
  indicators: [
    'Greets the judge professionally and establishes rapport',
    'Clearly identifies the problem or objective',
    'Proposes a specific, realistic solution',
    'Justifies the solution with sound business concepts',
    'Communicates with confidence and clear organization',
    'Answers follow-up questions thoughtfully',
  ],
);

const _genericPresentation = _CuratedPractice(
  scenario:
      'Prepare a presentation on the current event topic. Deliver it to a panel of judges with visual aids, then answer their questions. Focus on a clear structure, strong evidence, and confident delivery.',
  indicators: [
    'Opens with a clear hook and purpose',
    'Content is well-organized and addresses the prompt',
    'Uses credible evidence and examples',
    'Visual aids are clean and support the message',
    'Delivery is confident with good eye contact and pacing',
    'Handles Q&A accurately and calmly',
  ],
);

// Curated showcase events (hybrid: these work fully offline).
const Map<String, _CuratedPractice> _curatedPractice = {
  'Marketing': _CuratedPractice(
    scenario:
        'A local coffee shop has seen sales drop 20% after a national chain opened nearby. The owner (judge) wants a marketing strategy to win customers back within three months on a small budget. Present your plan and justify your choices.',
    indicators: [
      'Identifies the target customer and the shop’s competitive edge',
      'Proposes a clear marketing mix (product, price, place, promotion)',
      'Recommends realistic, low-cost promotion tactics',
      'Explains how success will be measured',
      'Communicates persuasively and professionally',
      'Defends the plan under judge questions',
    ],
  ),
  'Public Speaking': _CuratedPractice(
    scenario:
        'Prepare and deliver a 4-minute speech on: "How can young people use business skills to strengthen their local community?" You will be judged on content, organization, and delivery.',
    indicators: [
      'Strong opening that grabs attention',
      'Clear thesis and logical structure',
      'Specific examples and evidence',
      'Confident delivery: eye contact, pace, and projection',
      'Memorable, purposeful conclusion',
      'Stays within the time limit',
    ],
  ),
  'Entrepreneurship': _CuratedPractice(
    scenario:
        'Your team is pitching a new small-business idea to investors (the judges). Present the concept, target market, revenue model, and why your team can execute it.',
    indicators: [
      'Clear, compelling business concept',
      'Well-defined target market and need',
      'Realistic revenue and cost model',
      'Evidence the team can execute',
      'Confident, organized team delivery',
      'Strong answers to investor questions',
    ],
  ),
};
