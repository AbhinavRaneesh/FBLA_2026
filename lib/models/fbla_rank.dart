import 'package:flutter/material.dart';

class FBLARankTier {
  final String name;
  final String shortLabel;
  final int coinRequirement;
  final IconData icon;
  final List<Color> gradient;
  final Color accent;
  final String tagline;

  const FBLARankTier({
    required this.name,
    required this.shortLabel,
    required this.coinRequirement,
    required this.icon,
    required this.gradient,
    required this.accent,
    required this.tagline,
  });
}

class FBLARankSystem {
  static const String defaultRank = 'Intern';

  static const List<FBLARankTier> tiers = [
    FBLARankTier(
      name: 'Intern',
      shortLabel: 'Intern',
      coinRequirement: 0,
      icon: Icons.school_outlined,
      gradient: [Color(0xFF8D6E63), Color(0xFF5D4037)],
      accent: Color(0xFF8D6E63),
      tagline: 'Start your FBLA journey',
    ),
    FBLARankTier(
      name: 'Assistant',
      shortLabel: 'Asst',
      coinRequirement: 100,
      icon: Icons.support_agent_outlined,
      gradient: [Color(0xFF90A4AE), Color(0xFF607D8B)],
      accent: Color(0xFF90A4AE),
      tagline: 'Building momentum',
    ),
    FBLARankTier(
      name: 'Coordinator',
      shortLabel: 'Coord',
      coinRequirement: 250,
      icon: Icons.hub_outlined,
      gradient: [Color(0xFF78909C), Color(0xFF455A64)],
      accent: Color(0xFF78909C),
      tagline: 'Organizing the team',
    ),
    FBLARankTier(
      name: 'Specialist',
      shortLabel: 'Spec',
      coinRequirement: 500,
      icon: Icons.psychology_outlined,
      gradient: [Color(0xFFFFB74D), Color(0xFFF57C00)],
      accent: Color(0xFFFFB74D),
      tagline: 'Sharpening expertise',
    ),
    FBLARankTier(
      name: 'Analyst',
      shortLabel: 'Analyst',
      coinRequirement: 800,
      icon: Icons.analytics_outlined,
      gradient: [Color(0xFFFFD54F), Color(0xFFFFB300)],
      accent: Color(0xFFFFD54F),
      tagline: 'Turning insight into action',
    ),
    FBLARankTier(
      name: 'Associate',
      shortLabel: 'Assoc',
      coinRequirement: 1200,
      icon: Icons.groups_outlined,
      gradient: [Color(0xFFFFCA28), Color(0xFFFF8F00)],
      accent: Color(0xFFFFCA28),
      tagline: 'Growing your influence',
    ),
    FBLARankTier(
      name: 'Senior Associate',
      shortLabel: 'Sr Assoc',
      coinRequirement: 1700,
      icon: Icons.workspace_premium_outlined,
      gradient: [Color(0xFFBA68C8), Color(0xFF7B1FA2)],
      accent: Color(0xFFBA68C8),
      tagline: 'Leading with confidence',
    ),
    FBLARankTier(
      name: 'Manager',
      shortLabel: 'Manager',
      coinRequirement: 2300,
      icon: Icons.manage_accounts_outlined,
      gradient: [Color(0xFF9575CD), Color(0xFF512DA8)],
      accent: Color(0xFF9575CD),
      tagline: 'Guiding the chapter',
    ),
    FBLARankTier(
      name: 'Director',
      shortLabel: 'Director',
      coinRequirement: 3000,
      icon: Icons.corporate_fare_outlined,
      gradient: [Color(0xFF7986CB), Color(0xFF303F9F)],
      accent: Color(0xFF7986CB),
      tagline: 'Shaping the vision',
    ),
    FBLARankTier(
      name: 'Vice President',
      shortLabel: 'VP',
      coinRequirement: 4000,
      icon: Icons.account_balance_outlined,
      gradient: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
      accent: Color(0xFF4FC3F7),
      tagline: 'Driving statewide impact',
    ),
    FBLARankTier(
      name: 'President',
      shortLabel: 'President',
      coinRequirement: 5500,
      icon: Icons.military_tech_outlined,
      gradient: [Color(0xFFEF5350), Color(0xFFC62828)],
      accent: Color(0xFFEF5350),
      tagline: 'Commanding excellence',
    ),
    FBLARankTier(
      name: 'CEO',
      shortLabel: 'CEO',
      coinRequirement: 7500,
      icon: Icons.diamond_outlined,
      gradient: [Color(0xFFFF5252), Color(0xFFB71C1C)],
      accent: Color(0xFFFF5252),
      tagline: 'The pinnacle of FBLA leadership',
    ),
  ];

  static FBLARankTier tierByName(String name) {
    return tiers.firstWhere(
      (tier) => tier.name.toLowerCase() == name.trim().toLowerCase(),
      orElse: () => tiers.first,
    );
  }

  static int indexForRank(String name) {
    final normalized = name.trim().toLowerCase();
    return tiers.indexWhere((tier) => tier.name.toLowerCase() == normalized);
  }

  static FBLARankTier rankForCoins(int coins) {
    FBLARankTier current = tiers.first;
    for (final tier in tiers) {
      if (coins >= tier.coinRequirement) {
        current = tier;
      }
    }
    return current;
  }

  static String shortLabelFor(String name) => tierByName(name).shortLabel;

  static FBLARankTier? nextTierForCoins(int coins) {
    final current = rankForCoins(coins);
    final currentIndex = tiers.indexOf(current);
    if (currentIndex >= tiers.length - 1) return null;
    return tiers[currentIndex + 1];
  }

  static double progressToNextRank(int coins) {
    final current = rankForCoins(coins);
    final next = nextTierForCoins(coins);
    if (next == null) return 1;

    final span = next.coinRequirement - current.coinRequirement;
    if (span <= 0) return 1;
    return ((coins - current.coinRequirement) / span).clamp(0.0, 1.0);
  }

  static int coinsToNextRank(int coins) {
    final next = nextTierForCoins(coins);
    if (next == null) return 0;
    return (next.coinRequirement - coins).clamp(0, 999999);
  }
}
