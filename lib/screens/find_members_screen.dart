import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/firebase_service.dart';

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
  List<Map<String, dynamic>> _outgoingRequests = const [];
  Map<String, String> _relationStatuses = const {};
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final currentUserId = _currentUserId ?? '';
      final members = await FirebaseService.getUsers();
      members.sort(_sortMembers);

      final friends = currentUserId.isEmpty
          ? const <Map<String, dynamic>>[]
          : await FirebaseService.getFriendsForUser(currentUserId);
      final incoming = currentUserId.isEmpty
          ? const <Map<String, dynamic>>[]
          : await FirebaseService.getIncomingFriendRequests(currentUserId);
      final outgoing = currentUserId.isEmpty
          ? const <Map<String, dynamic>>[]
          : await FirebaseService.getOutgoingFriendRequests(currentUserId);

      final memberIds = members
          .map((member) => (member['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      final statuses = currentUserId.isEmpty
          ? const <String, String>{}
          : await FirebaseService.getFriendRelationStatuses(
              currentUserId,
              memberIds,
            );

      if (!mounted) return;
      setState(() {
        _allMembers = members;
        _friends = friends;
        _incomingRequests = incoming;
        _outgoingRequests = outgoing;
        _relationStatuses = statuses;
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

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> members) {
    return members.where((member) {
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
    final name =
        (member['name'] ?? member['displayName'] ?? '').toString().trim();
    return name.isEmpty ? 'Unnamed Member' : name;
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
      _showSnack('Friend request sent to ${_displayName(member)}.');
      await _loadData();
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    try {
      await FirebaseService.acceptFriendRequest(
        (request['id'] ?? '').toString(),
      );
      _showSnack('Friend request accepted.');
      await _loadData();
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _declineRequest(Map<String, dynamic> request) async {
    try {
      await FirebaseService.declineFriendRequest(
        (request['id'] ?? '').toString(),
      );
      _showSnack('Friend request declined.');
      await _loadData();
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: isDark ? const Color(0xFF101827) : fblaLightSurface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _fblaBlue,
                      radius: 24,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (officerPosition.isNotEmpty)
                            Text(
                              officerPosition,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : fblaLightSecondaryText,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildDetailRow(Icons.email_outlined, 'Email', email, isDark),
                _buildDetailRow(
                    Icons.school_outlined, 'School', school, isDark),
                _buildDetailRow(
                    Icons.groups_outlined, 'Chapter', chapter, isDark),
                if (biography.isNotEmpty)
                  _buildDetailRow(Icons.info_outline, 'Bio', biography, isDark),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: email.isEmpty
                        ? null
                        : () {
                            Navigator.pop(context);
                            _emailMember(email);
                          },
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Email Member'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

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
      appBar: AppBar(
        title: const Text('Member Directory'),
        backgroundColor: _fblaBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? appBackgroundGradient : null,
          color: isDark ? null : fblaLightBackground,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _buildErrorState(primaryText)
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Connect with FBLA members',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Browse members, manage friend requests, and view your friends.',
                          style: TextStyle(color: secondaryText, height: 1.35),
                        ),
                        const SizedBox(height: 16),
                        _buildTabSelector(isDark, primaryText),
                        const SizedBox(height: 16),
                        if (_selectedTab != _MembersTab.requests)
                          TextField(
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                            style: TextStyle(color: primaryText),
                            decoration: InputDecoration(
                              hintText: _selectedTab == _MembersTab.friends
                                  ? 'Search your friends...'
                                  : 'Search members by name, email, chapter, or school...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: surfaceColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: _fblaBlue,
                                  width: 1.4,
                                ),
                              ),
                            ),
                          ),
                        if (_selectedTab != _MembersTab.requests)
                          const SizedBox(height: 14),
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
        if (_incomingRequests.isEmpty && _outgoingRequests.isEmpty) {
          return [
            _buildEmptyCard(
              isDark: isDark,
              message: 'No friend requests yet.',
            ),
          ];
        }

        return [
          if (_incomingRequests.isNotEmpty) ...[
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
            const SizedBox(height: 18),
          ],
          Text(
            'Outgoing Requests',
            style: TextStyle(
              color: primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (_outgoingRequests.isEmpty)
            _buildEmptyCard(
              isDark: isDark,
              message: 'No outgoing friend requests right now.',
            )
          else
            ..._outgoingRequests.map(
              (request) => _buildOutgoingRequestCard(
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
            : Icon(Icons.check_circle, color: const Color(0xFF66BB6A)),
      ),
    );
  }

  Widget? _buildAddFriendButton(
    Map<String, dynamic> member,
    String? relation,
    bool isDark,
  ) {
    if (relation == 'self') return null;

    if (relation == 'friends') {
      return Icon(Icons.check_circle, color: const Color(0xFF66BB6A));
    }

    if (relation == 'outgoing') {
      return Icon(Icons.schedule_rounded,
          color: isDark ? Colors.white54 : fblaLightDisabledText);
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
          color: const Color(0xFF66BB6A).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.add_rounded, color: Color(0xFF66BB6A)),
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
          CircleAvatar(
            backgroundColor: _fblaBlue,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
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
                color: fblaLightSuccessBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.check_rounded, color: fblaLightSuccessText),
            ),
          ),
          IconButton(
            tooltip: 'Decline',
            onPressed: () => _declineRequest(request),
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: fblaLightDestructive.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.close_rounded, color: fblaLightDestructive),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingRequestCard(
    Map<String, dynamic> request, {
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    final name = (request['toUserName'] ?? 'Member').toString();

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
          CircleAvatar(
            backgroundColor: _fblaBlue,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outgoing request',
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
          Icon(Icons.schedule_rounded,
              color: isDark ? Colors.white54 : fblaLightDisabledText),
        ],
      ),
    );
  }
}
