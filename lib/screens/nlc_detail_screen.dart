import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_assets.dart';

const _fblaBlue = Color(0xFF1D4E89);
const _fblaGold = Color(0xFFFDB913);
const _lightBackground = Color(0xFFEFF3F6);
const _lightSurface = Color(0xFFFFFFFF);
const _lightPrimaryText = Color(0xFF0A192F);
const _lightSecondaryText = Color(0xFF475569);
const _lightBorder = Color(0xFFD5DEE6);
const _darkBackground = Color(0xFF07111F);

const _nlcImages = AppAssets.nlcPictures;

class NlcDetailScreen extends StatefulWidget {
  final VoidCallback? onViewCompetitions;

  const NlcDetailScreen({super.key, this.onViewCompetitions});

  @override
  State<NlcDetailScreen> createState() => _NlcDetailScreenState();
}

class _NlcDetailScreenState extends State<NlcDetailScreen> {
  late final PageController _pageController;
  Timer? _carouselTimer;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_pageIndex + 1) % _nlcImages.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? _darkBackground : _lightBackground;
    final primaryText = isDark ? Colors.white : _lightPrimaryText;
    final secondaryText = isDark ? Colors.white70 : _lightSecondaryText;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: primaryText,
        elevation: 0,
        title: const Text('NLC 2026'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildHero(isDark),
          const SizedBox(height: 18),
          _buildQuickFacts(isDark, primaryText, secondaryText),
          const SizedBox(height: 22),
          _buildIntroCard(isDark, primaryText, secondaryText),
          const SizedBox(height: 22),
          _buildSectionTitle(
            'Plan Your Trip',
            'Registration, travel, programming, and conference essentials',
            Icons.map_outlined,
            isDark,
            primaryText,
            secondaryText,
          ),
          const SizedBox(height: 12),
          for (final section in _planningSections)
            _buildInfoCard(section, isDark, primaryText, secondaryText),
          const SizedBox(height: 22),
          _buildSectionTitle(
            'Conference Actions',
            'Important NLC areas brought into the app',
            Icons.bolt_outlined,
            isDark,
            primaryText,
            secondaryText,
          ),
          const SizedBox(height: 12),
          _buildActionGrid(isDark, primaryText, secondaryText),
          const SizedBox(height: 22),
          _buildGetInvolvedCard(isDark, primaryText, secondaryText),
          const SizedBox(height: 22),
          _buildSectionTitle(
            'Partners & Sponsors',
            'Official partner information from the NLC page',
            Icons.handshake_outlined,
            isDark,
            primaryText,
            secondaryText,
          ),
          const SizedBox(height: 12),
          for (final sponsor in _sponsors)
            _buildSponsorTile(sponsor, isDark, primaryText, secondaryText),
        ],
      ),
    );
  }

  Widget _buildHero(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 285,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _nlcImages.length,
              onPageChanged: (index) => setState(() => _pageIndex = index),
              itemBuilder: (context, index) {
                return Image.asset(_nlcImages[index], fit: BoxFit.cover);
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.16),
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.68),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: _fblaGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _fblaGold.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Text(
                      'Middle School & High School NLC',
                      style: TextStyle(
                        color: _fblaGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'FBLA National Leadership Conference 2026',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _HeroChip(
                        icon: Icons.calendar_month_outlined,
                        label: 'June 29 - July 2, 2026',
                      ),
                      _HeroChip(
                        icon: Icons.location_on_outlined,
                        label: 'San Antonio, TX',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(
                      _nlcImages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: index == _pageIndex ? 18 : 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: index == _pageIndex
                              ? _fblaGold
                              : Colors.white.withValues(alpha: 0.56),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFacts(
    bool isDark,
    Color primaryText,
    Color secondaryText,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _buildFactCard(
          icon: Icons.event_available_outlined,
          label: 'Dates',
          value: 'June 29 - July 2, 2026',
          isDark: isDark,
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
        _buildFactCard(
          icon: Icons.business_outlined,
          label: 'Venue',
          value: 'Henry B. Gonzalez Convention Center',
          isDark: isDark,
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
        _buildFactCard(
          icon: Icons.location_city_outlined,
          label: 'City',
          value: 'San Antonio, Texas',
          isDark: isDark,
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
        _buildFactCard(
          icon: Icons.groups_2_outlined,
          label: 'Divisions',
          value: 'Middle School & High School',
          isDark: isDark,
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
      ],
    );
  }

  Widget _buildFactCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isDark ? _fblaGold : _fblaBlue, size: 25),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: primaryText,
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard(
    bool isDark,
    Color primaryText,
    Color secondaryText,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The competitive edge',
            style: TextStyle(
              color: primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'FBLA members have the competitive edge, as the best and brightest of FBLA convene to compete in leadership events, share their successes, and learn new ideas about shaping their career future through workshops and exhibits.',
            style: TextStyle(
              color: secondaryText,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _buildAddressBar(isDark),
        ],
      ),
    );
  }

  Widget _buildAddressBar(bool isDark) {
    final addressTextColor = isDark ? Colors.white : _lightPrimaryText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : _lightBackground.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : _lightBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.place_outlined, color: _fblaGold, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Henry B. Gonzalez Convention Center\n900 E Market Street\nSan Antonio, TX 78205',
              style: TextStyle(
                color: addressTextColor,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    String subtitle,
    IconData icon,
    bool isDark,
    Color primaryText,
    Color secondaryText,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (isDark ? _fblaGold : _fblaBlue).withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: isDark ? _fblaGold : _fblaBlue, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    _NlcInfoSection section,
    bool isDark,
    Color primaryText,
    Color secondaryText,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(isDark),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: isDark ? _fblaGold : _fblaBlue,
          collapsedIconColor: isDark ? Colors.white70 : _lightSecondaryText,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: section.color.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(section.icon, color: section.color, size: 22),
          ),
          title: Text(
            section.title,
            style: TextStyle(
              color: primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            section.summary,
            style: TextStyle(color: secondaryText, fontSize: 12, height: 1.25),
          ),
          children: [
            Text(
              section.body,
              style: TextStyle(
                color: secondaryText,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            if (section.bullets.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final bullet in section.bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: isDark ? _fblaGold : _fblaBlue,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bullet,
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(
    bool isDark,
    Color primaryText,
    Color secondaryText,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.14,
      children: [
        _buildActionCard(
          icon: Icons.schedule_outlined,
          title: 'MS CE Schedule',
          body: 'Middle School competitive event schedule information.',
          isDark: isDark,
          primaryText: primaryText,
          secondaryText: secondaryText,
          onTap: widget.onViewCompetitions,
        ),
        _buildActionCard(
          icon: Icons.calendar_view_week_outlined,
          title: 'HS CE Schedule',
          body: 'High School competitive event schedule information.',
          isDark: isDark,
          primaryText: primaryText,
          secondaryText: secondaryText,
          onTap: widget.onViewCompetitions,
        ),
        _buildActionCard(
          icon: Icons.school_outlined,
          title: 'Middle School Events',
          body: 'Competitive events for middle school members.',
          isDark: isDark,
          primaryText: primaryText,
          secondaryText: secondaryText,
          onTap: widget.onViewCompetitions,
        ),
        _buildActionCard(
          icon: Icons.workspace_premium_outlined,
          title: 'High School Events',
          body: 'Competitive events for high school members.',
          isDark: isDark,
          primaryText: primaryText,
          secondaryText: secondaryText,
          onTap: widget.onViewCompetitions,
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String body,
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: isDark ? _fblaGold : _fblaBlue, size: 28),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                body,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 11.5,
                  height: 1.25,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGetInvolvedCard(
    bool isDark,
    Color primaryText,
    Color secondaryText,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF102A4E), Color(0xFF07111F)]
              : const [Color(0xFFFFFFFF), Color(0xFFFFF7D6)],
        ),
        border: Border.all(
          color: _fblaGold.withValues(alpha: isDark ? 0.28 : 0.38),
        ),
        boxShadow: [
          BoxShadow(
            color: _fblaGold.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: _fblaGold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.volunteer_activism_outlined,
                    color: _fblaGold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Get Involved',
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Interested in guiding the next generation of community-minded business leaders? FBLA welcomes sponsors, exhibitors, speakers, and volunteers to help make the 2026 NLC rewarding for all attendees.',
            style: TextStyle(
              color: secondaryText,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSponsorTile(
    _NlcSponsor sponsor,
    bool isDark,
    Color primaryText,
    Color secondaryText,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDecoration(isDark),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: isDark ? _fblaGold : _fblaBlue,
          collapsedIconColor: isDark ? Colors.white70 : _lightSecondaryText,
          leading: CircleAvatar(
            backgroundColor:
                sponsor.color.withValues(alpha: isDark ? 0.18 : 0.12),
            child: Text(
              sponsor.name[0],
              style: TextStyle(
                color: sponsor.color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          title: Text(
            sponsor.name,
            style: TextStyle(
              color: primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            sponsor.summary,
            style: TextStyle(color: secondaryText, fontSize: 12, height: 1.25),
          ),
          children: [
            Text(
              sponsor.details,
              style: TextStyle(
                color: secondaryText,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF101827) : _lightSurface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : _lightBorder,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.055),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NlcInfoSection {
  final String title;
  final String summary;
  final String body;
  final List<String> bullets;
  final IconData icon;
  final Color color;

  const _NlcInfoSection({
    required this.title,
    required this.summary,
    required this.body,
    required this.icon,
    required this.color,
    this.bullets = const [],
  });
}

class _NlcSponsor {
  final String name;
  final String summary;
  final String details;
  final Color color;

  const _NlcSponsor({
    required this.name,
    required this.summary,
    required this.details,
    required this.color,
  });
}

const _planningSections = [
  _NlcInfoSection(
    title: 'Registration & Housing Instructions',
    summary: 'Registration guidance will be distributed by state.',
    body:
        'Registration and housing instructions will vary by state. States will distribute NLC Registration Guides to members and advisers this spring.',
    icon: Icons.hotel_outlined,
    color: _fblaBlue,
    bullets: [
      'Members should follow their state FBLA registration process.',
      'Advisers should watch for state-specific guides and deadlines.',
    ],
  ),
  _NlcInfoSection(
    title: 'Travel Information',
    summary: 'Plan flights, shuttles, and destination highlights.',
    body:
        'The NLC page directs attendees to travel resources for airline discounts, shuttle services, and San Antonio destination highlights.',
    icon: Icons.flight_takeoff_outlined,
    color: Color(0xFF0EA5E9),
    bullets: [
      'Travel planning support is intended to make conference arrival smoother.',
      'San Antonio discounts and attendee benefits are part of the travel planning experience.',
    ],
  ),
  _NlcInfoSection(
    title: 'Workshop Proposal Applications',
    summary: 'Applications are open for interactive workshops.',
    body:
        'FBLA invites workshop proposals for sessions that empower members and advisers through inspiring, dynamic, and interactive programming.',
    icon: Icons.record_voice_over_outlined,
    color: Color(0xFF7C3AED),
    bullets: [
      'Workshop proposal applications are due March 16.',
      'Sessions should help attendees build skills, confidence, and leadership capacity.',
    ],
  ),
  _NlcInfoSection(
    title: 'Conference Programming',
    summary: 'Speakers, workshops, block party, rodeo, and more.',
    body:
        'From inspiring speakers and workshops designed to help launch careers to a block party and a night at the rodeo, the 2026 NLC is packed with activities to help members make the most of San Antonio.',
    icon: Icons.local_activity_outlined,
    color: Color(0xFFF97316),
  ),
  _NlcInfoSection(
    title: 'Competitive Events',
    summary: 'Business and career-related competition experiences.',
    body:
        'FBLA competitive events recognize and reward excellence across business and career-related areas. Members apply classroom concepts in workforce-simulated competitive environments and receive feedback from business professionals.',
    icon: Icons.workspace_premium_outlined,
    color: _fblaGold,
    bullets: [
      'Middle School Competitive Events',
      'High School Competitive Events',
      'Events help members demonstrate skills in realistic business settings.',
    ],
  ),
  _NlcInfoSection(
    title: '2026-2027 National Officer Elections',
    summary: 'Learn about running for FBLA national office.',
    body:
        'The official NLC page includes information for members interested in applying and running for FBLA national office for the 2026-2027 year.',
    icon: Icons.how_to_vote_outlined,
    color: Color(0xFF16A34A),
  ),
  _NlcInfoSection(
    title: 'Exhibit at NLC',
    summary: 'Opportunities for exhibitors at the 2026 MS/HS NLC.',
    body:
        'Organizations can learn how to exhibit at the 2026 Middle School & High School NLC and connect with FBLA attendees.',
    icon: Icons.storefront_outlined,
    color: Color(0xFFE11D48),
  ),
  _NlcInfoSection(
    title: 'Conference Policies',
    summary: 'Policies and expectations for attendees.',
    body:
        'The NLC page includes a Conference Policies area so attendees can review official expectations and requirements for the event.',
    icon: Icons.policy_outlined,
    color: Color(0xFF64748B),
  ),
];

const _sponsors = [
  _NlcSponsor(
    name: 'USA TODAY',
    summary: 'Digital media careers, internships, and storytelling.',
    details:
        'Gannett is a next-generation, digitally-led media company that empowers communities to connect, act, and thrive. Its USA TODAY network includes 92+ media entities in the U.S. and U.K. with jobs and internships focused on digital solutions and storytelling.',
    color: Color(0xFF2563EB),
  ),
  _NlcSponsor(
    name: 'FICO Score',
    summary: 'Credit education and consumer financial empowerment.',
    details:
        'FICO supports consumer financial empowerment through Score A Better Future Fundamentals, a free credit education curriculum designed to make credit education simple, accessible, and useful for long-term financial decisions.',
    color: Color(0xFF0EA5E9),
  ),
  _NlcSponsor(
    name: 'AllFly',
    summary: 'Group flight planning and conference travel support.',
    details:
        'AllFly Marketplace helps groups search, book, and manage travel online with automated planning tools, dedicated account managers, group rates, trip management, payment options, reminders, and around-the-clock support.',
    color: Color(0xFF0284C7),
  ),
  _NlcSponsor(
    name: 'Country Meats',
    summary: 'Fundraising with snack stick programs.',
    details:
        'Country Meats has supported fundraisers since 1978 through in-person sales, pre-orders, and online fundraising. Their model helps schools, teams, clubs, and groups raise funds through snack stick sales.',
    color: Color(0xFFB45309),
  ),
  _NlcSponsor(
    name: 'AICPA',
    summary: 'Accounting career resources through ThisWayToCPA.',
    details:
        'The American Institute of Certified Public Accountants introduces students to accounting careers, student affiliate membership, educator resources, and pathways toward the CPA profession.',
    color: Color(0xFF1D4E89),
  ),
  _NlcSponsor(
    name: 'Hyatt Hotels',
    summary: 'Hotel discount information for attendees.',
    details:
        'Hyatt Hotels offers reservation support and a group discount code listed on the NLC page for eligible conference travel planning.',
    color: Color(0xFF0F766E),
  ),
  _NlcSponsor(
    name: 'College Board',
    summary: 'College and career readiness programs.',
    details:
        'College Board supports students through college and career pathways, including AP Business with Personal Finance, developed with industry advisors, higher education faculty, business educators, and FBLA leadership.',
    color: Color(0xFF7C3AED),
  ),
  _NlcSponsor(
    name: 'National Technical Honor Society',
    summary: 'Recognition and scholarship opportunities for CTE students.',
    details:
        'NTHS recognizes achievement in Career and Technical Education, encourages higher education, and partners with FBLA to provide scholarship opportunities for eligible members.',
    color: Color(0xFFF59E0B),
  ),
  _NlcSponsor(
    name: 'Nourishing Neighbors',
    summary: 'Project-based learning about hunger and food insecurity.',
    details:
        'The Explore.Act.Tell. program engages students in grades 6-12 through real-world projects that build collaboration, communication, problem-solving, critical thinking, and creativity.',
    color: Color(0xFF16A34A),
  ),
  _NlcSponsor(
    name: 'BusinessU',
    summary: 'Interactive business curriculum platform.',
    details:
        'BusinessU provides standards-based courses in marketing, accounting, entrepreneurship, business, economics, management, finance, and certification prep with video lessons, activities, projects, discussions, and assessments.',
    color: Color(0xFF2563EB),
  ),
  _NlcSponsor(
    name: 'SCAD',
    summary: 'Creative career education and degree programs.',
    details:
        'The Savannah College of Art and Design offers more than 100 academic degree programs across creative fields, with career preparation, technology resources, internships, certifications, and corporate collaboration.',
    color: Color(0xFFE11D48),
  ),
  _NlcSponsor(
    name: 'Rubin',
    summary: 'Employability and business communication skills.',
    details:
        'Rubin provides tools for email writing, K-12 business communication skills, and career exploration through resources such as Propel, Emerge, and Aspire.',
    color: Color(0xFF9333EA),
  ),
  _NlcSponsor(
    name: 'University of Vermont',
    summary: 'Vermont Pitch Challenge and scholarship opportunities.',
    details:
        'The University of Vermont offers the Vermont Pitch Challenge for high school students to pitch innovative business ideas for cash prizes and scholarship opportunities.',
    color: Color(0xFF15803D),
  ),
  _NlcSponsor(
    name: 'Lead4Change Student Leadership Program',
    summary: 'Free leadership curriculum for grades 6-12.',
    details:
        'Lead4Change teaches leadership skills through curriculum aligned to national standards, social emotional learning, project-based learning, career and technical education, and community impact.',
    color: Color(0xFFF97316),
  ),
  _NlcSponsor(
    name: 'Long Island University',
    summary: 'Business, entrepreneurship, data, and career programs.',
    details:
        'Long Island University offers academic programs across business, artificial intelligence, data analytics, entrepreneurship, finance, marketing, sports management, and other professional fields.',
    color: Color(0xFF0F766E),
  ),
  _NlcSponsor(
    name: 'IMA',
    summary: 'Management accounting student opportunities.',
    details:
        'The Institute of Management Accountants supports students through leadership opportunities, the CMA program, networking, student conferences, accounting honors, and professional development.',
    color: Color(0xFF1D4E89),
  ),
  _NlcSponsor(
    name: 'Office Depot and OfficeMax',
    summary: 'FBLA member savings program.',
    details:
        'The FBLA Office Depot member benefits program provides savings on preferred products, delivery options, pickup, and business supply support through ODP Business Solutions.',
    color: Color(0xFFDC2626),
  ),
  _NlcSponsor(
    name: 'City Pop Fundraising',
    summary: 'Online fundraising platform for chapters and groups.',
    details:
        'City Pop Fundraising offers online fundraising with popcorn, pretzels, candy, no minimums, no upfront costs, no distribution headaches, and direct delivery of raised funds after campaigns conclude.',
    color: Color(0xFFF59E0B),
  ),
];
