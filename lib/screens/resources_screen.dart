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
  DateTime _streakCalendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

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
            const SnackBar(content: Text('Official Documents are only available for the Cybersecurity course right now.')),
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
        onTap: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vocabulary tools are coming soon.')),
          );
        },
      ),
    ];

    final buttonContext = _courseMenuButtonKey.currentContext;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final buttonBox = buttonContext?.findRenderObject() as RenderBox?;
    if (overlay == null || buttonBox == null) return;

    final buttonTopLeft = buttonBox.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonBottomRight = buttonBox.localToGlobal(buttonBox.size.bottomRight(Offset.zero), ancestor: overlay);

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
              const Icon(Icons.leaderboard,
                  color: Color(0xFF66BB6A), size: 31),
              hideValue: true,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showStreakCalendar() async {
    final buttonContext = _streakButtonKey.currentContext;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final buttonBox = buttonContext?.findRenderObject() as RenderBox?;
    if (overlay == null || buttonBox == null) return;

    final now = DateTime.now();
    DateTime displayedMonth = DateTime(now.year, now.month);

    final buttonTopLeft = buttonBox.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonBottomLeft =
        buttonBox.localToGlobal(Offset(0, buttonBox.size.height), ancestor: overlay);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            final cardWidth = (overlay.size.width - 24).clamp(300.0, 360.0).toDouble();
            final cardHeight = 352.0;
            final left = ((overlay.size.width - cardWidth) / 2).toDouble();
            final top = (buttonBottomLeft.dy + 10)
              .clamp(12.0, overlay.size.height - cardHeight - 12.0)
              .toDouble();
            final monthStart = DateTime(displayedMonth.year, displayedMonth.month, 1);
            final daysInMonth = DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
            final firstWeekday = monthStart.weekday % 7;
            final totalCells = 42;
            final currentDay = DateTime(now.year, now.month, now.day);
            final isCurrentMonth = now.year == displayedMonth.year && now.month == displayedMonth.month;

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
                                icon: const Icon(Icons.chevron_left, color: Colors.white),
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
                                icon: const Icon(Icons.chevron_right, color: Colors.white),
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
                              Text('S', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
                              Text('M', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
                              Text('T', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
                              Text('W', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
                              Text('T', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
                              Text('F', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
                              Text('S', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: totalCells,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 5,
                              crossAxisSpacing: 5,
                            ),
                            itemBuilder: (context, index) {
                              final dayNumber = index - firstWeekday + 1;
                              final isInMonth = dayNumber >= 1 && dayNumber <= daysInMonth;
                              final isToday = isCurrentMonth && isInMonth && dayNumber == currentDay.day;

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
          child: ScaleTransition(scale: scale, alignment: Alignment.topCenter, child: child),
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
                          if (_userCourses.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        border:
                                            Border.all(color: Colors.white12),
                                      ),
                                      child: const Icon(
                                        Icons.school_outlined,
                                        color: Colors.white38,
                                        size: 28,
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
                          colors: [widget.color, widget.color.withOpacity(0.72)],
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
                  colors: [Colors.transparent, widget.color.withOpacity(0.55), Colors.transparent],
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
                  final status = level == 1 ? _LevelStatus.active : _LevelStatus.locked;
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

  const CybersecurityModulesScreen({required this.course, required this.color, Key? key}) : super(key: key);

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
                        builder: (_) => CybersecurityLevelOneScreen(course: course, color: color),
                      ));
                    } else if (mod['id'] == '1.2') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CybersecurityModuleOneTwoScreen(course: course, color: color),
                      ));
                    } else if (mod['id'] == '1.3') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CybersecurityModuleOneThreeScreen(course: course, color: color),
                      ));
                    } else if (mod['id'] == '1.4') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CybersecurityModuleOneFourScreen(course: course, color: color),
                      ));
                    } else if (mod['id'] == '1.5') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CybersecurityModuleOneFiveScreen(course: course, color: color),
                      ));
                    } else if (mod['id'] == '1.6') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CybersecurityModuleOneSixScreen(course: course, color: color),
                      ));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                              style: const TextStyle(fontWeight: FontWeight.w800),
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
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text('Tap to open the lesson', style: TextStyle(color: Colors.white.withOpacity(0.7))),
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

  const CybersecurityModuleOneTwoScreen({required this.course, required this.color, Key? key}) : super(key: key);

  @override
  State<CybersecurityModuleOneTwoScreen> createState() => _CybersecurityModuleOneTwoScreenState();
}

class CybersecurityModuleOneThreeScreen extends StatefulWidget {
  final String course;
  final Color color;

  const CybersecurityModuleOneThreeScreen({required this.course, required this.color, Key? key}) : super(key: key);

  @override
  State<CybersecurityModuleOneThreeScreen> createState() => _CybersecurityModuleOneThreeScreenState();
}

