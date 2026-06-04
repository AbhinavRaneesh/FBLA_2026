import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chatbot_screen.dart';
import '../models/fbla_events.dart';
import '../services/firebase_service.dart';

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
  if (n.contains('code') || n.contains('program') || n.contains('coding'))
    return Icons.code;
  if (n.contains('business') || n.contains('plan') || n.contains('management'))
    return Icons.business;
  if (n.contains('finance') || n.contains('bank') || n.contains('account'))
    return Icons.account_balance;
  if (n.contains('marketing') || n.contains('sales')) return Icons.campaign;
  if (n.contains('video') || n.contains('digital') || n.contains('animation'))
    return Icons.video_collection;
  if (n.contains('public') || n.contains('speaking') || n.contains('speech'))
    return Icons.record_voice_over;
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

bool _isCybersecurityCourse(String name) {
  return name.toLowerCase().contains('cybersecurity');
}

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({Key? key}) : super(key: key);

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final List<String> _userCourses = [];
  String? _selectedCourse;
  int _points = 0;
  int _streak = 0;
  final GlobalKey _courseMenuButtonKey = GlobalKey();
  final GlobalKey _streakButtonKey = GlobalKey();
  DateTime _streakCalendarMonth =
      DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _loadProgress();
  }

  Future<void> _loadCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('userCourses') ?? <String>[];
      final savedSelection = prefs.getString('selectedCourse');
      setState(() {
        _userCourses.clear();
        _userCourses.addAll(saved);
        if (savedSelection != null && _userCourses.contains(savedSelection)) {
          _selectedCourse = savedSelection;
        } else if (_userCourses.isNotEmpty) {
          _selectedCourse = _userCourses.first;
        } else {
          _selectedCourse = null;
        }
      });
    } catch (_) {}
  }

  Future<void> _saveCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('userCourses', _userCourses);
      if (_selectedCourse != null && _userCourses.contains(_selectedCourse)) {
        await prefs.setString('selectedCourse', _selectedCourse!);
      } else {
        await prefs.remove('selectedCourse');
      }
    } catch (_) {}
  }

  Future<void> _loadProgress() async {
    try {
      final progress = await FirebaseService.getCurrentUserProgress();
      if (!mounted) return;
      setState(() {
        _points = progress['points'] ?? 0;
        _streak = progress['streak'] ?? 0;
      });
    } catch (_) {}
  }

  void _selectCourse(String course) {
    setState(() => _selectedCourse = course);
    unawaited(_saveCourses());
  }

  void _openCoursePicker() => _showCoursePanel();

  Future<void> _addCourse(
    BuildContext navigatorContext, {
    VoidCallback? onCoursesChanged,
  }) async {
    dynamic appState;
    try {
      appState = Provider.of<dynamic>(context, listen: false);
    } catch (_) {}

    final selected = await Navigator.push<String>(
      navigatorContext,
      MaterialPageRoute(builder: (_) => const CourseSelectionScreen()),
    );
    if (!mounted || selected == null || selected.isEmpty) return;

    setState(() {
      if (!_userCourses.contains(selected)) {
        _userCourses.add(selected);
      }
      _selectedCourse = selected;
    });
    await _saveCourses();
    onCoursesChanged?.call();

    if (appState != null) {
      try {
        await appState.addUserCourse?.call(selected);
      } catch (_) {}
    }
  }

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
    final course = _selectedCourse ??
        (_userCourses.isNotEmpty ? _userCourses.first : null);

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
              GestureDetector(
                onTap: () {
                  unawaited(_addCourse(context));
                },
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        fblaGold.withValues(alpha: 0.95),
                        const Color(0xFFFFE082)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: fblaGold.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: fblaNavy, size: 48),
                ),
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
        onMoreMenu: () => _showCourseMenu(course),
        moreMenuButtonKey: _courseMenuButtonKey,
      ),
    );
  }

  Future<void> _showCourseMenu(String course) async {
    final menuItems = [
      _CourseMenuItem(
        label: 'Course',
        icon: Icons.school,
        onTap: _showCoursePanel,
      ),
      _CourseMenuItem(
        label: 'Concept Maps',
        icon: Icons.account_tree_outlined,
        onTap: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Concept Maps are coming soon.')),
          );
        },
      ),
      _CourseMenuItem(
        label: 'Question Bank',
        icon: Icons.quiz_outlined,
        onTap: () {
          if (_isCybersecurityCourse(course)) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CybersecurityQuestionBankScreen(
                  course: course,
                  color: _courseColor(course),
                ),
              ),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CompetitiveEventStudyPacksScreen(),
            ),
          );
        },
      ),
      _CourseMenuItem(
        label: 'Official Documents',
        icon: Icons.description_outlined,
        onTap: () {
          if (_isCybersecurityCourse(course)) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CybersecurityOfficialDocumentsScreen(),
              ),
            );
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Official Documents are only available for the Cybersecurity course right now.')),
          );
        },
      ),
      _CourseMenuItem(
        label: 'Learn with AI',
        icon: Icons.smart_toy_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatbotScreen()),
          );
        },
      ),
      _CourseMenuItem(
        label: 'Vocabulary',
        icon: Icons.menu_book_outlined,
        onTap: () {
          if (_isCybersecurityCourse(course)) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CybersecurityVocabularyScreen(
                  course: course,
                  color: _courseColor(course),
                ),
              ),
            );
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Vocabulary is only available for the Cybersecurity course right now.',
              ),
            ),
          );
        },
      ),
    ];

    final buttonContext = _courseMenuButtonKey.currentContext;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final buttonBox = buttonContext?.findRenderObject() as RenderBox?;
    if (overlay == null || buttonBox == null) return;

    final buttonTopLeft =
        buttonBox.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonBottomRight = buttonBox.localToGlobal(
        buttonBox.size.bottomRight(Offset.zero),
        ancestor: overlay);

    final selected = await showMenu<String>(
      context: context,
      color: const Color(0xFF0B1624),
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Colors.white12),
      ),
      position: RelativeRect.fromLTRB(
        buttonBottomRight.dx + 8,
        buttonTopLeft.dy - 8,
        overlay.size.width - buttonBottomRight.dx,
        overlay.size.height - buttonTopLeft.dy,
      ),
      items: [
        for (final item in menuItems)
          PopupMenuItem<String>(
            value: item.label,
            child: Row(
              children: [
                Icon(item.icon, color: fblaGold, size: 18),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (selected == null) return;
    final item = menuItems.firstWhere((entry) => entry.label == selected);
    item.onTap();
  }

  Widget _buildTopStatsBar() {
    final rand = Random();
    final selectedCourseShortForm = _selectedCourse == null
        ? 'COURSE'
        : courseShortFormForName(_selectedCourse!);

    Widget statInline(
      Widget iconWidget, {
      Key? key,
      int? value,
      bool hideValue = false,
      VoidCallback? onTap,
    }) {
      final displayValue = value ?? rand.nextInt(1000);
      final content = hideValue
          ? iconWidget
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
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
              ),
            );

      return GestureDetector(
        key: key,
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
              key: _streakButtonKey,
              value: _streak,
              onTap: _showStreakCalendar,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: statInline(
              Image.asset('assets/coins.png', width: 30, height: 30),
              value: _points,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: statInline(
              const Icon(Icons.leaderboard, color: Color(0xFF66BB6A), size: 31),
              hideValue: true,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showStreakCalendar() async {
    final buttonContext = _streakButtonKey.currentContext;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final buttonBox = buttonContext?.findRenderObject() as RenderBox?;
    if (overlay == null || buttonBox == null) return;

    final now = DateTime.now();
    DateTime displayedMonth = DateTime(now.year, now.month);

    final buttonTopLeft =
        buttonBox.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonBottomLeft = buttonBox
        .localToGlobal(Offset(0, buttonBox.size.height), ancestor: overlay);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            final cardWidth =
                (overlay.size.width - 24).clamp(300.0, 360.0).toDouble();
            final cardHeight = 352.0;
            final left = ((overlay.size.width - cardWidth) / 2).toDouble();
            final top = (buttonBottomLeft.dy + 10)
                .clamp(12.0, overlay.size.height - cardHeight - 12.0)
                .toDouble();
            final monthStart =
                DateTime(displayedMonth.year, displayedMonth.month, 1);
            final daysInMonth =
                DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
            final firstWeekday = monthStart.weekday % 7;
            final totalCells = 42;
            final currentDay = DateTime(now.year, now.month, now.day);
            final isCurrentMonth = now.year == displayedMonth.year &&
                now.month == displayedMonth.month;

            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  child: Material(
                    color: const Color(0xFF0B1624),
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      width: cardWidth,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 22,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.chevron_left,
                                    color: Colors.white),
                                onPressed: () {
                                  setPopupState(() {
                                    displayedMonth = DateTime(
                                      displayedMonth.year,
                                      displayedMonth.month - 1,
                                    );
                                  });
                                },
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    _monthLabel(displayedMonth),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.chevron_right,
                                    color: Colors.white),
                                onPressed: () {
                                  setPopupState(() {
                                    displayedMonth = DateTime(
                                      displayedMonth.year,
                                      displayedMonth.month + 1,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('S',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                              Text('M',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                              Text('T',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                              Text('W',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                              Text('T',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                              Text('F',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                              Text('S',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: totalCells,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 5,
                              crossAxisSpacing: 5,
                            ),
                            itemBuilder: (context, index) {
                              final dayNumber = index - firstWeekday + 1;
                              final isInMonth =
                                  dayNumber >= 1 && dayNumber <= daysInMonth;
                              final isToday = isCurrentMonth &&
                                  isInMonth &&
                                  dayNumber == currentDay.day;

                              if (!isInMonth) {
                                return const SizedBox.shrink();
                              }

                              return Container(
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? fblaGold.withOpacity(0.92)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isToday ? fblaGold : Colors.white12,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    color: isToday ? fblaNavy : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scale = Tween<double>(begin: 0.96, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
              scale: scale, alignment: Alignment.topCenter, child: child),
        );
      },
    );
  }

  String _monthLabel(DateTime month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[month.month - 1]} ${month.year}';
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
                await _addCourse(
                  dialogContext,
                  onCoursesChanged: () => setModalState(() {}),
                );
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
                      constraints: BoxConstraints(
                        maxHeight: screenHeight * 0.26,
                      ),
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
                        mainAxisSize: MainAxisSize.min,
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border:
                                            Border.all(color: Colors.white12),
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
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        unawaited(addCourse());
                                      },
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: fblaGold,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: fblaGold.withValues(
                                                  alpha: 0.28),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          color: fblaNavy,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_userCourses.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _AddCourseTile(
                                      onTap: () {
                                        unawaited(addCourse());
                                      },
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
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                              child: SizedBox(
                                height: 92,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _userCourses.length + 1,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    if (index == _userCourses.length) {
                                      return _AddCourseTile(onTap: addCourse);
                                    }

                                    final course = _userCourses[index];
                                    return _CourseTile(
                                      title: course,
                                      color: _courseColor(course),
                                      icon: _courseIcon(course),
                                      selected: course == _selectedCourse,
                                      onTap: () => _selectCourse(course),
                                      onRemove: () async {
                                        setState(() {
                                          _userCourses.removeAt(index);
                                          if (_selectedCourse == course) {
                                            _selectedCourse =
                                                _userCourses.isNotEmpty
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
    final index =
        course.toLowerCase().codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
            palette.length;
    return palette[index];
  }

  IconData _courseIcon(String course) {
    return courseIconForName(course);
  }
}

enum _LevelStatus { locked, active, completed }

class _CourseJourneyPanel extends StatefulWidget {
  final String course;
  final Color color;
  final IconData icon;
  final VoidCallback onMoreMenu;
  final GlobalKey moreMenuButtonKey;

  const _CourseJourneyPanel({
    super.key,
    required this.course,
    required this.color,
    required this.icon,
    required this.onMoreMenu,
    required this.moreMenuButtonKey,
  });

  @override
  State<_CourseJourneyPanel> createState() => _CourseJourneyPanelState();
}

class _CourseJourneyPanelState extends State<_CourseJourneyPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF0A1420),
        border: Border.all(
          color: widget.color.withOpacity(0.82),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.color,
                            widget.color.withOpacity(0.72)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withOpacity(0.28),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.course,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const SizedBox.shrink(),
                        ],
                      ),
                    ),
                    GestureDetector(
                      key: widget.moreMenuButtonKey,
                      onTap: widget.onMoreMenu,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(
                          Icons.menu,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
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
                  colors: [
                    Colors.transparent,
                    widget.color.withOpacity(0.55),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: _NoGlowScrollBehavior(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                physics: const BouncingScrollPhysics(),
                itemCount: 10,
                itemBuilder: (context, index) {
                  final level = index + 1;
                  final status =
                      level == 1 ? _LevelStatus.active : _LevelStatus.locked;
                  final isCybersecurity = _isCybersecurityCourse(widget.course);
                  final levelTap = level == 1 && isCybersecurity
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CybersecurityModulesScreen(
                                course: widget.course,
                                color: widget.color,
                              ),
                            ),
                          );
                        }
                      : null;

                  const amplitude = 0.92;
                  const step = 0.95;
                  final xAlign = sin(index * step) * amplitude;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment(xAlign, 0),
                        child: _LevelNode(
                          level: level,
                          color: widget.color,
                          status: status,
                          onTap: levelTap,
                        ),
                      ),
                      if (index < 9) const SizedBox(height: 8),
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
  final double startFrac; // 0..1 across width
  final double endFrac; // 0..1 across width
  final Color color;

  const _PathConnector({
    required this.startFrac,
    required this.endFrac,
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
              startFrac: startFrac,
              endFrac: endFrac,
            ),
          );
        },
      ),
    );
  }
}

class CybersecurityModulesScreen extends StatelessWidget {
  final String course;
  final Color color;

  const CybersecurityModulesScreen(
      {required this.course, required this.color, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final modules = [
      {'id': '1.1', 'title': 'Introduction to Cybersecurity'},
      {'id': '1.2', 'title': 'Digital Threats 101'},
      {'id': '1.3', 'title': 'Vocabulary (Flashcards)'},
      {'id': '1.4', 'title': 'Basic Protection Techniques'},
      {'id': '1.5', 'title': 'Password & Authentication Basics'},
      {'id': '1.6', 'title': 'Safe Internet Practices'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF061726),
      appBar: AppBar(
        title: Text('$course Modules'),
        backgroundColor: color,
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: appBackgroundGradient),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: modules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final mod = modules[index];
              return Material(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // Route each module to its screen
                    if (mod['id'] == '1.1') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CybersecurityLevelOneScreen(
                            course: course, color: color),
                      ));
                    } else if (mod['id'] == '1.2') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CybersecurityModuleOneTwoScreen(
                            course: course, color: color),
                      ));
                    } else if (mod['id'] == '1.3') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CybersecurityVocabularyScreen(
                            course: course, color: color),
                      ));
                    } else if (mod['id'] == '1.4') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CybersecurityModuleOneFourScreen(
                            course: course, color: color),
                      ));
                    } else if (mod['id'] == '1.5') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CybersecurityModuleOneFiveScreen(
                            course: course, color: color),
                      ));
                    } else if (mod['id'] == '1.6') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CybersecurityModuleOneSixScreen(
                            course: course, color: color),
                      ));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              mod['id']!,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mod['title']!,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text('Tap to open the lesson',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.7))),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class CybersecurityModuleOneTwoScreen extends StatefulWidget {
  final String course;
  final Color color;

  const CybersecurityModuleOneTwoScreen(
      {required this.course, required this.color, Key? key})
      : super(key: key);

  @override
  State<CybersecurityModuleOneTwoScreen> createState() =>
      _CybersecurityModuleOneTwoScreenState();
}

