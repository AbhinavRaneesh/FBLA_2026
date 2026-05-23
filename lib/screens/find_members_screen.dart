import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class FindMembersScreen extends StatefulWidget {
  const FindMembersScreen({super.key});

  @override
  State<FindMembersScreen> createState() => _FindMembersScreenState();
}

class _FindMembersScreenState extends State<FindMembersScreen> {
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
      final leftName = (left['name'] ?? '').toString().trim().toLowerCase();
      final rightName = (right['name'] ?? '').toString().trim().toLowerCase();

      if (leftName.isEmpty && rightName.isEmpty) {
        final leftEmail =
            (left['email'] ?? '').toString().trim().toLowerCase();
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
      final name = (member['name'] ?? '').toString().toLowerCase();
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

  @override
  Widget build(BuildContext context) {
    const fblaBlue = Color(0xFF1D4E89);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Members'),
        backgroundColor: fblaBlue,
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
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search members by name, email, chapter, or school...',
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text('No members match your filters.'),
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
    final name = (member['name'] ?? '').toString().trim().isEmpty
        ? 'Unnamed Member'
        : member['name'].toString().trim();
    final email = (member['email'] ?? '').toString().trim();
    final chapter = (member['chapter'] ?? '').toString().trim();
    final school = (member['school'] ?? '').toString().trim();
    final officerPosition = (member['officerPosition'] ?? '').toString().trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
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
      ),
    );
  }
}