class _CybersecurityModuleOneThreeScreenState extends State<CybersecurityModuleOneThreeScreen> {
  static const List<_CybersecuritySection> _sections = [
    _CybersecuritySection(title: 'Core Cybersecurity Terms', subtitle: 'Fundamental words everyone should know.'),
    _CybersecuritySection(title: 'CIA Triad', subtitle: 'Confidentiality, Integrity, Availability.'),
    _CybersecuritySection(title: 'Malware Types', subtitle: 'Common malware definitions.'),
    _CybersecuritySection(title: 'Social Engineering', subtitle: 'Human-targeted attacks.'),
    _CybersecuritySection(title: 'Network Security Terms', subtitle: 'Network-focused vocabulary.'),
    _CybersecuritySection(title: 'Authentication & Access', subtitle: 'Login and access control terms.'),
    _CybersecuritySection(title: 'System & Data Protection', subtitle: 'Protective measures and tools.'),
    _CybersecuritySection(title: 'Incident & Response', subtitle: 'How to react and what to look for.'),
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
          {'term': 'Cybersecurity', 'def': 'Protecting computers, networks, and data from digital threats.'},
          {'term': 'Threat', 'def': 'Anything that can cause harm to a system.'},
          {'term': 'Vulnerability', 'def': 'A weakness that can be exploited.'},
          {'term': 'Risk', 'def': 'The chance a threat will exploit a vulnerability.'},
          {'term': 'Attack Vector', 'def': 'The path an attacker uses to break in.'},
          {'term': 'Exploit', 'def': 'Code or technique used to take advantage of a vulnerability.'},
        ];
      case 1:
        return [
          {'term': 'Confidentiality', 'def': 'Only authorized people can access information.'},
          {'term': 'Integrity', 'def': 'Information stays accurate and unchanged.'},
          {'term': 'Availability', 'def': 'Systems and data are accessible when needed.'},
        ];
      case 2:
        return [
          {'term': 'Virus', 'def': 'Attaches to files and spreads when opened.'},
          {'term': 'Worm', 'def': 'Spreads automatically across networks.'},
          {'term': 'Trojan Horse', 'def': 'Looks safe but contains harmful code.'},
          {'term': 'Ransomware', 'def': 'Locks files and demands payment.'},
          {'term': 'Spyware', 'def': 'Secretly collects information.'},
          {'term': 'Adware', 'def': 'Shows unwanted ads; sometimes malicious.'},
        ];
      case 3:
        return [
          {'term': 'Phishing', 'def': 'Fake emails/messages that steal info.'},
          {'term': 'Spear Phishing', 'def': 'Targeted phishing at a specific person.'},
          {'term': 'Vishing', 'def': 'Phone‑based phishing.'},
          {'term': 'Smishing', 'def': 'Text‑message phishing.'},
          {'term': 'Pretexting', 'def': 'Attacker pretends to be someone trustworthy.'},
        ];
      case 4:
        return [
          {'term': 'Firewall', 'def': 'Blocks unwanted network traffic.'},
          {'term': 'Encryption', 'def': 'Scrambles data so only authorized people can read it.'},
          {'term': 'Decryption', 'def': 'Turning encrypted data back into readable form.'},
          {'term': 'MITM', 'def': 'Attacker intercepts communication.'},
          {'term': 'DDoS', 'def': 'Overloading a website so it crashes.'},
          {'term': 'Brute Force', 'def': 'Guessing passwords repeatedly.'},
        ];
      case 5:
        return [
          {'term': 'Authentication', 'def': 'Proving who you are (password, MFA).'},
          {'term': 'Authorization', 'def': 'What you’re allowed to access.'},
          {'term': 'MFA', 'def': 'Using more than one method to log in.'},
          {'term': 'Password Manager', 'def': 'Tool that stores and creates strong passwords.'},
        ];
      case 6:
        return [
          {'term': 'Patch', 'def': 'A software update that fixes vulnerabilities.'},
          {'term': 'Backup', 'def': 'Copy of data stored separately.'},
          {'term': 'Antivirus', 'def': 'Software that detects and removes malware.'},
          {'term': 'Secure Wi‑Fi', 'def': 'Encrypted wireless network (WPA2/WPA3).'},
        ];
      case 7:
      default:
        return [
          {'term': 'Incident', 'def': 'A security event that harms or threatens a system.'},
          {'term': 'IoC', 'def': 'Signs that an attack happened.'},
          {'term': 'Zero‑Day', 'def': 'A vulnerability with no patch yet.'},
          {'term': 'Insider Threat', 'def': 'Harm caused by someone inside an organization.'},
        ];
    }
  }

  Widget _buildCard(BuildContext context, Map<String, String> card, int pageIndex) {
    final flipped = _flippedCards.contains(pageIndex);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (flipped) _flippedCards.remove(pageIndex); else _flippedCards.add(pageIndex);
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
              Text(card['term']!, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (widget, children) => Stack(children: [for (final child in children) child],),
                transitionBuilder: (child, anim) {
                  // Determine which side this child represents using its key
                  final keyString = child.key is ValueKey ? (child.key as ValueKey).value?.toString() ?? '' : '';
                  final isDef = keyString.startsWith('def-');
                  // Incoming def side rotates from -90deg -> 0, outgoing rotates 0 -> 90deg
                  final rotateTween = isDef ? Tween(begin: -pi / 2, end: 0.0) : Tween(begin: 0.0, end: pi / 2);
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
                    ? Text(card['def']!, key: ValueKey('def-$pageIndex'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.4))
                    : Text('Tap to reveal', key: ValueKey('hint-$pageIndex'), style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCard({required String title, required String body, required Color tint}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withOpacity(0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 6),
        Text(body, style: TextStyle(color: Colors.white.withOpacity(0.86), fontSize: 13, height: 1.45)),
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
            child: Column(children: [
              Row(children: [
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white)),
                const SizedBox(width: 4),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.course, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Level 1 · Vocabulary', style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white12)), child: Text('1.3', style: const TextStyle(color: Colors.white70, fontSize: 11))),
              ]),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: _progress.clamp(0.0, 1.0), minHeight: 9, backgroundColor: Colors.white.withOpacity(0.08), valueColor: AlwaysStoppedAnimation<Color>(widget.color))),
              const SizedBox(height: 14),
              Expanded(child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 28, offset: Offset(0,16))]), child: Align(alignment: Alignment.topCenter, child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _inFlashcards ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Flashcards view
                Padding(padding: const EdgeInsets.symmetric(horizontal:12, vertical:8), child: Text(_sections[_currentSectionIndex].subtitle, style: TextStyle(color: widget.color.withOpacity(0.95), fontSize:12, fontWeight: FontWeight.w700),),),
                const SizedBox(height: 12),
                Expanded(child: Column(children: [
                  Expanded(child: PageView.builder(controller: _cardController, itemCount: cards.length, onPageChanged: (p) => setState(() { _currentCardPage = p; _flippedCards.clear(); }), itemBuilder: (ctx, p) => _buildCard(ctx, cards[p], p))),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(cards.length, (i) => Container(margin: const EdgeInsets.symmetric(horizontal:4), width: i==_currentCardPage?12:8, height: 8, decoration: BoxDecoration(color: i==_currentCardPage?widget.color:Colors.white12, borderRadius: BorderRadius.circular(6))),)),
                  const SizedBox(height: 8),
                  Row(children: [Expanded(child: OutlinedButton(onPressed: () { if (_currentCardPage>0) _cardController.previousPage(duration: const Duration(milliseconds:300), curve: Curves.ease); else _exitFlashcards(); }, style: OutlinedButton.styleFrom(foregroundColor: Colors.white), child: Text(_currentCardPage>0? 'Previous' : 'Back'))), const SizedBox(width: 12), Expanded(child: ElevatedButton(onPressed: () { if (_currentCardPage < cards.length-1) _cardController.nextPage(duration: const Duration(milliseconds:300), curve: Curves.ease); else _exitFlashcards(); }, style: ElevatedButton.styleFrom(backgroundColor: widget.color), child: Text(_currentCardPage < cards.length-1 ? 'Next Card' : 'Done')))],),
                ])),
              ]) : SingleChildScrollView(key: ValueKey(_currentSectionIndex), physics: const BouncingScrollPhysics(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: widget.color.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: widget.color.withOpacity(0.35))), child: Text(_sections[_currentSectionIndex].subtitle, style: TextStyle(color: widget.color.withOpacity(0.95), fontSize:12, fontWeight: FontWeight.w700),),),
                const SizedBox(height: 18),
                Text('Tap "Start" to begin the flashcards for this section.', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _startFlashcards, style: ElevatedButton.styleFrom(backgroundColor: widget.color), child: const Text('Start')),
                const SizedBox(height: 12),
                _buildMiniCard(title: 'Study tip', body: 'Try to recall the definition before tapping the card. Repeating cards helps memory.', tint: widget.color),
              ]))),),),),
              const SizedBox(height: 14),
              Row(children: [Expanded(child: GestureDetector(onTap: _currentSectionIndex>0? () => setState(()=> _currentSectionIndex--): null, child: AnimatedOpacity(duration: const Duration(milliseconds:180), opacity: _currentSectionIndex>0?1:0.45, child: Container(height:54, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size:18), SizedBox(width:8), Text('Prev Section', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize:14)),],),),),),), const SizedBox(width:12), Expanded(child: GestureDetector(onTap: _currentSectionIndex < _sections.length-1 ? () => setState(()=> _currentSectionIndex++): null, child: AnimatedOpacity(duration: const Duration(milliseconds:180), opacity: _currentSectionIndex < _sections.length-1?1:0.45, child: Container(height:54, decoration: BoxDecoration(gradient: LinearGradient(colors: [widget.color, widget.color.withOpacity(0.78)]), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: widget.color.withOpacity(0.32), blurRadius: 18, offset: const Offset(0,8))],), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_currentSectionIndex < _sections.length-1 ? 'Next Section' : 'Done', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize:14),), const SizedBox(width:8), Icon(_currentSectionIndex < _sections.length-1 ? Icons.arrow_forward_ios_rounded : Icons.check_rounded, color: Colors.white, size:18),],),),),),),],),
            ],),
          ),
        ),
      ),
    );
  }
}

