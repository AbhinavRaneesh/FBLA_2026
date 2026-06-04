import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firebase_service.dart';

class FindMembersScreen extends StatefulWidget {
  const FindMembersScreen({super.key});

  @override
  State<FindMembersScreen> createState() => _FindMembersScreenState();
}

class _FindMembersScreenState extends State<FindMembersScreen> {
  static const Color _fblaBlue = Color(0xFF1D4E89);

  final TextEditingController _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _membersFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadMembers() async {
    final members = await FirebaseService.getUsers();
    members.sort((left, right) {
      final leftName = _displayName(left).toLowerCase();
      final rightName = _displayName(right).toLowerCase();

      if (leftName.isEmpty && rightName.isEmpty) {
        final leftEmail = (left['email'] ?? '').toString().trim().toLowerCase();
        final rightEmail =
            (right['email'] ?? '').toString().trim().toLowerCase();
        return leftEmail.compareTo(rightEmail);
      }

      if (leftName.isEmpty) return 1;
      if (rightName.isEmpty) return -1;

      final comparison = leftName.compareTo(rightName);
      if (comparison != 0) return comparison;

      final leftEmail = (left['email'] ?? '').toString().trim().toLowerCase();
      final rightEmail = (right['email'] ?? '').toString().trim().toLowerCase();
      return leftEmail.compareTo(rightEmail);
    });
    return members;
  }

  Future<void> _refreshMembers() async {
    setState(() {
      _membersFuture = _loadMembers();
    });
    await _membersFuture;
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

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          chapter.contains(query) ||
          school.contains(query) ||
          officerPosition.contains(query);

      return matchesSearch;
    }).toList(growable: false);
  }

  String _displayName(Map<String, dynamic> member) {
    final name =
        (member['name'] ?? member['displayName'] ?? '').toString().trim();
    return name.isEmpty ? 'Unnamed Member' : name;
  }

  Future<void> _emailMember(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('This member does not have an email listed.')),
      );
      return;
    }

    final uri = Uri(scheme: 'mailto', path: email);
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open email for $email.')),
      );
    }
  }

  void _showMemberDetails(Map<String, dynamic> member) {
    final name = _displayName(member);
    final email = (member['email'] ?? '').toString().trim();
    final chapter = (member['chapter'] ?? '').toString().trim();
    final school = (member['school'] ?? '').toString().trim();
    final officerPosition = (member['officerPosition'] ?? '').toString().trim();
    final biography = (member['biography'] ?? '').toString().trim();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
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
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildDetailRow(Icons.email_outlined, 'Email', email),
                _buildDetailRow(Icons.school_outlined, 'School', school),
                _buildDetailRow(Icons.groups_outlined, 'Chapter', chapter),
                if (biography.isNotEmpty)
                  _buildDetailRow(Icons.info_outline, 'Bio', biography),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Members'),
        backgroundColor: _fblaBlue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 44),
                    const SizedBox(height: 10),
                    Text(
                      'Could not load members.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refreshMembers,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final allMembers = snapshot.data ?? const <Map<String, dynamic>>[];
          final filteredMembers = _applyFilters(allMembers);

          return RefreshIndicator(
            onRefresh: _refreshMembers,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Member Directory',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Browse all created accounts from Firestore in alphabetical order.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText:
                        'Search for friends by name, email, chapter, or school...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${filteredMembers.length} member${filteredMembers.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (filteredMembers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text(
                        allMembers.isEmpty
                            ? 'No member accounts found yet.'
                            : 'No friends match your search.',
                      ),
                    ),
                  )
                else
                  ...filteredMembers.map(_buildMemberCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final name = _displayName(member);
    final email = (member['email'] ?? '').toString().trim();
    final chapter = (member['chapter'] ?? '').toString().trim();
    final school = (member['school'] ?? '').toString().trim();
    final officerPosition = (member['officerPosition'] ?? '').toString().trim();
    final photoUrl = (member['photoUrl'] ?? '').toString().trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
        title: Text(name),
        subtitle: Text(
          [
            if (school.isNotEmpty) school,
            if (chapter.isNotEmpty) chapter,
            if (officerPosition.isNotEmpty) officerPosition,
            if (email.isNotEmpty) email,
          ].join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'details') {
              _showMemberDetails(member);
            } else if (value == 'email') {
              _emailMember(email);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'details',
              child: ListTile(
                leading: Icon(Icons.person_outline),
                title: Text('View details'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'email',
              enabled: email.isNotEmpty,
              child: const ListTile(
                leading: Icon(Icons.mail_outline),
                title: Text('Email member'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
