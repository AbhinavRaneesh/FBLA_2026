import 'package:flutter/material.dart';

import '../main.dart';

/// Bottom sheet for selecting one or more friends.
class FriendPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> friends;
  final String title;
  final String confirmLabel;
  final bool allowMultiple;

  const FriendPickerSheet({
    super.key,
    required this.friends,
    this.title = 'Select Friends',
    this.confirmLabel = 'Send',
    this.allowMultiple = true,
  });

  static Future<List<Map<String, dynamic>>?> show(
    BuildContext context, {
    required List<Map<String, dynamic>> friends,
    String title = 'Select Friends',
    String confirmLabel = 'Send',
    bool allowMultiple = true,
  }) {
    return showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FriendPickerSheet(
        friends: friends,
        title: title,
        confirmLabel: confirmLabel,
        allowMultiple: allowMultiple,
      ),
    );
  }

  @override
  State<FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends State<FriendPickerSheet> {
  final Set<String> _selectedIds = {};

  String _name(Map<String, dynamic> friend) {
    final name = (friend['name'] ?? friend['displayName'] ?? '').toString().trim();
    return name.isEmpty ? 'Member' : name;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F1C31) : fblaLightSurface;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: isDark ? Colors.white12 : fblaLightBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : fblaLightBorder,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: isDark ? Colors.white : fblaLightPrimaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : fblaLightSecondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.friends.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Add friends from the Member Directory first.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : fblaLightSecondaryText,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                itemCount: widget.friends.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final friend = widget.friends[index];
                  final id = (friend['id'] ?? '').toString();
                  final selected = _selectedIds.contains(id);
                  return Material(
                    color: selected
                        ? fblaGold.withValues(alpha: isDark ? 0.12 : 0.18)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : fblaLightBackground),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          if (widget.allowMultiple) {
                            if (selected) {
                              _selectedIds.remove(id);
                            } else {
                              _selectedIds.add(id);
                            }
                          } else {
                            _selectedIds
                              ..clear()
                              ..add(id);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: fblaBlue,
                              child: Text(
                                _name(friend).isNotEmpty
                                    ? _name(friend)[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _name(friend),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : fblaLightPrimaryText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: selected ? fblaGold : Colors.white38,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () {
                          final picked = widget.friends
                              .where((f) =>
                                  _selectedIds.contains((f['id'] ?? '').toString()))
                              .toList(growable: false);
                          Navigator.pop(context, picked);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: fblaBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    widget.confirmLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
