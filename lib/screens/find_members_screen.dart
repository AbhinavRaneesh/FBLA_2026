import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/firebase_service.dart';
import '../services/member_directory_cache.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/member_avatar.dart';

enum _MembersTab { directory, friends, requests }

class FindMembersScreen extends StatefulWidget {
  const FindMembersScreen({super.key});

  @override
  State<FindMembersScreen> createState() => _FindMembersScreenState();
}

class _FindMembersScreenState extends State<FindMembersScreen> {
  static const Color _fblaBlue = Color(0xFF1D4E89);

  final TextEditingController _searchController = TextEditingController();
  _MembersTab _selectedTab = _MembersTab.directory;
  String _searchQuery = '';

  List<Map<String, dynamic>> _allMembers = const [];
  List<Map<String, dynamic>> _friends = const [];
  List<Map<String, dynamic>> _incomingRequests = const [];
  Map<String, String> _relationStatuses = const {};
  bool _isLoading = true;
  String? _loadError;
  bool _sameNlcEventOnly = false;
  List<String> _myNlcEvents = const [];

  @override
  void initState() {
    super.initState();
    final cached = MemberDirectoryCache.snapshotFor(_currentUserId);
    if (cached != null) {
      _applySnapshot(cached);
      _isLoading = false;
    }
    _loadData(silent: cached != null);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  String _currentUserName(BuildContext context) {
    final app = Provider.of<AppState>(context, listen: false);
    return app.resolvedDisplayName;
  }

  void _applySnapshot(MemberDirectorySnapshot snapshot) {
    _allMembers = snapshot.allMembers;
    _friends = snapshot.friends;
    _incomingRequests = snapshot.incomingRequests;
    _relationStatuses = snapshot.relationStatuses;
    _myNlcEvents = snapshot.myNlcEvents;
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null || currentUserId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _allMembers = const [];
          _friends = const [];
          _incomingRequests = const [];
          _relationStatuses = const {};
          _loadError = null;
          _isLoading = false;
        });
        return;
      }

      final snapshot = await MemberDirectoryCache.preload(
        currentUserId,
        force: true,
      );

      if (!mounted || snapshot == null) return;
      setState(() {
        _applySnapshot(snapshot);
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      setState(() {
        if (message.contains('permission-denied')) {
          _loadError =
              'Could not load members. Deploy Firestore rules: firebase deploy --only firestore:rules';
        } else {
          _loadError = message.replaceFirst('Exception: ', '');
        }
        _isLoading = false;
      });
    }
  }

  int _sortMembers(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final leftName = _displayName(left).toLowerCase();
    final rightName = _displayName(right).toLowerCase();

    if (leftName.isEmpty && rightName.isEmpty) {
      final leftEmail = (left['email'] ?? '').toString().trim().toLowerCase();
      final rightEmail = (right['email'] ?? '').toString().trim().toLowerCase();
      return leftEmail.compareTo(rightEmail);
    }
    if (leftName.isEmpty) return 1;
    if (rightName.isEmpty) return -1;

    final comparison = leftName.compareTo(rightName);
    if (comparison != 0) return comparison;

    final leftEmail = (left['email'] ?? '').toString().trim().toLowerCase();
    final rightEmail = (right['email'] ?? '').toString().trim().toLowerCase();
    return leftEmail.compareTo(rightEmail);
  }

  List<String> _memberNlcEvents(Map<String, dynamic> member) {
    final raw = member['nlcEvents'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  bool _sharesNlcEvent(Map<String, dynamic> member) {
    if (_myNlcEvents.isEmpty) return false;
    final theirs = _memberNlcEvents(member);
    return theirs.any(_myNlcEvents.contains);
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> members) {
    return members.where((member) {
      if (_sameNlcEventOnly && !_sharesNlcEvent(member)) {
        return false;
      }

      final name = _displayName(member).toLowerCase();
      final email = (member['email'] ?? '').toString().toLowerCase();
      final chapter = (member['chapter'] ?? '').toString().toLowerCase();
      final school = (member['school'] ?? '').toString().toLowerCase();
      final officerPosition =
          (member['officerPosition'] ?? '').toString().toLowerCase();
      final query = _searchQuery.trim().toLowerCase();

      return query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          chapter.contains(query) ||
          school.contains(query) ||
          officerPosition.contains(query);
    }).toList(growable: false);
  }

  String _displayName(Map<String, dynamic> member) {
    final name = (member['name'] ??
            member['displayName'] ??
            member['fullName'] ??
            '')
        .toString()
        .trim();
    return name.isEmpty ? 'Unnamed Member' : name;
  }

  Widget _buildDirectoryHeader({
    required bool isDark,
    required int memberCount,
    required int friendCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0B1624), const Color(0xFF1D4E89)]
              : [fblaBlue, const Color(0xFF2563A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: fblaBlue.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: fblaGold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: fblaGold.withValues(alpha: 0.45)),
                ),
                child: const Icon(Icons.people_alt_rounded,
                    color: fblaGold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Member Directory',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$memberCount members · $friendCount friends',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _isLoading ? null : _loadData,
                icon: const Icon(Icons.refresh_rounded, color: fblaGold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendFriendRequest(Map<String, dynamic> member) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      _showSnack('Sign in to send friend requests.');
      return;
    }

    final targetUserId = (member['id'] ?? '').toString();
    if (targetUserId.isEmpty) {
      _showSnack('This member account is missing an ID.');
      return;
    }

    try {
      await FirebaseService.sendFriendRequest(
        fromUserId: currentUserId,
        toUserId: targetUserId,
        fromUserName: _currentUserName(context),
        toUserName: _displayName(member),
      );
      _showSnack('Friend request sent to ${_displayName(member)}.',
          type: AppSnackType.success);
      await _loadData();
    } catch (error) {
      final raw = error.toString().replaceFirst('Exception: ', '');
      final message = raw.contains('permission-denied') ||
              raw.contains('Firestore rules')
          ? 'Could not send friend request. Firestore rules may need to be deployed.'
          : raw;
      _showSnack(message, type: AppSnackType.error);
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    try {
      await FirebaseService.acceptFriendRequest(
        (request['id'] ?? '').toString(),
      );
      _showSnack('Friend request accepted.', type: AppSnackType.success);
      await _loadData();
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''),
          type: AppSnackType.error);
    }
  }

  Future<void> _declineRequest(Map<String, dynamic> request) async {
    try {
      await FirebaseService.declineFriendRequest(
        (request['id'] ?? '').toString(),
      );
      _showSnack('Friend request declined.', type: AppSnackType.info);
      await _loadData();
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''),
          type: AppSnackType.error);
    }
  }

  Future<void> _removeFriend(Map<String, dynamic> member) async {
    final currentUserId = _currentUserId;
    final friendId = (member['id'] ?? '').toString();
    if (currentUserId == null) {
      _showSnack('Sign in to manage friends.');
      return;
    }
    if (friendId.isEmpty) {
      _showSnack('This member account is missing an ID.');
      return;
    }

    try {
      await FirebaseService.removeFriend(
        currentUserId: currentUserId,
        friendUserId: friendId,
      );
      _showSnack(
        'Removed ${_displayName(member)} from friends.',
        type: AppSnackType.info,
      );
      await _loadData();
    } catch (error) {
      final raw = error.toString().replaceFirst('Exception: ', '');
      final message = raw.contains('permission-denied') ||
              raw.contains('Firestore rules')
          ? 'Could not remove friend. Firestore rules may need to be deployed.'
          : raw;
      _showSnack(message, type: AppSnackType.error);
    }
  }

  Future<void> _confirmRemoveFriend(Map<String, dynamic> member) async {
    final name = _displayName(member);
    final school = (member['school'] ?? '').toString().trim();
    final chapter = (member['chapter'] ?? '').toString().trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F1C31) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF0A192F);
    final secondaryText =
        isDark ? Colors.white.withValues(alpha: 0.68) : const Color(0xFF475569);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFEF5350).withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.person_remove_rounded,
                  color: Color(0xFFEF5350),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Remove friend?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              CircleAvatar(
                radius: 26,
                backgroundColor: _fblaBlue,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (school.isNotEmpty || chapter.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  [if (school.isNotEmpty) school, if (chapter.isNotEmpty) chapter]
                      .join(' • '),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryText, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'They will be removed from your Friends list and your chat history will be cleared. You can send a new friend request anytime.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryText,
                        side: BorderSide(
                          color: isDark
                              ? Colors.white24
                              : const Color(0xFFD5DEE6),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Remove'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF5350),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await _removeFriend(member);
    }
  }

  void _showSnack(String message, {AppSnackType? type}) {
    if (!mounted) return;
    AppSnackBar.show(context, message: message, type: type);
  }

  Future<void> _emailMember(String email) async {
    if (email.isEmpty) {
      _showSnack('This member does not have an email listed.');
      return;
    }

    final uri = Uri(scheme: 'mailto', path: email);
    if (!await launchUrl(uri)) {
      _showSnack('Could not open email for $email.');
    }
  }

  void _showMemberDetails(Map<String, dynamic> member) {
    final name = _displayName(member);
    final email = (member['email'] ?? '').toString().trim();
    final chapter = (member['chapter'] ?? '').toString().trim();
    final school = (member['school'] ?? '').toString().trim();
    final officerPosition = (member['officerPosition'] ?? '').toString().trim();
    final biography = (member['biography'] ?? '').toString().trim();
    final points = int.tryParse((member['points'] ?? 0).toString()) ?? 0;
    final streak = int.tryParse((member['streak'] ?? 0).toString()) ?? 0;
    final rank = (member['rank'] ?? 'Intern').toString().trim();
    final role = officerPosition.isNotEmpty ? officerPosition : 'Member';
    final memberId = (member['id'] ?? '').toString();
    final isFriend = _relationStatuses[memberId] == 'friends';
    final participatingIds = (member['participatingEvents'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final app = Provider.of<AppState>(context, listen: false);
    final competingLabels = participatingIds.map((id) {
      final match = app.events.cast<Event?>().firstWhere(
            (e) => e?.id == id,
            orElse: () => null,
          );
      return match?.title ?? id;
    }).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: isDark ? const Color(0xFF0F1C31) : fblaLightSurface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _fblaBlue,
                        radius: 28,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : fblaLightPrimaryText,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              role,
                              style: TextStyle(
                                color: isDark
                                    ? fblaGold
                                    : fblaBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'User Stats',
                    style: TextStyle(
                      color: isDark ? Colors.white : fblaLightPrimaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatChip(
                          'Credits',
                          '$points',
                          Icons.monetization_on_outlined,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatChip(
                          'Rank',
                          rank,
                          Icons.military_tech_outlined,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatChip(
                          'Streak',
                          '$streak',
                          Icons.local_fire_department_outlined,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildDetailRow(
                    Icons.email_outlined,
                    'Email',
                    email.isEmpty ? '—' : email,
                    isDark,
                  ),
                  _buildDetailRow(
                    Icons.school_outlined,
                    'School',
                    school.isEmpty ? '—' : school,
                    isDark,
                  ),
                  _buildDetailRow(
                    Icons.groups_outlined,
                    'Chapter',
                    chapter.isEmpty ? '—' : chapter,
                    isDark,
                  ),
                  _buildDetailRow(
                    Icons.badge_outlined,
                    'Role',
                    role,
                    isDark,
                  ),
                  _buildDetailRow(
                    Icons.emoji_events_outlined,
                    'Competing In',
                    competingLabels.isEmpty
                        ? '—'
                        : competingLabels.join(', '),
                    isDark,
                  ),
                  if (biography.isNotEmpty)
                    _buildDetailRow(
                        Icons.info_outline, 'Bio', biography, isDark),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (isFriend && memberId.isNotEmpty)
                        IconButton(
                          tooltip: 'Remove friend',
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmRemoveFriend(member);
                          },
                          icon: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF5350)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFFEF5350),
                              size: 22,
                            ),
                          ),
                        ),
                      if (isFriend && memberId.isNotEmpty)
                        const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: email.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _emailMember(email);
                                },
                          icon: const Icon(Icons.mail_outline),
                          label: const Text('Email'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: fblaBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : fblaLightBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : fblaLightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: fblaGold, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : fblaLightPrimaryText,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white60 : fblaLightSecondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _fblaBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : fblaLightSecondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : fblaLightPrimaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final isDark = app.isDarkMode;
    final backgroundColor = isDark ? appBackgroundColor : fblaLightBackground;
    final primaryText = isDark ? Colors.white : fblaLightPrimaryText;
    final secondaryText = isDark ? Colors.white70 : fblaLightSecondaryText;
    final surfaceColor = isDark ? const Color(0xFF101827) : fblaLightSurface;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : fblaLightBorder;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? appBackgroundGradient : null,
          color: isDark ? null : fblaLightBackground,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDirectoryHeader(
                isDark: isDark,
                memberCount: _allMembers.length,
                friendCount: _friends.length,
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: fblaGold),
                      )
                    : _currentUserId == null
                        ? _buildSignInPrompt(primaryText, secondaryText)
                        : _loadError != null
                            ? _buildErrorState(primaryText)
                            : RefreshIndicator(
                                onRefresh: _loadData,
                                color: fblaGold,
                                child: ListView(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 16, 16, 96),
                                  children: [
                                    _buildTabSelector(isDark, primaryText),
                                    const SizedBox(height: 16),
                                    if (_selectedTab != _MembersTab.requests)
                                      TextField(
                                        controller: _searchController,
                                        onChanged: (value) => setState(
                                            () => _searchQuery = value),
                                        style: TextStyle(color: primaryText),
                                        decoration: InputDecoration(
                                          hintText: _selectedTab ==
                                                  _MembersTab.friends
                                              ? 'Search your friends...'
                                              : 'Search by name, email, chapter, or school...',
                                          prefixIcon: const Icon(
                                              Icons.search_rounded),
                                          filled: true,
                                          fillColor: surfaceColor,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            borderSide:
                                                BorderSide(color: borderColor),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            borderSide:
                                                BorderSide(color: borderColor),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            borderSide: const BorderSide(
                                              color: _fblaBlue,
                                              width: 1.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_selectedTab != _MembersTab.requests)
                                      const SizedBox(height: 14),
                                    if (_selectedTab == _MembersTab.directory &&
                                        _myNlcEvents.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: FilterChip(
                                          label: const Text(
                                              'Same NLC event (Study Squad)'),
                                          selected: _sameNlcEventOnly,
                                          onSelected: (v) => setState(
                                              () => _sameNlcEventOnly = v),
                                          selectedColor:
                                              fblaGold.withValues(alpha: 0.25),
                                          checkmarkColor: fblaGold,
                                        ),
                                      ),
                                    ..._buildTabContent(
                                      isDark: isDark,
                                      primaryText: primaryText,
                                      secondaryText: secondaryText,
                                      surfaceColor: surfaceColor,
                                      borderColor: borderColor,
                                    ),
                                  ],
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInPrompt(Color primaryText, Color secondaryText) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.login_rounded,
                size: 48, color: secondaryText.withValues(alpha: 0.8)),
            const SizedBox(height: 12),
            Text(
              'Sign in to browse the member directory',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primaryText,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your FBLA account is required to view members and send friend requests.',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryText, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Color primaryText) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 10),
            Text(
              'Could not load members.\n$_loadError',
              textAlign: TextAlign.center,
              style: TextStyle(color: primaryText),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(bool isDark, Color primaryText) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101827) : fblaLightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark ? Colors.white.withValues(alpha: 0.08) : fblaLightBorder,
        ),
      ),
      child: Row(
        children: [
          _buildTabButton(
              'Directory', _MembersTab.directory, isDark, primaryText),
          _buildTabButton('Friends', _MembersTab.friends, isDark, primaryText),
          _buildTabButton(
              'Requests', _MembersTab.requests, isDark, primaryText),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    String label,
    _MembersTab tab,
    bool isDark,
    Color primaryText,
  ) {
    final isSelected = _selectedTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? _fblaBlue : fblaLightSelectedNav)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? (isDark ? Colors.white : _fblaBlue)
                  : (isDark ? Colors.white70 : fblaLightSecondaryText),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTabContent({
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    switch (_selectedTab) {
      case _MembersTab.directory:
        final filteredMembers = _applyFilters(_allMembers);
        return [
          Text(
            '${filteredMembers.length} member${filteredMembers.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (filteredMembers.isEmpty)
            _buildEmptyCard(
              isDark: isDark,
              message: _allMembers.isEmpty
                  ? 'No member accounts found yet.'
                  : 'No members match your search.',
            )
          else
            ...filteredMembers.map(
              (member) => _buildMemberCard(
                member,
                isDark: isDark,
                primaryText: primaryText,
                secondaryText: secondaryText,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                showAddButton: true,
              ),
            ),
        ];
      case _MembersTab.friends:
        final filteredFriends = _applyFilters(_friends);
        return [
          Text(
            '${filteredFriends.length} friend${filteredFriends.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (filteredFriends.isEmpty)
            _buildEmptyCard(
              isDark: isDark,
              message: _friends.isEmpty
                  ? 'You do not have any friends yet. Send requests from the Directory tab.'
                  : 'No friends match your search.',
            )
          else
            ...filteredFriends.map(
              (member) => _buildMemberCard(
                member,
                isDark: isDark,
                primaryText: primaryText,
                secondaryText: secondaryText,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                showAddButton: false,
              ),
            ),
        ];
      case _MembersTab.requests:
        if (_incomingRequests.isEmpty) {
          return [
            _buildEmptyCard(
              isDark: isDark,
              message: 'No friend requests yet.',
            ),
          ];
        }

        return [
          Text(
            'Incoming Requests',
            style: TextStyle(
              color: primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ..._incomingRequests.map(
            (request) => _buildIncomingRequestCard(
              request,
              isDark: isDark,
              primaryText: primaryText,
              secondaryText: secondaryText,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
            ),
          ),
        ];
    }
  }

  Widget _buildEmptyCard({required bool isDark, required String message}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101827) : fblaLightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isDark ? Colors.white.withValues(alpha: 0.08) : fblaLightBorder,
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDark ? Colors.white70 : fblaLightSecondaryText,
        ),
      ),
    );
  }

  Widget _buildMemberCard(
    Map<String, dynamic> member, {
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required Color surfaceColor,
    required Color borderColor,
    required bool showAddButton,
  }) {
    final memberId = (member['id'] ?? '').toString();
    final name = _displayName(member);
    final email = (member['email'] ?? '').toString().trim();
    final chapter = (member['chapter'] ?? '').toString().trim();
    final school = (member['school'] ?? '').toString().trim();
    final officerPosition = (member['officerPosition'] ?? '').toString().trim();
    final photoUrl = (member['photoUrl'] ?? '').toString().trim();
    final relation = _relationStatuses[memberId];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ListTile(
        onTap: () => _showMemberDetails(member),
        leading: CircleAvatar(
          backgroundColor: _fblaBlue,
          backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
          child: photoUrl.isEmpty
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          name,
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          [
            if (school.isNotEmpty) school,
            if (chapter.isNotEmpty) chapter,
            if (officerPosition.isNotEmpty) officerPosition,
            if (email.isNotEmpty) email,
          ].join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: secondaryText),
        ),
        trailing: showAddButton
            ? _buildAddFriendButton(member, relation, isDark)
            : _buildRemoveFriendAction(member),
      ),
    );
  }

  Widget _buildRemoveFriendAction(Map<String, dynamic> member) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: fblaGold),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Remove friend',
          onPressed: () => _confirmRemoveFriend(member),
          icon: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Color(0xFFEF5350),
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildAddFriendButton(
    Map<String, dynamic> member,
    String? relation,
    bool isDark,
  ) {
    if (relation == 'self') return null;

    if (relation == 'friends') {
      return _buildRemoveFriendAction(member);
    }

    if (relation == 'incoming') {
      return Icon(Icons.inbox_rounded, color: fblaGold);
    }

    return IconButton(
      tooltip: 'Send friend request',
      onPressed: () => _sendFriendRequest(member),
      icon: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: fblaGold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fblaGold.withValues(alpha: 0.35)),
        ),
        child: const Icon(Icons.person_add_rounded, color: fblaGold),
      ),
    );
  }

  Widget _buildIncomingRequestCard(
    Map<String, dynamic> request, {
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    final name = (request['fromUserName'] ?? 'Member').toString();
    final photoUrl = (request['fromUserPhotoUrl'] ?? request['photoUrl'] ?? '')
        .toString()
        .trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          MemberAvatar(
            name: name,
            photoUrl: photoUrl.isEmpty ? null : photoUrl,
            radius: 22,
            backgroundColor: _fblaBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incoming request',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Accept',
            onPressed: () => _acceptRequest(request),
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? fblaGold.withValues(alpha: 0.16)
                    : fblaGold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: fblaGold.withValues(alpha: isDark ? 0.55 : 0.4),
                ),
              ),
              child: const Icon(Icons.check_rounded, color: fblaGold, size: 22),
            ),
          ),
          IconButton(
            tooltip: 'Decline',
            onPressed: () => _declineRequest(request),
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFFEF5350).withValues(alpha: 0.16)
                    : fblaLightDestructive.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFEF5350).withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Color(0xFFEF5350), size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