class CybersecurityModuleOneThreeScreen extends StatefulWidget {
  final String course;
  final Color color;

  const CybersecurityModuleOneThreeScreen(
      {required this.course, required this.color, Key? key})
      : super(key: key);

  @override
  State<CybersecurityModuleOneThreeScreen> createState() =>
      _CybersecurityModuleOneThreeScreenState();
}

class _CybersecurityModuleOneThreeScreenState
    extends State<CybersecurityModuleOneThreeScreen> {
  static const List<_CybersecuritySection> _sections = [
    _CybersecuritySection(
        title: 'Core Cybersecurity Terms',
        subtitle: 'Fundamental words everyone should know.'),
    _CybersecuritySection(
        title: 'CIA Triad',
        subtitle: 'Confidentiality, Integrity, Availability.'),
    _CybersecuritySection(
        title: 'Malware Types', subtitle: 'Common malware definitions.'),
    _CybersecuritySection(
        title: 'Social Engineering', subtitle: 'Human-targeted attacks.'),
    _CybersecuritySection(
        title: 'Network Security Terms',
        subtitle: 'Network-focused vocabulary.'),
    _CybersecuritySection(
        title: 'Authentication & Access',
        subtitle: 'Login and access control terms.'),
    _CybersecuritySection(
        title: 'System & Data Protection',
        subtitle: 'Protective measures and tools.'),
    _CybersecuritySection(
        title: 'Incident & Response',
        subtitle: 'How to react and what to look for.'),
  ];

  int _currentSectionIndex = 0;
  bool _inFlashcards = false;
  late PageController _cardController;
  int _currentCardPage = 0;
  final Set<int> _flippedCards = {};

  @override
  void initState() {
    super.initState();
    _cardController = PageController();
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  double get _progress => (_currentSectionIndex + 1) / _sections.length;

  void _startFlashcards() {
    setState(() {
      _inFlashcards = true;
      _currentCardPage = 0;
      _flippedCards.clear();
      _cardController = PageController(initialPage: 0);
    });
  }

  void _exitFlashcards() {
    setState(() {
      _inFlashcards = false;
      _flippedCards.clear();
    });
  }

  List<Map<String, String>> _cardsForSection(int idx) {
    switch (idx) {
      case 0:
        return [
          {
            'term': 'Cybersecurity',
            'def':
                'Protecting computers, networks, and data from digital threats.'
          },
          {
            'term': 'Threat',
            'def': 'Anything that can cause harm to a system.'
          },
          {'term': 'Vulnerability', 'def': 'A weakness that can be exploited.'},
          {
            'term': 'Risk',
            'def': 'The chance a threat will exploit a vulnerability.'
          },
          {
            'term': 'Attack Vector',
            'def': 'The path an attacker uses to break in.'
          },
          {
            'term': 'Exploit',
            'def':
                'Code or technique used to take advantage of a vulnerability.'
          },
        ];
      case 1:
        return [
          {
            'term': 'Confidentiality',
            'def': 'Only authorized people can access information.'
          },
          {
            'term': 'Integrity',
            'def': 'Information stays accurate and unchanged.'
          },
          {
            'term': 'Availability',
            'def': 'Systems and data are accessible when needed.'
          },
        ];
      case 2:
        return [
          {
            'term': 'Virus',
            'def': 'Attaches to files and spreads when opened.'
          },
          {'term': 'Worm', 'def': 'Spreads automatically across networks.'},
          {
            'term': 'Trojan Horse',
            'def': 'Looks safe but contains harmful code.'
          },
          {'term': 'Ransomware', 'def': 'Locks files and demands payment.'},
          {'term': 'Spyware', 'def': 'Secretly collects information.'},
          {'term': 'Adware', 'def': 'Shows unwanted ads; sometimes malicious.'},
        ];
      case 3:
        return [
          {'term': 'Phishing', 'def': 'Fake emails/messages that steal info.'},
          {
            'term': 'Spear Phishing',
            'def': 'Targeted phishing at a specific person.'
          },
          {'term': 'Vishing', 'def': 'Phone‑based phishing.'},
          {'term': 'Smishing', 'def': 'Text‑message phishing.'},
          {
            'term': 'Pretexting',
            'def': 'Attacker pretends to be someone trustworthy.'
          },
        ];
      case 4:
        return [
          {'term': 'Firewall', 'def': 'Blocks unwanted network traffic.'},
          {
            'term': 'Encryption',
            'def': 'Scrambles data so only authorized people can read it.'
          },
          {
            'term': 'Decryption',
            'def': 'Turning encrypted data back into readable form.'
          },
          {'term': 'MITM', 'def': 'Attacker intercepts communication.'},
          {'term': 'DDoS', 'def': 'Overloading a website so it crashes.'},
          {'term': 'Brute Force', 'def': 'Guessing passwords repeatedly.'},
        ];
      case 5:
        return [
          {
            'term': 'Authentication',
            'def': 'Proving who you are (password, MFA).'
          },
          {'term': 'Authorization', 'def': 'What you’re allowed to access.'},
          {'term': 'MFA', 'def': 'Using more than one method to log in.'},
          {
            'term': 'Password Manager',
            'def': 'Tool that stores and creates strong passwords.'
          },
        ];
      case 6:
        return [
          {
            'term': 'Patch',
            'def': 'A software update that fixes vulnerabilities.'
          },
          {'term': 'Backup', 'def': 'Copy of data stored separately.'},
          {
            'term': 'Antivirus',
            'def': 'Software that detects and removes malware.'
          },
          {
            'term': 'Secure Wi‑Fi',
            'def': 'Encrypted wireless network (WPA2/WPA3).'
          },
        ];
      case 7:
      default:
        return [
          {
            'term': 'Incident',
            'def': 'A security event that harms or threatens a system.'
          },
          {'term': 'IoC', 'def': 'Signs that an attack happened.'},
          {'term': 'Zero‑Day', 'def': 'A vulnerability with no patch yet.'},
          {
            'term': 'Insider Threat',
            'def': 'Harm caused by someone inside an organization.'
          },
        ];
    }
  }

  Widget _buildCard(
      BuildContext context, Map<String, String> card, int pageIndex) {
    final flipped = _flippedCards.contains(pageIndex);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (flipped)
            _flippedCards.remove(pageIndex);
          else
            _flippedCards.add(pageIndex);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(flipped ? 0.06 : 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.color.withOpacity(0.18)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(card['term']!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (widget, children) => Stack(
                  children: [for (final child in children) child],
                ),
                transitionBuilder: (child, anim) {
                  // Determine which side this child represents using its key
                  final keyString = child.key is ValueKey
                      ? (child.key as ValueKey).value?.toString() ?? ''
                      : '';
                  final isDef = keyString.startsWith('def-');
                  // Incoming def side rotates from -90deg -> 0, outgoing rotates 0 -> 90deg
                  final rotateTween = isDef
                      ? Tween(begin: -pi / 2, end: 0.0)
                      : Tween(begin: 0.0, end: pi / 2);
                  final rotation = rotateTween.animate(anim);
                  return AnimatedBuilder(
                    animation: rotation,
                    child: child,
                    builder: (context, child) {
                      final angle = rotation.value;
                      final transform = Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle);
                      // When the card is near edge-on, hide it to avoid text showing mirrored
                      final visible = (angle.abs() < (pi / 2 - 0.05));
                      return Opacity(
                        opacity: visible ? 1 : 0,
                        child: Transform(
                          transform: transform,
                          alignment: Alignment.center,
                          child: child,
                        ),
                      );
                    },
                  );
                },
                child: flipped
                    ? Text(card['def']!,
                        key: ValueKey('def-$pageIndex'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            height: 1.4))
                    : Text('Tap to reveal',
                        key: ValueKey('hint-$pageIndex'),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCard(
      {required String title, required String body, required Color tint}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withOpacity(0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
        const SizedBox(height: 6),
        Text(body,
            style: TextStyle(
                color: Colors.white.withOpacity(0.86),
                fontSize: 13,
                height: 1.45)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cardsForSection(_currentSectionIndex);
    return Scaffold(
      backgroundColor: const Color(0xFF061726),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: appBackgroundGradient),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Row(children: [
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white)),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(widget.course,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text('Level 1 · Vocabulary',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.72),
                                fontSize: 12)),
                      ])),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white12)),
                      child: Text('1.3',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11))),
                ]),
                const SizedBox(height: 12),
                ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                        value: _progress.clamp(0.0, 1.0),
                        minHeight: 9,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(widget.color))),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 28,
                              offset: Offset(0, 16))
                        ]),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _inFlashcards
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      // Flashcards view
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        child: Text(
                                          _sections[_currentSectionIndex]
                                              .subtitle,
                                          style: TextStyle(
                                              color: widget.color
                                                  .withOpacity(0.95),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                          child: Column(children: [
                                        Expanded(
                                            child: PageView.builder(
                                                controller: _cardController,
                                                itemCount: cards.length,
                                                onPageChanged: (p) =>
                                                    setState(() {
                                                      _currentCardPage = p;
                                                      _flippedCards.clear();
                                                    }),
                                                itemBuilder: (ctx, p) =>
                                                    _buildCard(
                                                        ctx, cards[p], p))),
                                        const SizedBox(height: 10),
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: List.generate(
                                              cards.length,
                                              (i) => Container(
                                                  margin: const EdgeInsets
                                                      .symmetric(horizontal: 4),
                                                  width: i == _currentCardPage
                                                      ? 12
                                                      : 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                      color:
                                                          i == _currentCardPage
                                                              ? widget.color
                                                              : Colors.white12,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6))),
                                            )),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                                child: OutlinedButton(
                                                    onPressed: () {
                                                      if (_currentCardPage > 0)
                                                        _cardController.previousPage(
                                                            duration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        300),
                                                            curve: Curves.ease);
                                                      else
                                                        _exitFlashcards();
                                                    },
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                            foregroundColor:
                                                                Colors.white),
                                                    child: Text(
                                                        _currentCardPage > 0
                                                            ? 'Previous'
                                                            : 'Back'))),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: ElevatedButton(
                                                    onPressed: () {
                                                      if (_currentCardPage <
                                                          cards.length - 1)
                                                        _cardController.nextPage(
                                                            duration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        300),
                                                            curve: Curves.ease);
                                                      else
                                                        _exitFlashcards();
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                            backgroundColor:
                                                                widget.color),
                                                    child: Text(
                                                        _currentCardPage <
                                                                cards.length - 1
                                                            ? 'Next Card'
                                                            : 'Done')))
                                          ],
                                        ),
                                      ])),
                                    ])
                              : SingleChildScrollView(
                                  key: ValueKey(_currentSectionIndex),
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                              color: widget.color
                                                  .withOpacity(0.14),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                  color: widget.color
                                                      .withOpacity(0.35))),
                                          child: Text(
                                            _sections[_currentSectionIndex]
                                                .subtitle,
                                            style: TextStyle(
                                                color: widget.color
                                                    .withOpacity(0.95),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        Text(
                                            'Tap "Start" to begin the flashcards for this section.',
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.9),
                                                fontSize: 14)),
                                        const SizedBox(height: 12),
                                        ElevatedButton(
                                            onPressed: _startFlashcards,
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: widget.color),
                                            child: const Text('Start')),
                                        const SizedBox(height: 12),
                                        _buildMiniCard(
                                            title: 'Study tip',
                                            body:
                                                'Try to recall the definition before tapping the card. Repeating cards helps memory.',
                                            tint: widget.color),
                                      ]))),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _currentSectionIndex > 0
                            ? () => setState(() => _currentSectionIndex--)
                            : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _currentSectionIndex > 0 ? 1 : 0.45,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white12)),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_back_ios_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Prev Section',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _currentSectionIndex < _sections.length - 1
                            ? () => setState(() => _currentSectionIndex++)
                            : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _currentSectionIndex < _sections.length - 1
                              ? 1
                              : 0.45,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                widget.color,
                                widget.color.withOpacity(0.78)
                              ]),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                    color: widget.color.withOpacity(0.32),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8))
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentSectionIndex < _sections.length - 1
                                      ? 'Next Section'
                                      : 'Done',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                    _currentSectionIndex < _sections.length - 1
                                        ? Icons.arrow_forward_ios_rounded
                                        : Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CybersecurityVocabularyScreen extends StatefulWidget {
  final String course;
  final Color color;

  const CybersecurityVocabularyScreen({
    super.key,
    required this.course,
    required this.color,
  });

  @override
  State<CybersecurityVocabularyScreen> createState() =>
      _CybersecurityVocabularyScreenState();
}

