import 'package:flutter/material.dart' show Color, Icons;

import '../../constants/app_assets.dart';
import '../../main.dart' show ChatThread, NewsItem;
import '../../models/video_model.dart';
import '../../services/youtube_service.dart';
import '../models/social_models.dart';

/// Aggregates content from BlueWave, Instagram, YouTube, forums, and news.
class SocialDataService {
  final YouTubeService _youtubeService;

  SocialDataService({YouTubeService? youtubeService})
      : _youtubeService = youtubeService ?? YouTubeService();

  /// Stub — replace with Instagram Graph API / backend proxy in production.
  Future<List<InstagramPostData>> fetchInstagramPosts() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return [
      InstagramPostData(
        id: 'ig_1',
        imageUrl: AppAssets.nlcPictures[0],
        caption:
            'NLC 2026 is almost here! San Antonio is ready for FBLA leaders. #FBLA #NLC2026',
        permalink: 'https://www.instagram.com/fbla_national/',
        publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      InstagramPostData(
        id: 'ig_2',
        imageUrl: AppAssets.nlcPictures[1],
        caption:
            'Competition season prep tips from national officers. Drop a wave if you are ready!',
        permalink: 'https://www.instagram.com/fbla_national/',
        publishedAt: DateTime.now().subtract(const Duration(hours: 26)),
      ),
    ];
  }

  Future<List<YouTubeFeedData>> fetchYouTubeVideos({int maxResults = 8}) async {
    try {
      final videos = await _youtubeService.fetchVideos(maxResults: maxResults);
      return videos.map(_videoToFeedData).toList();
    } catch (_) {
      return _fallbackYouTube();
    }
  }

