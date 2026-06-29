import 'firebase_service.dart';
import 'nlc_prep_service.dart';

/// Preloaded member directory data so Find Members opens instantly.
class MemberDirectorySnapshot {
  final List<Map<String, dynamic>> allMembers;
  final List<Map<String, dynamic>> friends;
  final List<Map<String, dynamic>> incomingRequests;
  final List<Map<String, dynamic>> outgoingRequests;
  final Map<String, String> relationStatuses;
  final List<String> myNlcEvents;

  const MemberDirectorySnapshot({
    required this.allMembers,
    required this.friends,
    required this.incomingRequests,
    required this.outgoingRequests,
    required this.relationStatuses,
    required this.myNlcEvents,
  });
}

class MemberDirectoryCache {
  MemberDirectoryCache._();

  static MemberDirectorySnapshot? _cached;
  static String? _cachedUserId;
  static Future<MemberDirectorySnapshot?>? _inFlight;
  static String? _inFlightUserId;

  static bool hasSnapshot(String? userId) =>
      userId != null && userId == _cachedUserId && _cached != null;

  static MemberDirectorySnapshot? snapshotFor(String? userId) {
    if (!hasSnapshot(userId)) return null;
    return _cached;
  }

  static void invalidate() {
    _cached = null;
    _cachedUserId = null;
  }

  /// Loads directory data in the background. Reuses in-flight work when possible.
  static Future<MemberDirectorySnapshot?> preload(
    String userId, {
    bool force = false,
  }) async {
    if (userId.isEmpty) {
      invalidate();
      return null;
    }

    if (!force && hasSnapshot(userId)) {
      return _cached;
    }

    if (_inFlight != null && _inFlightUserId == userId) {
      return _inFlight;
    }

    _inFlightUserId = userId;
    final future = _fetch(userId);
    _inFlight = future;

    try {
      final snapshot = await future;
      _cached = snapshot;
      _cachedUserId = userId;
      return snapshot;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
        _inFlightUserId = null;
      }
    }
  }

  static Future<MemberDirectorySnapshot?> _fetch(String currentUserId) async {
    final members = await FirebaseService.getUsers();
    members.sort(_sortMembers);

    final myEvents = await NlcPrepService.loadNlcEvents(currentUserId);

    final friends = await FirebaseService.getFriendsForUser(currentUserId);
    final incoming =
        await FirebaseService.getIncomingFriendRequests(currentUserId);
    final outgoing =
        await FirebaseService.getOutgoingFriendRequests(currentUserId);

    final memberById = {
      for (final member in members) (member['id'] ?? '').toString(): member,
    };
    final enrichedIncoming = incoming.map((request) {
      final fromId = (request['fromUserId'] ?? '').toString();
      final fromMember = memberById[fromId];
      if (fromMember == null) return request;
      return {
        ...request,
        'fromUserPhotoUrl': (fromMember['photoUrl'] ?? '').toString(),
      };
    }).toList(growable: false);

    final memberIds = members
        .map((member) => (member['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final statuses = await FirebaseService.getFriendRelationStatuses(
      currentUserId,
      memberIds,
    );

    return MemberDirectorySnapshot(
      allMembers: members,
      friends: friends,
      incomingRequests: enrichedIncoming,
      outgoingRequests: outgoing,
      relationStatuses: statuses,
      myNlcEvents: myEvents,
    );
  }

  static int _sortMembers(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    String displayName(Map<String, dynamic> member) {
      final name = (member['name'] ??
              member['displayName'] ??
              member['fullName'] ??
              '')
          .toString()
          .trim();
      return name.isEmpty ? 'Unnamed Member' : name;
    }

    final leftName = displayName(left).toLowerCase();
    final rightName = displayName(right).toLowerCase();

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
}