class _CybersecurityModuleOneTwoScreenState extends State<CybersecurityModuleOneTwoScreen> {
  static const List<_CybersecuritySection> _sections = [
    _CybersecuritySection(title: 'Malware (Malicious Software)', subtitle: 'Types, how they spread, and why they are dangerous.'),
    _CybersecuritySection(title: 'Social Engineering', subtitle: 'Attacking people, not computers.'),
    _CybersecuritySection(title: 'Network Attacks', subtitle: 'How attackers target networks and services.'),
    _CybersecuritySection(title: 'Vulnerabilities', subtitle: 'Weaknesses attackers exploit.'),
    _CybersecuritySection(title: 'Zero-Day Attacks', subtitle: 'Unknown vulnerabilities with no patch.'),
    _CybersecuritySection(title: 'Insider Threats', subtitle: 'Risks from people inside an organization.'),
    _CybersecuritySection(title: 'Indicators of Compromise (IoCs)', subtitle: 'Signs that a system may be compromised.'),
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
            child: Container(width: 7, height: 7, decoration: BoxDecoration(color: color ?? widget.color, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.45))),
        ],
      ),
    );
  }

  Widget _buildSectionHero({required String label, required String body, required IconData icon, required Color tint}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [tint.withOpacity(0.22), Colors.white.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint.withOpacity(0.42)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: tint.withOpacity(0.22), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: tint, size: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.5)),
        ])),
      ]),
    );
  }

  Widget _buildMiniCard({required String title, required String body, required Color tint}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: tint.withOpacity(0.14), borderRadius: BorderRadius.circular(18), border: Border.all(color: tint.withOpacity(0.45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 6),
        Text(body, style: TextStyle(color: Colors.white.withOpacity(0.86), fontSize: 13, height: 1.45)),
      ]),
    );
  }

  Widget _buildSectionContent(int index) {
    switch (index) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHero(label: 'Malware (Malicious Software)', body: 'Malware is software designed to harm, steal, or take control of a device. These are the main types you must know.', icon: Icons.bug_report_rounded, tint: widget.color),
          const SizedBox(height: 12),
          _buildMiniCard(title: 'Virus', body: 'Attaches to files or programs. Spreads when the infected file is opened. Can delete files or corrupt systems.', tint: const Color(0xFF64B5F6)),
          const SizedBox(height: 8),
          _buildMiniCard(title: 'Worm', body: 'Spreads automatically across networks. Doesn\'t need user action. Can overload systems and cause slowdowns.', tint: const Color(0xFFFF7043)),
          const SizedBox(height: 8),
          _buildMiniCard(title: 'Trojan Horse', body: 'Pretends to be something safe. Once opened, it installs harmful code. Often used to steal data or open backdoors.', tint: const Color(0xFF66BB6A)),
          const SizedBox(height: 8),
          _buildMiniCard(title: 'Ransomware', body: 'Locks your files and demands payment to unlock them. One of the most dangerous modern threats.', tint: const Color(0xFFF06292)),
          const SizedBox(height: 8),
          _buildMiniCard(title: 'Spyware & Adware', body: 'Spyware secretly collects information. Adware shows unwanted ads and can track users.', tint: widget.color),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHero(label: 'Social Engineering', body: 'Social engineering tricks people into giving up information or access.', icon: Icons.people_alt_rounded, tint: const Color(0xFF64B5F6)),
          const SizedBox(height: 12),
          _buildBullet('Phishing: Fake emails or messages that look real and try to steal passwords or personal info.'),
          _buildBullet('Spear Phishing: Targeted phishing aimed at a specific person.'),
          _buildBullet('Vishing: Voice phishing (scam phone calls).'),
          _buildBullet('Smishing: SMS/text message phishing.'),
          _buildBullet('Pretexting: Pretending to be someone trustworthy (like tech support).'),
          const SizedBox(height: 10),
          _buildMiniCard(title: 'Why it works', body: 'Social engineering relies on trust, urgency, and authority. Attackers exploit emotions and routines.', tint: widget.color),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHero(label: 'Network Attacks', body: 'These attacks target networks, websites, or communication systems.', icon: Icons.settings_ethernet_rounded, tint: const Color(0xFFFF7043)),
          const SizedBox(height: 12),
          _buildBullet('DDoS: Flood a website with traffic so it becomes slow or crashes.'),
          _buildBullet('Man-in-the-Middle (MITM): Intercept communication, common on unsafe public Wi‑Fi.'),
          _buildBullet('Brute Force Attack: Repeatedly guessing passwords; works on weak passwords.'),
          _buildBullet('SQL Injection: Inject malicious code into a website\'s database to steal or delete data.'),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHero(label: 'Vulnerabilities', body: 'A vulnerability is a weakness in a system that attackers can exploit.', icon: Icons.warning_amber_rounded, tint: const Color(0xFF66BB6A)),
          const SizedBox(height: 12),
          _buildBullet('Outdated software'),
          _buildBullet('Weak passwords'),
          _buildBullet('Misconfigured settings'),
          _buildBullet('Unpatched security flaws'),
          const SizedBox(height: 10),
          _buildMiniCard(title: 'Fixing vulnerabilities', body: 'Regular updates, strong passwords, and secure configuration reduce many risks.', tint: widget.color),
        ]);
      case 4:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHero(label: 'Zero-Day Attacks', body: 'A zero-day is a vulnerability that developers don\'t know about and has no patch; attackers exploit it immediately.', icon: Icons.flash_on_rounded, tint: const Color(0xFFF06292)),
          const SizedBox(height: 12),
          _buildBullet('Developers have no patch'),
          _buildBullet('Attackers exploit before defenses exist'),
          _buildMiniCard(title: 'Why they are dangerous', body: 'No immediate fix exists, so detection and containment are critical.', tint: widget.color),
        ]);
      case 5:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHero(label: 'Insider Threats', body: 'Threats from people inside an organization: accidental or malicious.', icon: Icons.person_off_rounded, tint: const Color(0xFF64B5F6)),
          const SizedBox(height: 12),
          _buildBullet('Accidental insiders: click phishing links, misconfigure systems, lose devices.'),
          _buildBullet('Malicious insiders: steal data, sabotage systems, abuse access.'),
          _buildMiniCard(title: 'Mitigation', body: 'Least privilege, auditing, and training reduce insider risks.', tint: widget.color),
        ]);
      case 6:
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionHero(label: 'Indicators of Compromise (IoCs)', body: 'Signs that something is wrong and may indicate an attack.', icon: Icons.search_rounded, tint: const Color(0xFFFF7043)),
          const SizedBox(height: 12),
          _buildBullet('Sudden slow performance'),
          _buildBullet('Unknown programs appearing'),
          _buildBullet('Strange network activity'),
          _buildBullet('Unauthorized logins'),
          _buildBullet('Files disappearing or changing'),
          const SizedBox(height: 10),
          _buildMiniCard(title: 'Action steps', body: 'If you spot IoCs, disconnect, report to your administrator, and preserve logs for investigation.', tint: widget.color),
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
            child: Column(children: [
              Row(children: [
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white)),
                const SizedBox(width: 4),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.course, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Level 1 · Section ${_currentSectionIndex + 1} of ${_sections.length}', style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white12)), child: const Text('1.2', style: TextStyle(color: Colors.white70, fontSize: 11))),
              ]),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: _progress.clamp(0.0, 1.0), minHeight: 9, backgroundColor: Colors.white.withOpacity(0.08), valueColor: AlwaysStoppedAnimation<Color>(widget.color))),
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
                        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(animation);
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: widget.color.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: widget.color.withOpacity(0.35)),
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
              Row(children: [Expanded(child: GestureDetector(onTap: _canGoBack ? _goBack : null, child: AnimatedOpacity(duration: const Duration(milliseconds: 180), opacity: _canGoBack ? 1 : 0.45, child: Container(height:54, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18), SizedBox(width:8), Text('Back', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize:14),),],),),),),), const SizedBox(width:12), Expanded(child: GestureDetector(onTap: _canGoForward ? _goForward : null, child: AnimatedOpacity(duration: const Duration(milliseconds:180), opacity: _canGoForward ? 1 : 0.45, child: Container(height:54, decoration: BoxDecoration(gradient: LinearGradient(colors: [widget.color, widget.color.withOpacity(0.78)]), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: widget.color.withOpacity(0.32), blurRadius: 18, offset: const Offset(0,8))],), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_canGoForward ? 'Next' : 'Done', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize:14),), const SizedBox(width:8), Icon(_canGoForward ? Icons.arrow_forward_ios_rounded : Icons.check_rounded, color: Colors.white, size:18),],),),),),),],),
            ],),
          ),
        ),
      ),
    );
  }
}