  List<YouTubeFeedData> _fallbackYouTube() {
    return [
      YouTubeFeedData(
        id: 'yt_fallback_1',
        title: 'FBLA National Leadership Conference Highlights',
        channelName: 'FBLA National',
        thumbnailUrl: AppAssets.nlcPictures[2],
        duration: '4:32',
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  YouTubeFeedData _videoToFeedData(Video video) {
    return YouTubeFeedData(
      id: video.id,
      title: video.title,
      channelName: 'FBLA National',
      thumbnailUrl: video.thumbnailUrl,
      duration: '',
      publishedAt: video.publishedAt,
    );
  }

  List<BlueWavePostData> seedBlueWavePosts() {
    final now = DateTime.now();
    return [
      BlueWavePostData(
        id: 'bw_seed_1',
        author: const SocialAuthor(
          id: 'officer_1',
          name: 'Alex Rivera',
          role: 'State President',
          isOfficer: true,
        ),
        text:
            'Welcome to FBLA Social! Share your competition prep, chapter wins, and leadership moments. Make a wave when something inspires you.',
        kind: BlueWavePostKind.announcement,
        createdAt: now.subtract(const Duration(hours: 3)),
        waveCount: 48,
        commentCount: 12,
        tags: ['#Leadership', '#FBLA', '#Announcement'],
      ),
      BlueWavePostData(
        id: 'bw_seed_2',
        author: const SocialAuthor(
          id: 'member_1',
          name: 'Jordan Kim',
          role: 'Chapter VP',
        ),
        text:
            'Just finished our cybersecurity practice set with 92% on the mock exam. Who else is competing in tech events this year?',
        kind: BlueWavePostKind.standard,
        createdAt: now.subtract(const Duration(hours: 11)),
        waveCount: 31,
        commentCount: 8,
        tags: ['#Competition', '#Tech', '#Cybersecurity'],
      ),
      BlueWavePostData(
        id: 'bw_seed_3',
        author: const SocialAuthor(
          id: 'member_2',
          name: 'Taylor Brooks',
          role: 'Member',
        ),
        text: 'Chapter community service day: 120 hours logged in one weekend!',
        kind: BlueWavePostKind.memberHighlight,
        createdAt: now.subtract(const Duration(days: 1)),
        waveCount: 67,
        commentCount: 19,
        tags: ['#Community', '#Service'],
        imageUrls: [AppAssets.nlcPictures[3]],
      ),
      BlueWavePostData(
        id: 'bw_seed_4',
        author: const SocialAuthor(
          id: 'member_3',
          name: 'Morgan Lee',
          role: 'Treasurer',
        ),
        text: 'Quick reel: 3 tips for your NLC elevator pitch.',
        kind: BlueWavePostKind.reel,
        createdAt: now.subtract(const Duration(hours: 18)),
        waveCount: 89,
        commentCount: 24,
        tags: ['#Tips', '#NLC', '#Competition'],
        videoUrl: AppAssets.cybersecurityIntroVideo,
      ),
    ];
  }

  List<ForumThreadData> buildForumThreads(List<ChatThread> threads) {
    if (threads.isNotEmpty) {
      return threads.asMap().entries.map((entry) {
        final t = entry.value;
        final category = _categoryFromTitle(t.title);
        final lastMsg = t.messages.isNotEmpty ? t.messages.last.text : '';
        return ForumThreadData(
          id: t.id,
          title: t.title,
          category: category,
          author: SocialAuthor(
            id: 'thread_${t.id}',
            name: t.messages.isNotEmpty ? t.messages.first.author : 'Member',
            role: 'Member',
          ),
          replyCount: t.messages.length,
          createdAt: t.messages.isNotEmpty
              ? t.messages.first.time
              : DateTime.now(),
          preview: lastMsg,
        );
      }).toList();
    }

    return _seedForumThreads();
  }

  List<ForumThreadData> _seedForumThreads() {
    final now = DateTime.now();
    return [
      ForumThreadData(
        id: 'forum_1',
        title: 'NLC travel tips: flights & hotels',
        category: ForumCategory.events,
        author: const SocialAuthor(id: 'u1', name: 'Casey Nguyen', role: 'Member'),
        replyCount: 14,
        createdAt: now.subtract(const Duration(hours: 6)),
        preview: 'Best shuttle options from SAT airport?',
      ),
      ForumThreadData(
        id: 'forum_2',
        title: 'Cybersecurity objective test study group',
        category: ForumCategory.competitions,
        author: const SocialAuthor(id: 'u2', name: 'Riley Chen', role: 'Member'),
        replyCount: 22,
        createdAt: now.subtract(const Duration(hours: 20)),
        preview: 'Sharing a Quizlet deck and weekly Zoom link.',
      ),
      ForumThreadData(
        id: 'forum_3',
        title: 'How to run a chapter social media account',
        category: ForumCategory.tips,
        author: const SocialAuthor(
          id: 'u3',
          name: 'Sam Ortiz',
          role: 'Parliamentarian',
        ),
        replyCount: 9,
        createdAt: now.subtract(const Duration(days: 2)),
        preview: 'Posting cadence and Canva templates that work.',
      ),
      ForumThreadData(
        id: 'forum_4',
        title: 'Introduce yourself!',
        category: ForumCategory.general,
        author: const SocialAuthor(id: 'u4', name: 'FBLA Mod', role: 'Officer'),
        replyCount: 56,
        createdAt: now.subtract(const Duration(days: 5)),
        preview: 'Tell us your chapter, role, and favorite event.',
      ),
    ];
  }

  ForumCategory _categoryFromTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('event') || lower.contains('nlc')) {
      return ForumCategory.events;
    }
    if (lower.contains('compet')) return ForumCategory.competitions;
    if (lower.contains('tip')) return ForumCategory.tips;
    return ForumCategory.general;
  }

  List<NewsFeedData> buildNewsItems(List<NewsItem> news) {
    if (news.isEmpty) {
      return [
        NewsFeedData(
          id: 'news_seed_1',
          title: 'NLC 2026 Registration Now Open',
          summary:
              'Secure your spot in San Antonio for the National Leadership Conference.',
          source: 'National',
          date: DateTime.now().subtract(const Duration(hours: 5)),
        ),
        NewsFeedData(
          id: 'news_seed_2',
          title: 'Chapter Officer Toolkit Updated',
          summary:
              'New templates for meetings, social media, and competition prep.',
          source: 'Chapter',
          date: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
    }

    return news.map((n) {
      return NewsFeedData(
        id: n.id,
        title: n.title,
        summary: n.body.length > 140 ? '${n.body.substring(0, 137)}...' : n.body,
        source: 'National',
        date: n.date,
      );
    }).toList();
  }

  List<FeedItem> assembleRawFeed({
    required List<BlueWavePostData> blueWavePosts,
    required List<InstagramPostData> instagramPosts,
    required List<YouTubeFeedData> youtubeVideos,
    required List<ForumThreadData> forumThreads,
    required List<NewsFeedData> newsItems,
  }) {
    final items = <FeedItem>[];

    for (final post in blueWavePosts) {
      final isReel = post.kind == BlueWavePostKind.reel;
      items.add(FeedItem(
        id: post.id,
        kind: isReel ? FeedItemKind.blueWaveReel : FeedItemKind.blueWavePost,
        metadata: ContentMetadata(
          id: post.id,
          platform: SocialPlatform.blueWave,
          contentTypeLabel: isReel ? 'Reel' : post.kind.name,
          tags: post.tags,
          likes: post.waveCount,
          comments: post.commentCount,
          views: post.waveCount * 3,
          publishedAt: post.createdAt,
          authorId: post.author.id,
        ),
        blueWave: post,
      ));
    }

    for (final ig in instagramPosts) {
      items.add(FeedItem(
        id: ig.id,
        kind: FeedItemKind.instagramPost,
        metadata: ContentMetadata(
          id: ig.id,
          platform: SocialPlatform.instagram,
          contentTypeLabel: 'Instagram',
          tags: const ['#FBLA', '#Instagram'],
          likes: 120,
          comments: 18,
          views: 900,
          publishedAt: ig.publishedAt,
        ),
        instagram: ig,
      ));
    }

    for (final yt in youtubeVideos) {
      items.add(FeedItem(
        id: yt.id,
        kind: FeedItemKind.youtubeVideo,
        metadata: ContentMetadata(
          id: yt.id,
          platform: SocialPlatform.youtube,
          contentTypeLabel: 'Video',
          tags: const ['#Video', '#FBLA'],
          likes: 340,
          comments: 42,
          views: 4200,
          publishedAt: yt.publishedAt,
        ),
        youtube: yt,
      ));
    }

    for (final forum in forumThreads) {
      items.add(FeedItem(
        id: forum.id,
        kind: FeedItemKind.forumThread,
        metadata: ContentMetadata(
          id: forum.id,
          platform: SocialPlatform.forum,
          contentTypeLabel: forum.category.name,
          tags: ['#${forum.category.name}', '#Forum'],
          likes: forum.replyCount * 2,
          comments: forum.replyCount,
          views: forum.replyCount * 10,
          publishedAt: forum.createdAt,
          authorId: forum.author.id,
        ),
        forum: forum,
      ));
    }

    for (final news in newsItems) {
      items.add(FeedItem(
        id: news.id,
        kind: FeedItemKind.newsItem,
        metadata: ContentMetadata(
          id: news.id,
          platform: SocialPlatform.news,
          contentTypeLabel: 'News',
          tags: ['#News', '#${news.source}'],
          likes: 24,
          comments: 4,
          views: 500,
          publishedAt: news.date,
        ),
        news: news,
      ));
    }

    return items;
  }

  List<SocialPlatformLink> platformLinks() {
    return const [
      SocialPlatformLink(
        name: 'Instagram',
        icon: Icons.camera_alt_rounded,
        color: Color(0xFFE1306C),
        url: 'https://www.instagram.com/fbla_national/',
        description: 'Photos, reels, and chapter highlights',
        inApp: true,
      ),
      SocialPlatformLink(
        name: 'LinkedIn',
        icon: Icons.business_center_rounded,
        color: Color(0xFF0A66C2),
        url: 'https://www.linkedin.com/company/fbla-pbl/',
        description: 'Career updates and professional FBLA news',
        inApp: true,
      ),
      SocialPlatformLink(
        name: 'YouTube',
        icon: Icons.smart_display_rounded,
        color: Color(0xFFFF0000),
        url: 'https://www.youtube.com/@fbla_national',
        description: 'Workshops, keynotes, and competition tips',
      ),
      SocialPlatformLink(
        name: 'TikTok',
        icon: Icons.music_note_rounded,
        color: Color(0xFF010101),
        url: 'https://www.tiktok.com/@fbla_national',
        description: 'Short-form FBLA content',
      ),
      SocialPlatformLink(
        name: 'X',
        icon: Icons.alternate_email_rounded,
        color: Color(0xFF1DA1F2),
        url: 'https://twitter.com/FBLA_National',
        description: 'Live updates and national announcements',
      ),
    ];
  }
}