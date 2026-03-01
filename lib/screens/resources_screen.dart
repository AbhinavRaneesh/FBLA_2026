import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color fblaBlue = const Color(0xFF1D4E89);
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    final Color fblaGold = const Color(0xFFF6C500);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 56,
            floating: false,
            pinned: true,
            backgroundColor: fblaBlue,
            title: const Text(
              'Resources',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Access Section
                  _buildModernSectionHeader(
                      context, 'Quick Access', Icons.flash_on),
                  const SizedBox(height: 16),

                  _buildResourceCard(
                    context,
                    'FBLA Connect',
                    'Access your FBLA Connect account',
                    Icons.account_circle,
                    Color(0xFF1D4E89),
                    () => _launchUrl('https://connect.fbla.org/'),
                  ),

                  _buildResourceCard(
                    context,
                    'Competition Guidelines',
                    'Study guides and competition rules',
                    Icons.school,
                    Color(0xFFF6C500),
                    () => _launchUrl(
                        'https://www.fbla-pbl.org/competitive-events/'),
                  ),

                  _buildResourceCard(
                    context,
                    'Leadership Development',
                    'Build your leadership skills',
                    Icons.leaderboard,
                    Color(0xFF4CAF50),
                    () => _launchUrl(
                        'https://www.fbla-pbl.org/leadership-development/'),
                  ),

                  const SizedBox(height: 28),

                  // Study Materials Section
                  _buildModernSectionHeader(
                      context, 'Study Materials', Icons.book),
                  const SizedBox(height: 16),

                  _buildResourceCard(
                    context,
                    'FBLA Competitive Events',
                    'Browse all FBLA events with search and filters',
                    Icons.emoji_events,
                    Color(0xFF1D4E89),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CompetitiveEventsScreen(),
                        ),
                      );
                    },
                  ),

                  _buildResourceCard(
                    context,
                    'Business Skills',
                    'Fundamentals of business and entrepreneurship',
                    Icons.business,
                    Color(0xFFFF9800),
                    () => _showComingSoon(context),
                  ),

                  _buildResourceCard(
                    context,
                    'Technology & Innovation',
                    'Latest trends in business technology',
                    Icons.computer,
                    Color(0xFF2196F3),
                    () => _showComingSoon(context),
                  ),

                  _buildResourceCard(
                    context,
                    'Career Preparation',
                    'Resume building and interview skills',
                    Icons.work,
                    Color(0xFF9C27B0),
                    () => _showComingSoon(context),
                  ),

                  const SizedBox(height: 28),

                  // Downloads Section
                  _buildModernSectionHeader(
                      context, 'Downloads', Icons.download),
                  const SizedBox(height: 16),

                  _buildResourceCard(
                    context,
                    'FBLA Handbook',
                    'Complete guide to FBLA programs',
                    Icons.book,
                    Color(0xFFFF5722),
                    () => _showComingSoon(context),
                  ),

                  _buildResourceCard(
                    context,
                    'Chapter Resources',
                    'Templates and guides for chapter activities',
                    Icons.group,
                    Color(0xFF607D8B),
                    () => _showComingSoon(context),
                  ),

                  _buildResourceCard(
                    context,
                    'Competition Materials',
                    'Practice tests and study guides',
                    Icons.quiz,
                    Colors.deepPurple,
                    () => _showComingSoon(context),
                  ),

                  const SizedBox(height: 28),

                  // External Links Section
                  _buildModernSectionHeader(
                      context, 'External Links', Icons.link),
                  const SizedBox(height: 16),

                  _buildResourceCard(
                    context,
                    'FBLA-PBL Official Website',
                    'Visit the national FBLA website',
                    Icons.language,
                    Color(0xFF1D4E89),
                    () => _launchUrl('https://www.fbla-pbl.org/'),
                  ),

                  _buildResourceCard(
                    context,
                    'State FBLA',
                    'Connect with your state organization',
                    Icons.location_on,
                    Color(0xFFE91E63),
                    () => _showComingSoon(context),
                  ),

                  _buildResourceCard(
                    context,
                    'Career Center',
                    'Explore career opportunities',
                    Icons.explore,
                    Color(0xFF00BCD4),
                    () => _launchUrl('https://www.fbla-pbl.org/career-center/'),
                  ),

                  const SizedBox(height: 28),

                  // Social Media Section
                  _buildModernSectionHeader(
                      context, 'Connect With Us', Icons.share),
                  const SizedBox(height: 16),
                  _buildSocialMediaRow(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialMediaRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSocialButton(
          context,
          'Instagram',
          Icons.camera_alt,
          Color(0xFFE1306C),
          () => _launchUrl('https://www.instagram.com/fbla_pbl/'),
        ),
        _buildSocialButton(
          context,
          'Twitter',
          Icons.flutter_dash,
          Color(0xFF1DA1F2),
          () => _launchUrl('https://twitter.com/FBLA_PBL'),
        ),
        _buildSocialButton(
          context,
          'Facebook',
          Icons.facebook,
          Color(0xFF1877F2),
          () => _launchUrl('https://www.facebook.com/FBLAPBL/'),
        ),
        _buildSocialButton(
          context,
          'LinkedIn',
          Icons.business,
          Color(0xFF0A66C2),
          () => _launchUrl('https://www.linkedin.com/company/fbla-pbl/'),
        ),
      ],
    );
  }

  Widget _buildSocialButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSectionHeader(
      BuildContext context, String title, IconData icon) {
    final Color fblaBlue = const Color(0xFF1D4E89);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: fblaBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: fblaBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : fblaBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildResourceCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showComingSoon(BuildContext context) {
    return;
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
    _CompetitiveEventItem('Broadcast Journalism', 'Presentation Events'),
    _CompetitiveEventItem('Business Ethics', 'Presentation Events'),
    _CompetitiveEventItem('Business Plan', 'Presentation Events'),
    _CompetitiveEventItem('Coding & Programming', 'Presentation Events'),
    _CompetitiveEventItem(
        'Computer Game & Simulation Programming', 'Presentation Events'),
    _CompetitiveEventItem('Data Analysis', 'Presentation Events'),
    _CompetitiveEventItem('Digital Animation', 'Presentation Events'),
    _CompetitiveEventItem('Digital Video Production', 'Presentation Events'),
    _CompetitiveEventItem('Electronic Career Portfolio', 'Presentation Events'),
    _CompetitiveEventItem('Financial Planning', 'Presentation Events'),
    _CompetitiveEventItem(
        'Financial Statement Analysis', 'Presentation Events'),
    _CompetitiveEventItem('Future Business Educator', 'Presentation Events'),
    _CompetitiveEventItem('Future Business Leader', 'Presentation Events'),
    _CompetitiveEventItem('Graphic Design', 'Presentation Events'),
    _CompetitiveEventItem('Impromptu Speaking', 'Presentation Events'),
    _CompetitiveEventItem(
        'Introduction to Business Presentation', 'Presentation Events'),
    _CompetitiveEventItem(
        'Introduction to Public Speaking', 'Presentation Events'),
    _CompetitiveEventItem(
        'Introduction to Social Media Strategy', 'Presentation Events'),
    _CompetitiveEventItem('Job Interview', 'Presentation Events'),
    _CompetitiveEventItem(
        'Mobile Application Development', 'Presentation Events'),
    _CompetitiveEventItem('Public Service Announcement', 'Presentation Events'),
    _CompetitiveEventItem('Public Speaking', 'Presentation Events'),
    _CompetitiveEventItem('Sales Presentation', 'Presentation Events'),
    _CompetitiveEventItem('Social Media Strategies', 'Presentation Events'),
    _CompetitiveEventItem('Visual Design', 'Presentation Events'),
    _CompetitiveEventItem('Website Design', 'Presentation Events'),
    _CompetitiveEventItem('Banking & Financial Systems', 'Roleplay Events'),
    _CompetitiveEventItem('Business Management', 'Roleplay Events'),
    _CompetitiveEventItem('Customer Service', 'Roleplay Events'),
    _CompetitiveEventItem('Entrepreneurship', 'Roleplay Events'),
    _CompetitiveEventItem('Hospitality & Event Management', 'Roleplay Events'),
    _CompetitiveEventItem('International Business', 'Roleplay Events'),
    _CompetitiveEventItem('Management Information Systems', 'Roleplay Events'),
    _CompetitiveEventItem('Marketing', 'Roleplay Events'),
    _CompetitiveEventItem('Network Design', 'Roleplay Events'),
    _CompetitiveEventItem('Parliamentary Procedure', 'Roleplay Events'),
    _CompetitiveEventItem(
        'Sports & Entertainment Management', 'Roleplay Events'),
    _CompetitiveEventItem('Accounting I & II', 'Objective Test Events'),
    _CompetitiveEventItem('Advertising', 'Objective Test Events'),
    _CompetitiveEventItem('Agribusiness', 'Objective Test Events'),
    _CompetitiveEventItem('Business Communication', 'Objective Test Events'),
    _CompetitiveEventItem('Business Law', 'Objective Test Events'),
    _CompetitiveEventItem('Cybersecurity', 'Objective Test Events'),
    _CompetitiveEventItem('Data Science & AI', 'Objective Test Events'),
    _CompetitiveEventItem('Economics', 'Objective Test Events'),
    _CompetitiveEventItem('Financial Planning', 'Objective Test Events'),
    _CompetitiveEventItem('Healthcare Administration', 'Objective Test Events'),
    _CompetitiveEventItem(
        'Insurance & Risk Management', 'Objective Test Events'),
    _CompetitiveEventItem(
        'Introduction to Business Communication', 'Objective Test Events'),
    _CompetitiveEventItem(
        'Introduction to Business Concepts', 'Objective Test Events'),
    _CompetitiveEventItem('Introduction to FBLA', 'Objective Test Events'),
    _CompetitiveEventItem('Journalism', 'Objective Test Events'),
    _CompetitiveEventItem('Organizational Leadership', 'Objective Test Events'),
    _CompetitiveEventItem('Personal Finance', 'Objective Test Events'),
    _CompetitiveEventItem('Supply Chain Management', 'Objective Test Events'),
    _CompetitiveEventItem('Computer Applications', 'Production Events'),
    _CompetitiveEventItem('Spreadsheet Applications', 'Production Events'),
    _CompetitiveEventItem('Word Processing', 'Production Events'),
    _CompetitiveEventItem(
        'Virtual Business Finance Challenge', 'Virtual & Partner Challenges'),
    _CompetitiveEventItem('Virtual Business Management Challenge',
        'Virtual & Partner Challenges'),
    _CompetitiveEventItem(
        'FBLA Stock Market Game', 'Virtual & Partner Challenges'),
    _CompetitiveEventItem('LifeSmarts', 'Virtual & Partner Challenges'),
    _CompetitiveEventItem('American Enterprise Project', 'Chapter Events'),
    _CompetitiveEventItem('Community Service Project', 'Chapter Events'),
    _CompetitiveEventItem(
        'Local Chapter Annual Business Report', 'Chapter Events'),
    _CompetitiveEventItem(
        'Partnership with Business Project', 'Chapter Events'),
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
                  Icon(
                    Icons.arrow_forward_ios,
                    color: categoryColor,
                    size: 14,
                  ),
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
                    title: Text(
                      category,
                      style: const TextStyle(color: Colors.white),
                    ),
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
          ...resources.map((resource) => _buildResourceTile(resource)).toList(),
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
          child: Row(
            children: const [
              Expanded(
                child: Text(
                  'Mobile Application Development Guidless',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF64B5F6),
                size: 16,
              ),
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
            description:
                'Competency weighting summary (example: Ethics 10%, Economics 20%).',
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
          _StudyPackResource(
            title: '${event.name} Rulebook',
            description:
                'Official guidelines: eligibility, test timing, and calculator rules.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Official Rules',
          ),
          _StudyPackResource(
            title: '${event.name} Study Links',
            description:
                'Quick links to Quizlet and relevant Investopedia topics.',
            url:
                'https://www.investopedia.com/search?q=${Uri.encodeComponent(event.name)}',
            linkLabel: 'Investopedia Search',
          ),
        ];
      case 'Roleplay Events':
        return [
          _StudyPackResource(
            title: '${event.name} Case Study Library',
            description:
                '3–5 practice scenarios for timed 10-minute prep sessions.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Past Scenarios',
          ),
          _StudyPackResource(
            title: '${event.name} Performance Rubric',
            description:
                'Judge scoring sheet focus: eye contact, creativity, and practical solution quality.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Rubric Guide',
          ),
          _StudyPackResource(
            title: '${event.name} Secret Sauce Guide',
            description:
                'Roleplay structure one-pager: Intro, 3 Main Points, Ask, Conclusion.',
          ),
          _StudyPackResource(
            title: '${event.name} Objective Test Sample',
            description:
                '100-question practice exam for the objective test portion.',
            url:
                'https://quizlet.com/search?query=FBLA%20${Uri.encodeComponent(event.name)}%20test',
            linkLabel: 'Practice Exams',
          ),
        ];
      case 'Presentation Events':
        return [
          _StudyPackResource(
            title: '${event.name} Current Prompt',
            description:
                'Current-year event prompt and topic requirements for preparation.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Current Prompt',
          ),
          _StudyPackResource(
            title: '${event.name} Scoring Rubric',
            description:
                'Checklist for delivery, visual aids quality, and Q&A performance.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Scoring Rubric',
          ),
          _StudyPackResource(
            title: '${event.name} Equipment Checklist',
            description:
                'Bring-ready list (HDMI adapter, clicker, backup file copy, presentation remote).',
          ),
          _StudyPackResource(
            title: '${event.name} Sample Video',
            description:
                'Reference quality examples from national-level winning presentations.',
            url:
                'https://www.youtube.com/results?search_query=FBLA+${Uri.encodeComponent(event.name)}+national+winner',
            linkLabel: 'Watch Examples',
          ),
        ];
      case 'Production Events':
        return [
          _StudyPackResource(
            title: '${event.name} Production Test',
            description:
                'Sample timed job packet (example tasks completed within event limits).',
          ),
          _StudyPackResource(
            title: '${event.name} FBLA Format Guide',
            description:
                'Official formatting rules for documents, margins, spacing, and report structure.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Format Rules',
          ),
          _StudyPackResource(
            title: '${event.name} Solution Key',
            description:
                'Reference output showing what a fully correct final product should look like.',
          ),
        ];
      case 'Virtual & Partner Challenges':
        return [
          _StudyPackResource(
            title: '${event.name} Login Gateway',
            description:
                'Direct access to challenge portals (Knowledge Matters and partner systems).',
            url:
                'https://knowledgematters.com/high-school/virtual-business-challenge/',
            linkLabel: 'Open Portal',
          ),
          _StudyPackResource(
            title: '${event.name} Strategy Guide',
            description:
                'Tips from top competitors (focus priorities, first-round decisions, and pacing).',
          ),
          _StudyPackResource(
            title: '${event.name} Dates & Rounds',
            description:
                'Round opening and closing schedule with checkpoint reminders.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Official Schedule',
          ),
        ];
      case 'Chapter Events':
        return [
          _StudyPackResource(
            title: '${event.name} Project Guide',
            description:
                'Official project structure, required components, and submission instructions.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Project Rules',
          ),
          _StudyPackResource(
            title: '${event.name} Judging Rubric',
            description:
                'How chapter projects are evaluated for impact, planning, and execution quality.',
            url: 'https://www.fbla-pbl.org/competitive-events/',
            linkLabel: 'Rubric',
          ),
          _StudyPackResource(
            title: '${event.name} Winning Samples',
            description:
                'Review past examples to benchmark scope, documentation, and presentation quality.',
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
      body: SfPdfViewer.asset(
        'assets/Mobile-Application-Development.pdf',
      ),
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
          description:
              'Summary of tested competencies by weight (for example, Ethics 10%, Economics 20%).',
          url: 'https://www.fbla-pbl.org/competitive-events/',
          linkLabel: 'Official Event Blueprints',
        ),
        _StudyPackResource(
          title: 'Question Bank',
          description:
              'Daily Practice: 10–15 multiple-choice questions to build speed and accuracy.',
          url: 'https://quizlet.com/search?query=FBLA%20objective%20test',
          linkLabel: 'Quizlet Practice Sets',
        ),
        _StudyPackResource(
          title: 'The Rulebook',
          description:
              'Official PDF guidelines including eligibility, timing, and calculator rules.',
          url: 'https://www.fbla-pbl.org/competitive-events/',
          linkLabel: 'Official Guidelines',
        ),
        _StudyPackResource(
          title: 'Study Links',
          description:
              'Direct external resources such as Quizlet and Investopedia articles.',
          url:
              'https://www.investopedia.com/search?q=business%20law%20personal%20finance',
          linkLabel: 'Investopedia Topics',
        ),
      ],
    ),
    _StudyPackCategory(
      title: 'Roleplay Events',
      examples: 'Marketing, Entrepreneurship, Hospitality & Event Management',
      resources: [
        _StudyPackResource(
          title: 'Case Study Library',
          description:
              '3–5 past scenarios to practice timed 10-minute prep and delivery.',
          url: 'https://www.fbla-pbl.org/competitive-events/',
          linkLabel: 'Past Event Resources',
        ),
        _StudyPackResource(
          title: 'Performance Rubric',
          description:
              'Judge score sheet criteria including eye contact, clarity, and creativity.',
          url: 'https://www.fbla-pbl.org/competitive-events/',
          linkLabel: 'Judging Rubrics',
        ),
        _StudyPackResource(
          title: 'The Secret Sauce Guide',
          description:
              'One-page structure: Intro, 3 Main Points, the Ask, and Conclusion.',
        ),
        _StudyPackResource(
          title: 'Objective Test Sample',
          description:
              '100-question practice exam for the objective test portion before roleplay.',
          url:
              'https://quizlet.com/search?query=FBLA%20roleplay%20objective%20test',
          linkLabel: 'Practice Question Sets',
        ),
      ],
    ),
    _StudyPackCategory(
      title: 'Presentation & Speech Events',
      examples: 'Public Speaking, Social Media Strategies, Graphic Design',
      resources: [
        _StudyPackResource(
          title: 'The Prompt',
          description:
              'Current-year topic statement and required scenario scope for your event.',
          url: 'https://www.fbla-pbl.org/competitive-events/',
          linkLabel: 'Current Year Topics',
        ),
        _StudyPackResource(
          title: 'Scoring Rubric',
          description:
              'Checklist emphasizing delivery, visual aids, and Q&A performance.',
          url: 'https://www.fbla-pbl.org/competitive-events/',
          linkLabel: 'Presentation Rubrics',
        ),
        _StudyPackResource(
          title: 'Equipment Checklist',
          description:
              'Bring-required items checklist (adapter, projector compatibility, clicker, backups).',
        ),
        _StudyPackResource(
          title: 'Sample Video',
          description:
              'Watch national-winning style performances to benchmark quality expectations.',
          url:
              'https://www.youtube.com/results?search_query=FBLA+national+winning+presentation',
          linkLabel: 'YouTube Samples',
        ),
      ],
    ),
    _StudyPackCategory(
      title: 'Production Events',
      examples: 'Computer Applications, Spreadsheet Applications',
      resources: [
        _StudyPackResource(
          title: 'The Production Test',
          description:
              'Sample timed job packet (example: create a business letter and database in 2 hours).',
        ),
        _StudyPackResource(
          title: 'FBLA Format Guide',
          description:
              'Formatting standards reference for reports, letters, spacing, and margins.',
          url: 'https://www.fbla-pbl.org/competitive-events/',
          linkLabel: 'Format Standards',
        ),
        _StudyPackResource(
          title: 'Solution Key',
          description:
              'Target output PDF showing what a full-credit final document should look like.',
        ),
      ],
    ),
    _StudyPackCategory(
      title: 'Virtual Business Challenges',
      examples: 'VBC Finance, VBC Management',
      resources: [
        _StudyPackResource(
          title: 'Login Gateway',
          description:
              'Direct launch point for competition simulation access and participation.',
          url:
              'https://knowledgematters.com/high-school/virtual-business-challenge/',
          linkLabel: 'Knowledge Matters Portal',
        ),
        _StudyPackResource(
          title: 'Strategy Guide',
          description:
              'Tips from top competitors (e.g., early-round staffing and decision priorities).',
        ),
        _StudyPackResource(
          title: 'Dates & Rounds',
          description:
              'Clear schedule for Round 1 and Round 2 opening/closing deadlines.',
          url: 'https://www.fbla-pbl.org/competitive-events/',
          linkLabel: 'Official Schedule',
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
          return _buildPackCard(context, pack);
        },
      ),
    );
  }

  Widget _buildPackCard(BuildContext context, _StudyPackCategory pack) {
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