class CybersecurityModuleOneFourScreen extends StatefulWidget {
  final String course;
  final Color color;

  const CybersecurityModuleOneFourScreen({required this.course, required this.color, Key? key}) : super(key: key);

  @override
  State<CybersecurityModuleOneFourScreen> createState() => _CybersecurityModuleOneFourScreenState();
}

class _CybersecurityModuleOneFourScreenState extends State<CybersecurityModuleOneFourScreen> {
  static const List<_CybersecuritySection> _sections = [
    _CybersecuritySection(title: 'Antivirus & Anti‑Malware', subtitle: 'Scans, blocks and removes malware.'),
    _CybersecuritySection(title: 'Firewalls', subtitle: 'Network traffic control and protection.'),
    _CybersecuritySection(title: 'Software Updates & Patches', subtitle: 'Keep systems patched and protected.'),
    _CybersecuritySection(title: 'Safe Browsing', subtitle: 'Best practices when online.'),
    _CybersecuritySection(title: 'Recognizing Suspicious Links & Emails', subtitle: 'Phishing and social engineering signs.'),
    _CybersecuritySection(title: 'Backups', subtitle: 'Protect data with regular backups.'),
    _CybersecuritySection(title: 'Secure Wi‑Fi', subtitle: 'Protect your network and connections.'),
    _CybersecuritySection(title: 'Basic Account Protection', subtitle: 'Passwords, MFA, and account hygiene.'),
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
        Padding(padding: const EdgeInsets.only(top:7), child: Container(width:7, height:7, decoration: BoxDecoration(color: color ?? widget.color, shape: BoxShape.circle))),
        const SizedBox(width:10),
        Expanded(child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.45))),
      ]),
    );
  }

  Widget _buildMiniCard({required String title, required String body, required Color tint}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: tint.withOpacity(0.14), borderRadius: BorderRadius.circular(18), border: Border.all(color: tint.withOpacity(0.45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height:6),
        Text(body, style: TextStyle(color: Colors.white.withOpacity(0.86), fontSize: 13, height: 1.45)),
      ]),
    );
  }

  Widget _buildSectionContent(int index) {
    switch (index) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'What it does', body: 'Scans your device for harmful software; blocks suspicious files; removes viruses, worms, trojans, and spyware; warns about unsafe downloads.', tint: widget.color),
          const SizedBox(height:10),
          _buildMiniCard(title: 'Why it matters', body: 'Malware is a common digital threat — antivirus acts like a shield for your device.', tint: const Color(0xFF64B5F6)),
          const SizedBox(height:10),
          _buildMiniCard(title: 'Good habits', body: 'Keep antivirus updated. Run regular scans. Don’t ignore warnings.', tint: widget.color),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'What a firewall does', body: 'Controls incoming and outgoing network traffic and decides what to allow or block — like a security guard for your connection.', tint: const Color(0xFFFF7043)),
          const SizedBox(height:10),
          _buildBullet('Prevents unauthorized access'),
          _buildBullet('Stops malware from communicating with attackers'),
          const SizedBox(height:8),
          _buildMiniCard(title: 'Types', body: 'Hardware firewalls (routers) and software firewalls (on your device). Both are useful.', tint: widget.color),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'What updates do', body: 'Fix vulnerabilities, improve security, patch bugs, and add protections.', tint: const Color(0xFF66BB6A)),
          const SizedBox(height:10),
          _buildMiniCard(title: 'Why it matters', body: 'Most attacks succeed because devices are out of date. Updates close the holes attackers use.', tint: widget.color),
          const SizedBox(height:10),
          _buildMiniCard(title: 'Good habits', body: 'Turn on automatic updates. Update apps, browsers, and OS regularly.', tint: const Color(0xFF64B5F6)),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'How to browse safely', body: 'Only visit trusted sites; look for https://; avoid random ads; don’t download from unknown sources.', tint: widget.color),
          const SizedBox(height:10),
          _buildMiniCard(title: 'Why it matters', body: 'Many attacks start with a single unsafe click.', tint: const Color(0xFFFF7043)),
        ]);
      case 4:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Signs of suspicious messages', body: 'Urgent language, strange sender, misspellings, unexpected attachments, links that don’t match the real site.', tint: widget.color),
          const SizedBox(height:10),
          _buildMiniCard(title: 'What to do', body: 'Don’t click, don’t reply, delete or report. This protects you from phishing and social engineering.', tint: const Color(0xFF64B5F6)),
        ]);
      case 5:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'What backups do', body: 'A backup is a copy of important files stored somewhere safe.', tint: const Color(0xFF66BB6A)),
          const SizedBox(height:10),
          _buildMiniCard(title: 'Why it matters', body: 'Backups protect you from ransomware, accidental deletion, and device failure.', tint: widget.color),
          const SizedBox(height:10),
          _buildMiniCard(title: 'Good habits', body: 'Use cloud storage or external drives, back up regularly, keep backups separate.', tint: const Color(0xFFFF7043)),
        ]);
      case 6:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Secure Wi‑Fi', body: 'Use strong Wi‑Fi passwords; avoid public Wi‑Fi for sensitive tasks; turn off auto‑connect; use a hotspot when possible.', tint: widget.color),
          const SizedBox(height:10),
          _buildMiniCard(title: 'Why it matters', body: 'Public Wi‑Fi is a hotspot for MITM attacks, data theft, and fake networks.', tint: const Color(0xFF64B5F6)),
        ]);
      case 7:
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Basic account protection', body: 'Use strong, unique passwords; turn on multi‑factor authentication (MFA); don’t reuse passwords; log out on shared devices.', tint: widget.color),
          const SizedBox(height:10),
          _buildMiniCard(title: 'Why it matters', body: 'Good account hygiene reduces account takeover and protects personal data.', tint: const Color(0xFF66BB6A)),
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
            child: Column(children: [
              Row(children: [
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white)),
                const SizedBox(width: 4),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.course, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Level 1 · Basic Protection', style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white12)), child: const Text('1.4', style: TextStyle(color: Colors.white70, fontSize: 11))),
              ]),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: _progress.clamp(0.0, 1.0), minHeight: 9, backgroundColor: Colors.white.withOpacity(0.08), valueColor: AlwaysStoppedAnimation<Color>(widget.color))),
              const SizedBox(height: 14),
              Expanded(child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 28, offset: Offset(0,16))]), child: Align(alignment: Alignment.topCenter, child: AnimatedSwitcher(duration: const Duration(milliseconds: 340), child: SingleChildScrollView(key: ValueKey(_currentSectionIndex), physics: const BouncingScrollPhysics(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: widget.color.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: widget.color.withOpacity(0.35))), child: Text(_sections[_currentSectionIndex].subtitle, style: TextStyle(color: widget.color.withOpacity(0.95), fontSize:12, fontWeight: FontWeight.w700),),),
                const SizedBox(height: 18),
                _buildSectionContent(_currentSectionIndex),
              ])))),),),
              const SizedBox(height: 14),
              Row(children: [Expanded(child: GestureDetector(onTap: _canGoBack ? _goBack : null, child: AnimatedOpacity(duration: const Duration(milliseconds:180), opacity: _canGoBack ? 1 : 0.45, child: Container(height:54, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size:18), SizedBox(width:8), Text('Back', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize:14)),],),),),),), const SizedBox(width:12), Expanded(child: GestureDetector(onTap: _canGoForward ? _goForward : null, child: AnimatedOpacity(duration: const Duration(milliseconds:180), opacity: _canGoForward ? 1 : 0.45, child: Container(height:54, decoration: BoxDecoration(gradient: LinearGradient(colors: [widget.color, widget.color.withOpacity(0.78)]), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: widget.color.withOpacity(0.32), blurRadius: 18, offset: const Offset(0,8))],), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_canGoForward ? 'Next' : 'Done', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize:14),), const SizedBox(width:8), Icon(_canGoForward ? Icons.arrow_forward_ios_rounded : Icons.check_rounded, color: Colors.white, size:18),],),),),),),],),
            ],),
          ),
        ),
      ),
    );
  }
}

