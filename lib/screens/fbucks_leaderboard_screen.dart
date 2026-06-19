import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_assets.dart';
import '../main.dart' show AppState, appBackgroundGradient, fblaGold, fblaNavy;
import '../services/firebase_service.dart';

class FbucksLeaderboardScreen extends StatefulWidget {
  const FbucksLeaderboardScreen({super.key});

  @override
  State<FbucksLeaderboardScreen> createState() =>
      _FbucksLeaderboardScreenState();
}

class _FbucksLeaderboardScreenState extends State<FbucksLeaderboardScreen> {
  List<Map<String, dynamic>> _members = const [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final members = await FirebaseService.getUsers();
      members.sort(_sortByPoints);
      if (!mounted) return;
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  int _sortByPoints(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final leftPoints = _pointsFor(left);
    final rightPoints = _pointsFor(right);
    if (leftPoints != rightPoints) return rightPoints.compareTo(leftPoints);

    return _displayName(left).toLowerCase().compareTo(
          _displayName(right).toLowerCase(),
        );
  }

  int _pointsFor(Map<String, dynamic> member) =>
      int.tryParse((member['points'] ?? 0).toString()) ?? 0;

  String _displayName(Map<String, dynamic> member) {
    final name =
        (member['name'] ?? member['displayName'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final email = (member['email'] ?? '').toString().trim();
    if (email.contains('@')) return email.split('@').first;
    return 'Unnamed Member';
  }

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId ?? '';
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Credits Leaderboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: fblaGold))
            : _loadError != null
                ? _buildErrorState()
                : RefreshIndicator(
                    color: fblaGold,
                    onRefresh: _loadLeaderboard,
                    child: _members.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'No members found yet.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomSafe + 80),
                            itemCount: _members.length + 1,
                            separatorBuilder: (_, index) =>
                                index == 0 ? const SizedBox(height: 12) : const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildHeaderCard(
                                  memberCount: _members.length,
                                );
                              }

                              final member = _members[index - 1];
                              final rank = index;
                              final isCurrentUser =
                                  (member['id'] ?? '').toString() ==
                                      currentUserId;

                              return _LeaderboardRow(
                                rank: rank,
                                name: _displayName(member),
                                school: (member['school'] ?? '')
                                    .toString()
                                    .trim(),
                                points: _pointsFor(member),
                                rankTitle: (member['rank'] ?? 'Intern')
                                    .toString()
                                    .trim(),
                                isCurrentUser: isCurrentUser,
                              );
                            },
                          ),
                  ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, color: Colors.white54, size: 48),
            const SizedBox(height: 14),
            const Text(
              'Could not load leaderboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLeaderboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: fblaGold,
                foregroundColor: fblaNavy,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard({required int memberCount}) {
    final app = context.watch<AppState>();
    final myPoints = app.userProfile?.points ?? 0;
    int myRank = 0;
    for (var i = 0; i < _members.length; i++) {
      if ((_members[i]['id'] ?? '').toString() == _currentUserId) {
        myRank = i + 1;
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1624),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fblaGold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Image.asset(AppAssets.coins, width: 42, height: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chapter Credits Rankings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$memberCount members ranked by total Credits.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                if (myRank > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'You are #$myRank with $myPoints Credits',
                    style: const TextStyle(
                      color: fblaGold,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String name;
  final String school;
  final int points;
  final String rankTitle;
  final bool isCurrentUser;

  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.school,
    required this.points,
    required this.rankTitle,
    required this.isCurrentUser,
  });

  Color get _medalColor {
    if (rank == 1) return const Color(0xFFFFD54F);
    if (rank == 2) return const Color(0xFFB0BEC5);
    if (rank == 3) return const Color(0xFFFF8A65);
    return Colors.white30;
  }

  @override
  Widget build(BuildContext context) {
    final medal = _medalColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? fblaGold.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser
              ? fblaGold.withValues(alpha: 0.55)
              : rank <= 3
                  ? medal.withValues(alpha: 0.45)
                  : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medal.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: medal),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank <= 3 ? medal : Colors.white70,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF1D4E89),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? '$name (You)' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (school.isNotEmpty) school,
                    if (rankTitle.isNotEmpty) rankTitle,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AppAssets.coins, width: 18, height: 18),
              const SizedBox(width: 4),
              Text(
                '$points',
                style: const TextStyle(
                  color: fblaGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
