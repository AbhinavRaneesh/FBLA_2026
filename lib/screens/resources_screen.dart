import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/fbla_events.dart';

// Local theme constants (kept here to avoid circular imports)
const Color fblaGold = Color(0xFFFDB913);
const Color fblaNavy = Color(0xFF1D4E89);
const Color fblaAccent = Color(0xFF64B5F6);

const LinearGradient appBackgroundGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF061726), Color(0xFF071A2A)],
);

IconData courseIconForName(String name) {
  final n = name.toLowerCase();
  if (n.contains('code') || n.contains('program') || n.contains('coding')) return Icons.code;
  if (n.contains('business') || n.contains('plan') || n.contains('management')) return Icons.business;
  if (n.contains('finance') || n.contains('bank') || n.contains('account')) return Icons.account_balance;
  if (n.contains('marketing') || n.contains('sales')) return Icons.campaign;
  if (n.contains('video') || n.contains('digital') || n.contains('animation')) return Icons.video_collection;
  if (n.contains('public') || n.contains('speaking') || n.contains('speech')) return Icons.record_voice_over;
  return Icons.school;
}

String courseShortFormForName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[&/\-]'), ' ')
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final parts = cleaned.split(' ').where((part) {
    final lower = part.toLowerCase();
    return part.isNotEmpty &&
        lower != 'and' &&
        lower != 'of' &&
        lower != 'the' &&
        lower != 'to' &&
        lower != 'in' &&
        lower != 'for' &&
        lower != 'with';
  }).toList();

  final letters = <String>[];
  for (final part in parts) {
    final match = RegExp(r'[A-Za-z0-9]').firstMatch(part);
    if (match != null) {
      letters.add(match.group(0)!.toUpperCase());
    }
  }

  if (letters.isEmpty) return 'FBLA';
  return letters.join('.');
}

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({Key? key}) : super(key: key);

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final List<String> _userCourses = [];
  String? _selectedCourse;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('userCourses') ?? <String>[];
      setState(() {
        _userCourses.clear();
        _userCourses.addAll(saved);
        if (_userCourses.isNotEmpty) _selectedCourse = _userCourses.first;
      });
    } catch (_) {}
  }

  Future<void> _saveCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('userCourses', _userCourses);
    } catch (_) {}
  }

  void _selectCourse(String course) {
    setState(() => _selectedCourse = course);
  }

  void _openCoursePicker() => _showCoursePanel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                _buildTopStatsBar(),
                const SizedBox(height: 12),
                Expanded(child: _buildCourseJourney()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseJourney() {
    final course = _selectedCourse ?? (_userCourses.isNotEmpty ? _userCourses.first : null);

    if (course == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [fblaGold.withOpacity(0.95), const Color(0xFFFFE082)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: fblaGold.withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.route, color: fblaNavy, size: 44),
              ),
              const SizedBox(height: 18),
              const Text(
                'Pick a course to begin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Choose one of your saved courses to unlock the level path and see your next step.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      child: _CourseJourneyPanel(
        key: ValueKey(course),
        course: course,
        color: _courseColor(course),
        icon: _courseIcon(course),
      ),
    );
  }

  Widget _buildTopStatsBar() {
    final rand = Random();
    final selectedCourseShortForm = _selectedCourse == null
        ? 'COURSE'
        : courseShortFormForName(_selectedCourse!);

    Widget statInline(
      Widget iconWidget, {
      int? value,
      bool hideValue = false,
      VoidCallback? onTap,
    }) {
      final displayValue = value ?? rand.nextInt(1000);
      final content = hideValue
          ? iconWidget
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                const SizedBox(width: 6),
                Text(
                  '$displayValue',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                ),
              ],
            );

      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: content,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: _openCoursePicker,
              behavior: HitTestBehavior.opaque,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _selectedCourse == null
                          ? Icons.school
                          : courseIconForName(_selectedCourse!),
                      color: _selectedCourse == null
                          ? fblaGold
                          : _courseColor(_selectedCourse!),
                      size: 27,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        selectedCourseShortForm,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: statInline(
              const Icon(Icons.local_fire_department,
                  color: Color(0xFFFF7043), size: 31),
              hideValue: true,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: statInline(
              Image.asset('assets/coins.png', width: 30, height: 30),
              hideValue: true,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: statInline(
              const Icon(Icons.leaderboard,
                  color: Color(0xFF66BB6A), size: 31),
              hideValue: true,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCoursePanel() async {
    final screenHeight = MediaQuery.of(context).size.height;
    final topOffset = MediaQuery.of(context).padding.top + 72;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> addCourse() async {
                dynamic appState;
                try {
                  appState = Provider.of<dynamic>(context, listen: false);
                } catch (_) {}
                final selected = await Navigator.push<String>(
                  dialogContext,
                  MaterialPageRoute(builder: (_) => const CourseSelectionScreen()),
                );
                if (selected != null && selected.isNotEmpty) {
                  setState(() {
                    if (!_userCourses.contains(selected)) {
                      _userCourses.add(selected);
                    }
                    _selectedCourse = selected;
                  });
                  await _saveCourses();
                  setModalState(() {});
                  if (appState != null) {
                    try {
                      await appState.addUserCourse?.call(selected);
                    } catch (_) {}
                  }
                }
              }

              final panel = Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: topOffset,
                    left: 12,
                    right: 12,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      height: screenHeight * 0.31,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1624),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 6),
                          Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 9, 16, 4),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Courses',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Text(
                                    '${_userCourses.length} added',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _userCourses.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 62,
                                          height: 62,
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: Colors.white12),
                                          ),
                                          child: const Icon(
                                            Icons.school_outlined,
                                            color: Colors.white38,
                                            size: 30,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'No courses added yet',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 10),
                                    children: [
                                      SizedBox(
                                        height: 92,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _userCourses.length + 1,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(width: 12),
                                          itemBuilder: (context, index) {
                                            if (index == _userCourses.length) {
                                              return _AddCourseTile(
                                                  onTap: addCourse);
                                            }

                                            final course = _userCourses[index];
                                            return _CourseTile(
                                              title: course,
                                              color: _courseColor(course),
                                              icon: _courseIcon(course),
                                              selected:
                                                  course == _selectedCourse,
                                              onTap: () => _selectCourse(course),
                                              onRemove: () async {
                                                setState(() {
                                                  _userCourses.removeAt(index);
                                                  if (_selectedCourse ==
                                                      course) {
                                                    _selectedCourse = _userCourses.isNotEmpty
                                                        ? _userCourses.first
                                                        : null;
                                                  }
                                                });
                                                await _saveCourses();
                                                setModalState(() {});
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              return AnimatedBuilder(
                animation: animation,
                child: panel,
                builder: (context, child) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0, -0.18),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  );
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Color _courseColor(String course) {
    final palette = [
      const Color(0xFF1D4E89),
      const Color(0xFF2E7D32),
      const Color(0xFFF57C00),
      const Color(0xFF7B1FA2),
      const Color(0xFF00897B),
      const Color(0xFFC62828),
      const Color(0xFF1565C0),
      const Color(0xFF6D4C41),
    ];
    final index = course.toLowerCase().codeUnits.fold<int>(0,
            (sum, unit) => sum + unit) %
        palette.length;
    return palette[index];
  }

  IconData _courseIcon(String course) {
    return courseIconForName(course);
  }
}

enum _LevelStatus { locked, active, completed }

class _CourseJourneyPanel extends StatelessWidget {
  final String course;
  final Color color;
  final IconData icon;

  const _CourseJourneyPanel({
    super.key,
    required this.course,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.28),
            const Color(0xFF0D1826),
            const Color(0xFF08111B),
          ],
        ),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.14),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.72)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start at Level 1 and climb the path.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.66),
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Text(
                    '10 levels',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, color.withOpacity(0.38), Colors.transparent],
                ),
              ),
            ),
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: _NoGlowScrollBehavior(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                physics: const BouncingScrollPhysics(),
                itemCount: 10,
                itemBuilder: (context, index) {
                  final level = index + 1;
                  final status = level == 1 ? _LevelStatus.active : _LevelStatus.locked;
                  final alignRight = level.isOdd;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: 0.82,
                          child: _LevelNode(
                            level: level,
                            color: color,
                            status: status,
                            alignRight: alignRight,
                          ),
                        ),
                      ),
                      if (index < 9)
                        _PathConnector(
                          alignRight: alignRight,
                          color: color,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathConnector extends StatelessWidget {
  final bool alignRight;
  final Color color;

  const _PathConnector({
    required this.alignRight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, 60),
            painter: _DiagonalConnectorPainter(
              color: color,
              alignRight: alignRight,
            ),
          );
        },
      ),
    );
  }
}