class CybersecurityModuleOneFiveScreen extends StatefulWidget {
  final String course;
  final Color color;

  const CybersecurityModuleOneFiveScreen({required this.course, required this.color, Key? key}) : super(key: key);

  @override
  State<CybersecurityModuleOneFiveScreen> createState() => _CybersecurityModuleOneFiveScreenState();
}

class _CybersecurityModuleOneFiveScreenState extends State<CybersecurityModuleOneFiveScreen> {
  static const List<_CybersecuritySection> _sections = [
    _CybersecuritySection(title: 'What Makes a Password Strong?', subtitle: 'Length, complexity, uniqueness, and unpredictability.'),
    _CybersecuritySection(title: 'Common Password Mistakes', subtitle: 'Reuse, short passwords, personal info.'),
    _CybersecuritySection(title: 'Passphrases', subtitle: 'Long memorable phrases that are strong.'),
    _CybersecuritySection(title: 'Password Managers', subtitle: 'Store and generate passwords safely.'),
    _CybersecuritySection(title: 'Multi‑Factor Authentication (MFA)', subtitle: 'Adds extra verification steps.'),
    _CybersecuritySection(title: 'Auth Apps vs SMS Codes', subtitle: 'Why apps are preferred over SMS'),
    _CybersecuritySection(title: 'Recognizing Account Compromise', subtitle: 'Signs your account may be hacked.'),
    _CybersecuritySection(title: 'Safe Account Habits', subtitle: 'Practical daily habits to stay safe.'),
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

  Widget _buildMiniCard({required String title, required String body, required Color tint}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: tint.withOpacity(0.14), borderRadius: BorderRadius.circular(18), border: Border.all(color: tint.withOpacity(0.45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 6),
        Text(body, style: TextStyle(color: Colors.white.withOpacity(0.86), fontSize: 13, height: 1.45)),
      ]),
    );
  }

  // No interactive icon row: removed per request.

  Widget _buildSectionContent(int idx) {
    switch (idx) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Length', body: 'Use at least 12–16 characters.', tint: widget.color),
          const SizedBox(height:8),
          _buildMiniCard(title: 'Complexity', body: 'Mix uppercase, lowercase, numbers, and symbols.', tint: const Color(0xFF64B5F6)),
          const SizedBox(height:8),
          _buildMiniCard(title: 'Uniqueness & Unpredictability', body: 'Don’t reuse passwords or use personal info like names or birthdays.', tint: widget.color),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Common Mistakes', body: 'Reusing passwords, short passwords, personal info, sticky notes, sharing, simple patterns.', tint: const Color(0xFFFF7043)),
          const SizedBox(height:8),
          _buildMiniCard(title: 'Why it matters', body: 'Predictable passwords make account takeover trivial for attackers.', tint: widget.color),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Passphrases', body: 'Long, memorable phrases like "BlueTacoRiver!92" are easy to remember and hard to crack.', tint: const Color(0xFF66BB6A)),
          const SizedBox(height:8),
          _buildMiniCard(title: 'Benefits', body: 'Passphrases are long, memorable, and resistant to brute-force attacks.', tint: widget.color),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'What password managers do', body: 'Store encrypted passwords, generate strong passwords, autofill logins, and protect against phishing autofill traps.', tint: widget.color),
          const SizedBox(height:8),
          _buildMiniCard(title: 'Why use one', body: 'You only remember one master password; no need to reuse passwords.', tint: const Color(0xFF64B5F6)),
        ]);
      case 4:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'What is MFA?', body: 'Requires two or more verification methods: something you know, have, or are.', tint: widget.color),
          const SizedBox(height:8),
          _buildMiniCard(title: 'Why it matters', body: 'Blocks most account takeover attempts even if a password is stolen.', tint: const Color(0xFFFF7043)),
        ]);
      case 5:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Auth Apps vs SMS', body: 'Authenticator apps (Google Authenticator) are more secure and work offline; SMS can be intercepted or SIM-swapped.', tint: widget.color),
        ]);
      case 6:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Signs of compromise', body: 'Unexpected login alerts, password stops working, unknown devices, messages sent without you.', tint: widget.color),
          const SizedBox(height:8),
          _buildMiniCard(title: 'If compromised', body: 'Change password, enable MFA, log out devices, check activity.', tint: const Color(0xFF64B5F6)),
        ]);
      case 7:
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Safe account habits', body: 'Unique passwords, MFA, update passwords, never share, use a password manager, log out on shared devices.', tint: widget.color),
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
            child: Column(children: [
              Row(children: [
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white)),
                const SizedBox(width: 4),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.course, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Level 1 · Password Basics', style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white12)), child: const Text('1.5', style: TextStyle(color: Colors.white70, fontSize: 11))),
              ]),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: _progress.clamp(0.0, 1.0), minHeight: 9, backgroundColor: Colors.white.withOpacity(0.08), valueColor: AlwaysStoppedAnimation<Color>(widget.color))),
              const SizedBox(height: 14),
              Expanded(child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 28, offset: Offset(0,16))]), child: Align(alignment: Alignment.topCenter, child: AnimatedSwitcher(duration: const Duration(milliseconds: 340), child: SingleChildScrollView(key: ValueKey(_currentSectionIndex), physics: const BouncingScrollPhysics(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: widget.color.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: widget.color.withOpacity(0.35))), child: Text(_sections[_currentSectionIndex].subtitle, style: TextStyle(color: widget.color.withOpacity(0.95), fontSize:12, fontWeight: FontWeight.w700),),),
                const SizedBox(height: 18),
                _buildSectionContent(_currentSectionIndex),
              ])))),),),
              const SizedBox(height: 14),
              Row(children: [Expanded(child: GestureDetector(onTap: _canGoBack ? _goBack : null, child: AnimatedOpacity(duration: const Duration(milliseconds:180), opacity: _canGoBack ? 1 : 0.45, child: Container(height:54, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size:18), SizedBox(width:8), Text('Back', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize:14)),],),),),),), const SizedBox(width:12), Expanded(child: GestureDetector(onTap: _canGoForward ? _goForward : null, child: AnimatedOpacity(duration: const Duration(milliseconds:180), opacity: _canGoForward ? 1 : 0.45, child: Container(height:54, decoration: BoxDecoration(gradient: LinearGradient(colors: [widget.color, widget.color.withOpacity(0.78)]), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: widget.color.withOpacity(0.32), blurRadius: 18, offset: const Offset(0,8))],), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_canGoForward ? 'Next' : 'Done', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize:14),), const SizedBox(width:8), Icon(_canGoForward ? Icons.arrow_forward_ios_rounded : Icons.check_rounded, color: Colors.white, size:18),],),),),),),],),
            ],),
          ),
        ),
      ),
    );
  }
}