class _CybersecurityVocabularyScreenState
    extends State<CybersecurityVocabularyScreen> {
  static const List<_CyberVocabularyTerm> _terms = [
    _CyberVocabularyTerm(
      term: 'Virus',
      definition:
          'A piece of code that is capable of copying itself and typically has a detrimental effect, such as corrupting the system or destroying data.',
      difficulty: 'Easy',
    ),
    _CyberVocabularyTerm(
      term: 'Social Engineering',
      definition:
          'Tricking/deceiving someone into giving you private information or data.',
      difficulty: 'Medium',
    ),
    _CyberVocabularyTerm(
      term: 'Backdoor',
      definition:
          'An attacker gets access by using an exploit to access the system.',
      difficulty: 'Difficult',
    ),
  ];

  static const List<String> _difficultyOptions = [
    'All',
    'Easy',
    'Medium',
    'Difficult',
  ];

  final PageController _pageController = PageController(viewportFraction: 0.9);
  String _selectedDifficulty = 'All';
  int _currentIndex = 0;
  bool _isFlipped = false;

  List<_CyberVocabularyTerm> get _visibleTerms {
    if (_selectedDifficulty == 'All') return _terms;
    return _terms
        .where((term) => term.difficulty == _selectedDifficulty)
        .toList(growable: false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _setDifficulty(String difficulty) {
    setState(() {
      _selectedDifficulty = difficulty;
      _currentIndex = 0;
      _isFlipped = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  void _handleMoreAction(String action) {
    if (action == 'reset') {
      setState(() {
        _currentIndex = 0;
        _isFlipped = false;
      });
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    _setDifficulty(action);
  }

  void _goToPrevious() {
    if (_currentIndex == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToNext(List<_CyberVocabularyTerm> terms) {
    if (_currentIndex >= terms.length - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return const Color(0xFF66BB6A);
      case 'Medium':
        return fblaGold;
      case 'Difficult':
        return const Color(0xFFFF7043);
      default:
        return widget.color;
    }
  }

  Widget _buildStatPill({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    final pillColor = color ?? widget.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pillColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: pillColor, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyChip(String difficulty) {
    final selected = _selectedDifficulty == difficulty;
    final chipColor =
        difficulty == 'All' ? widget.color : _difficultyColor(difficulty);

    return GestureDetector(
      onTap: () => _setDifficulty(difficulty),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? chipColor.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                selected ? chipColor.withValues(alpha: 0.72) : Colors.white12,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          difficulty,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty) {
    final color = _difficultyColor(difficulty);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.46)),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildFlashcard(_CyberVocabularyTerm term, int index) {
    final shouldFlip = _isFlipped && index == _currentIndex;

    return GestureDetector(
      onTap: () => setState(() => _isFlipped = !_isFlipped),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: shouldFlip ? pi : 0),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
        builder: (context, angle, child) {
          final showBack = angle > pi / 2;
          final displayAngle = showBack ? angle - pi : angle;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0018)
              ..rotateY(displayAngle),
            child: _buildCardSide(term, showBack: showBack),
          );
        },
      ),
    );
  }

  Widget _buildCardSide(_CyberVocabularyTerm term, {required bool showBack}) {
    final difficultyColor = _difficultyColor(term.difficulty);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: showBack
              ? [
                  difficultyColor.withValues(alpha: 0.28),
                  const Color(0xFF0B1624),
                ]
              : [
                  widget.color.withValues(alpha: 0.28),
                  const Color(0xFF0B1624),
                ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: (showBack ? difficultyColor : widget.color)
              .withValues(alpha: 0.52),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: (showBack ? difficultyColor : widget.color)
                .withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildDifficultyBadge(term.difficulty),
              const Spacer(),
              Icon(
                showBack ? Icons.auto_stories_outlined : Icons.style_outlined,
                color: Colors.white70,
                size: 20,
              ),
            ],
          ),
          const Spacer(),
          Text(
            showBack ? 'Definition' : 'Term',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            showBack ? term.definition : term.term,
            style: TextStyle(
              color: Colors.white,
              fontSize: showBack ? 22 : 30,
              height: showBack ? 1.35 : 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.touch_app_outlined,
                color: Colors.white.withValues(alpha: 0.62),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                showBack ? 'Tap to return to the term' : 'Tap to reveal',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.64),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermPreview(_CyberVocabularyTerm term) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  term.term,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildDifficultyBadge(term.difficulty),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            term.definition,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final terms = _visibleTerms;
    final currentTerm = terms.isEmpty ? null : terms[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF061726),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vocabulary',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.course} · Flashcards',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      color: const Color(0xFF0B1624),
                      icon: const Icon(Icons.more_horiz, color: Colors.white),
                      onSelected: _handleMoreAction,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'reset',
                          child: Text('Reset deck'),
                        ),
                        const PopupMenuDivider(),
                        for (final difficulty in _difficultyOptions)
                          PopupMenuItem(
                            value: difficulty,
                            child: Text('Show $difficulty'),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: fblaGold.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: fblaGold.withValues(alpha: 0.38),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.menu_book_rounded,
                                    color: fblaGold,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Cybersecurity Vocabulary',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Flip through each card, filter by difficulty, and use the list below as a quick reference.',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.72),
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _buildStatPill(
                                  icon: Icons.format_list_numbered_rounded,
                                  label: 'Number of terms',
                                  value: '${terms.length} of ${_terms.length}',
                                ),
                                _buildStatPill(
                                  icon: Icons.speed_rounded,
                                  label: 'Difficulty',
                                  value: _selectedDifficulty,
                                  color: _selectedDifficulty == 'All'
                                      ? widget.color
                                      : _difficultyColor(_selectedDifficulty),
                                ),
                                _buildStatPill(
                                  icon: Icons.touch_app_outlined,
                                  label: 'Mode',
                                  value: 'Flip cards',
                                  color: fblaGold,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Difficulty',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            for (final difficulty in _difficultyOptions) ...[
                              _buildDifficultyChip(difficulty),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (terms.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Text(
                            'No terms match this filter yet.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      else ...[
                        SizedBox(
                          height: 330,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: terms.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentIndex = index;
                                _isFlipped = false;
                              });
                            },
                            itemBuilder: (context, index) {
                              return _buildFlashcard(terms[index], index);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            terms.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: index == _currentIndex ? 18 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: index == _currentIndex
                                    ? widget.color
                                    : Colors.white24,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _currentIndex == 0 ? null : _goToPrevious,
                                icon: const Icon(Icons.chevron_left_rounded),
                                label: const Text('Previous'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: Colors.white30,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.24),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() => _isFlipped = !_isFlipped);
                                },
                                icon: const Icon(Icons.flip_rounded),
                                label: Text(
                                  _isFlipped ? 'Show Term' : 'Flip',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: fblaGold,
                                  foregroundColor: fblaNavy,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _currentIndex >= terms.length - 1
                                    ? null
                                    : () => _goToNext(terms),
                                icon: const Icon(Icons.chevron_right_rounded),
                                label: const Text('Next'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.color,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      Colors.white.withValues(alpha: 0.10),
                                  disabledForegroundColor: Colors.white38,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (currentTerm != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Card ${_currentIndex + 1} of ${terms.length} · ${currentTerm.difficulty}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Term List',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            'Expandable',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.58),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final term in terms) _buildTermPreview(term),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CyberVocabularyTerm {
  final String term;
  final String definition;
  final String difficulty;

  const _CyberVocabularyTerm({
    required this.term,
    required this.definition,
    required this.difficulty,
  });
}

class CybersecurityQuestionBankScreen extends StatefulWidget {
  final String course;
  final Color color;

  const CybersecurityQuestionBankScreen({
    super.key,
    required this.course,
    required this.color,
  });

  @override
  State<CybersecurityQuestionBankScreen> createState() =>
      _CybersecurityQuestionBankScreenState();
}

class _CybersecurityQuestionBankScreenState
    extends State<CybersecurityQuestionBankScreen> {
  static final List<_CyberQuestion> _questions =
      _parseQuestionBank(_cyberQuestionSeed);

  final Map<int, int> _answers = {};
  final Set<int> _savedQuestions = {};
  String _selectedTopic = 'All Topics';
  String _selectedDifficulty = 'All';
  String _completedFilter = 'All';
  String _resultFilter = 'All';
  bool _savedOnly = false;
  int _currentIndex = 0;

  static List<_CyberQuestion> _parseQuestionBank(String seed) {
    return seed
        .trim()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
      final parts = line.split('|');
      return _CyberQuestion(
        id: int.parse(parts[0]),
        topic: parts[1],
        difficulty: parts[2],
        answerIndex: 'ABCD'.indexOf(parts[3]),
        prompt: parts[4],
        options: parts.sublist(5, 9),
      );
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final answerEntries =
        prefs.getStringList('cyberQuestionBankAnswers') ?? const <String>[];
    final savedEntries =
        prefs.getStringList('cyberQuestionBankSaved') ?? const <String>[];

    if (!mounted) return;
    setState(() {
      _answers.clear();
      for (final entry in answerEntries) {
        final parts = entry.split(':');
        if (parts.length != 2) continue;
        final id = int.tryParse(parts[0]);
        final answer = int.tryParse(parts[1]);
        if (id != null && answer != null) {
          _answers[id] = answer;
        }
      }

      _savedQuestions
        ..clear()
        ..addAll(savedEntries.map(int.tryParse).whereType<int>());
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'cyberQuestionBankAnswers',
      _answers.entries.map((entry) => '${entry.key}:${entry.value}').toList(),
    );
    await prefs.setStringList(
      'cyberQuestionBankSaved',
      _savedQuestions.map((id) => id.toString()).toList(),
    );
  }

  List<String> get _topics {
    return [
      'All Topics',
      ..._questions.map((question) => question.topic).toSet()
    ];
  }

  List<_CyberQuestion> get _filteredQuestions {
    return _questions.where((question) {
      if (_selectedTopic != 'All Topics' && question.topic != _selectedTopic) {
        return false;
      }
      if (_selectedDifficulty != 'All' &&
          question.difficulty != _selectedDifficulty) {
        return false;
      }
      if (_savedOnly && !_savedQuestions.contains(question.id)) {
        return false;
      }

      final selectedAnswer = _answers[question.id];
      final completed = selectedAnswer != null;
      if (_completedFilter == 'Completed' && !completed) return false;
      if (_completedFilter == 'Uncompleted' && completed) return false;

      if (_resultFilter == 'Correct') {
        return completed && selectedAnswer == question.answerIndex;
      }
      if (_resultFilter == 'Incorrect') {
        return completed && selectedAnswer != question.answerIndex;
      }
      if (_resultFilter == 'Unanswered') {
        return !completed;
      }

      return true;
    }).toList(growable: false);
  }

  double get _overallProgress => _answers.length / _questions.length;

  double get _overallAccuracy {
    if (_answers.isEmpty) return 0;
    final correct = _questions
        .where((question) => _answers[question.id] == question.answerIndex)
        .length;
    return correct / _answers.length;
  }

  void _resetFilters() {
    setState(() {
      _selectedTopic = 'All Topics';
      _selectedDifficulty = 'All';
      _completedFilter = 'All';
      _resultFilter = 'All';
      _savedOnly = false;
      _currentIndex = 0;
    });
  }

  Future<void> _resetProgress() async {
    setState(() {
      _answers.clear();
      _savedQuestions.clear();
      _currentIndex = 0;
    });
    await _saveProgress();
  }

  void _setTopic(String topic) {
    setState(() {
      _selectedTopic = topic;
      _currentIndex = 0;
    });
  }

  void _setDifficulty(String difficulty) {
    setState(() {
      _selectedDifficulty = difficulty;
      _currentIndex = 0;
    });
  }

  void _setCompletedFilter(String filter) {
    setState(() {
      _completedFilter = filter;
      _currentIndex = 0;
    });
  }

  void _setResultFilter(String filter) {
    setState(() {
      _resultFilter = filter;
      _currentIndex = 0;
    });
  }

  Future<void> _answerQuestion(_CyberQuestion question, int optionIndex) async {
    setState(() => _answers[question.id] = optionIndex);
    await _saveProgress();
  }

  Future<void> _toggleSaved(_CyberQuestion question) async {
    setState(() {
      if (_savedQuestions.contains(question.id)) {
        _savedQuestions.remove(question.id);
      } else {
        _savedQuestions.add(question.id);
      }
    });
    await _saveProgress();
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return const Color(0xFF66BB6A);
      case 'Medium':
        return fblaGold;
      case 'Difficult':
        return const Color(0xFFFF7043);
      default:
        return widget.color;
    }
  }

  Color _optionColor(_CyberQuestion question, int index) {
    final selectedAnswer = _answers[question.id];
    if (selectedAnswer == null) return Colors.white.withValues(alpha: 0.055);
    if (index == question.answerIndex) {
      return const Color(0xFF66BB6A).withValues(alpha: 0.2);
    }
    if (index == selectedAnswer) {
      return const Color(0xFFFF7043).withValues(alpha: 0.2);
    }
    return Colors.white.withValues(alpha: 0.035);
  }

  Color _optionBorderColor(_CyberQuestion question, int index) {
    final selectedAnswer = _answers[question.id];
    if (selectedAnswer == null) return Colors.white12;
    if (index == question.answerIndex) {
      return const Color(0xFF66BB6A).withValues(alpha: 0.7);
    }
    if (index == selectedAnswer) {
      return const Color(0xFFFF7043).withValues(alpha: 0.7);
    }
    return Colors.white12;
  }

  List<_CyberQuestion> _questionsForTopic(String topic) {
    return _questions
        .where((question) => question.topic == topic)
        .toList(growable: false);
  }

  double _topicProgress(String topic) {
    final questions = _questionsForTopic(topic);
    if (questions.isEmpty) return 0;
    final completed =
        questions.where((question) => _answers.containsKey(question.id)).length;
    return completed / questions.length;
  }

  double? _topicAccuracy(String topic) {
    final answered = _questionsForTopic(topic)
        .where((question) => _answers.containsKey(question.id))
        .toList(growable: false);
    if (answered.isEmpty) return null;
    final correct = answered
        .where((question) => _answers[question.id] == question.answerIndex)
        .length;
    return correct / answered.length;
  }

  Widget _buildPopupFilter({
    required IconData icon,
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    return PopupMenuButton<String>(
      color: const Color(0xFF0B1624),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                if (option == value)
                  Icon(Icons.check_rounded, color: widget.color, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      Text(option, style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 17),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(List<_CyberQuestion> filteredQuestions) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.color.withValues(alpha: 0.38)),
            ),
            child: Icon(Icons.quiz_rounded, color: widget.color, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Practice all topics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start practicing ${filteredQuestions.length} filtered questions from ${_questions.length} total cybersecurity MCQs.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: filteredQuestions.isEmpty
                ? null
                : () => setState(() => _currentIndex = 0),
            style: ElevatedButton.styleFrom(
              backgroundColor: fblaGold,
              foregroundColor: fblaNavy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: const Text(
              'Start',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStats() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            label: 'Progress',
            value: '${(_overallProgress * 100).round()}%',
            icon: Icons.trending_up_rounded,
            color: widget.color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            label: 'Accuracy',
            value: _answers.isEmpty
                ? '--'
                : '${(_overallAccuracy * 100).round()}%',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF66BB6A),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            label: 'Saved',
            value: '${_savedQuestions.length}',
            icon: Icons.bookmark_rounded,
            color: fblaGold,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicDashboard() {
    final topics = _topics.where((topic) => topic != 'All Topics').toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Topic',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(
                width: 94,
                child: Text(
                  'Progress',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(
                width: 68,
                child: Text(
                  'Accuracy',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final topic in topics) _buildTopicRow(topic),
        ],
      ),
    );
  }

  Widget _buildTopicRow(String topic) {
    final topicQuestions = _questionsForTopic(topic);
    final progress = _topicProgress(topic);
    final accuracy = _topicAccuracy(topic);
    final completed = topicQuestions
        .where((question) => _answers.containsKey(question.id))
        .length;
    final selected = _selectedTopic == topic;

    return InkWell(
      onTap: () => _setTopic(topic),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected
              ? widget.color.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              progress >= 1
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: progress >= 1 ? const Color(0xFF66BB6A) : Colors.white30,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                topic,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: 94,
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.10),
                        valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$completed/${topicQuestions.length}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.66),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 68,
              child: Text(
                accuracy == null ? '--' : '${(accuracy * 100).round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: accuracy == null
                      ? Colors.white38
                      : const Color(0xFF66BB6A),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(List<_CyberQuestion> filteredQuestions) {
    if (filteredQuestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: const Text(
          'No questions match these filters yet.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final safeIndex =
        _currentIndex.clamp(0, filteredQuestions.length - 1).toInt();
    if (safeIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = safeIndex);
      });
    }
    final question = filteredQuestions[safeIndex];
    final selectedAnswer = _answers[question.id];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: widget.color.withValues(alpha: 0.36)),
                ),
                child: Text(
                  question.topic,
                  style: TextStyle(
                    color: widget.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _difficultyColor(question.difficulty)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _difficultyColor(question.difficulty)
                        .withValues(alpha: 0.42),
                  ),
                ),
                child: Text(
                  question.difficulty,
                  style: TextStyle(
                    color: _difficultyColor(question.difficulty),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _toggleSaved(question),
                icon: Icon(
                  _savedQuestions.contains(question.id)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _savedQuestions.contains(question.id)
                      ? fblaGold
                      : Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Question ${safeIndex + 1} of ${filteredQuestions.length}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question.prompt,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.35,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => _answerQuestion(question, i),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _optionColor(question, i),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _optionBorderColor(question, i)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          String.fromCharCode(65 + i),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          question.options[i],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (selectedAnswer != null && i == question.answerIndex)
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF66BB6A))
                      else if (selectedAnswer == i &&
                          selectedAnswer != question.answerIndex)
                        const Icon(Icons.cancel_rounded,
                            color: Color(0xFFFF7043)),
                    ],
                  ),
                ),
              ),
            ),
          if (selectedAnswer != null) ...[
            const SizedBox(height: 4),
            Text(
              selectedAnswer == question.answerIndex
                  ? 'Correct. Nice work.'
                  : 'Incorrect. Correct answer: ${String.fromCharCode(65 + question.answerIndex)}',
              style: TextStyle(
                color: selectedAnswer == question.answerIndex
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFFFF7043),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: safeIndex == 0
                      ? null
                      : () => setState(() => _currentIndex = safeIndex - 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white30,
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: safeIndex >= filteredQuestions.length - 1
                      ? null
                      : () => setState(() => _currentIndex = safeIndex + 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.10),
                    disabledForegroundColor: Colors.white38,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredQuestions = _filteredQuestions;

    return Scaffold(
      backgroundColor: const Color(0xFF061726),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Question Bank',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.course} · Cybersecurity MCQs',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      color: const Color(0xFF0B1624),
                      icon: const Icon(Icons.more_horiz, color: Colors.white),
                      onSelected: (value) {
                        if (value == 'resetFilters') {
                          _resetFilters();
                        } else if (value == 'resetProgress') {
                          _resetProgress();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'resetFilters',
                          child: Text('Reset filters'),
                        ),
                        PopupMenuItem(
                          value: 'resetProgress',
                          child: Text('Reset progress'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildOverviewStats(),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPopupFilter(
                            icon: Icons.folder_rounded,
                            label: 'Question set',
                            value: _selectedTopic,
                            options: _topics,
                            onSelected: _setTopic,
                          ),
                          _buildPopupFilter(
                            icon: Icons.bar_chart_rounded,
                            label: 'Difficulty',
                            value: _selectedDifficulty,
                            options: const [
                              'All',
                              'Easy',
                              'Medium',
                              'Difficult'
                            ],
                            onSelected: _setDifficulty,
                          ),
                          _buildPopupFilter(
                            icon: Icons.check_circle_rounded,
                            label: 'Completed',
                            value: _completedFilter,
                            options: const ['All', 'Completed', 'Uncompleted'],
                            onSelected: _setCompletedFilter,
                          ),
                          _buildPopupFilter(
                            icon: Icons.insights_rounded,
                            label: 'Result',
                            value: _resultFilter,
                            options: const [
                              'All',
                              'Correct',
                              'Incorrect',
                              'Unanswered'
                            ],
                            onSelected: _setResultFilter,
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _savedOnly = !_savedOnly;
                                _currentIndex = 0;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: _savedOnly
                                    ? fblaGold.withValues(alpha: 0.18)
                                    : Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _savedOnly
                                      ? fblaGold.withValues(alpha: 0.46)
                                      : Colors.white12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _savedOnly
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    color:
                                        _savedOnly ? fblaGold : Colors.white70,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Saved',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildHeroCard(filteredQuestions),
                      const SizedBox(height: 18),
                      _buildTopicDashboard(),
                      const SizedBox(height: 18),
                      _buildQuestionCard(filteredQuestions),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CyberQuestion {
  final int id;
  final String topic;
  final String difficulty;
  final String prompt;
  final List<String> options;
  final int answerIndex;

  const _CyberQuestion({
    required this.id,
    required this.topic,
    required this.difficulty,
    required this.prompt,
    required this.options,
    required this.answerIndex,
  });
}

const String _cyberQuestionSeed = r'''
1|Cybersecurity Fundamentals|Easy|C|What is the main objective of cybersecurity measures?|To enhance system performance|To streamline software development|To safeguard information and infrastructure from cyber threats|To boost data storage efficiency
2|Cybersecurity Fundamentals|Easy|A|What does CIA stand for in the context of cybersecurity?|Confidentiality, Integrity, Availability|Control, Isolation, Authentication|Compliance, Investigation, Access|Connectivity, Inspection, Authorization
3|Cybersecurity Fundamentals|Easy|B|What is the primary function of multi-factor authentication (MFA)?|To reduce authentication time|To enhance security with multiple verification steps|To simplify user login processes|To increase network capacity
4|Cybersecurity Fundamentals|Easy|A|Which of the following is a type of authentication factor?|Biometric|Firewall|Encryption|Packet filtering
5|Cybersecurity Fundamentals|Easy|D|What is the key role of encryption in securing digital information?|To compress data for storage|To accelerate data processing|To facilitate data sharing|To render data unreadable without a key
6|Cybersecurity Fundamentals|Easy|C|Which of the following is a common access control model?|Data encryption model|Network segmentation model|Role-Based Access Control (RBAC)|Packet filtering model
7|Cybersecurity Fundamentals|Medium|D|What is a digital signature used for?|To encrypt network traffic|To store user credentials|To increase server performance|To verify the authenticity of a message
8|Cybersecurity Fundamentals|Medium|A|Which of the following is an example of a public key encryption algorithm?|RSA|DES|3DES|Blowfish
9|Cybersecurity Fundamentals|Medium|A|What is the primary function of a hardware security token?|To verify user identity securely|To enhance network speed|To store large datasets|To monitor system performance
10|Cybersecurity Fundamentals|Easy|C|What does the principle of least privilege (PoLP) entail?|Granting users full system access|Encrypting all user data|Limiting user access to only necessary resources|Monitoring all user activities
11|Threats and Attacks|Easy|C|Which of the following is a common type of cyber attack?|Data encryption|System backup|Phishing|Network optimization
12|Threats and Attacks|Easy|C|Which type of malware locks a user's data and demands payment for access?|Virus|Worm|Ransomware|Spyware
13|Threats and Attacks|Easy|D|Which of the following best describes a DDoS attack?|Stealing user credentials|Encrypting sensitive data|Installing malware on a device|Overwhelming a system with traffic
14|Threats and Attacks|Medium|B|Which technique involves manipulating individuals to disclose sensitive information?|SQL injection|Baiting|Brute force attack|Network scanning
15|Threats and Attacks|Medium|D|What does the term zero-day refer to in cybersecurity?|A day with no cyber attacks|A day when systems are updated|A day when backups are performed|A vulnerability exploited before a patch is available
16|Threats and Attacks|Medium|C|What is a man-in-the-middle (MITM) attack?|Locking a user's data for ransom|Flooding a server with requests|Intercepting communication between two parties|Guessing a user's password
17|Threats and Attacks|Easy|A|What is the purpose of a brute force attack?|To guess passwords through trial and error|To encrypt sensitive data|To monitor network traffic|To optimize server performance
18|Threats and Attacks|Easy|A|Which of the following is a type of malware that disguises itself as legitimate software?|Trojan|Worm|Virus|Ransomware
19|Threats and Attacks|Medium|C|Which of the following is a common type of spyware?|Ransomware|Worm|Keylogger|Trojan
20|Threats and Attacks|Easy|A|Which of the following is a common type of phishing attack?|Spear phishing|Brute force attack|SQL injection|Packet sniffing
21|Security Technologies|Easy|A|What is the primary role of a firewall in a network?|To filter and regulate network traffic|To store critical system logs|To develop secure applications|To encrypt user credentials
22|Security Technologies|Easy|B|What is the primary function of an Intrusion Detection System (IDS)?|To encrypt network traffic|To detect suspicious activity|To optimize database queries|To manage user accounts
23|Security Technologies|Medium|B|Which encryption algorithm uses the same key for both encryption and decryption?|RSA|AES|ECC|DSA
24|Security Technologies|Medium|C|What is the main function of a proxy server in a secure network?|To encrypt all network traffic|To store sensitive data securely|To mediate between users and external networks|To optimize server performance
25|Security Technologies|Medium|D|What is the core function of a Security Information and Event Management (SIEM) system?|To develop secure applications|To manage user permissions|To optimize network performance|To collect and analyze security event data
26|Security Technologies|Medium|B|What is the purpose of a honeypot in cybersecurity?|To store sensitive data|To attract and detect malicious activity|To encrypt network traffic|To optimize server performance
27|Security Technologies|Medium|A|What is the purpose of a sandbox in cybersecurity?|To isolate and analyze suspicious files|To store sensitive data|To optimize network traffic|To manage user accounts
28|Security Technologies|Medium|A|Which of the following is a network security device?|Intrusion Prevention System (IPS)|Database server|Web server|File server
29|Security Technologies|Medium|D|What is the purpose of a certificate authority (CA)?|To monitor network traffic|To optimize server performance|To manage user accounts|To issue and manage digital certificates
30|Security Technologies|Medium|B|What is the role of a Web Application Firewall (WAF)?|To manage user authentication|To protect web applications from attacks|To optimize server storage|To monitor network bandwidth
31|Security Practices and Management|Easy|B|What is the purpose of a security policy?|To increase network speed|To define rules for protecting an organization's assets|To optimize database performance|To store user data
32|Security Practices and Management|Easy|B|What is the purpose of a security audit?|To increase server storage|To evaluate and improve security measures|To optimize database performance|To develop new software
33|Security Practices and Management|Easy|B|What is the purpose of a penetration test?|To develop new software|To identify vulnerabilities in a system|To optimize network performance|To manage user permissions
34|Security Practices and Management|Medium|A|What is the primary role of a Security Operations Center (SOC)?|To detect and respond to security events|To develop cybersecurity software|To enhance network speed|To manage user authentication
35|Security Practices and Management|Easy|B|What is the purpose of a penetration test?|To develop new software|To identify vulnerabilities in a system|To optimize network performance|To manage user permissions
36|Security Practices and Management|Easy|B|What is the purpose of a security awareness training program?|To optimize network performance|To educate employees about cybersecurity best practices|To develop new software|To manage user accounts
37|Security Practices and Management|Easy|A|What does patch management involve?|Updating software to fix vulnerabilities|Encrypting network traffic|Monitoring user activity|Backing up data
38|Security Practices and Management|Easy|D|What is the purpose of a vulnerability assessment?|To optimize network performance|To manage user accounts|To encrypt sensitive data|To identify weaknesses in a system
39|Security Practices and Management|Medium|B|Which of the following is a common type of insider threat?|DDoS attack|Data theft by employees|SQL injection|Packet sniffing
40|Security Practices and Management|Medium|C|What is the purpose of incident response planning?|To optimize server performance|To develop new applications|To prepare for and mitigate security breaches|To increase network bandwidth
41|Latest Cybersecurity Features and Updates|Difficult|C|What is the core principle of Zero Trust Architecture, a recent cybersecurity trend?|Trust all users by default|Encrypt all data automatically|Verify every user and device continuously|Allow unrestricted network access
42|Latest Cybersecurity Features and Updates|Medium|A|Which recent technology is increasingly used for real-time threat detection?|Artificial Intelligence (AI)|Manual log analysis|Basic antivirus software|Static rule-based systems
43|Latest Cybersecurity Features and Updates|Difficult|B|What is the purpose of post-quantum cryptography, a developing field in cybersecurity?|To increase network speed|To protect against quantum computer attacks|To simplify user authentication|To optimize database queries
44|Latest Cybersecurity Features and Updates|Difficult|D|Which of the following is a feature of modern Endpoint Detection and Response (EDR) systems?|Blocking all network traffic|Encrypting all data by default|Managing user accounts|Continuous monitoring and automated response
45|Latest Cybersecurity Features and Updates|Difficult|A|What is a key benefit of Secure Access Service Edge (SASE), a recent cybersecurity framework?|Integrates network security with cloud-based services|Reduces network security controls|Stores all data locally|Disables cloud access
46|Latest Cybersecurity Features and Updates|Difficult|B|Which recent advancement enhances Security Orchestration, Automation, and Response (SOAR) platforms?|Manual threat analysis|Automated incident response workflows|Disabling firewalls|Reducing encryption strength
47|Latest Cybersecurity Features and Updates|Difficult|C|What is the purpose of Extended Detection and Response (XDR), a newer cybersecurity solution?|To manage user accounts|To optimize network performance|To integrate security data across multiple systems|To store sensitive data
48|Latest Cybersecurity Features and Updates|Difficult|A|Which of the following is a recent trend in cloud security?|Cloud-native security platforms|Disabling cloud access|Manual log monitoring|Reducing encryption levels
49|Latest Cybersecurity Features and Updates|Difficult|B|What is the role of AI-driven User and Entity Behavior Analytics (UEBA) in modern cybersecurity?|To optimize database performance|To detect anomalies in user behavior|To store sensitive data|To manage network bandwidth
50|Latest Cybersecurity Features and Updates|Difficult|D|Which of the following is a feature of modern passwordless authentication systems?|Requiring longer passwords|Using static credentials|Relying solely on usernames|Using biometrics or secure tokens
51|Network Security|Easy|C|Which protocol is commonly used to secure web communication?|FTP|HTTP|HTTPS|SMTP
52|Network Security|Easy|B|What is a VPN used for?|To block all network traffic|To create a secure connection over the internet|To increase server storage|To monitor user activity
53|Network Security|Easy|A|Which of the following is a common network security protocol?|TLS|SMTP|FTP|HTTP
54|Network Security|Medium|B|Which of the following is a common type of network attack?|Data encryption|Packet sniffing|User authentication|Database backup
55|Network Security|Medium|C|What is the purpose of network segmentation in cybersecurity?|To increase network speed|To store sensitive data|To isolate network sections for security|To optimize database queries
56|Network Security|Medium|A|What is the role of a Network Intrusion Detection System (NIDS)?|To monitor network traffic for suspicious activity|To encrypt sensitive data|To manage user accounts|To optimize server performance
57|Network Security|Medium|B|What is the purpose of a DMZ (Demilitarized Zone) in network security?|To store sensitive data|To provide a buffer zone for public-facing services|To increase network bandwidth|To manage user authentication
58|Network Security|Medium|D|Which of the following is a benefit of using VLANs in network security?|Increasing server storage|Encrypting all network traffic|Monitoring user activity|Isolating network traffic for security
59|Network Security|Medium|A|What is the purpose of IPsec in network security?|To provide secure communication over IP networks|To manage user accounts|To optimize database performance|To monitor server performance
60|Network Security|Medium|C|What is the role of a packet filter in network security?|To encrypt sensitive data|To store network logs|To control network traffic based on rules|To optimize network bandwidth
61|Data Protection and Compliance|Medium|D|What is the purpose of a data loss prevention (DLP) system?|To optimize network performance|To manage user accounts|To encrypt network traffic|To prevent unauthorized data access and leakage
62|Data Protection and Compliance|Medium|C|Which of the following is a common standard for information security management?|HTTP|FTP|ISO 27001|SMTP
63|Data Protection and Compliance|Medium|B|Which of the following is a common method to prevent SQL injection attacks?|Increasing server bandwidth|Using parameterized queries|Disabling firewalls|Reducing encryption strength
64|Data Protection and Compliance|Medium|B|Which of the following is a common method to protect against cross-site scripting (XSS) attacks?|Increasing server bandwidth|Input validation and sanitization|Disabling encryption|Reducing firewall rules
65|Data Protection and Compliance|Medium|B|What is the purpose of the General Data Protection Regulation (GDPR)?|To optimize network performance|To protect personal data and privacy|To manage user accounts|To increase server storage
66|Data Protection and Compliance|Medium|A|What is the purpose of data encryption at rest?|To protect stored data from unauthorized access|To increase data transmission speed|To monitor network traffic|To optimize database queries
67|Data Protection and Compliance|Difficult|C|Which of the following is a key requirement of the Payment Card Industry Data Security Standard (PCI DSS)?|Optimizing network bandwidth|Disabling encryption|Protecting cardholder data|Increasing server storage
68|Data Protection and Compliance|Medium|B|What is the purpose of a data retention policy?|To increase data storage capacity|To define how long data should be stored|To monitor network traffic|To optimize server performance
69|Data Protection and Compliance|Difficult|A|What is the role of a Data Protection Officer (DPO) under GDPR?|To oversee data protection compliance|To manage network firewalls|To optimize database performance|To develop new software
70|Data Protection and Compliance|Medium|C|What is the purpose of data anonymization in cybersecurity?|To increase data storage|To monitor user activity|To remove identifiable information from data|To optimize network bandwidth
71|Data Protection and Compliance|Medium|B|What is the primary purpose of hashing in cybersecurity?|To encrypt data for transmission|To convert data into a fixed-length value|To compress files|To store data permanently
72|Data Protection and Compliance|Easy|C|Which hashing algorithm is currently considered secure?|MD5|SHA-1|SHA-256|DES
73|Cybersecurity Quick Review|Easy|A|What is a vulnerability in cybersecurity?|A weakness that can be exploited|A backup mechanism|A security policy|An encryption algorithm
74|Cybersecurity Quick Review|Easy|D|What does patching primarily involve?|Monitoring logs|Backing up data|Encrypting systems|Fixing known vulnerabilities
75|Cybersecurity Quick Review|Easy|B|What is social engineering in cybersecurity?|Securing networks|Manipulating people to reveal information|Writing secure code|Encrypting databases
76|Cybersecurity Quick Review|Medium|A|Which attack involves inserting malicious queries into a database?|SQL Injection|Phishing|DDoS|Spoofing
77|Cybersecurity Quick Review|Medium|C|What does XSS stand for?|Extended Secure System|Cross Server Security|Cross-Site Scripting|External Security Script
78|Cybersecurity Quick Review|Easy|B|What is spoofing?|Encrypting traffic|Pretending to be a trusted entity|Blocking access|Monitoring systems
79|Cybersecurity Quick Review|Medium|A|What is a botnet?|A group of infected devices controlled remotely|A firewall system|A type of encryption|A data backup system
80|Cybersecurity Quick Review|Easy|D|What does endpoint security focus on?|Securing databases|Securing cloud storage|Securing networks|Securing user devices
81|Cybersecurity Quick Review|Easy|C|What is the primary goal of ransomware?|Data backup|Monitoring systems|Extorting money|Improving performance
82|Cybersecurity Quick Review|Easy|A|What is the role of antivirus software?|Detect and remove malware|Increase speed|Backup data|Encrypt files
83|Cybersecurity Quick Review|Easy|B|What is cybersecurity risk?|Encryption process|Potential for loss or damage|Firewall configuration|Network monitoring
84|Cybersecurity Quick Review|Medium|C|What is threat modeling?|Writing secure code|Encrypting systems|Identifying potential threats|Monitoring logs
85|Cybersecurity Quick Review|Easy|A|What is authentication?|Verifying identity|Granting access|Encrypting data|Monitoring traffic
86|Cybersecurity Quick Review|Easy|D|What is authorization in cybersecurity?|Verifying identity|Encrypting data|Monitoring logs|Granting access permissions
87|Cybersecurity Quick Review|Easy|B|What is a security breach?|System update|Unauthorized access to data|Backup process|Network optimization
88|Cybersecurity Quick Review|Easy|A|What is an encryption key?|A secret value used for encryption/decryption|A network protocol|A firewall rule|A backup file
89|Cybersecurity Quick Review|Easy|C|What is malware?|Secure software|Backup software|Malicious software|Network tool
90|Cybersecurity Quick Review|Easy|B|Which malware replicates itself across systems?|Trojan|Worm|Spyware|Adware
91|Cybersecurity Quick Review|Easy|D|What is spyware designed to do?|Encrypt files|Destroy data|Improve performance|Monitor user activity secretly
92|Cybersecurity Quick Review|Easy|A|What is a firewall rule?|A condition to allow or block traffic|A type of malware|Encryption key|Backup setting
93|Cybersecurity Quick Review|Easy|C|What is two-factor authentication (2FA)?|Using two passwords|Encrypting twice|Using two verification methods|Using two firewalls
94|Cybersecurity Quick Review|Easy|B|What is a digital certificate?|Backup file|Electronic document verifying identity|Encryption key|Security patch
95|Cybersecurity Quick Review|Easy|A|What is HTTPS?|Secure version of HTTP|File transfer protocol|Email protocol|Network attack
96|Cybersecurity Quick Review|Easy|D|What is data integrity?|Data storage|Data encryption|Data transmission|Ensuring data is accurate and unchanged
97|Cybersecurity Quick Review|Easy|B|What is data availability?|Encrypting data|Ensuring data is accessible when needed|Backing up data|Monitoring data
98|Cybersecurity Quick Review|Easy|A|What is a security incident?|An event that compromises security|System update|Backup activity|Performance tuning
99|Cybersecurity Quick Review|Easy|C|What is penetration testing?|Monitoring traffic|Encrypting systems|Simulating attacks to find vulnerabilities|Backing up systems
100|Cybersecurity Quick Review|Easy|B|What is cyber hygiene?|Cleaning hardware|Maintaining security best practices|Installing software|Monitoring performance
101|Cybersecurity Quick Review|Easy|C|What is the main goal of a security audit?|Increase system speed|Backup data|Evaluate security controls|Encrypt files
102|Cybersecurity Quick Review|Easy|B|What is the function of a VPN?|Increase bandwidth|Secure internet communication|Store data|Monitor logs
103|Cybersecurity Quick Review|Easy|A|Which type of attack involves overwhelming a system with traffic?|DDoS|Phishing|XSS|Spoofing
104|Cybersecurity Quick Review|Medium|D|What is a zero-day vulnerability?|A fixed bug|A tested patch|A known issue|A vulnerability with no patch available
105|Cybersecurity Quick Review|Medium|C|What is the purpose of a honeypot?|Encrypt data|Backup systems|Attract attackers for monitoring|Increase speed
106|Cybersecurity Quick Review|Easy|B|What is role-based access control (RBAC)?|Access based on passwords|Access based on user roles|Access based on location|Access based on time
107|Cybersecurity Quick Review|Easy|A|What is phishing?|Fraudulent attempt to steal information|Network monitoring|Data encryption|Backup process
108|Cybersecurity Quick Review|Easy|D|What is a strong password?|Short and simple|Only letters|Same for all accounts|Complex with mix of characters
109|Cybersecurity Quick Review|Easy|C|What is data backup?|Encrypting files|Monitoring logs|Copying data for recovery|Blocking traffic
110|Cybersecurity Quick Review|Easy|A|What is multi-factor authentication?|Using multiple verification methods|Using one password|Encrypting twice|Monitoring users
111|Cybersecurity Quick Review|Medium|B|What is insider threat?|External hacker|Threat from inside organization|Firewall attack|Network failure
112|Cybersecurity Quick Review|Easy|C|What is least privilege principle?|Full access to users|No access|Minimum necessary access|Unlimited access
113|Cybersecurity Quick Review|Easy|D|What is encryption at rest?|Encrypting network traffic|Encrypting emails|Encrypting during transfer|Encrypting stored data
114|Cybersecurity Quick Review|Easy|A|What is brute force attack?|Trying many password combinations|Injecting SQL|Monitoring logs|Encrypting data
115|Cybersecurity Quick Review|Medium|B|What is SIEM?|Encryption tool|Security monitoring and analysis system|Backup software|Network protocol
116|Cybersecurity Quick Review|Medium|C|What is an IDS?|Backup system|Encryption tool|Intrusion detection system|Network cable
117|Cybersecurity Quick Review|Medium|A|What is an IPS?|Intrusion prevention system|Internet protocol service|Internal protection system|Input processing system
118|Cybersecurity Quick Review|Medium|D|What is data masking?|Encrypting data|Deleting data|Backing up data|Hiding sensitive data
119|Cybersecurity Quick Review|Easy|B|What is compliance in cybersecurity?|Hacking systems|Following security regulations|Encrypting files|Monitoring traffic
120|Cybersecurity Quick Review|Medium|C|What is cyber resilience?|Preventing all attacks|Blocking internet access|Ability to recover from cyber attacks|Encrypting all data
121|Cybersecurity Quick Review|Medium|A|What is the primary purpose of a Web Application Firewall (WAF)?|To protect web applications from malicious traffic|To increase internet speed|To manage employee attendance|To encrypt local storage
122|Cybersecurity Quick Review|Medium|C|Which type of malware secretly records user activities such as keystrokes?|Worm|Trojan|Spyware|Rootkit
123|Cybersecurity Quick Review|Easy|B|What is the purpose of role-based access control (RBAC)?|To improve internet bandwidth|To assign permissions based on user roles|To monitor network cables|To increase storage capacity
124|Cybersecurity Quick Review|Easy|D|Which cybersecurity attack overloads systems with excessive traffic?|Phishing|Spoofing|SQL Injection|DDoS Attack
125|Cybersecurity Quick Review|Easy|A|What is the purpose of encryption in cybersecurity?|To protect data from unauthorized access|To increase processor speed|To reduce file sizes|To optimize databases
126|Cybersecurity Quick Review|Medium|C|Which security practice involves regularly reviewing system and user activity logs?|Penetration Testing|Threat Modeling|Security Monitoring|Data Compression
127|Cybersecurity Quick Review|Medium|B|What is the main objective of vulnerability management?|To improve website design|To identify and fix security weaknesses|To increase internet speed|To monitor hardware temperature
128|Cybersecurity Quick Review|Easy|A|Which authentication method uses physical traits for identity verification?|Biometric Authentication|Password Authentication|Token Authentication|Captcha Verification
129|Cybersecurity Quick Review|Easy|D|What is the purpose of cybersecurity awareness training?|To increase hardware performance|To configure firewalls automatically|To replace antivirus software|To educate users about security risks and best practices
130|Cybersecurity Quick Review|Medium|C|What is cyber threat intelligence?|A firewall configuration process|A method for compressing files|Information used to identify and prevent cyber threats|A type of malware
''';

class _CybersecurityModuleOneTwoScreenState
    extends State<CybersecurityModuleOneTwoScreen> {
  static const List<_CybersecuritySection> _sections = [
    _CybersecuritySection(
        title: 'Malware (Malicious Software)',
        subtitle: 'Types, how they spread, and why they are dangerous.'),
    _CybersecuritySection(
        title: 'Social Engineering',
        subtitle: 'Attacking people, not computers.'),
    _CybersecuritySection(
        title: 'Network Attacks',
        subtitle: 'How attackers target networks and services.'),
    _CybersecuritySection(
        title: 'Vulnerabilities', subtitle: 'Weaknesses attackers exploit.'),
    _CybersecuritySection(
        title: 'Zero-Day Attacks',
        subtitle: 'Unknown vulnerabilities with no patch.'),
    _CybersecuritySection(
        title: 'Insider Threats',
        subtitle: 'Risks from people inside an organization.'),
    _CybersecuritySection(
        title: 'Indicators of Compromise (IoCs)',
        subtitle: 'Signs that a system may be compromised.'),
  ];

  int _currentSectionIndex = 0;

  double get _progress => (_currentSectionIndex + 1) / _sections.length;
  bool get _canGoBack => _currentSectionIndex > 0;
  bool get _canGoForward => _currentSectionIndex < _sections.length - 1;

  void _goToSection(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= _sections.length) return;
    setState(() => _currentSectionIndex = nextIndex);
  }

  void _goBack() => _goToSection(_currentSectionIndex - 1);
  void _goForward() => _goToSection(_currentSectionIndex + 1);

  Widget _buildBullet(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: color ?? widget.color, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.45))),
        ],
      ),
    );
  }

  Widget _buildSectionHero(
      {required String label,
      required String body,
      required IconData icon,
      required Color tint}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [tint.withOpacity(0.22), Colors.white.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint.withOpacity(0.42)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: tint.withOpacity(0.22),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: tint, size: 24)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text(body,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  height: 1.5)),
        ])),
      ]),
    );
  }

  Widget _buildMiniCard(
      {required String title, required String body, required Color tint}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: tint.withOpacity(0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withOpacity(0.45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
        const SizedBox(height: 6),
        Text(body,
            style: TextStyle(
                color: Colors.white.withOpacity(0.86),
                fontSize: 13,
                height: 1.45)),
      ]),
    );
  }

  Widget _buildSectionContent(int index) {
    switch (index) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHero(
              label: 'Malware (Malicious Software)',
              body:
                  'Malware is software designed to harm, steal, or take control of a device. These are the main types you must know.',
              icon: Icons.bug_report_rounded,
              tint: widget.color),
          const SizedBox(height: 12),
          _buildMiniCard(
              title: 'Virus',
              body:
                  'Attaches to files or programs. Spreads when the infected file is opened. Can delete files or corrupt systems.',
              tint: const Color(0xFF64B5F6)),
          const SizedBox(height: 8),
          _buildMiniCard(
              title: 'Worm',
              body:
                  'Spreads automatically across networks. Doesn\'t need user action. Can overload systems and cause slowdowns.',
              tint: const Color(0xFFFF7043)),
          const SizedBox(height: 8),
          _buildMiniCard(
              title: 'Trojan Horse',
              body:
                  'Pretends to be something safe. Once opened, it installs harmful code. Often used to steal data or open backdoors.',
              tint: const Color(0xFF66BB6A)),
          const SizedBox(height: 8),
          _buildMiniCard(
              title: 'Ransomware',
              body:
                  'Locks your files and demands payment to unlock them. One of the most dangerous modern threats.',
              tint: const Color(0xFFF06292)),
          const SizedBox(height: 8),
          _buildMiniCard(
              title: 'Spyware & Adware',
              body:
                  'Spyware secretly collects information. Adware shows unwanted ads and can track users.',
              tint: widget.color),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHero(
              label: 'Social Engineering',
              body:
                  'Social engineering tricks people into giving up information or access.',
              icon: Icons.people_alt_rounded,
              tint: const Color(0xFF64B5F6)),
          const SizedBox(height: 12),
          _buildBullet(
              'Phishing: Fake emails or messages that look real and try to steal passwords or personal info.'),
          _buildBullet(
              'Spear Phishing: Targeted phishing aimed at a specific person.'),
          _buildBullet('Vishing: Voice phishing (scam phone calls).'),
          _buildBullet('Smishing: SMS/text message phishing.'),
          _buildBullet(
              'Pretexting: Pretending to be someone trustworthy (like tech support).'),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Why it works',
              body:
                  'Social engineering relies on trust, urgency, and authority. Attackers exploit emotions and routines.',
              tint: widget.color),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHero(
              label: 'Network Attacks',
              body:
                  'These attacks target networks, websites, or communication systems.',
              icon: Icons.settings_ethernet_rounded,
              tint: const Color(0xFFFF7043)),
          const SizedBox(height: 12),
          _buildBullet(
              'DDoS: Flood a website with traffic so it becomes slow or crashes.'),
          _buildBullet(
              'Man-in-the-Middle (MITM): Intercept communication, common on unsafe public Wi‑Fi.'),
          _buildBullet(
              'Brute Force Attack: Repeatedly guessing passwords; works on weak passwords.'),
          _buildBullet(
              'SQL Injection: Inject malicious code into a website\'s database to steal or delete data.'),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHero(
              label: 'Vulnerabilities',
              body:
                  'A vulnerability is a weakness in a system that attackers can exploit.',
              icon: Icons.warning_amber_rounded,
              tint: const Color(0xFF66BB6A)),
          const SizedBox(height: 12),
          _buildBullet('Outdated software'),
          _buildBullet('Weak passwords'),
          _buildBullet('Misconfigured settings'),
          _buildBullet('Unpatched security flaws'),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Fixing vulnerabilities',
              body:
                  'Regular updates, strong passwords, and secure configuration reduce many risks.',
              tint: widget.color),
        ]);
      case 4:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHero(
              label: 'Zero-Day Attacks',
              body:
                  'A zero-day is a vulnerability that developers don\'t know about and has no patch; attackers exploit it immediately.',
              icon: Icons.flash_on_rounded,
              tint: const Color(0xFFF06292)),
          const SizedBox(height: 12),
          _buildBullet('Developers have no patch'),
          _buildBullet('Attackers exploit before defenses exist'),
          _buildMiniCard(
              title: 'Why they are dangerous',
              body:
                  'No immediate fix exists, so detection and containment are critical.',
              tint: widget.color),
        ]);
      case 5:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHero(
              label: 'Insider Threats',
              body:
                  'Threats from people inside an organization: accidental or malicious.',
              icon: Icons.person_off_rounded,
              tint: const Color(0xFF64B5F6)),
          const SizedBox(height: 12),
          _buildBullet(
              'Accidental insiders: click phishing links, misconfigure systems, lose devices.'),
          _buildBullet(
              'Malicious insiders: steal data, sabotage systems, abuse access.'),
          _buildMiniCard(
              title: 'Mitigation',
              body:
                  'Least privilege, auditing, and training reduce insider risks.',
              tint: widget.color),
        ]);
      case 6:
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHero(
              label: 'Indicators of Compromise (IoCs)',
              body: 'Signs that something is wrong and may indicate an attack.',
              icon: Icons.search_rounded,
              tint: const Color(0xFFFF7043)),
          const SizedBox(height: 12),
          _buildBullet('Sudden slow performance'),
          _buildBullet('Unknown programs appearing'),
          _buildBullet('Strange network activity'),
          _buildBullet('Unauthorized logins'),
          _buildBullet('Files disappearing or changing'),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Action steps',
              body:
                  'If you spot IoCs, disconnect, report to your administrator, and preserve logs for investigation.',
              tint: widget.color),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061726),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: appBackgroundGradient),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Row(children: [
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white)),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(widget.course,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                            'Level 1 · Section ${_currentSectionIndex + 1} of ${_sections.length}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.72),
                                fontSize: 12)),
                      ])),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white12)),
                      child: const Text('1.2',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11))),
                ]),
                const SizedBox(height: 12),
                ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                        value: _progress.clamp(0.0, 1.0),
                        minHeight: 9,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(widget.color))),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 28,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 340),
                        reverseDuration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final fade = Tween<double>(begin: 0.0, end: 1.0)
                              .animate(animation);
                          final slide = Tween<Offset>(
                            begin: const Offset(0.06, 0.02),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: fade,
                            child: SlideTransition(
                              position: slide,
                              child: child,
                            ),
                          );
                        },
                        child: SingleChildScrollView(
                          key: ValueKey(_currentSectionIndex),
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: widget.color.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: widget.color.withOpacity(0.35)),
                                ),
                                child: Text(
                                  _sections[_currentSectionIndex].subtitle,
                                  style: TextStyle(
                                    color: widget.color.withOpacity(0.95),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              _buildSectionContent(_currentSectionIndex),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _canGoBack ? _goBack : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _canGoBack ? 1 : 0.45,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white12)),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_back_ios_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Back',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _canGoForward ? _goForward : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _canGoForward ? 1 : 0.45,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                widget.color,
                                widget.color.withOpacity(0.78)
                              ]),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                    color: widget.color.withOpacity(0.32),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8))
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _canGoForward ? 'Next' : 'Done',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                    _canGoForward
                                        ? Icons.arrow_forward_ios_rounded
                                        : Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CybersecurityModuleOneFourScreen extends StatefulWidget {
  final String course;
  final Color color;

  const CybersecurityModuleOneFourScreen(
      {required this.course, required this.color, Key? key})
      : super(key: key);

  @override
  State<CybersecurityModuleOneFourScreen> createState() =>
      _CybersecurityModuleOneFourScreenState();
}

