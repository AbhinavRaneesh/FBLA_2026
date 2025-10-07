import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color fblaBlue = const Color(0xFF1D4E89);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resources'),
        backgroundColor: fblaBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Access Section
          _buildSectionHeader(context, 'Quick Access'),
          const SizedBox(height: 16),

          _buildResourceCard(
            context,
            'FBLA Connect',
            'Access your FBLA Connect account',
            Icons.account_circle,
            () => _launchUrl('https://connect.fbla.org/'),
          ),

          _buildResourceCard(
            context,
            'Competition Guidelines',
            'Study guides and competition rules',
            Icons.school,
            () => _launchUrl('https://www.fbla-pbl.org/competitive-events/'),
          ),

          _buildResourceCard(
            context,
            'Leadership Development',
            'Build your leadership skills',
            Icons.leaderboard,
            () =>
                _launchUrl('https://www.fbla-pbl.org/leadership-development/'),
          ),

          const SizedBox(height: 24),

          // Study Materials Section
          _buildSectionHeader(context, 'Study Materials'),
          const SizedBox(height: 16),

          _buildResourceCard(
            context,
            'Business Skills',
            'Fundamentals of business and entrepreneurship',
            Icons.business,
            () => _showComingSoon(context),
          ),

          _buildResourceCard(
            context,
            'Technology & Innovation',
            'Latest trends in business technology',
            Icons.computer,
            () => _showComingSoon(context),
          ),

          _buildResourceCard(
            context,
            'Career Preparation',
            'Resume building and interview skills',
            Icons.work,
            () => _showComingSoon(context),
          ),

          const SizedBox(height: 24),

          // Downloads Section
          _buildSectionHeader(context, 'Downloads'),
          const SizedBox(height: 16),

          _buildResourceCard(
            context,
            'FBLA Handbook',
            'Complete guide to FBLA programs',
            Icons.book,
            () => _showComingSoon(context),
          ),

          _buildResourceCard(
            context,
            'Chapter Resources',
            'Templates and guides for chapter activities',
            Icons.group,
            () => _showComingSoon(context),
          ),

          _buildResourceCard(
            context,
            'Competition Materials',
            'Practice tests and study guides',
            Icons.quiz,
            () => _showComingSoon(context),
          ),

          const SizedBox(height: 24),

          // External Links Section
          _buildSectionHeader(context, 'External Links'),
          const SizedBox(height: 16),

          _buildResourceCard(
            context,
            'FBLA-PBL Official Website',
            'Visit the national FBLA website',
            Icons.language,
            () => _launchUrl('https://www.fbla-pbl.org/'),
          ),

          _buildResourceCard(
            context,
            'State FBLA',
            'Connect with your state organization',
            Icons.location_on,
            () => _showComingSoon(context),
          ),

          _buildResourceCard(
            context,
            'Career Center',
            'Explore career opportunities',
            Icons.explore,
            () => _launchUrl('https://www.fbla-pbl.org/career-center/'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final Color fblaBlue = const Color(0xFF1D4E89);
    final Color fblaGold = const Color(0xFFF6C500);

    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: fblaGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: fblaBlue,
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
    VoidCallback onTap,
  ) {
    final Color fblaBlue = const Color(0xFF1D4E89);
    final Color fblaGold = const Color(0xFFF6C500);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: fblaBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: fblaBlue,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: fblaGold,
          size: 16,
        ),
        onTap: onTap,
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This resource will be available soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
