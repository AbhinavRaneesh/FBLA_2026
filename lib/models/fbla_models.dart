import 'package:cloud_firestore/cloud_firestore.dart';

class FBLAUser {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String? chapter;
  final String? school;
  final String? officerPosition;
  final String? biography;
  final List<String> achievements;
  final List<String> badges;
  final DateTime createdAt;
  final DateTime updatedAt;

  FBLAUser({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.chapter,
    this.school,
    this.officerPosition,
    this.biography,
    this.achievements = const [],
    this.badges = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory FBLAUser.fromFirestore(Map<String, dynamic> data) {
    return FBLAUser(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      chapter: data['chapter'],
      school: data['school'],
      officerPosition: data['officerPosition'],
      biography: data['biography'],
      achievements: List<String>.from(data['achievements'] ?? []),
      badges: List<String>.from(data['badges'] ?? []),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'chapter': chapter,
      'school': school,
      'officerPosition': officerPosition,
      'biography': biography,
      'achievements': achievements,
      'badges': badges,
      // Temporarily disabled Timestamp
      // 'createdAt': Timestamp.fromDate(createdAt),
      // 'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class Chapter {
  final String id;
  final String name;
  final String school;
  final String advisorName;
  final String advisorEmail;
  final String state;
  final List<String> members;
  final Map<String, String> officers;
  final DateTime createdAt;
  final DateTime updatedAt;

  Chapter({
    required this.id,
    required this.name,
    required this.school,
    required this.advisorName,
    required this.advisorEmail,
    required this.state,
    this.members = const [],
    this.officers = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory Chapter.fromFirestore(Map<String, dynamic> data) {
    return Chapter(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      school: data['school'] ?? '',
      advisorName: data['advisorName'] ?? '',
      advisorEmail: data['advisorEmail'] ?? '',
      state: data['state'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      officers: Map<String, String>.from(data['officers'] ?? {}),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'school': school,
      'advisorName': advisorName,
      'advisorEmail': advisorEmail,
      'state': state,
      'members': members,
      'officers': officers,
      // Temporarily disabled Timestamp
      // 'createdAt': Timestamp.fromDate(createdAt),
      // 'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class FBLAEvent {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime startTime;
  final DateTime? endTime;
  final String type; // 'meeting', 'competition', 'social', 'workshop'
  final List<String> attendees;
  final Map<String, String> rsvps; // userId -> 'yes'|'no'|'maybe'
  final DateTime createdAt;
  final DateTime updatedAt;

  FBLAEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.startTime,
    this.endTime,
    required this.type,
    this.attendees = const [],
    this.rsvps = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  // Temporarily disabled Firestore conversion methods
  // factory FBLAEvent.fromFirestore(DocumentSnapshot doc) {
  //   Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  //   return FBLAEvent(
  //     id: doc.id,
  //     title: data['title'] ?? '',
  //     description: data['description'] ?? '',
  //     location: data['location'] ?? '',
  //     startTime: (data['startTime'] as Timestamp).toDate(),
  //     endTime: data['endTime'] != null ? (data['endTime'] as Timestamp).toDate() : null,
  //     type: data['type'] ?? 'meeting',
  //     attendees: List<String>.from(data['attendees'] ?? []),
  //     rsvps: Map<String, String>.from(data['rsvps'] ?? {}),
  //     createdAt: (data['createdAt'] as Timestamp).toDate(),
  //     updatedAt: (data['updatedAt'] as Timestamp).toDate(),
  //   );
  // }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'location': location,
      // Temporarily disabled Timestamp
      // 'startTime': Timestamp.fromDate(startTime),
      // 'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'type': type,
      'attendees': attendees,
      'rsvps': rsvps,
      // 'createdAt': Timestamp.fromDate(createdAt),
      // 'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String content;
  final List<String> imageUrls;
  final String? videoUrl;
  final String? linkUrl;
  final List<String> likes; // userIds
  final int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    this.imageUrls = const [],
    this.videoUrl,
    this.linkUrl,
    this.likes = const [],
    this.commentCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // Temporarily disabled Firestore conversion methods
  // factory Post.fromFirestore(DocumentSnapshot doc) {
  //   Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  //   return Post(
  //     id: doc.id,
  //     authorId: data['authorId'] ?? '',
  //     authorName: data['authorName'] ?? '',
  //     content: data['content'] ?? '',
  //     imageUrls: List<String>.from(data['imageUrls'] ?? []),
  //     videoUrl: data['videoUrl'],
  //     linkUrl: data['linkUrl'],
  //     likes: List<String>.from(data['likes'] ?? []),
  //     commentCount: data['commentCount'] ?? 0,
  //     createdAt: (data['createdAt'] as Timestamp).toDate(),
  //     updatedAt: (data['updatedAt'] as Timestamp).toDate(),
  //   );
  // }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'linkUrl': linkUrl,
      'likes': likes,
      'commentCount': commentCount,
      // Temporarily disabled Timestamp
      // 'createdAt': Timestamp.fromDate(createdAt),
      // 'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class Resource {
  final String id;
  final String title;
  final String description;
  final String category; // 'guidelines', 'forms', 'study-materials'
  final String fileUrl;
  final String fileType; // 'pdf', 'doc', 'xlsx', etc.
  final int downloadCount;
  final DateTime uploadedAt;
  final DateTime updatedAt;

  Resource({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.fileUrl,
    required this.fileType,
    this.downloadCount = 0,
    required this.uploadedAt,
    required this.updatedAt,
  });

  // Temporarily disabled Firestore conversion methods
  // factory Resource.fromFirestore(DocumentSnapshot doc) {
  //   Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  //   return Resource(
  //     id: doc.id,
  //     title: data['title'] ?? '',
  //     description: data['description'] ?? '',
  //     category: data['category'] ?? '',
  //     fileUrl: data['fileUrl'] ?? '',
  //     fileType: data['fileType'] ?? '',
  //     downloadCount: data['downloadCount'] ?? 0,
  //     uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
  //     updatedAt: (data['updatedAt'] as Timestamp).toDate(),
  //   );
  // }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'downloadCount': downloadCount,
      // Temporarily disabled Timestamp
      // 'uploadedAt': Timestamp.fromDate(uploadedAt),
      // 'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