class _CybersecurityModuleOneFourScreenState
    extends State<CybersecurityModuleOneFourScreen> {
  static const List<_CybersecuritySection> _sections = [
    _CybersecuritySection(
        title: 'Antivirus & Anti‑Malware',
        subtitle: 'Scans, blocks and removes malware.'),
    _CybersecuritySection(
        title: 'Firewalls',
        subtitle: 'Network traffic control and protection.'),
    _CybersecuritySection(
        title: 'Software Updates & Patches',
        subtitle: 'Keep systems patched and protected.'),
    _CybersecuritySection(
        title: 'Safe Browsing', subtitle: 'Best practices when online.'),
    _CybersecuritySection(
        title: 'Recognizing Suspicious Links & Emails',
        subtitle: 'Phishing and social engineering signs.'),
    _CybersecuritySection(
        title: 'Backups', subtitle: 'Protect data with regular backups.'),
    _CybersecuritySection(
        title: 'Secure Wi‑Fi',
        subtitle: 'Protect your network and connections.'),
    _CybersecuritySection(
        title: 'Basic Account Protection',
        subtitle: 'Passwords, MFA, and account hygiene.'),
  ];

  int _currentSectionIndex = 0;

  double get _progress => (_currentSectionIndex + 1) / _sections.length;

  bool get _canGoBack => _currentSectionIndex > 0;
  bool get _canGoForward => _currentSectionIndex < _sections.length - 1;

  void _goToSection(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= _sections.length) return;
    setState(() => _currentSectionIndex = nextIndex);
  }

  void _goBack() => _goToSection(_currentSectionIndex - 1);
  void _goForward() => _goToSection(_currentSectionIndex + 1);

  Widget _buildBullet(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: color ?? widget.color, shape: BoxShape.circle))),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.45))),
      ]),
    );
  }

  Widget _buildMiniCard(
      {required String title, required String body, required Color tint}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: tint.withOpacity(0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withOpacity(0.45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
        const SizedBox(height: 6),
        Text(body,
            style: TextStyle(
                color: Colors.white.withOpacity(0.86),
                fontSize: 13,
                height: 1.45)),
      ]),
    );
  }

  Widget _buildSectionContent(int index) {
    switch (index) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'What it does',
              body:
                  'Scans your device for harmful software; blocks suspicious files; removes viruses, worms, trojans, and spyware; warns about unsafe downloads.',
              tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Why it matters',
              body:
                  'Malware is a common digital threat — antivirus acts like a shield for your device.',
              tint: const Color(0xFF64B5F6)),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Good habits',
              body:
                  'Keep antivirus updated. Run regular scans. Don’t ignore warnings.',
              tint: widget.color),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'What a firewall does',
              body:
                  'Controls incoming and outgoing network traffic and decides what to allow or block — like a security guard for your connection.',
              tint: const Color(0xFFFF7043)),
          const SizedBox(height: 10),
          _buildBullet('Prevents unauthorized access'),
          _buildBullet('Stops malware from communicating with attackers'),
          const SizedBox(height: 8),
          _buildMiniCard(
              title: 'Types',
              body:
                  'Hardware firewalls (routers) and software firewalls (on your device). Both are useful.',
              tint: widget.color),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'What updates do',
              body:
                  'Fix vulnerabilities, improve security, patch bugs, and add protections.',
              tint: const Color(0xFF66BB6A)),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Why it matters',
              body:
                  'Most attacks succeed because devices are out of date. Updates close the holes attackers use.',
              tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Good habits',
              body:
                  'Turn on automatic updates. Update apps, browsers, and OS regularly.',
              tint: const Color(0xFF64B5F6)),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'How to browse safely',
              body:
                  'Only visit trusted sites; look for https://; avoid random ads; don’t download from unknown sources.',
              tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Why it matters',
              body: 'Many attacks start with a single unsafe click.',
              tint: const Color(0xFFFF7043)),
        ]);
      case 4:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Signs of suspicious messages',
              body:
                  'Urgent language, strange sender, misspellings, unexpected attachments, links that don’t match the real site.',
              tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'What to do',
              body:
                  'Don’t click, don’t reply, delete or report. This protects you from phishing and social engineering.',
              tint: const Color(0xFF64B5F6)),
        ]);
      case 5:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'What backups do',
              body:
                  'A backup is a copy of important files stored somewhere safe.',
              tint: const Color(0xFF66BB6A)),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Why it matters',
              body:
                  'Backups protect you from ransomware, accidental deletion, and device failure.',
              tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Good habits',
              body:
                  'Use cloud storage or external drives, back up regularly, keep backups separate.',
              tint: const Color(0xFFFF7043)),
        ]);
      case 6:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Secure Wi‑Fi',
              body:
                  'Use strong Wi‑Fi passwords; avoid public Wi‑Fi for sensitive tasks; turn off auto‑connect; use a hotspot when possible.',
              tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Why it matters',
              body:
                  'Public Wi‑Fi is a hotspot for MITM attacks, data theft, and fake networks.',
              tint: const Color(0xFF64B5F6)),
        ]);
      case 7:
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Basic account protection',
              body:
                  'Use strong, unique passwords; turn on multi‑factor authentication (MFA); don’t reuse passwords; log out on shared devices.',
              tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Why it matters',
              body:
                  'Good account hygiene reduces account takeover and protects personal data.',
              tint: const Color(0xFF66BB6A)),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061726),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: appBackgroundGradient),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Row(children: [
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white)),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(widget.course,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text('Level 1 · Basic Protection',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.72),
                                fontSize: 12)),
                      ])),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white12)),
                      child: const Text('1.4',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11))),
                ]),
                const SizedBox(height: 12),
                ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                        value: _progress.clamp(0.0, 1.0),
                        minHeight: 9,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(widget.color))),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 28,
                              offset: Offset(0, 16))
                        ]),
                    child: Align(
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 340),
                            child: SingleChildScrollView(
                                key: ValueKey(_currentSectionIndex),
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                            color:
                                                widget.color.withOpacity(0.14),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                                color: widget.color
                                                    .withOpacity(0.35))),
                                        child: Text(
                                          _sections[_currentSectionIndex]
                                              .subtitle,
                                          style: TextStyle(
                                              color: widget.color
                                                  .withOpacity(0.95),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      _buildSectionContent(
                                          _currentSectionIndex),
                                    ])))),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _canGoBack ? _goBack : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _canGoBack ? 1 : 0.45,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white12)),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_back_ios_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Back',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _canGoForward ? _goForward : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _canGoForward ? 1 : 0.45,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                widget.color,
                                widget.color.withOpacity(0.78)
                              ]),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                    color: widget.color.withOpacity(0.32),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8))
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _canGoForward ? 'Next' : 'Done',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                    _canGoForward
                                        ? Icons.arrow_forward_ios_rounded
                                        : Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CybersecurityModuleOneFiveScreen extends StatefulWidget {
  final String course;
  final Color color;

  const CybersecurityModuleOneFiveScreen(
      {required this.course, required this.color, Key? key})
      : super(key: key);

  @override
  State<CybersecurityModuleOneFiveScreen> createState() =>
      _CybersecurityModuleOneFiveScreenState();
}

