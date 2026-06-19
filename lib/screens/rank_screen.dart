import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_assets.dart';

import '../main.dart' show AppState;
import '../models/fbla_rank.dart';

const Color _lightPrimaryText = Color(0xFF0A192F);
const Color _lightSecondaryText = Color(0xFF475569);
const Color _lightBorder = Color(0xFFD5DEE6);

class RankScreen extends StatelessWidget {
  final int coinBalance;
  final String currentRank;

  const RankScreen({
    super.key,
    required this.coinBalance,
    required this.currentRank,
  });

  static void open(BuildContext context) {
    final app = Provider.of<AppState>(context, listen: false);
    final coins = app.userProfile?.points ?? 0;
    final storedRank = app.userProfile?.rank ?? FBLARankSystem.defaultRank;
    final effectiveRank = _effectiveRank(storedRank, coins);

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RankScreen(
          coinBalance: coins,
          currentRank: effectiveRank,
        ),
      ),
    );
  }

  static String _effectiveRank(String storedRank, int coins) {
    final coinRank = FBLARankSystem.rankForCoins(coins).name;
    final storedIndex = FBLARankSystem.indexForRank(storedRank);
    final coinIndex = FBLARankSystem.indexForRank(coinRank);
    if (coinIndex >= storedIndex) return coinRank;
    return storedRank;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTier = FBLARankSystem.tierByName(currentRank);
    final currentIndex = FBLARankSystem.indexForRank(currentRank);
    final nextTier = FBLARankSystem.nextTierForCoins(coinBalance);
    final progress = FBLARankSystem.progressToNextRank(coinBalance);
    final coinsNeeded = FBLARankSystem.coinsToNextRank(coinBalance);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF050B14) : const Color(0xFFE8EEF5),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF07182B),
                    const Color(0xFF050B14),
                    const Color(0xFF0A1628),
                  ]
                : [
                    const Color(0xFFDCE8F8),
                    const Color(0xFFE8EEF5),
                    const Color(0xFFF4F7FB),
                  ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark ? Colors.white : _lightPrimaryText,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Career Ranks',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white : _lightPrimaryText,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: _buildHeroCard(
                    context,
                    currentTier: currentTier,
                    coinBalance: coinBalance,
                    nextTier: nextTier,
                    progress: progress,
                    coinsNeeded: coinsNeeded,
                    isDark: isDark,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverList.separated(
                  itemCount: FBLARankSystem.tiers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final tier = FBLARankSystem.tiers[index];
                    final isUnlocked = coinBalance >= tier.coinRequirement;
                    final isCurrent = index == currentIndex;
                    final isNext = nextTier?.name == tier.name;

                    return _buildRankLadderCard(
                      tier: tier,
                      index: index,
                      isUnlocked: isUnlocked,
                      isCurrent: isCurrent,
                      isNext: isNext,
                      isDark: isDark,
                      isLast: index == FBLARankSystem.tiers.length - 1,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required FBLARankTier currentTier,
    required int coinBalance,
    required FBLARankTier? nextTier,
    required double progress,
    required int coinsNeeded,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            currentTier.gradient.first.withValues(alpha: 0.92),
            currentTier.gradient.last.withValues(alpha: 0.98),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: currentTier.accent.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(currentTier.icon, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 16),
          Text(
            'Your Rank',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            currentTier.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentTier.tagline,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(AppAssets.coins, width: 22, height: 22),
              const SizedBox(width: 8),
              Text(
                '$coinBalance Credits',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (nextTier != null) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$coinsNeeded Credits to reach ${nextTier.name}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'You reached the highest rank!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRankLadderCard({
    required FBLARankTier tier,
    required int index,
    required bool isUnlocked,
    required bool isCurrent,
    required bool isNext,
    required bool isDark,
    required bool isLast,
  }) {
    final cardColor = isDark ? const Color(0xFF101827) : Colors.white;
    final mutedText = isDark ? Colors.white60 : _lightSecondaryText;
    final primaryText = isDark ? Colors.white : _lightPrimaryText;
    final badgeSize = 58.0 + (index * 1.8).clamp(0, 18);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? tier.accent
                      : isUnlocked
                          ? tier.accent.withValues(alpha: 0.55)
                          : Colors.white
                              .withValues(alpha: isDark ? 0.12 : 0.35),
                  border: Border.all(
                    color: isCurrent ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: tier.accent.withValues(alpha: 0.55),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
              ),
              if (!isLast)
                Container(
                  width: 3,
                  height: 118,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isUnlocked
                          ? [
                              tier.accent.withValues(alpha: 0.7),
                              FBLARankSystem.tiers[index + 1].accent
                                  .withValues(alpha: 0.35),
                            ]
                          : [
                              Colors.white
                                  .withValues(alpha: isDark ? 0.08 : 0.2),
                              Colors.white
                                  .withValues(alpha: isDark ? 0.04 : 0.1),
                            ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isCurrent
                    ? tier.accent
                    : isNext
                        ? tier.accent.withValues(alpha: 0.45)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : _lightBorder,
                width: isCurrent ? 2.2 : 1,
              ),
              boxShadow: [
                if (isCurrent)
                  BoxShadow(
                    color: tier.accent.withValues(alpha: 0.22),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isUnlocked
                          ? tier.gradient
                          : [
                              Colors.grey.shade700,
                              Colors.grey.shade800,
                            ],
                    ),
                    boxShadow: isUnlocked
                        ? [
                            BoxShadow(
                              color: tier.accent.withValues(alpha: 0.28),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    tier.icon,
                    color: isUnlocked ? Colors.white : Colors.white54,
                    size: badgeSize * 0.42,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tier.name,
                              style: TextStyle(
                                color: isUnlocked ? primaryText : mutedText,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: tier.accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'CURRENT',
                                style: TextStyle(
                                  color: tier.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            )
                          else if (!isUnlocked)
                            Icon(Icons.lock_outline,
                                color: mutedText, size: 18),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tier.tagline,
                        style: TextStyle(
                          color: mutedText,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Opacity(
                            opacity: isUnlocked ? 1 : 0.45,
                            child: Image.asset(
                              AppAssets.coins,
                              width: 16,
                              height: 16,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tier.coinRequirement == 0
                                ? 'Starting rank'
                                : '${tier.coinRequirement}+ Credits',
                            style: TextStyle(
                              color: isUnlocked ? primaryText : mutedText,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