class _DiagonalConnectorPainter extends CustomPainter {
  final Color color;
  final bool alignRight;

  const _DiagonalConnectorPainter({
    required this.color,
    required this.alignRight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final start = alignRight
      ? Offset(size.width * 0.82, 8)
      : Offset(size.width * 0.18, 8);
    final end = alignRight
      ? Offset(size.width * 0.18, size.height - 8)
      : Offset(size.width * 0.82, size.height - 8);

    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashCount = 14;
    for (var i = 0; i < dashCount; i++) {
      final t0 = i / dashCount;
      final t1 = (i + 0.7) / dashCount;
      final p0 = Offset.lerp(start, end, t0)!;
      final p1 = Offset.lerp(start, end, t1)!;
      canvas.drawLine(p0, p1, paint);
    }

    final endpointPaint = Paint()..color = fblaGold.withValues(alpha: 0.98);
    canvas.drawCircle(start, 5, endpointPaint);
    canvas.drawCircle(end, 5, endpointPaint);
  }

  @override
  bool shouldRepaint(covariant _DiagonalConnectorPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.alignRight != alignRight;
  }
}

class _LevelNode extends StatelessWidget {
  final int level;
  final Color color;
  final _LevelStatus status;
  final bool alignRight;

  const _LevelNode({
    required this.level,
    required this.color,
    required this.status,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = status == _LevelStatus.active;
    final isCompleted = status == _LevelStatus.completed;

    final bubbleGradient = isActive
        ? LinearGradient(
            colors: [fblaGold, const Color(0xFFFF8A65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : isCompleted
            ? const LinearGradient(
                colors: [Color(0xFF43A047), Color(0xFF81C784)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              );

    final borderColor = isActive
        ? fblaGold
        : isCompleted
            ? const Color(0xFF81C784)
            : Colors.white12;

    return Row(
      mainAxisAlignment:
          alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: bubbleGradient,
            border: Border.all(color: borderColor, width: isActive ? 2.2 : 1.2),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: fblaGold.withOpacity(0.32),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.2,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.45),
                        width: 1.2,
                      ),
                    ),
                  ),
                if (isCompleted || isActive)
                  Text(
                    '$level',
                    style: TextStyle(
                      color: isActive ? fblaNavy : Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                else
                  const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class _CourseTile extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _CourseTile({
    required this.title,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final label = title.trim().isEmpty ? 'Course' : title.trim();

    return SizedBox(
      width: 102,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 102,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.98),
                      color.withOpacity(0.82),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? fblaGold : Colors.white12,
                    width: selected ? 1.6 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                    if (selected)
                      const Positioned(
                        bottom: 2,
                        left: 2,
                        child: Icon(Icons.check_circle,
                            color: fblaGold, size: 13),
                      ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 10, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCourseTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddCourseTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 72,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: const Column(
                children: [
                  SizedBox(height: 4),
                  Expanded(
                    child: Center(
                      child: Icon(Icons.add, color: Colors.white70, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 1),
          const Text(
            'Add',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 9,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class CourseSelectionScreen extends StatefulWidget {
  const CourseSelectionScreen({super.key});

  @override
  State<CourseSelectionScreen> createState() => _CourseSelectionScreenState();
}

class _CourseSelectionScreenState extends State<CourseSelectionScreen> {
  String _query = '';
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final queryLower = _query.trim().toLowerCase();
    final Map<String, List<String>> grouped = {};
    for (final category in fblaEventCategories) {
      if (category == 'All') continue;
      grouped[category] = [];
    }

    for (final opt in fblaEventCatalog) {
      final nameLower = opt.name.toLowerCase();
      if (queryLower.isEmpty ||
          nameLower.contains(queryLower) ||
          opt.category.toLowerCase().contains(queryLower)) {
        grouped[opt.category]?.add(opt.name);
      }
    }

    final items = grouped.entries.where((entry) => entry.value.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Add Course'), backgroundColor: fblaNavy),
      backgroundColor: const Color(0xFF0B1624),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search events',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final category = items[index].key;
                final list = items[index].value;
                return ExpansionTile(
                  backgroundColor: Colors.transparent,
                  collapsedBackgroundColor: Colors.transparent,
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  childrenPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  title: Text(
                    category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  children: list.map((eventName) {
                    final selected = _selected == eventName;
                    return InkWell(
                      onTap: () => setState(() => _selected = eventName),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF123A6A) : const Color(0xFF07121A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? fblaAccent : Colors.white12, width: 1.2),
                          boxShadow: selected ? [BoxShadow(color: fblaAccent.withOpacity(0.12), blurRadius: 8, offset: Offset(0,4))] : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: selected ? fblaAccent.withOpacity(0.25) : Colors.blueGrey.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                courseIconForName(eventName),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(eventName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                            AnimatedOpacity(
                              opacity: selected ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: AnimatedScale(
                                scale: selected ? 1.0 : 0.8,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(Icons.check_circle, color: Color(0xFFFDB913)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          if (_selected != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: fblaGold,
                    foregroundColor: fblaNavy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CompetitiveEventsScreen extends StatefulWidget {
  const CompetitiveEventsScreen({super.key});

  @override
  State<CompetitiveEventsScreen> createState() => _CompetitiveEventsScreenState();
}

class _CompetitiveEventsScreenState extends State<CompetitiveEventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All';

  static const List<String> _categories = [
    'All',
    'Presentation Events',
    'Roleplay Events',
    'Objective Test Events',
    'Production Events',
    'Virtual & Partner Challenges',
    'Chapter Events',
  ];

  final List<_CompetitiveEventItem> _events = const [
    _CompetitiveEventItem('Business Ethics', 'Presentation Events'),
    _CompetitiveEventItem('Business Plan', 'Presentation Events'),
    _CompetitiveEventItem('Coding & Programming', 'Presentation Events'),
    _CompetitiveEventItem('Digital Video Production', 'Presentation Events'),
    _CompetitiveEventItem('Financial Planning', 'Presentation Events'),
    _CompetitiveEventItem('Public Speaking', 'Presentation Events'),
    _CompetitiveEventItem('Marketing', 'Roleplay Events'),
    _CompetitiveEventItem('Entrepreneurship', 'Roleplay Events'),
    _CompetitiveEventItem('Accounting I & II', 'Objective Test Events'),
    _CompetitiveEventItem('Business Law', 'Objective Test Events'),
    _CompetitiveEventItem('Computer Applications', 'Production Events'),
    _CompetitiveEventItem('Spreadsheet Applications', 'Production Events'),
    _CompetitiveEventItem(
        'Virtual Business Finance Challenge', 'Virtual & Partner Challenges'),
    _CompetitiveEventItem('FBLA Stock Market Game', 'Virtual & Partner Challenges'),
    _CompetitiveEventItem('Community Service Project', 'Chapter Events'),
    _CompetitiveEventItem('Local Chapter Annual Business Report', 'Chapter Events'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_CompetitiveEventItem> get _filteredEvents {
    final query = _query.trim().toLowerCase();
    final filtered = _events.where((event) {
      final categoryMatch =
          _selectedCategory == 'All' || event.category == _selectedCategory;
      final queryMatch = query.isEmpty ||
          event.name.toLowerCase().contains(query) ||
          event.category.toLowerCase().contains(query);
      return categoryMatch && queryMatch;
    }).toList();

    filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final Color fblaBlue = const Color(0xFF1D4E89);
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('FBLA Competitive Events'),
        backgroundColor: fblaBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search events',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.grey.shade400),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: Colors.grey.shade400),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF161616),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _showFilterSheet,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Filters'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: fblaBlue.withOpacity(0.7)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedCategory != 'All')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: fblaBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: fblaBlue.withOpacity(0.6)),
                  ),
                  child: Text(
                    _selectedCategory,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 20 + bottomSafe + 16),
              itemCount: _filteredEvents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final event = _filteredEvents[index];
                return _buildEventCard(event);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(_CompetitiveEventItem event) {
    final categoryColor = _categoryColor(event.category);
    final badgeLetter = _categoryBadgeLetter(event.category);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CompetitiveEventDetailScreen(event: event),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: categoryColor.withOpacity(0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: categoryColor.withOpacity(0.75)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeLetter,
                      style: TextStyle(
                        color: categoryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tap to open study resources',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: categoryColor, size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryBadgeLetter(String category) {
    switch (category) {
      case 'Presentation Events':
        return 'Pr';
      case 'Production Events':
        return 'Po';
      case 'Roleplay Events':
        return 'R';
      case 'Virtual & Partner Challenges':
        return 'V';
      case 'Objective Test Events':
        return 'O';
      case 'Chapter Events':
        return 'C';
      default:
        return 'E';
    }
  }

  Future<void> _showFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101010),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter by category',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                ..._categories.map(
                  (category) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(category,
                        style: const TextStyle(color: Colors.white)),
                    trailing: _selectedCategory == category
                        ? const Icon(Icons.check_circle,
                            color: Color(0xFF1D4E89))
                        : const SizedBox.shrink(),
                    onTap: () {
                      setState(() => _selectedCategory = category);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Presentation Events':
        return const Color(0xFF64B5F6);
      case 'Roleplay Events':
        return const Color(0xFFFFD54F);
      case 'Objective Test Events':
        return const Color(0xFF81C784);
      case 'Production Events':
        return const Color(0xFFBA68C8);
      case 'Virtual & Partner Challenges':
        return const Color(0xFF4DD0E1);
      case 'Chapter Events':
        return const Color(0xFFFF8A65);
      default:
        return const Color(0xFF90A4AE);
    }
  }
}

class _CompetitiveEventItem {
  final String name;
  final String category;

  const _CompetitiveEventItem(this.name, this.category);
}

class CompetitiveEventDetailScreen extends StatelessWidget {
  final _CompetitiveEventItem event;

  const CompetitiveEventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    const fblaBlue = Color(0xFF1D4E89);
    final resources = _resourcesForEvent(event);
    final isMobileAppDev = event.name == 'Mobile Application Development';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(event.name),
        backgroundColor: fblaBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: fblaBlue.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.category,
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${event.name} Study Toolkit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (isMobileAppDev) ...[
            _buildMobileAppGuidelinesTile(context),
            const SizedBox(height: 10),
          ],
          ...resources.map((resource) => _buildResourceTile(resource)),
        ],
      ),
    );
  }

  Widget _buildMobileAppGuidelinesTile(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MobileAppDevGuidelinesScreen(),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF64B5F6).withOpacity(0.7)),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Text(
                  'Mobile Application Development Guidelines',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Color(0xFF64B5F6), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceTile(_StudyPackResource resource) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resource.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            resource.description,
            style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
          ),
          if (resource.url != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _launchUrl(resource.url!),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(resource.linkLabel ?? 'Open Link'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64B5F6),
                side: const BorderSide(color: Color(0xFF64B5F6)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_StudyPackResource> _resourcesForEvent(_CompetitiveEventItem event) {
    switch (event.category) {
      case 'Objective Test Events':
        return [
          _StudyPackResource(
            title: '${event.name} Blueprint',
            description: 'Competency weighting summary and topic guide.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Official Blueprint',
          ),
          _StudyPackResource(
            title: '${event.name} Daily Practice',
            description: '10–15 sample multiple-choice questions each day.',
            url: 'https://quizlet.com/search?query=FBLA%20${Uri.encodeComponent(event.name)}',
            linkLabel: 'Open Quizlet Sets',
          ),
        ];
      case 'Roleplay Events':
        return [
          _StudyPackResource(
            title: '${event.name} Case Study Library',
            description: 'Timed scenarios to practice the roleplay format.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Past Scenarios',
          ),
          _StudyPackResource(
            title: '${event.name} Performance Rubric',
            description: 'Judge scoring criteria and delivery expectations.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Rubric Guide',
          ),
        ];
      case 'Presentation Events':
        return [
          _StudyPackResource(
            title: '${event.name} Current Prompt',
            description: 'Current-year event prompt and topic requirements.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Current Prompt',
          ),
          _StudyPackResource(
            title: '${event.name} Scoring Rubric',
            description: 'Checklist for delivery, visuals, and Q&A performance.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Scoring Rubric',
          ),
        ];
      case 'Production Events':
        return [
          _StudyPackResource(
            title: '${event.name} Production Test',
            description: 'Sample timed job packet and output target.',
          ),
          _StudyPackResource(
            title: '${event.name} FBLA Format Guide',
            description: 'Formatting standards for documents and reports.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Format Rules',
          ),
        ];
      case 'Virtual & Partner Challenges':
        return [
          _StudyPackResource(
            title: '${event.name} Login Gateway',
            description: 'Direct access to challenge portals and simulation tools.',
            url: 'https://knowledgematters.com/high-school/virtual-business-challenge/',
            linkLabel: 'Open Portal',
          ),
          _StudyPackResource(
            title: '${event.name} Strategy Guide',
            description: 'Tips from top competitors and pacing advice.',
          ),
        ];
      case 'Chapter Events':
        return [
          _StudyPackResource(
            title: '${event.name} Project Guide',
            description: 'Official project structure and submission instructions.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Project Rules',
          ),
          _StudyPackResource(
            title: '${event.name} Judging Rubric',
            description: 'How chapter projects are evaluated.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Rubric',
          ),
        ];
      default:
        return [
          _StudyPackResource(
            title: '${event.name} Official Information',
            description: 'General event details and current-year guidance.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Open Official Page',
          ),
        ];
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class MobileAppDevGuidelinesScreen extends StatelessWidget {
  const MobileAppDevGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const fblaBlue = Color(0xFF1D4E89);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile App Dev Guidelines'),
        backgroundColor: fblaBlue,
        foregroundColor: Colors.white,
      ),
      body: SfPdfViewer.asset('assets/Mobile-Application-Development.pdf'),
    );
  }
}

class CompetitiveEventStudyPacksScreen extends StatelessWidget {
  const CompetitiveEventStudyPacksScreen({super.key});

  static const List<_StudyPackCategory> _packs = [
    _StudyPackCategory(
      title: 'Objective Test Events',
      examples: 'Accounting I, Business Law, Personal Finance',
      resources: [
        _StudyPackResource(
          title: 'The Blueprint',
          description: 'Summary of tested competencies by weight.',
          url: 'https://www.fbla-pbl.org/competitive-events/',
          linkLabel: 'Official Event Blueprints',
        ),
        _StudyPackResource(
          title: 'Question Bank',
          description: 'Daily practice questions to build speed and accuracy.',
          url: 'https://quizlet.com/search?query=FBLA%20objective%20test',
          linkLabel: 'Quizlet Practice Sets',
        ),
      ],
    ),
    _StudyPackCategory(
      title: 'Roleplay Events',
      examples: 'Marketing, Entrepreneurship, Hospitality & Event Management',
      resources: [
        _StudyPackResource(
          title: 'Case Study Library',
          description: 'Practice timed 10-minute prep and delivery.',
          url: 'https://www.fbla-pbl.org/competitive-events/',
          linkLabel: 'Past Event Resources',
        ),
        _StudyPackResource(
          title: 'Performance Rubric',
          description: 'Focus on eye contact, clarity, and creativity.',
          url: 'https://www.fbla-pbl.org/competitive-events/',
          linkLabel: 'Judging Rubrics',
        ),
      ],
    ),
    _StudyPackCategory(
      title: 'Presentation & Speech Events',
      examples: 'Public Speaking, Social Media Strategies, Graphic Design',
      resources: [
        _StudyPackResource(
          title: 'The Prompt',
          description: 'Current-year topic statement and required scope.',
          url: 'https://www.fbla-pbl.org/competitive-events/',
          linkLabel: 'Current Year Topics',
        ),
        _StudyPackResource(
          title: 'Scoring Rubric',
          description: 'Checklist for delivery, visuals, and Q&A performance.',
          url: 'https://www.fbla-pbl.org/competitive-events/',
          linkLabel: 'Presentation Rubrics',
        ),
      ],
    ),
    _StudyPackCategory(
      title: 'Production Events',
      examples: 'Computer Applications, Spreadsheet Applications',
      resources: [
        _StudyPackResource(
          title: 'The Production Test',
          description: 'Sample timed job packet and format expectations.',
        ),
        _StudyPackResource(
          title: 'FBLA Format Guide',
          description: 'Formatting standards reference for reports and letters.',
          url: 'https://www.fbla-pbl.org/competitive-events/',
          linkLabel: 'Format Standards',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const fblaBlue = Color(0xFF1D4E89);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Category Study Packs'),
        backgroundColor: fblaBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _packs.length,
        itemBuilder: (context, index) {
          final pack = _packs[index];
          return _buildPackCard(pack);
        },
      ),
    );
  }

  Widget _buildPackCard(_StudyPackCategory pack) {
    final accent = _packColor(pack.title);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pack.title,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Examples: ${pack.examples}',
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...pack.resources.map(
            (resource) => _buildPackResourceTile(resource, accent),
          ),
        ],
      ),
    );
  }

  Widget _buildPackResourceTile(_StudyPackResource resource, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resource.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            resource.description,
            style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
          ),
          if (resource.url != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _launchResource(resource.url!),
              icon: const Icon(Icons.open_in_new, size: 15),
              label: Text(resource.linkLabel ?? 'Open Link'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withOpacity(0.6)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _packColor(String title) {
    if (title.contains('Objective')) return const Color(0xFF81C784);
    if (title.contains('Roleplay')) return const Color(0xFFFFD54F);
    if (title.contains('Presentation')) return const Color(0xFF64B5F6);
    if (title.contains('Production')) return const Color(0xFFBA68C8);
    if (title.contains('Virtual')) return const Color(0xFF4DD0E1);
    return const Color(0xFF90A4AE);
  }

  Future<void> _launchResource(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _StudyPackCategory {
  final String title;
  final String examples;
  final List<_StudyPackResource> resources;

  const _StudyPackCategory({
    required this.title,
    required this.examples,
    required this.resources,
  });
}

class _StudyPackResource {
  final String title;
  final String description;
  final String? url;
  final String? linkLabel;

  const _StudyPackResource({
    required this.title,
    required this.description,
    this.url,
    this.linkLabel,
  });
}
