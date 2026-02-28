import 'package:flutter/material.dart';
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
                  _buildModernSectionHeader(context, 'Quick Access', Icons.flash_on),
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
                    () => _launchUrl('https://www.fbla-pbl.org/competitive-events/'),
                  ),

                  _buildResourceCard(
                    context,
                    'Leadership Development',
                    'Build your leadership skills',
                    Icons.leaderboard,
                    Color(0xFF4CAF50),
                    () =>
                        _launchUrl('https://www.fbla-pbl.org/leadership-development/'),
                  ),

                  const SizedBox(height: 28),

                  // Study Materials Section
                  _buildModernSectionHeader(context, 'Study Materials', Icons.book),
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
                  _buildModernSectionHeader(context, 'Downloads', Icons.download),
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
                  _buildModernSectionHeader(context, 'External Links', Icons.link),
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
                  _buildModernSectionHeader(context, 'Connect With Us', Icons.share),
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

  Widget _buildModernSectionHeader(BuildContext context, String title, IconData icon) {
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
    _CompetitiveEventItem('Broadcast Journalism', 'Presentation Events'),
    _CompetitiveEventItem('Business Ethics', 'Presentation Events'),
    _CompetitiveEventItem('Business Plan', 'Presentation Events'),
    _CompetitiveEventItem('Coding & Programming', 'Presentation Events'),
    _CompetitiveEventItem('Computer Game & Simulation Programming', 'Presentation Events'),
    _CompetitiveEventItem('Data Analysis', 'Presentation Events'),
    _CompetitiveEventItem('Digital Animation', 'Presentation Events'),
    _CompetitiveEventItem('Digital Video Production', 'Presentation Events'),
    _CompetitiveEventItem('Electronic Career Portfolio', 'Presentation Events'),
    _CompetitiveEventItem('Financial Planning', 'Presentation Events'),
    _CompetitiveEventItem('Financial Statement Analysis', 'Presentation Events'),
    _CompetitiveEventItem('Future Business Educator', 'Presentation Events'),
    _CompetitiveEventItem('Future Business Leader', 'Presentation Events'),
    _CompetitiveEventItem('Graphic Design', 'Presentation Events'),
    _CompetitiveEventItem('Impromptu Speaking', 'Presentation Events'),
    _CompetitiveEventItem('Introduction to Business Presentation', 'Presentation Events'),
    _CompetitiveEventItem('Introduction to Public Speaking', 'Presentation Events'),
    _CompetitiveEventItem('Introduction to Social Media Strategy', 'Presentation Events'),
    _CompetitiveEventItem('Job Interview', 'Presentation Events'),
    _CompetitiveEventItem('Mobile Application Development', 'Presentation Events'),
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
    _CompetitiveEventItem('Sports & Entertainment Management', 'Roleplay Events'),
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
    _CompetitiveEventItem('Insurance & Risk Management', 'Objective Test Events'),
    _CompetitiveEventItem('Introduction to Business Communication', 'Objective Test Events'),
    _CompetitiveEventItem('Introduction to Business Concepts', 'Objective Test Events'),
    _CompetitiveEventItem('Introduction to FBLA', 'Objective Test Events'),
    _CompetitiveEventItem('Journalism', 'Objective Test Events'),
    _CompetitiveEventItem('Organizational Leadership', 'Objective Test Events'),
    _CompetitiveEventItem('Personal Finance', 'Objective Test Events'),
    _CompetitiveEventItem('Supply Chain Management', 'Objective Test Events'),
    _CompetitiveEventItem('Computer Applications', 'Production Events'),
    _CompetitiveEventItem('Spreadsheet Applications', 'Production Events'),
    _CompetitiveEventItem('Word Processing', 'Production Events'),
    _CompetitiveEventItem('Virtual Business Finance Challenge', 'Virtual & Partner Challenges'),
    _CompetitiveEventItem('Virtual Business Management Challenge', 'Virtual & Partner Challenges'),
    _CompetitiveEventItem('FBLA Stock Market Game', 'Virtual & Partner Challenges'),
    _CompetitiveEventItem('LifeSmarts', 'Virtual & Partner Challenges'),
    _CompetitiveEventItem('American Enterprise Project', 'Chapter Events'),
    _CompetitiveEventItem('Community Service Project', 'Chapter Events'),
    _CompetitiveEventItem('Local Chapter Annual Business Report', 'Chapter Events'),
    _CompetitiveEventItem('Partnership with Business Project', 'Chapter Events'),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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

    return Container(
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
                  border: Border.all(color: categoryColor.withOpacity(0.75)),
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
        ],
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
                        ? const Icon(Icons.check_circle, color: Color(0xFF1D4E89))
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
