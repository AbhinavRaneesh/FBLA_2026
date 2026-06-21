import 'dart:math';

import '../models/social_models.dart';

/// ML-style ranking, recommendations, and search for the unified social feed.
///
/// Scoring formula per item:
/// score = w_platform * platformScore
///       + w_type * typeScore
///       + w_interest * interestMatch
///       + w_recency * recencyScore
///       + w_popularity * popularityScore
///       + w_personal * personalInteractionScore
class SocialMlService {
  static const _wPlatform = 0.22;
  static const _wType = 0.18;
  static const _wInterest = 0.20;
  static const _wRecency = 0.15;
  static const _wPopularity = 0.12;
  static const _wPersonal = 0.13;

  /// Orders feed items by computed relevance score.
  List<FeedItem> rankFeedItems({
    required UserPreferences preferences,
    required List<UserInteraction> interactions,
    required List<FeedItem> items,
  }) {
    final scored = items.map((item) {
      final score = _computeScore(
        item: item,
        preferences: preferences,
        interactions: interactions,
      );
      final isNew = !_hasInteracted(interactions, item.id);
      return item.copyWith(
        rankingScore: score,
        isNewForYou: isNew && score > 0.55,
      );
    }).toList();

    scored.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));
    return _interleavePlatforms(scored);
  }

  /// Returns top recommended items for the "Recommended for you" strip.
  List<FeedItem> getRecommendedContent({
    required UserPreferences preferences,
    required List<UserInteraction> interactions,
    required List<FeedItem> allContent,
    int limit = 5,
  }) {
    final ranked = rankFeedItems(
      preferences: preferences,
      interactions: interactions,
      items: allContent,
    );
    return ranked
        .where((i) =>
            i.kind != FeedItemKind.sectionHeader &&
            i.kind != FeedItemKind.recommendedHeader)
        .take(limit)
        .toList();
  }

  /// Global search across all content types with preference-weighted ranking.
  List<SocialSearchResult> searchContent({
    required String query,
    required UserPreferences preferences,
    required List<UserInteraction> interactions,
    required List<FeedItem> items,
    List<SocialAuthor> members = const [],
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final results = <SocialSearchResult>[];

    for (final item in items) {
      if (item.kind == FeedItemKind.sectionHeader ||
          item.kind == FeedItemKind.recommendedHeader) {
        continue;
      }

      final searchable = _searchableText(item).toLowerCase();
      if (!searchable.contains(q)) continue;

      final relevance = _textRelevance(q, searchable);
      final prefBoost = _computeScore(
            item: item,
            preferences: preferences,
            interactions: interactions,
          ) *
          0.35;
      final score = relevance + prefBoost;

      results.add(SocialSearchResult(
        id: item.id,
        title: _titleForItem(item),
        subtitle: _subtitleForItem(item),
        platform: item.metadata.platform,
        kind: item.kind,
        score: score,
        feedItem: item,
      ));
    }

    for (final member in members) {
      if (!member.name.toLowerCase().contains(q) &&
          !member.role.toLowerCase().contains(q)) {
        continue;
      }
      results.add(SocialSearchResult(
        id: 'member_${member.id}',
        title: member.name,
        subtitle: member.role,
        platform: SocialPlatform.blueWave,
        kind: FeedItemKind.blueWavePost,
        score: 0.6,
      ));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  double _computeScore({
    required FeedItem item,
    required UserPreferences preferences,
    required List<UserInteraction> interactions,
  }) {
    final platformScore = _platformScore(item.metadata.platform, preferences);
    final typeScore = _typeScore(item, preferences);
    final interestMatch = _interestMatch(item, preferences);
    final recencyScore = _recencyScore(item.metadata.publishedAt);
    final popularityScore = _popularityScore(item.metadata);
    final personalScore = _personalScore(item, interactions);

    return _wPlatform * platformScore +
        _wType * typeScore +
        _wInterest * interestMatch +
        _wRecency * recencyScore +
        _wPopularity * popularityScore +
        _wPersonal * personalScore;
  }

  double _platformScore(SocialPlatform platform, UserPreferences prefs) {
    switch (platform) {
      case SocialPlatform.blueWave:
        return prefs.platforms.contains(PlatformPreference.blueWave) ? 1.0 : 0.5;
      case SocialPlatform.instagram:
        return prefs.platforms.contains(PlatformPreference.instagram)
            ? 1.0
            : 0.45;
      case SocialPlatform.youtube:
        return prefs.platforms.contains(PlatformPreference.youtube) ? 1.0 : 0.45;
      case SocialPlatform.forum:
        return prefs.contentTypes.contains(ContentTypePreference.forums)
            ? 0.95
            : 0.5;
      case SocialPlatform.news:
        return prefs.contentTypes.contains(ContentTypePreference.news)
            ? 0.95
            : 0.5;
    }
  }

  double _typeScore(FeedItem item, UserPreferences prefs) {
    switch (item.kind) {
      case FeedItemKind.blueWaveReel:
        return prefs.contentTypes.contains(ContentTypePreference.shortVideo)
            ? 1.0
            : 0.4;
      case FeedItemKind.instagramPost:
      case FeedItemKind.blueWavePost:
        if (item.blueWave?.imageUrls.isNotEmpty == true) {
          return prefs.contentTypes.contains(ContentTypePreference.photos)
              ? 1.0
              : 0.5;
        }
        return prefs.contentTypes.contains(ContentTypePreference.textPosts)
            ? 0.9
            : 0.5;
      case FeedItemKind.youtubeVideo:
        return prefs.contentTypes.contains(ContentTypePreference.shortVideo)
            ? 0.95
            : 0.55;
      case FeedItemKind.forumThread:
        return prefs.contentTypes.contains(ContentTypePreference.forums)
            ? 1.0
            : 0.45;
      case FeedItemKind.newsItem:
        return prefs.contentTypes.contains(ContentTypePreference.news)
            ? 1.0
            : 0.45;
      default:
        return 0.5;
    }
  }

  double _interestMatch(FeedItem item, UserPreferences prefs) {
    final tags = item.metadata.tags.map((t) => t.toLowerCase()).toList();
    if (tags.isEmpty) return 0.5;

    var matches = 0;
    for (final interest in prefs.interests) {
      final keyword = interest.name.toLowerCase();
      if (tags.any((t) => t.contains(keyword))) matches++;
    }

    if (prefs.eventFrequency == EventContentFrequency.often &&
        tags.any((t) => t.contains('event'))) {
      matches++;
    }

    return (matches / max(prefs.interests.length, 1)).clamp(0.0, 1.0);
  }

  double _recencyScore(DateTime publishedAt) {
    final hours = DateTime.now().difference(publishedAt).inHours;
    if (hours < 24) return 1.0;
    if (hours < 72) return 0.85;
    if (hours < 168) return 0.65;
    if (hours < 720) return 0.4;
    return 0.2;
  }

  double _popularityScore(ContentMetadata meta) {
    final raw = meta.likes * 2 + meta.comments * 3 + meta.views * 0.01;
    return (log(raw + 1) / log(100)).clamp(0.0, 1.0);
  }

  double _personalScore(FeedItem item, List<UserInteraction> interactions) {
    final related = interactions.where((i) {
      if (i.contentId == item.id) return true;
      if (item.metadata.authorId != null &&
          i.contentId.contains(item.metadata.authorId!)) {
        return true;
      }
      return false;
    });

    if (related.isEmpty) return 0.3;

    var score = 0.0;
    for (final i in related) {
      if (i.reacted) score += 0.35;
      if (i.commented) score += 0.25;
      if (i.shared) score += 0.2;
      if (i.viewed) score += 0.1;
      score += (i.secondsViewed / 60).clamp(0.0, 0.1);
    }
    return score.clamp(0.0, 1.0);
  }

  bool _hasInteracted(List<UserInteraction> interactions, String id) {
    return interactions.any((i) => i.contentId == id && i.viewed);
  }

  /// Light interleaving so the feed never clusters one platform.
  List<FeedItem> _interleavePlatforms(List<FeedItem> ranked) {
    final headers = ranked
        .where((i) =>
            i.kind == FeedItemKind.sectionHeader ||
            i.kind == FeedItemKind.recommendedHeader)
        .toList();
    final content = ranked
        .where((i) =>
            i.kind != FeedItemKind.sectionHeader &&
            i.kind != FeedItemKind.recommendedHeader)
        .toList();

    if (content.length <= 2) return [...headers, ...content];

    final buckets = <SocialPlatform, List<FeedItem>>{};
    for (final item in content) {
      buckets.putIfAbsent(item.metadata.platform, () => []).add(item);
    }

    final interleaved = <FeedItem>[];
    var added = true;
    while (added) {
      added = false;
      for (final platform in SocialPlatform.values) {
        final bucket = buckets[platform];
        if (bucket != null && bucket.isNotEmpty) {
          interleaved.add(bucket.removeAt(0));
          added = true;
        }
      }
    }

    return [...headers, ...interleaved];
  }

  double _textRelevance(String query, String text) {
    if (text == query) return 1.0;
    if (text.startsWith(query)) return 0.9;
    final words = query.split(RegExp(r'\s+'));
    var hits = 0;
    for (final w in words) {
      if (text.contains(w)) hits++;
    }
    return (hits / words.length).clamp(0.0, 1.0);
  }

  String _searchableText(FeedItem item) {
    return [
      _titleForItem(item),
      _subtitleForItem(item),
      ...item.metadata.tags,
      item.blueWave?.text,
      item.instagram?.caption,
      item.youtube?.title,
      item.forum?.title,
      item.forum?.preview,
      item.news?.summary,
    ].whereType<String>().join(' ');
  }

  String _titleForItem(FeedItem item) {
    switch (item.kind) {
      case FeedItemKind.blueWavePost:
      case FeedItemKind.blueWaveReel:
        return item.blueWave?.author.name ?? 'FBLA Social';
      case FeedItemKind.instagramPost:
        return 'Instagram';
      case FeedItemKind.youtubeVideo:
        return item.youtube?.title ?? 'YouTube';
      case FeedItemKind.forumThread:
        return item.forum?.title ?? 'Forum';
      case FeedItemKind.newsItem:
        return item.news?.title ?? 'News';
      default:
        return item.sectionTitle ?? '';
    }
  }

  String _subtitleForItem(FeedItem item) {
    switch (item.kind) {
      case FeedItemKind.blueWavePost:
      case FeedItemKind.blueWaveReel:
        return item.blueWave?.text ?? '';
      case FeedItemKind.instagramPost:
        return item.instagram?.caption ?? '';
      case FeedItemKind.youtubeVideo:
        return item.youtube?.channelName ?? '';
      case FeedItemKind.forumThread:
        return item.forum?.preview ?? '';
      case FeedItemKind.newsItem:
        return item.news?.summary ?? '';
      default:
        return '';
    }
  }
}
