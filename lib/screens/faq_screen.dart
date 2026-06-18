import 'package:flutter/material.dart';

import '../main.dart' show appBackgroundGradient, fblaGold, fblaNavy;

enum FaqCategory {
  all('All'),
  gettingStarted('Getting Started'),
  events('Events'),
  resources('Resources'),
  social('Social'),
  appSettings('App & Settings');

  const FaqCategory(this.label);
  final String label;
}

class FaqItem {
  final String question;
  final String answer;
  final FaqCategory category;
  final IconData icon;

  const FaqItem({
    required this.question,
    required this.answer,
    required this.category,
    required this.icon,
  });
}

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  FaqCategory _selectedCategory = FaqCategory.all;

  static const List<FaqItem> _items = [
    FaqItem(
      question: 'How do I join FBLA at my school?',
      answer:
          'Ask your chapter adviser about local membership steps, dues, and registration deadlines for your school.',
      category: FaqCategory.gettingStarted,
      icon: Icons.school_outlined,
    ),
    FaqItem(
      question: 'How do I update my profile photo?',
      answer:
          'Open More or Profile, then tap the camera icon on your avatar to choose a new image from your device.',
      category: FaqCategory.gettingStarted,
      icon: Icons.account_circle_outlined,
    ),
    FaqItem(
      question: 'How do I sign out of the app?',
      answer: 'Go to Profile or Settings and tap Log Out at the bottom.',
      category: FaqCategory.gettingStarted,
      icon: Icons.logout_outlined,
    ),
    FaqItem(
      question: 'Who should I contact for app support?',
      answer:
          'Start with your chapter adviser or officer team. They can help with access, events, and chapter-specific questions.',
      category: FaqCategory.gettingStarted,
      icon: Icons.support_agent_outlined,
    ),
    FaqItem(
      question: 'Where do I see upcoming chapter events?',
      answer:
          'Open the Events tab for the calendar, weekly schedule, and event details. Use filters to show official FBLA or custom chapter events.',
      category: FaqCategory.events,
      icon: Icons.event_note_outlined,
    ),
    FaqItem(
      question: 'How do I RSVP to an event?',
      answer:
          'Open an event card and tap RSVP, then choose Yes, Maybe, or No. Your response is saved on your device.',
      category: FaqCategory.events,
      icon: Icons.how_to_reg_outlined,
    ),
    FaqItem(
      question: 'Can I set reminders for events?',
      answer:
          'Yes. Tap Remind on an event card to schedule a local notification before the event starts.',
      category: FaqCategory.events,
      icon: Icons.notifications_active_outlined,
    ),
    FaqItem(
      question: 'Can I save events for later?',
      answer:
          'Yes. Tap the bookmark icon on any event card to save or unsave it for quick access.',
      category: FaqCategory.events,
      icon: Icons.bookmark_outline,
    ),
    FaqItem(
      question: 'How do I invite friends to an event?',
      answer:
          'When creating a custom event, use Invite Friends to send a join invitation through chat. Friends can accept from the message.',
      category: FaqCategory.events,
      icon: Icons.person_add_outlined,
    ),
    FaqItem(
      question: 'How do I add a competitive event course?',
      answer:
          'Open Resources, tap the + button or course picker, and search the FBLA event catalog to add a course to your learning path.',
      category: FaqCategory.resources,
      icon: Icons.menu_book_outlined,
    ),
    FaqItem(
      question: 'Where can I open official FBLA PDFs?',
      answer:
          'Go to More > Document Library. Search or filter by category, then tap any document to read it in the app.',
      category: FaqCategory.resources,
      icon: Icons.folder_open_outlined,
    ),
    FaqItem(
      question: 'How do I practice for roleplay or presentation events?',
      answer:
          'Add the event under Resources, then use the practice tools for AI coaching, recording, and rubric feedback where available.',
      category: FaqCategory.resources,
      icon: Icons.record_voice_over_outlined,
    ),
    FaqItem(
      question: 'Why does AI chat not respond?',
      answer:
          'The AI coach uses Gemini. Add a valid API key with --dart-define=GEMINI_API_KEY=your_key when building, and make sure your device has internet.',
      category: FaqCategory.resources,
      icon: Icons.smart_toy_outlined,
    ),
    FaqItem(
      question: 'How do I find other FBLA members?',
      answer:
          'Open More > Find Members to browse the directory, send friend requests, and view member profiles.',
      category: FaqCategory.social,
      icon: Icons.badge_outlined,
    ),
    FaqItem(
      question: 'How do I message a friend?',
      answer:
          'After you are friends, open their profile or go to Social > Messages to start a direct chat. You can also share posts and event invites in chat.',
      category: FaqCategory.social,
      icon: Icons.chat_bubble_outline,
    ),
    FaqItem(
      question: 'What is on the Social tab?',
      answer:
          'The Social tab includes BlueWave posts, reels, chapter feeds, and links to official FBLA social channels.',
      category: FaqCategory.social,
      icon: Icons.public_outlined,
    ),
    FaqItem(
      question: 'Can I switch between dark and light mode?',
      answer:
          'Yes. Open More > Settings and toggle Dark Mode to change the app theme.',
      category: FaqCategory.appSettings,
      icon: Icons.dark_mode_outlined,
    ),
    FaqItem(
      question: 'Can I use the app offline?',
      answer:
          'Bundled resources like Document Library PDFs may work offline after they have loaded once. Most live features such as chat, members, and news require internet.',
      category: FaqCategory.appSettings,
      icon: Icons.wifi_off_outlined,
    ),
    FaqItem(
      question: 'How do I replay the app tour?',
      answer:
          'Open More > Replay App Tour to walk through the main features again.',
      category: FaqCategory.appSettings,
      icon: Icons.tips_and_updates_outlined,
    ),
    FaqItem(
      question: 'How do I report incorrect event information?',
      answer:
          'Share the details with your chapter officer or adviser so they can update official chapter data.',
      category: FaqCategory.appSettings,
      icon: Icons.flag_outlined,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FaqItem> get _filteredItems {
    final query = _searchQuery.trim().toLowerCase();

    return _items.where((item) {
      final matchesCategory =
          _selectedCategory == FaqCategory.all ||
              item.category == _selectedCategory;
      if (!matchesCategory) return false;
      if (query.isEmpty) return true;

      return item.question.toLowerCase().contains(query) ||
          item.answer.toLowerCase().contains(query) ||
          item.category.label.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Help / FAQ'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1624),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: fblaGold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: fblaGold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.help_outline_rounded,
                        color: fblaGold,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How can we help?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Quick answers about events, resources, and your chapter.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search help topics...',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: FaqCategory.values.map((category) {
                  final selected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category.label),
                      selected: selected,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: selected ? fblaNavy : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      selectedColor: fblaGold,
                      side: BorderSide(
                        color: selected
                            ? fblaGold.withValues(alpha: 0.8)
                            : Colors.white24,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 20 + bottomSafe),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _FaqTile(item: items[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 52,
              color: Colors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 14),
            const Text(
              'No matching topics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try another search term or category filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final FaqItem item;

  const _FaqTile({required this.item});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _expanded
            ? fblaGold.withValues(alpha: 0.08)
            : const Color(0xFF0B1624),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded
              ? fblaGold.withValues(alpha: 0.45)
              : Colors.white12,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.white10,
          highlightColor: Colors.white10,
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (value) => setState(() => _expanded = value),
          tilePadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          collapsedIconColor: Colors.white54,
          iconColor: fblaGold,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _expanded
                  ? fblaGold.withValues(alpha: 0.18)
                  : const Color(0xFF1D4E89).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.item.icon,
              color: _expanded ? fblaGold : Colors.white70,
              size: 20,
            ),
          ),
          title: Text(
            widget.item.question,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.item.answer,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
