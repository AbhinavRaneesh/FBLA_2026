import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color fblaBlue = const Color(0xFF1D4E89);
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