class _CybersecurityModuleOneFiveScreenState
    extends State<CybersecurityModuleOneFiveScreen> {
  static const List<_CybersecuritySection> _sections = [
    _CybersecuritySection(
        title: 'What Makes a Password Strong?',
        subtitle: 'Length, complexity, uniqueness, and unpredictability.'),
    _CybersecuritySection(
        title: 'Common Password Mistakes',
        subtitle: 'Reuse, short passwords, personal info.'),
    _CybersecuritySection(
        title: 'Passphrases',
        subtitle: 'Long memorable phrases that are strong.'),
    _CybersecuritySection(
        title: 'Password Managers',
        subtitle: 'Store and generate passwords safely.'),
    _CybersecuritySection(
        title: 'Multi‑Factor Authentication (MFA)',
        subtitle: 'Adds extra verification steps.'),
    _CybersecuritySection(
        title: 'Auth Apps vs SMS Codes',
        subtitle: 'Why apps are preferred over SMS'),
    _CybersecuritySection(
        title: 'Recognizing Account Compromise',
        subtitle: 'Signs your account may be hacked.'),
    _CybersecuritySection(
        title: 'Safe Account Habits',
        subtitle: 'Practical daily habits to stay safe.'),
  ];

  int _currentSectionIndex = 0;

  // (no persistent interactive tiles in this module)

  double get _progress => (_currentSectionIndex + 1) / _sections.length;

  bool get _canGoBack => _currentSectionIndex > 0;
  bool get _canGoForward => _currentSectionIndex < _sections.length - 1;

  void _goToSection(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= _sections.length) return;
    setState(() => _currentSectionIndex = nextIndex);
  }

  void _goBack() => _goToSection(_currentSectionIndex - 1);
  void _goForward() => _goToSection(_currentSectionIndex + 1);

  Widget _buildMiniCard(
      {required String title, required String body, required Color tint}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: tint.withOpacity(0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withOpacity(0.45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
        const SizedBox(height: 6),
        Text(body,
            style: TextStyle(
                color: Colors.white.withOpacity(0.86),
                fontSize: 13,
                height: 1.45)),
      ]),
    );
  }

  // No interactive icon row: removed per request.

  Widget _buildSectionContent(int idx) {
    switch (idx) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Length',
              body: 'Use at least 12–16 characters.',
              tint: widget.color),
          const SizedBox(height: 8),
          _buildMiniCard(
              title: 'Complexity',
              body: 'Mix uppercase, lowercase, numbers, and symbols.',
              tint: const Color(0xFF64B5F6)),
          const SizedBox(height: 8),
          _buildMiniCard(
              title: 'Uniqueness & Unpredictability',
              body:
                  'Don’t reuse passwords or use personal info like names or birthdays.',
              tint: widget.color),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Common Mistakes',
              body:
                  'Reusing passwords, short passwords, personal info, sticky notes, sharing, simple patterns.',
              tint: const Color(0xFFFF7043)),
          const SizedBox(height: 8),
          _buildMiniCard(
              title: 'Why it matters',
              body:
                  'Predictable passwords make account takeover trivial for attackers.',
              tint: widget.color),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Passphrases',
              body:
                  'Long, memorable phrases like "BlueTacoRiver!92" are easy to remember and hard to crack.',
              tint: const Color(0xFF66BB6A)),
          const SizedBox(height: 8),
          _buildMiniCard(
              title: 'Benefits',
              body:
                  'Passphrases are long, memorable, and resistant to brute-force attacks.',
              tint: widget.color),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'What password managers do',
              body:
                  'Store encrypted passwords, generate strong passwords, autofill logins, and protect against phishing autofill traps.',
              tint: widget.color),
          const SizedBox(height: 8),
          _buildMiniCard(
              title: 'Why use one',
              body:
                  'You only remember one master password; no need to reuse passwords.',
              tint: const Color(0xFF64B5F6)),
        ]);
      case 4:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'What is MFA?',
              body:
                  'Requires two or more verification methods: something you know, have, or are.',
              tint: widget.color),
          const SizedBox(height: 8),
          _buildMiniCard(
              title: 'Why it matters',
              body:
                  'Blocks most account takeover attempts even if a password is stolen.',
              tint: const Color(0xFFFF7043)),
        ]);
      case 5:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Auth Apps vs SMS',
              body:
                  'Authenticator apps (Google Authenticator) are more secure and work offline; SMS can be intercepted or SIM-swapped.',
              tint: widget.color),
        ]);
      case 6:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Signs of compromise',
              body:
                  'Unexpected login alerts, password stops working, unknown devices, messages sent without you.',
              tint: widget.color),
          const SizedBox(height: 8),
          _buildMiniCard(
              title: 'If compromised',
              body:
                  'Change password, enable MFA, log out devices, check activity.',
              tint: const Color(0xFF64B5F6)),
        ]);
      case 7:
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Safe account habits',
              body:
                  'Unique passwords, MFA, update passwords, never share, use a password manager, log out on shared devices.',
              tint: widget.color),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061726),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: appBackgroundGradient),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Row(children: [
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white)),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(widget.course,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text('Level 1 · Password Basics',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.72),
                                fontSize: 12)),
                      ])),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white12)),
                      child: const Text('1.5',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11))),
                ]),
                const SizedBox(height: 12),
                ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                        value: _progress.clamp(0.0, 1.0),
                        minHeight: 9,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(widget.color))),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 28,
                              offset: Offset(0, 16))
                        ]),
                    child: Align(
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 340),
                            child: SingleChildScrollView(
                                key: ValueKey(_currentSectionIndex),
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                            color:
                                                widget.color.withOpacity(0.14),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                                color: widget.color
                                                    .withOpacity(0.35))),
                                        child: Text(
                                          _sections[_currentSectionIndex]
                                              .subtitle,
                                          style: TextStyle(
                                              color: widget.color
                                                  .withOpacity(0.95),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      _buildSectionContent(
                                          _currentSectionIndex),
                                    ])))),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _canGoBack ? _goBack : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _canGoBack ? 1 : 0.45,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white12)),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_back_ios_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Back',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _canGoForward ? _goForward : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _canGoForward ? 1 : 0.45,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                widget.color,
                                widget.color.withOpacity(0.78)
                              ]),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                    color: widget.color.withOpacity(0.32),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8))
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _canGoForward ? 'Next' : 'Done',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                    _canGoForward
                                        ? Icons.arrow_forward_ios_rounded
                                        : Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CybersecurityModuleOneSixScreen extends StatefulWidget {
  final String course;
  final Color color;

  const CybersecurityModuleOneSixScreen(
      {required this.course, required this.color, Key? key})
      : super(key: key);

  @override
  State<CybersecurityModuleOneSixScreen> createState() =>
      _CybersecurityModuleOneSixScreenState();
}