class CybersecurityModuleOneSixScreen extends StatefulWidget {
  final String course;
  final Color color;

  const CybersecurityModuleOneSixScreen({required this.course, required this.color, Key? key}) : super(key: key);

  @override
  State<CybersecurityModuleOneSixScreen> createState() => _CybersecurityModuleOneSixScreenState();
}

class _CybersecurityModuleOneSixScreenState extends State<CybersecurityModuleOneSixScreen> {
  static const List<_CybersecuritySection> _sections = [
    _CybersecuritySection(title: 'Safe Browsing', subtitle: 'Verify sites, look for https, avoid suspicious pop-ups.'),
    _CybersecuritySection(title: 'Safe Downloading', subtitle: 'Only download from trusted sources and scan files.'),
    _CybersecuritySection(title: 'Recognizing Online Scams', subtitle: 'Spot urgency, check sender, avoid strange links.'),
    _CybersecuritySection(title: 'Safe Social Media Use', subtitle: 'Protect personal info and control privacy.'),
    _CybersecuritySection(title: 'Public Wi‑Fi Safety', subtitle: 'Avoid sensitive logins and auto‑connect.'),
    _CybersecuritySection(title: 'Protecting Personal Information', subtitle: 'Keep phone, address, and IDs private.'),
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

  Widget _buildMiniCard({required String title, required String body, required Color tint}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: tint.withOpacity(0.14), borderRadius: BorderRadius.circular(18), border: Border.all(color: tint.withOpacity(0.45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 6),
        Text(body, style: TextStyle(color: Colors.white.withOpacity(0.86), fontSize: 13, height: 1.45)),
      ]),
    );
  }

  Widget _buildSectionContent(int idx) {
    switch (idx) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Look for secure connections', body: 'Check for https:// and the lock icon. Verify the URL carefully for small spelling changes.', tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(title: 'Avoid unsafe sites', body: 'Leave sites with aggressive pop‑ups or pressure prompts; don’t click suspicious banners.', tint: const Color(0xFFFF7043)),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Download from trusted sources', body: 'Use official app stores or the developer’s website. Avoid .exe/.apk/.zip from unknown places.', tint: const Color(0xFF66BB6A)),
          const SizedBox(height: 10),
          _buildMiniCard(title: 'Scan files', body: 'Scan downloads with antivirus before opening; avoid cracked software.', tint: widget.color),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Spot scams', body: 'Urgent or threatening language, improbable prizes, links that don’t match the sender — these are red flags.', tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(title: 'Before you click', body: 'Verify sender, check grammar/spelling, and confirm via a known channel if in doubt.', tint: const Color(0xFFFF7043)),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Protect personal info', body: 'Keep your profiles private and avoid sharing location, school, or routine details.', tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(title: 'Be selective with connections', body: 'Only accept requests from people you know; remember posted content can be saved even after deletion.', tint: const Color(0xFF64B5F6)),
        ]);
      case 4:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Public Wi‑Fi risks', body: 'Avoid logging into banking or email on public Wi‑Fi; attackers can intercept traffic.', tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(title: 'Safer alternatives', body: 'Use your phone hotspot, turn off auto‑connect, and prefer mobile data for sensitive work.', tint: const Color(0xFFFF7043)),
        ]);
      case 5:
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMiniCard(title: 'Protecting personal info', body: 'Don’t post phone numbers, addresses, or ID numbers. Use app privacy settings and never share passwords.', tint: widget.color),
          const SizedBox(height: 10),
          _buildMiniCard(title: 'Good habits', body: 'Limit personal details, review privacy settings, and be cautious before sharing.', tint: const Color(0xFF66BB6A)),
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
            child: Column(children: [
              Row(children: [
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white)),
                const SizedBox(width: 4),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.course, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Level 1 · Safe Internet Practices', style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white12)), child: const Text('1.6', style: TextStyle(color: Colors.white70, fontSize: 11))),
              ]),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: _progress.clamp(0.0, 1.0), minHeight: 9, backgroundColor: Colors.white.withOpacity(0.08), valueColor: AlwaysStoppedAnimation<Color>(widget.color))),
              const SizedBox(height: 14),
              Expanded(child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 28, offset: Offset(0,16))]), child: Align(alignment: Alignment.topCenter, child: AnimatedSwitcher(duration: const Duration(milliseconds: 340), child: SingleChildScrollView(key: ValueKey(_currentSectionIndex), physics: const BouncingScrollPhysics(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: widget.color.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: widget.color.withOpacity(0.35))), child: Text(_sections[_currentSectionIndex].subtitle, style: TextStyle(color: widget.color.withOpacity(0.95), fontSize:12, fontWeight: FontWeight.w700),),),
                const SizedBox(height: 18),
                _buildSectionContent(_currentSectionIndex),
              ])))),),),
              const SizedBox(height: 14),
              Row(children: [Expanded(child: GestureDetector(onTap: _canGoBack ? _goBack : null, child: AnimatedOpacity(duration: const Duration(milliseconds:180), opacity: _canGoBack ? 1 : 0.45, child: Container(height:54, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size:18), SizedBox(width:8), Text('Back', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize:14)),],),),),),), const SizedBox(width:12), Expanded(child: GestureDetector(onTap: _canGoForward ? _goForward : null, child: AnimatedOpacity(duration: const Duration(milliseconds:180), opacity: _canGoForward ? 1 : 0.45, child: Container(height:54, decoration: BoxDecoration(gradient: LinearGradient(colors: [widget.color, widget.color.withOpacity(0.78)]), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: widget.color.withOpacity(0.32), blurRadius: 18, offset: const Offset(0,8))],), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_canGoForward ? 'Next' : 'Done', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize:14),), const SizedBox(width:8), Icon(_canGoForward ? Icons.arrow_forward_ios_rounded : Icons.check_rounded, color: Colors.white, size:18),],),),),),),],),
            ],),
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
    return oldDelegate.color != color || oldDelegate.startFrac != startFrac || oldDelegate.endFrac != endFrac;
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

