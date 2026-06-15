import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, IconData;

// ---------------------------------------------------------------------------
// Feed item taxonomy — each card type in the unified social feed.
// ---------------------------------------------------------------------------

enum SocialPlatform {
  blueWave,
  instagram,
  youtube,
  forum,
  news,
}

enum BlueWavePostKind {
  standard,
  photo,
  video,
  reel,
  announcement,
  memberHighlight,
}

enum ForumCategory { events, competitions, tips, general }

enum ContentInterest {
  competitions,
  leadership,
  business,
  tech,
  community,
  news,
}

enum ContentTypePreference {
  shortVideo,
  photos,
  textPosts,
  forums,
  news,
}

enum PlatformPreference { instagram, youtube, tiktok, blueWave }

enum EventContentFrequency { rarely, sometimes, often }

// ---------------------------------------------------------------------------
// ML data model — tracks preferences and behavior for ranking.
// ---------------------------------------------------------------------------

@immutable
class UserPreferences {
  final Set<ContentInterest> interests;
  final Set<ContentTypePreference> contentTypes;
  final Set<PlatformPreference> platforms;
  final EventContentFrequency eventFrequency;
  final bool onboardingComplete;

  const UserPreferences({
    this.interests = const {ContentInterest.competitions, ContentInterest.community},
    this.contentTypes = const {ContentTypePreference.textPosts},
    this.platforms = const {PlatformPreference.blueWave},
    this.eventFrequency = EventContentFrequency.sometimes,
    this.onboardingComplete = false,
  });

  UserPreferences copyWith({
    Set<ContentInterest>? interests,
    Set<ContentTypePreference>? contentTypes,
    Set<PlatformPreference>? platforms,
    EventContentFrequency? eventFrequency,
    bool? onboardingComplete,
  }) {
    return UserPreferences(
      interests: interests ?? this.interests,
      contentTypes: contentTypes ?? this.contentTypes,
      platforms: platforms ?? this.platforms,
      eventFrequency: eventFrequency ?? this.eventFrequency,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  Map<String, dynamic> toJson() => {
        'interests': interests.map((e) => e.name).toList(),
        'contentTypes': contentTypes.map((e) => e.name).toList(),
        'platforms': platforms.map((e) => e.name).toList(),
        'eventFrequency': eventFrequency.name,
        'onboardingComplete': onboardingComplete,
      };

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      interests: _enumSetFromJson(
        json['interests'],
        ContentInterest.values,
      ),
      contentTypes: _enumSetFromJson(
        json['contentTypes'],
        ContentTypePreference.values,
      ),
      platforms: _enumSetFromJson(
        json['platforms'],
        PlatformPreference.values,
      ),
      eventFrequency: EventContentFrequency.values.firstWhere(
        (e) => e.name == json['eventFrequency'],
        orElse: () => EventContentFrequency.sometimes,
      ),
      onboardingComplete: json['onboardingComplete'] == true,
    );
  }
}

Set<T> _enumSetFromJson<T>(dynamic raw, List<T> values) {
  if (raw is! List) return {};
  return raw
      .map((e) => values.cast<T?>().firstWhere(
            (v) => (v as dynamic).name == e,
            orElse: () => null,
          ))
      .whereType<T>()
      .toSet();
}

@immutable
class UserInteraction {
  final String contentId;
  final SocialPlatform platform;
  final DateTime timestamp;
  final bool viewed;
  final bool reacted;
  final bool commented;
  final bool shared;
  final int secondsViewed;

  const UserInteraction({
    required this.contentId,
    required this.platform,
    required this.timestamp,
    this.viewed = false,
    this.reacted = false,
    this.commented = false,
    this.shared = false,
    this.secondsViewed = 0,
  });

  Map<String, dynamic> toJson() => {
        'contentId': contentId,
        'platform': platform.name,
        'timestamp': timestamp.toIso8601String(),
        'viewed': viewed,
        'reacted': reacted,
        'commented': commented,
        'shared': shared,
        'secondsViewed': secondsViewed,
      };