class _CybersecurityModuleOneSixScreenState
    extends State<CybersecurityModuleOneSixScreen> {
  static const List<_CybersecuritySection> _sections = [
    _CybersecuritySection(
        title: 'Safe Browsing',
        subtitle: 'Verify sites, look for https, avoid suspicious pop-ups.'),
    _CybersecuritySection(
        title: 'Safe Downloading',
        subtitle: 'Only download from trusted sources and scan files.'),
    _CybersecuritySection(
        title: 'Recognizing Online Scams',
        subtitle: 'Spot urgency, check sender, avoid strange links.'),
    _CybersecuritySection(
        title: 'Safe Social Media Use',
        subtitle: 'Protect personal info and control privacy.'),
    _CybersecuritySection(
        title: 'Public Wi‑Fi Safety',
        subtitle: 'Avoid sensitive logins and auto‑connect.'),
    _CybersecuritySection(
        title: 'Protecting Personal Information',
        subtitle: 'Keep phone, address, and IDs private.'),
  ];

  int _currentSectionIndex = 0;

  double get _progress => (_currentSectionIndex + 1) / _sections.length;

  bool get _canGoBack => _currentSectionIndex > 0;
  bool get _canGoForward => _currentSectionIndex < _sections.length - 1;

  void _goToSection(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= _sections.length) return;
    setState(() => _currentSectionIndex = nextIndex);
  }

  void _goBack() => _goToSection(_currentSectionIndex - 1);
  void _goForward() => _goToSection(_currentSectionIndex + 1);

  Widget _buildMiniCard(
      {required String title, required String body, required Color tint}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: tint.withOpacity(0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withOpacity(0.45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
        const SizedBox(height: 6),
        Text(body,
            style: TextStyle(
                color: Colors.white.withOpacity(0.86),
                fontSize: 13,
                height: 1.45)),
      ]),
    );
  }

  Widget _buildSectionContent(int idx) {
    switch (idx) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Look for secure connections',
              body:
                  'Check for https:// and the lock icon. Verify the URL carefully for small spelling changes.',
              tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Avoid unsafe sites',
              body:
                  'Leave sites with aggressive pop‑ups or pressure prompts; don’t click suspicious banners.',
              tint: const Color(0xFFFF7043)),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Download from trusted sources',
              body:
                  'Use official app stores or the developer’s website. Avoid .exe/.apk/.zip from unknown places.',
              tint: const Color(0xFF66BB6A)),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Scan files',
              body:
                  'Scan downloads with antivirus before opening; avoid cracked software.',
              tint: widget.color),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Spot scams',
              body:
                  'Urgent or threatening language, improbable prizes, links that don’t match the sender — these are red flags.',
              tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Before you click',
              body:
                  'Verify sender, check grammar/spelling, and confirm via a known channel if in doubt.',
              tint: const Color(0xFFFF7043)),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Protect personal info',
              body:
                  'Keep your profiles private and avoid sharing location, school, or routine details.',
              tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Be selective with connections',
              body:
                  'Only accept requests from people you know; remember posted content can be saved even after deletion.',
              tint: const Color(0xFF64B5F6)),
        ]);
      case 4:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Public Wi‑Fi risks',
              body:
                  'Avoid logging into banking or email on public Wi‑Fi; attackers can intercept traffic.',
              tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Safer alternatives',
              body:
                  'Use your phone hotspot, turn off auto‑connect, and prefer mobile data for sensitive work.',
              tint: const Color(0xFFFF7043)),
        ]);
      case 5:
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(
              title: 'Protecting personal info',
              body:
                  'Don’t post phone numbers, addresses, or ID numbers. Use app privacy settings and never share passwords.',
              tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(
              title: 'Good habits',
              body:
                  'Limit personal details, review privacy settings, and be cautious before sharing.',
              tint: const Color(0xFF66BB6A)),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061726),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: appBackgroundGradient),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Row(children: [
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white)),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(widget.course,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text('Level 1 · Safe Internet Practices',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.72),
                                fontSize: 12)),
                      ])),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white12)),
                      child: const Text('1.6',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11))),
                ]),
                const SizedBox(height: 12),
                ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                        value: _progress.clamp(0.0, 1.0),
                        minHeight: 9,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(widget.color))),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 28,
                              offset: Offset(0, 16))
                        ]),
                    child: Align(
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 340),
                            child: SingleChildScrollView(
                                key: ValueKey(_currentSectionIndex),
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                            color:
                                                widget.color.withOpacity(0.14),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                                color: widget.color
                                                    .withOpacity(0.35))),
                                        child: Text(
                                          _sections[_currentSectionIndex]
                                              .subtitle,
                                          style: TextStyle(
                                              color: widget.color
                                                  .withOpacity(0.95),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      _buildSectionContent(
                                          _currentSectionIndex),
                                    ])))),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _canGoBack ? _goBack : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _canGoBack ? 1 : 0.45,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white12)),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_back_ios_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Back',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _canGoForward ? _goForward : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _canGoForward ? 1 : 0.45,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                widget.color,
                                widget.color.withOpacity(0.78)
                              ]),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                    color: widget.color.withOpacity(0.32),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8))
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _canGoForward ? 'Next' : 'Done',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                    _canGoForward
                                        ? Icons.arrow_forward_ios_rounded
                                        : Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagonalConnectorPainter extends CustomPainter {
  final Color color;
  final double startFrac;
  final double endFrac;

  const _DiagonalConnectorPainter({
    required this.color,
    required this.startFrac,
    required this.endFrac,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width * startFrac, 8);
    final end = Offset(size.width * endFrac, size.height - 8);

    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 3
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
    canvas.drawCircle(start, 4, endpointPaint);
    canvas.drawCircle(end, 4, endpointPaint);
  }

  @override
  bool shouldRepaint(covariant _DiagonalConnectorPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.startFrac != startFrac ||
        oldDelegate.endFrac != endFrac;
  }
}