class _LevelNodeState extends State<_LevelNode> with SingleTickerProviderStateMixin {
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
        final pulse = isActive ? (0.5 + 0.5 * sin(_controller.value * pi * 2)) : 0.0;
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
                              color: Colors.white.withOpacity(0.18 + (pulse * 0.18)),
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
  State<CybersecurityLevelOneScreen> createState() => _CybersecurityLevelOneScreenState();
}

class _CybersecurityLevelOneScreenState extends State<CybersecurityLevelOneScreen> {
  static const List<_CybersecuritySection> _sections = [
    _CybersecuritySection(
      title: 'What Cybersecurity Is',
      subtitle: 'Start with the core idea before moving deeper into the module.',
    ),
    _CybersecuritySection(
      title: 'Why Cybersecurity Matters',
      subtitle: 'See why digital safety affects everyday life and trust.',
    ),
    _CybersecuritySection(
      title: 'The CIA Triad',
      subtitle: 'Confidentiality, integrity, and availability are the core model.',
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
              body: 'Cybersecurity is the practice of protecting computers, phones, networks, accounts, data, and the people using them from digital threats. It is digital safety for the tools we rely on every day.',
              icon: Icons.shield_rounded,
              tint: fblaGold,
            ),
            const SizedBox(height: 14),
            _buildMiniCard(
              title: 'Think of it this way',
              body: 'A secure device should work the way it is supposed to, keep your information private, and resist misuse from outsiders or harmful software.',
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
              body: 'We use technology for almost everything: schoolwork, banking, communication, entertainment, shopping, and storing personal information. That makes cybersecurity part of everyday life, not just a computer topic.',
              icon: Icons.public_rounded,
              tint: const Color(0xFF64B5F6),
            ),
            const SizedBox(height: 14),
            _buildMiniCard(
              title: 'If cybersecurity fails, attackers can:',
              body: 'Steal identities, access private accounts, damage devices, spread harmful software, cause financial loss, and disrupt important services.',
              tint: const Color(0xFFFF7043),
            ),
            const SizedBox(height: 14),
            _buildMiniCard(
              title: 'Big picture',
              body: 'When cybersecurity works well, people can study, work, message, shop, and bank online with more confidence. It protects privacy, safety, and trust in the digital world.',
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
              body: 'Confidentiality, integrity, and availability are the foundation of cybersecurity. Every security decision connects to at least one of these three goals.',
              icon: Icons.lock_rounded,
              tint: fblaGold,
            ),
            const SizedBox(height: 14),
            _buildMiniCard(
              title: 'Confidentiality',
              body: 'Information should only be seen by the right people. Examples include passwords, medical records, and private messages. Tools that help include encryption, passwords, and access controls.',
              tint: fblaGold,
            ),
            const SizedBox(height: 12),
            _buildMiniCard(
              title: 'Integrity',
              body: 'Information must stay accurate and unaltered. Grades should not be changed, bank balances should not be modified, and files should not be corrupted. Tools that help include checksums, version control, and digital signatures.',
              tint: const Color(0xFF66BB6A),
            ),
            const SizedBox(height: 12),
            _buildMiniCard(
              title: 'Availability',
              body: 'Information and systems must be accessible when needed. School websites, emergency services, and cloud storage should stay online. Threats include DDoS attacks, power outages, and system failures.',
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
              body: 'Cybersecurity protects many kinds of information. Anything stored digitally can become a target if it is not protected properly.',
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
              body: 'Anything stored digitally needs protection. The more sensitive the data, the stronger the security should be.',
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
              body: 'Cybersecurity and information security overlap, but they are not identical. The difference matters when deciding what needs to be protected and how wide the protection should reach.',
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
              body: 'Protects all information, whether digital or physical, like paper files.',
              tint: const Color(0xFF64B5F6),
            ),
            const SizedBox(height: 14),
            _buildMiniCard(
              title: 'Relationship',
              body: 'Cybersecurity is a subset of information security. Information security is the broader category because it also covers physical information, like paper files.',
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
              body: 'Cyber hygiene is a set of simple habits that dramatically reduce risk. The goal is not perfection; it is to make attacks harder and mistakes less likely.',
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
              body: 'Cyber hygiene is like brushing your teeth: small habits prevent big problems. A few safe choices every day can block a lot of common attacks.',
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
              body: 'These examples show how cybersecurity failures appear in everyday life. Most attacks rely on tricking people, exploiting weak passwords, or hiding malware inside something that looks harmless.',
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
              body: 'If a message, network, or download feels unusual, pause and verify it before you click, connect, or share. That one habit stops many real attacks.',
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
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          final fade = Tween<double>(begin: 0.0, end: 1.0).animate(animation);
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: widget.color.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: widget.color.withOpacity(0.35)),
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
                                Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
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
                                colors: [widget.color, widget.color.withOpacity(0.78)],
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
                                  _canGoForward ? Icons.arrow_forward_ios_rounded : Icons.check_rounded,
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
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
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
                      child: Icon(Icons.check_circle, color: fblaGold, size: 13),
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
                        child: const Icon(Icons.close, size: 10, color: Colors.white),
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

class CybersecurityOfficialDocumentsScreen extends StatefulWidget {
  const CybersecurityOfficialDocumentsScreen({super.key});

  @override
  State<CybersecurityOfficialDocumentsScreen> createState() => _CybersecurityOfficialDocumentsScreenState();
}

class _CybersecurityOfficialDocumentsScreenState extends State<CybersecurityOfficialDocumentsScreen> {
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
                            border: Border.all(color: fblaGold.withOpacity(0.35)),
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
                                  color: selected ? fblaGold.withOpacity(0.10) : Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected ? fblaGold.withOpacity(0.6) : Colors.white12,
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
                                      child: Icon(document.icon, color: fblaGold, size: 26),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                              color: Colors.white.withOpacity(0.68),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _showDocumentDetails(document),
                                      icon: const Icon(Icons.info_outline, color: Colors.white70),
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
