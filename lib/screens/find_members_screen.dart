import 'package:flutter/material.dart';

import '../services/mongodb_service.dart';

class FindMembersScreen extends StatefulWidget {
  const FindMembersScreen({super.key});

  @override
  State<FindMembersScreen> createState() => _FindMembersScreenState();
}

class _FindMembersScreenState extends State<FindMembersScreen> {
  static const List<String> _roleFilters = [
    'All',
    'Students',
    'Advisors',
    'Officers',
    'Chapter Members',
    'Other',
  ];

  final TextEditingController _searchController = TextEditingController();
  late Future<List<Map<String, String>>> _membersFuture;
  String _searchQuery = '';
  String _selectedRoleFilter = 'All';

  @override
  void initState() {
    super.initState();
    _membersFuture = MongoDbService.listUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshMembers() async {
    setState(() {
      _membersFuture = MongoDbService.listUsers();
    });
    await _membersFuture;
  }

  bool _matchesRoleFilter(String role) {
    if (_selectedRoleFilter == 'All') return true;

    final value = role.trim().toLowerCase();
    switch (_selectedRoleFilter) {
      case 'Students':
        return value.contains('student');
      case 'Advisors':
        return value.contains('advisor') || value.contains('adviser');
      case 'Officers':
        return value.contains('officer');
      case 'Chapter Members':
        return value.contains('chapter member');
      case 'Other':
        return value.isEmpty || value.contains('other');
      default:
        return true;
    }
  }

  List<Map<String, String>> _applyFilters(List<Map<String, String>> members) {
    return members.where((member) {
      final name = (member['name'] ?? '').toLowerCase();
      final username = (member['username'] ?? '').toLowerCase();
      final email = (member['email'] ?? '').toLowerCase();
      final role = (member['role'] ?? '').toLowerCase();
      final query = _searchQuery.trim().toLowerCase();

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          username.contains(query) ||
          email.contains(query) ||
          role.contains(query);

      return matchesSearch && _matchesRoleFilter(member['role'] ?? '');
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
      body: FutureBuilder<List<Map<String, String>>>(
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

          final allMembers = snapshot.data ?? const <Map<String, String>>[];
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
                    hintText: 'Search members, usernames, roles...',
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _roleFilters
                      .map(
                        (filter) => ChoiceChip(
                          label: Text(filter),
                          selected: _selectedRoleFilter == filter,
                          onSelected: (_) =>
                              setState(() => _selectedRoleFilter = filter),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 14),
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

  Widget _buildMemberCard(Map<String, String> member) {
    final name = (member['name'] ?? '').trim().isEmpty
        ? 'Unnamed Member'
        : member['name']!.trim();
    final username = (member['username'] ?? '').trim();
    final role = (member['role'] ?? '').trim();
    final grade = (member['gradeLevel'] ?? '').trim();
    final email = (member['email'] ?? '').trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(name[0].toUpperCase()),
        ),
        title: Text(name),
        subtitle: Text(
          [
            if (username.isNotEmpty) '@$username',
            if (role.isNotEmpty) role,
            if (grade.isNotEmpty) grade,
            if (email.isNotEmpty) email,
          ].join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