class _LevelNode extends StatefulWidget {
  final int level;
  final Color color;
  final _LevelStatus status;
  final VoidCallback? onTap;

  const _LevelNode({
    required this.level,
    required this.color,
    required this.status,
    this.onTap,
  });

  @override
  State<_LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<_LevelNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  );

  @override
  void initState() {
    super.initState();
    if (widget.status == _LevelStatus.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _LevelNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate = widget.status == _LevelStatus.active;
    final wasAnimating = oldWidget.status == _LevelStatus.active;
    if (shouldAnimate && !wasAnimating) {
      _controller.repeat(reverse: true);
    } else if (!shouldAnimate && wasAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.status == _LevelStatus.active;
    final isCompleted = widget.status == _LevelStatus.completed;

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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse =
            isActive ? (0.5 + 0.5 * sin(_controller.value * pi * 2)) : 0.0;
        final glowOpacity = isActive ? 0.32 + (pulse * 0.28) : 0.0;
        final glowBlur = isActive ? 16 + (pulse * 7) : 0.0;
        final glowSpread = isActive ? 0.4 + (pulse * 0.8) : 0.0;
        final borderWidth = isActive ? 1.6 + (pulse * 0.9) : 0.9;

        return SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: bubbleGradient,
                  border: Border.all(color: borderColor, width: borderWidth),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: fblaGold.withOpacity(glowOpacity),
                            blurRadius: glowBlur,
                            spreadRadius: glowSpread,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (isActive)
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white
                                  .withOpacity(0.18 + (pulse * 0.18)),
                              width: 1.0 + (pulse * 0.4),
                            ),
                          ),
                        ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.0,
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.45),
                              width: 1.0,
                            ),
                          ),
                        ),
                      if (isCompleted || isActive)
                        Text(
                          '${widget.level}',
                          style: TextStyle(
                            color: isActive ? fblaNavy : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      else
                        Text(
                          '${widget.level}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!isActive && !isCompleted)
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1420),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              if (widget.onTap != null)
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: widget.onTap,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class CybersecurityLevelOneScreen extends StatefulWidget {
  final String course;
  final Color color;

  const CybersecurityLevelOneScreen({
    super.key,
    required this.course,
    required this.color,
  });

  @override
  State<CybersecurityLevelOneScreen> createState() =>
      _CybersecurityLevelOneScreenState();
}

class _CybersecurityLevelOneScreenState
    extends State<CybersecurityLevelOneScreen> {
  static const List<_CybersecuritySection> _sections = [
    _CybersecuritySection(
      title: 'What Cybersecurity Is',
      subtitle:
          'Start with the core idea before moving deeper into the module.',
    ),
    _CybersecuritySection(
      title: 'Why Cybersecurity Matters',
      subtitle: 'See why digital safety affects everyday life and trust.',
    ),
    _CybersecuritySection(
      title: 'The CIA Triad',
      subtitle:
          'Confidentiality, integrity, and availability are the core model.',
    ),
    _CybersecuritySection(
      title: 'Types of Data Cybersecurity Protects',
      subtitle: 'Different kinds of information need protection.',
    ),
    _CybersecuritySection(
      title: 'Cybersecurity vs. Information Security',
      subtitle: 'These two ideas overlap, but they are not identical.',
    ),
    _CybersecuritySection(
      title: 'Basic Cyber Hygiene',
      subtitle: 'Small habits that prevent big problems.',
    ),
    _CybersecuritySection(
      title: 'Real-World Cyber Risks',
      subtitle: 'Recognize the threats you are most likely to see.',
    ),
  ];

  int _currentSectionIndex = 0;

  double get _progress => (_currentSectionIndex + 1) / _sections.length;

  bool get _canGoBack => _currentSectionIndex > 0;
  bool get _canGoForward => _currentSectionIndex < _sections.length - 1;

  void _goToSection(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= _sections.length) return;
    setState(() {
      _currentSectionIndex = nextIndex;
    });
  }

  void _goBack() => _goToSection(_currentSectionIndex - 1);

  void _goForward() => _goToSection(_currentSectionIndex + 1);

  Widget _buildBullet(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color ?? widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard({
    required String title,
    required String body,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withOpacity(0.86),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHero({
    required String label,
    required String body,
    required IconData icon,
    required Color tint,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tint.withOpacity(0.22), Colors.white.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint.withOpacity(0.42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tint.withOpacity(0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tint, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.withOpacity(0.95),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSectionContent(int index) {
    switch (index) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHero(
              label: 'What cybersecurity is',
              body:
                  'Cybersecurity is the practice of protecting computers, phones, networks, accounts, data, and the people using them from digital threats. It is digital safety for the tools we rely on every day.',
              icon: Icons.shield_rounded,
              tint: fblaGold,
            ),
            const SizedBox(height: 14),
            _buildMiniCard(
              title: 'Think of it this way',
              body:
                  'A secure device should work the way it is supposed to, keep your information private, and resist misuse from outsiders or harmful software.',
              tint: const Color(0xFF64B5F6),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPill('Digital safety', fblaGold),
                _buildPill('Protection', fblaAccent),
                _buildPill('Trust', const Color(0xFF66BB6A)),
              ],
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHero(
              label: 'Why it matters',
              body:
                  'We use technology for almost everything: schoolwork, banking, communication, entertainment, shopping, and storing personal information. That makes cybersecurity part of everyday life, not just a computer topic.',
              icon: Icons.public_rounded,
              tint: const Color(0xFF64B5F6),
            ),
            const SizedBox(height: 14),
            _buildMiniCard(
              title: 'If cybersecurity fails, attackers can:',
              body:
                  'Steal identities, access private accounts, damage devices, spread harmful software, cause financial loss, and disrupt important services.',
              tint: const Color(0xFFFF7043),
            ),
            const SizedBox(height: 14),
            _buildMiniCard(
              title: 'Big picture',
              body:
                  'When cybersecurity works well, people can study, work, message, shop, and bank online with more confidence. It protects privacy, safety, and trust in the digital world.',
              tint: widget.color,
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHero(
              label: 'The CIA Triad',
              body:
                  'Confidentiality, integrity, and availability are the foundation of cybersecurity. Every security decision connects to at least one of these three goals.',
              icon: Icons.lock_rounded,
              tint: fblaGold,
            ),
            const SizedBox(height: 14),
            _buildMiniCard(
              title: 'Confidentiality',
              body:
                  'Information should only be seen by the right people. Examples include passwords, medical records, and private messages. Tools that help include encryption, passwords, and access controls.',
              tint: fblaGold,
            ),
            const SizedBox(height: 12),
            _buildMiniCard(
              title: 'Integrity',
              body:
                  'Information must stay accurate and unaltered. Grades should not be changed, bank balances should not be modified, and files should not be corrupted. Tools that help include checksums, version control, and digital signatures.',
              tint: const Color(0xFF66BB6A),
            ),
            const SizedBox(height: 12),
            _buildMiniCard(
              title: 'Availability',
              body:
                  'Information and systems must be accessible when needed. School websites, emergency services, and cloud storage should stay online. Threats include DDoS attacks, power outages, and system failures.',
              tint: const Color(0xFF64B5F6),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHero(
              label: 'What data needs protection',
              body:
                  'Cybersecurity protects many kinds of information. Anything stored digitally can become a target if it is not protected properly.',
              icon: Icons.storage_rounded,
              tint: const Color(0xFF66BB6A),
            ),
            const SizedBox(height: 14),
            _buildBullet('Personal data: name, address, and phone number'),
            _buildBullet('Financial data: bank accounts and credit cards'),
            _buildBullet('Health data'),
            _buildBullet('Business data'),
            _buildBullet('Government data'),
            _buildBullet('School records'),
            const SizedBox(height: 10),
            _buildMiniCard(
              title: 'Bottom line',
              body:
                  'Anything stored digitally needs protection. The more sensitive the data, the stronger the security should be.',
              tint: widget.color,
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHero(
              label: 'Related but different',
              body:
                  'Cybersecurity and information security overlap, but they are not identical. The difference matters when deciding what needs to be protected and how wide the protection should reach.',
              icon: Icons.compare_arrows_rounded,
              tint: fblaAccent,
            ),
            const SizedBox(height: 14),
            _buildMiniCard(
              title: 'Cybersecurity',
              body: 'Protects digital systems and networks.',
              tint: fblaGold,
            ),
            const SizedBox(height: 12),
            _buildMiniCard(
              title: 'Information Security',
              body:
                  'Protects all information, whether digital or physical, like paper files.',
              tint: const Color(0xFF64B5F6),
            ),
            const SizedBox(height: 14),
            _buildMiniCard(
              title: 'Relationship',
              body:
                  'Cybersecurity is a subset of information security. Information security is the broader category because it also covers physical information, like paper files.',
              tint: widget.color,
            ),
          ],
        );
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHero(
              label: 'Everyday habits',
              body:
                  'Cyber hygiene is a set of simple habits that dramatically reduce risk. The goal is not perfection; it is to make attacks harder and mistakes less likely.',
              icon: Icons.cleaning_services_rounded,
              tint: const Color(0xFFFF7043),
            ),
            const SizedBox(height: 14),
            _buildBullet('Use strong, unique passwords'),
            _buildBullet('Turn on multi-factor authentication'),
            _buildBullet('Keep software updated'),
            _buildBullet('Avoid suspicious links'),
            _buildBullet('Do not overshare personal info'),
            _buildBullet('Use secure Wi-Fi'),
            _buildBullet('Back up important files'),
            const SizedBox(height: 12),
            _buildMiniCard(
              title: 'Memory trick',
              body:
                  'Cyber hygiene is like brushing your teeth: small habits prevent big problems. A few safe choices every day can block a lot of common attacks.',
              tint: widget.color,
            ),
          ],
        );
      case 6:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHero(
              label: 'Real-world cyber risks',
              body:
                  'These examples show how cybersecurity failures appear in everyday life. Most attacks rely on tricking people, exploiting weak passwords, or hiding malware inside something that looks harmless.',
              icon: Icons.warning_amber_rounded,
              tint: const Color(0xFFF06292),
            ),
            const SizedBox(height: 14),
            _buildBullet('A phishing email pretending to be your school'),
            _buildBullet('A fake Wi-Fi network at a cafe'),
            _buildBullet('Malware hidden in a free download'),
            _buildBullet('Someone guessing a weak password'),
            _buildBullet('A scam message asking for personal info'),
            const SizedBox(height: 10),
            _buildMiniCard(
              title: 'Takeaway',
              body:
                  'If a message, network, or download feels unusual, pause and verify it before you click, connect, or share. That one habit stops many real attacks.',
              tint: widget.color,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061726),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: appBackgroundGradient),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.course,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Level 1 · Section ${_currentSectionIndex + 1} of ${_sections.length}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text(
                        '1.1',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _progress.clamp(0.0, 1.0),
                    minHeight: 9,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 28,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 340),
                        reverseDuration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final fade = Tween<double>(begin: 0.0, end: 1.0)
                              .animate(animation);
                          final slide = Tween<Offset>(
                            begin: const Offset(0.06, 0.02),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: fade,
                            child: SlideTransition(
                              position: slide,
                              child: child,
                            ),
                          );
                        },
                        child: SingleChildScrollView(
                          key: ValueKey(_currentSectionIndex),
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: widget.color.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: widget.color.withOpacity(0.35)),
                                ),
                                child: Text(
                                  _sections[_currentSectionIndex].subtitle,
                                  style: TextStyle(
                                    color: widget.color.withOpacity(0.95),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              _buildSectionContent(_currentSectionIndex),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _canGoBack ? _goBack : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _canGoBack ? 1 : 0.45,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_back_ios_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Back',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _canGoForward ? _goForward : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _canGoForward ? 1 : 0.45,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.color,
                                  widget.color.withOpacity(0.78)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.color.withOpacity(0.32),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _canGoForward ? 'Next' : 'Done',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _canGoForward
                                      ? Icons.arrow_forward_ios_rounded
                                      : Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CybersecuritySection {
  final String title;
  final String subtitle;

  const _CybersecuritySection({
    required this.title,
    required this.subtitle,
  });
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
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.98), color.withOpacity(0.82)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
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
                      child: Icon(icon, color: Colors.white, size: 34),
                    ),
                  ),
                  if (selected)
                    const Positioned(
                      bottom: 2,
                      left: 2,
                      child:
                          Icon(Icons.check_circle, color: fblaGold, size: 13),
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
          const SizedBox(height: 2),
          Text(
            title,
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

    final items =
        grouped.entries.where((entry) => entry.value.isNotEmpty).toList();

    return Scaffold(
      appBar:
          AppBar(title: const Text('Add Course'), backgroundColor: fblaNavy),
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
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF123A6A)
                              : const Color(0xFF07121A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: selected ? fblaAccent : Colors.white12,
                              width: 1.2),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                      color: fblaAccent.withOpacity(0.12),
                                      blurRadius: 8,
                                      offset: Offset(0, 4))
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: selected
                                    ? fblaAccent.withOpacity(0.25)
                                    : Colors.blueGrey.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                courseIconForName(eventName),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(eventName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600))),
                            AnimatedOpacity(
                              opacity: selected ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: AnimatedScale(
                                scale: selected ? 1.0 : 0.8,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(Icons.check_circle,
                                    color: Color(0xFFFDB913)),
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
  State<CompetitiveEventsScreen> createState() =>
      _CompetitiveEventsScreenState();
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
    _CompetitiveEventItem(
        'FBLA Stock Market Game', 'Virtual & Partner Challenges'),
    _CompetitiveEventItem('Community Service Project', 'Chapter Events'),
    _CompetitiveEventItem(
        'Local Chapter Annual Business Report', 'Chapter Events'),
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

    filtered
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
            url:
                'https://quizlet.com/search?query=FBLA%20${Uri.encodeComponent(event.name)}',
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
            description:
                'Checklist for delivery, visuals, and Q&A performance.',
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
            description:
                'Direct access to challenge portals and simulation tools.',
            url:
                'https://knowledgematters.com/high-school/virtual-business-challenge/',
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
            description:
                'Official project structure and submission instructions.',
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

class CybersecurityOfficialDocumentsScreen extends StatefulWidget {
  const CybersecurityOfficialDocumentsScreen({super.key});

  @override
  State<CybersecurityOfficialDocumentsScreen> createState() =>
      _CybersecurityOfficialDocumentsScreenState();
}

class _CybersecurityOfficialDocumentsScreenState
    extends State<CybersecurityOfficialDocumentsScreen> {
  static const List<_OfficialDocumentEntry> _documents = [
    _OfficialDocumentEntry(
      title: 'Cybersecurity Guidelines',
      subtitle: 'Open the official PDF for the Cybersecurity course.',
      icon: Icons.picture_as_pdf_outlined,
    ),
  ];

  _OfficialDocumentEntry? _selectedDocument;

  @override
  void initState() {
    super.initState();
    _selectedDocument = _documents.first;
  }

  void _openDocument(_OfficialDocumentEntry document) {
    if (document.title == 'Cybersecurity Guidelines') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const _CybersecurityGuidelinesPdfScreen(),
        ),
      );
    }
  }

  void _showDocumentDetails(_OfficialDocumentEntry document) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B1624),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                document.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                document.subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: fblaGold,
                    foregroundColor: fblaNavy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text(
                    'Open Document',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _openDocument(document);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const fblaBlue = Color(0xFF1D4E89);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Official Documents'),
        backgroundColor: fblaBlue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Material(
                  color: const Color(0xFF0B1624),
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: fblaGold.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(22),
                            border:
                                Border.all(color: fblaGold.withOpacity(0.35)),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: fblaGold,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Cybersecurity Official Documents',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap a document card to open it or tap the info button for details.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ..._documents.map((document) {
                          final selected = document == _selectedDocument;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                setState(() => _selectedDocument = document);
                                _openDocument(document);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? fblaGold.withOpacity(0.10)
                                      : Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected
                                        ? fblaGold.withOpacity(0.6)
                                        : Colors.white12,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: fblaGold.withOpacity(0.16),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(document.icon,
                                          color: fblaGold, size: 26),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            document.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            document.subtitle,
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.68),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () =>
                                          _showDocumentDetails(document),
                                      icon: const Icon(Icons.info_outline,
                                          color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 4),
                        Text(
                          'More documents can be added here later.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CybersecurityGuidelinesPdfScreen extends StatelessWidget {
  const _CybersecurityGuidelinesPdfScreen();

  @override
  Widget build(BuildContext context) {
    const fblaBlue = Color(0xFF1D4E89);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Cybersecurity Guidelines'),
        backgroundColor: fblaBlue,
        foregroundColor: Colors.white,
      ),
      body: SfPdfViewer.asset('assets/Cybersecurity.pdf'),
    );
  }
}

class _OfficialDocumentEntry {
  final String title;
  final String subtitle;
  final IconData icon;

  const _OfficialDocumentEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
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
          description:
              'Formatting standards reference for reports and letters.',
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

class _CourseMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CourseMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}