  factory UserInteraction.fromJson(Map<String, dynamic> json) {
    return UserInteraction(
      contentId: json['contentId'] as String,
      platform: SocialPlatform.values.firstWhere(
        (e) => e.name == json['platform'],
        orElse: () => SocialPlatform.blueWave,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      viewed: json['viewed'] == true,
      reacted: json['reacted'] == true,
      commented: json['commented'] == true,
      shared: json['shared'] == true,
      secondsViewed: (json['secondsViewed'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class ContentMetadata {
  final String id;
  final SocialPlatform platform;
  final String contentTypeLabel;
  final List<String> tags;
  final int likes;
  final int comments;
  final int views;
  final DateTime publishedAt;
  final String? authorId;

  const ContentMetadata({
    required this.id,
    required this.platform,
    required this.contentTypeLabel,
    this.tags = const [],
    this.likes = 0,
    this.comments = 0,
    this.views = 0,
    required this.publishedAt,
    this.authorId,
  });
}

// ---------------------------------------------------------------------------
// Unified feed envelope — one list, many card types.
// ---------------------------------------------------------------------------

enum FeedItemKind {
  blueWavePost,
  blueWaveReel,
  instagramPost,
  youtubeVideo,
  forumThread,
  newsItem,
  recommendedHeader,
  sectionHeader,
}

@immutable
class SocialAuthor {
  final String id;
  final String name;
  final String? photoUrl;
  final String role;
  final bool isOfficer;

  const SocialAuthor({
    required this.id,
    required this.name,
    this.photoUrl,
    this.role = 'Member',
    this.isOfficer = false,
  });
}

@immutable
class BlueWavePostData {
  final String id;
  final SocialAuthor author;
  final String text;
  final List<String> imageUrls;
  final String? videoUrl;
  final BlueWavePostKind kind;
  final DateTime createdAt;
  final int waveCount;
  final int commentCount;
  final List<String> tags;
  final bool isRecommended;

  const BlueWavePostData({
    required this.id,
    required this.author,
    required this.text,
    this.imageUrls = const [],
    this.videoUrl,
    this.kind = BlueWavePostKind.standard,
    required this.createdAt,
    this.waveCount = 0,
    this.commentCount = 0,
    this.tags = const [],
    this.isRecommended = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': author.id,
        'authorName': author.name,
        'authorRole': author.role,
        'authorPhotoUrl': author.photoUrl,
        'text': text,
        'imageUrls': imageUrls,
        'videoUrl': videoUrl,
        'kind': kind.name,
        'createdAt': createdAt.toIso8601String(),
        'waveCount': waveCount,
        'commentCount': commentCount,
        'tags': tags,
      };

  factory BlueWavePostData.fromJson(Map<String, dynamic> json) {
    return BlueWavePostData(
      id: json['id'] as String,
      author: SocialAuthor(
        id: json['authorId'] as String? ?? 'user',
        name: json['authorName'] as String? ?? 'Member',
        photoUrl: json['authorPhotoUrl'] as String?,
        role: json['authorRole'] as String? ?? 'Member',
      ),
      text: json['text'] as String? ?? '',
      imageUrls: (json['imageUrls'] as List?)?.cast<String>() ?? const [],
      videoUrl: json['videoUrl'] as String?,
      kind: BlueWavePostKind.values.firstWhere(
        (e) => e.name == json['kind'],
        orElse: () => BlueWavePostKind.standard,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      waveCount: (json['waveCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    );
  }
}

@immutable
class InstagramPostData {
  final String id;
  final String imageUrl;
  final String caption;
  final String permalink;
  final DateTime publishedAt;

  const InstagramPostData({
    required this.id,
    required this.imageUrl,
    required this.caption,
    required this.permalink,
    required this.publishedAt,
  });
}

@immutable
class YouTubeFeedData {
  final String id;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final String duration;
  final DateTime publishedAt;

  const YouTubeFeedData({
    required this.id,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    this.duration = '',
    required this.publishedAt,
  });
}

@immutable
class ForumThreadData {
  final String id;
  final String title;
  final ForumCategory category;
  final SocialAuthor author;
  final int replyCount;
  final DateTime createdAt;
  final String preview;

  const ForumThreadData({
    required this.id,
    required this.title,
    required this.category,
    required this.author,
    required this.replyCount,
    required this.createdAt,
    this.preview = '',
  });
}

@immutable
class NewsFeedData {
  final String id;
  final String title;
  final String summary;
  final String source;
  final DateTime date;

  const NewsFeedData({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.date,
  });
}

@immutable
class FeedItem {
  final String id;
  final FeedItemKind kind;
  final ContentMetadata metadata;
  final double rankingScore;
  final bool isNewForYou;
  final BlueWavePostData? blueWave;
  final InstagramPostData? instagram;
  final YouTubeFeedData? youtube;
  final ForumThreadData? forum;
  final NewsFeedData? news;
  final String? sectionTitle;

  const FeedItem({
    required this.id,
    required this.kind,
    required this.metadata,
    this.rankingScore = 0,
    this.isNewForYou = false,
    this.blueWave,
    this.instagram,
    this.youtube,
    this.forum,
    this.news,
    this.sectionTitle,
  });

  FeedItem copyWith({double? rankingScore, bool? isNewForYou}) {
    return FeedItem(
      id: id,
      kind: kind,
      metadata: metadata,
      rankingScore: rankingScore ?? this.rankingScore,
      isNewForYou: isNewForYou ?? this.isNewForYou,
      blueWave: blueWave,
      instagram: instagram,
      youtube: youtube,
      forum: forum,
      news: news,
      sectionTitle: sectionTitle,
    );
  }
}

@immutable
class SocialSearchResult {
  final String id;
  final String title;
  final String subtitle;
  final SocialPlatform platform;
  final FeedItemKind kind;
  final double score;
  final FeedItem? feedItem;

  const SocialSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.platform,
    required this.kind,
    required this.score,
    this.feedItem,
  });
}

@immutable
class SocialPlatformLink {
  final String name;
  final IconData icon;
  final Color color;
  final String url;
  final String description;
  final bool inApp;

  const SocialPlatformLink({
    required this.name,
    required this.icon,
    required this.color,
    required this.url,
    required this.description,
    this.inApp = false,
  });
}