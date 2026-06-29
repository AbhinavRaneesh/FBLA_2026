import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import '../../constants/app_assets.dart';
import '../../main.dart' show fblaGold, fblaLightBorder, fblaLightPrimaryText, fblaLightSecondaryText, fblaNavy;
import '../../widgets/social_platform_logo.dart';
import '../screens/local_video_player_screen.dart';
import '../models/social_models.dart';
import '../services/video_cover_service.dart';
import '../theme/bluewave_theme.dart';

class SocialSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const SocialSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? BlueWaveTheme.primary.withValues(alpha: 0.25)
              : fblaLightBorder,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          color: isDark ? Colors.white : fblaLightPrimaryText,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Search FBLA Social, forums, news, members...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white54 : fblaLightSecondaryText,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? BlueWaveTheme.waveGlow : fblaNavy,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class FeedShareButton extends StatelessWidget {
  final VoidCallback onTap;

  const FeedShareButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: BlueWaveTheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: BlueWaveTheme.primary.withValues(alpha: 0.28),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.share_rounded, size: 16, color: BlueWaveTheme.waveGlow),
            SizedBox(width: 6),
            Text(
              'Share',
              style: TextStyle(
                color: BlueWaveTheme.waveGlow,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BlueWaveHeader extends StatelessWidget {
  const BlueWaveHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: BlueWaveTheme.headerGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BlueWaveTheme.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: BlueWaveTheme.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: BlueWaveTheme.waveAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.waves_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FBLA Social',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Where leaders make waves.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeedPlatformBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool showNew;
  final String? logoAsset;

  const FeedPlatformBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.showNew = false,
    this.logoAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SocialPlatformLogo(
                assetPath: logoAsset,
                fallbackIcon: icon,
                color: color,
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        if (showNew) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: fblaGold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'New for you',
              style: TextStyle(
                color: fblaGold,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class BlueWavePostCard extends StatelessWidget {
  final BlueWavePostData post;
  final bool isDark;
  final bool hasWaved;
  final VoidCallback onWave;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onShare;

  const BlueWavePostCard({
    super.key,
    required this.post,
    required this.isDark,
    required this.hasWaved,
    required this.onWave,
    this.onAuthorTap,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    final secondary = isDark ? Colors.white70 : fblaLightSecondaryText;
    final isReel = post.kind == BlueWavePostKind.reel;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BlueWaveTheme.cardDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeedPlatformBadge(
            label: isReel ? 'FBLA Reel' : _kindLabel(post.kind),
            icon: isReel ? Icons.play_circle_outline : Icons.waves_rounded,
            color: BlueWaveTheme.primary,
            showNew: post.isRecommended,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onAuthorTap,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: BlueWaveTheme.primary.withValues(alpha: 0.2),
                  backgroundImage: post.author.photoUrl != null
                      ? CachedNetworkImageProvider(post.author.photoUrl!)
                      : null,
                  child: post.author.photoUrl == null
                      ? Text(
                          post.author.name.isNotEmpty
                              ? post.author.name[0]
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author.name,
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${post.author.role} · ${_timeAgo(post.createdAt)}',
                        style: TextStyle(color: secondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            post.text,
            style: TextStyle(
              color: primary,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (post.imageUrls.isNotEmpty && !post.hasVideo) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _FeedImage(
                imageUrl: post.imageUrls.first,
                height: 180,
                isDark: isDark,
              ),
            ),
          ],
          if (post.hasVideo && post.videoUrl != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocalVideoPlayerScreen(
                      videoSource: post.videoUrl!,
                      title: post.text,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      VideoCoverThumbnail(
                        coverUrl: post.videoCoverUrl,
                        videoUrl: post.videoUrl!,
                        isDark: isDark,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.08),
                              Colors.black.withValues(alpha: 0.42),
                            ],
                          ),
                        ),
                      ),
                      Icon(
                        Icons.play_circle_fill_rounded,
                        size: 56,
                        color: BlueWaveTheme.primary.withValues(alpha: 0.95),
                      ),
                      if (post.isOnYouTube)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF0000),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.smart_display_rounded,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'YouTube',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: post.tags
                  .map(
                    (t) => Text(
                      t,
                      style: TextStyle(
                        color: BlueWaveTheme.waveGlow,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _WaveButton(
                active: hasWaved,
                count: post.waveCount + (hasWaved ? 1 : 0),
                onTap: onWave,
              ),
              const SizedBox(width: 16),
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 18, color: secondary),
              const SizedBox(width: 6),
              Text(
                '${post.commentCount}',
                style: TextStyle(
                  color: secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (onShare != null) FeedShareButton(onTap: onShare!),
            ],
          ),
        ],
      ),
    );
  }

  String _kindLabel(BlueWavePostKind kind) {
    switch (kind) {
      case BlueWavePostKind.announcement:
        return 'Announcement';
      case BlueWavePostKind.memberHighlight:
        return 'Member Highlight';
      case BlueWavePostKind.photo:
        return 'Photo';
      case BlueWavePostKind.video:
        return 'Video';
      default:
        return 'FBLA Social';
    }
  }
}

class _WaveButton extends StatelessWidget {
  final bool active;
  final int count;
  final VoidCallback onTap;

  const _WaveButton({
    required this.active,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? BlueWaveTheme.primary.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: BlueWaveTheme.primary.withValues(alpha: active ? 0.5 : 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌊', style: TextStyle(fontSize: active ? 18 : 16)),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: active ? BlueWaveTheme.waveGlow : Colors.white70,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InstagramPostCard extends StatelessWidget {
  final InstagramPostData post;
  final bool isDark;
  final VoidCallback onOpen;
  final VoidCallback? onShare;

  const InstagramPostCard({
    super.key,
    required this.post,
    required this.isDark,
    required this.onOpen,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BlueWaveTheme.cardDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: FeedPlatformBadge(
              label: 'Instagram',
              icon: Icons.camera_alt_rounded,
              color: Color(0xFFE1306C),
              logoAsset: AppAssets.instagramLogo,
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.zero),
            child: _FeedImage(
              imageUrl: post.imageUrl,
              height: 200,
              isDark: isDark,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.caption.length > 120
                      ? '${post.caption.substring(0, 117)}...'
                      : post.caption,
                  style: TextStyle(
                    color: primary,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('View on Instagram'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFE1306C),
                      ),
                    ),
                    const Spacer(),
                    if (onShare != null) FeedShareButton(onTap: onShare!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class YouTubeVideoCard extends StatelessWidget {
  final YouTubeFeedData video;
  final bool isDark;
  final VoidCallback onPlay;
  final VoidCallback? onShare;

  const YouTubeVideoCard({
    super.key,
    required this.video,
    required this.isDark,
    required this.onPlay,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    final secondary = isDark ? Colors.white70 : fblaLightSecondaryText;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BlueWaveTheme.cardDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: FeedPlatformBadge(
              label: 'YouTube',
              icon: Icons.smart_display_rounded,
              color: Color(0xFFFF0000),
              logoAsset: AppAssets.youtubeLogo,
            ),
          ),
          GestureDetector(
            onTap: onPlay,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: _FeedImage(
                    imageUrl: video.thumbnailUrl,
                    height: 190,
                    isDark: isDark,
                  ),
                ),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 34),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${video.channelName}${video.duration.isNotEmpty ? ' · ${video.duration}' : ''}',
                  style: TextStyle(color: secondary, fontSize: 12),
                ),
                if (onShare != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FeedShareButton(onTap: onShare!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ForumThreadCard extends StatelessWidget {
  final ForumThreadData thread;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onShare;

  const ForumThreadCard({
    super.key,
    required this.thread,
    required this.isDark,
    required this.onTap,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    final secondary = isDark ? Colors.white70 : fblaLightSecondaryText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        padding: const EdgeInsets.all(16),
        decoration: BlueWaveTheme.cardDecoration(isDark: isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FeedPlatformBadge(
              label: 'Forum · ${_categoryLabel(thread.category)}',
              icon: Icons.forum_outlined,
              color: const Color(0xFF8B5CF6),
            ),
            const SizedBox(height: 12),
            Text(
              thread.title,
              style: TextStyle(
                color: primary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (thread.preview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                thread.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: secondary, height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  thread.author.name,
                  style: TextStyle(
                    color: BlueWaveTheme.waveGlow,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chat_bubble_outline, size: 16, color: secondary),
                const SizedBox(width: 4),
                Text(
                  '${thread.replyCount} replies',
                  style: TextStyle(color: secondary, fontSize: 12),
                ),
                if (onShare != null) ...[
                  const SizedBox(width: 12),
                  FeedShareButton(onTap: onShare!),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(ForumCategory c) {
    switch (c) {
      case ForumCategory.events:
        return 'Events';
      case ForumCategory.competitions:
        return 'Competitions';
      case ForumCategory.tips:
        return 'Tips';
      case ForumCategory.general:
        return 'General';
    }
  }
}

class NewsCard extends StatelessWidget {
  final NewsFeedData news;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onShare;

  const NewsCard({
    super.key,
    required this.news,
    required this.isDark,
    this.onTap,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    final secondary = isDark ? Colors.white70 : fblaLightSecondaryText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        padding: const EdgeInsets.all(16),
        decoration: BlueWaveTheme.cardDecoration(isDark: isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FeedPlatformBadge(
              label: 'News · ${news.source}',
              icon: Icons.newspaper_rounded,
              color: fblaGold,
            ),
            const SizedBox(height: 12),
            Text(
              news.title,
              style: TextStyle(
                color: primary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              news.summary,
              style: TextStyle(color: secondary, height: 1.45, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  DateFormat.yMMMd().format(news.date),
                  style: TextStyle(
                    color: secondary.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (onShare != null) FeedShareButton(onTap: onShare!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SocialPlatformCard extends StatelessWidget {
  final SocialPlatformLink platform;
  final bool isDark;
  final VoidCallback onTap;

  const SocialPlatformCard({
    super.key,
    required this.platform,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: double.infinity,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BlueWaveTheme.cardDecoration(isDark: isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: platform.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SocialPlatformLogo(
                platformName: platform.name,
                fallbackIcon: platform.icon,
                color: platform.color,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  platform.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : fblaLightPrimaryText,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cover image for uploaded social videos (network URL or generated frame).
class VideoCoverThumbnail extends StatefulWidget {
  final String? coverUrl;
  final String videoUrl;
  final bool isDark;

  const VideoCoverThumbnail({
    super.key,
    this.coverUrl,
    required this.videoUrl,
    required this.isDark,
  });

  @override
  State<VideoCoverThumbnail> createState() => _VideoCoverThumbnailState();
}

class _VideoCoverThumbnailState extends State<VideoCoverThumbnail> {
  Uint8List? _generatedBytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final cover = widget.coverUrl;
    if ((cover == null || cover.isEmpty) && widget.videoUrl.startsWith('http')) {
      _loadGeneratedCover();
    }
  }

  Future<void> _loadGeneratedCover() async {
    setState(() => _loading = true);
    final bytes = await VideoCoverService.thumbnailBytesForUrl(widget.videoUrl);
    if (!mounted) return;
    setState(() {
      _generatedBytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cover = widget.coverUrl;
    if (cover != null && cover.isNotEmpty) {
      if (_isBundledAsset(cover)) {
        return Image.asset(
          _bundledAssetPath(cover),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      }
      return CachedNetworkImage(
        imageUrl: cover,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => _fallback(showSpinner: true),
        errorWidget: (_, __, ___) => _fallback(showSpinner: false),
      );
    }

    if (_generatedBytes != null) {
      return Image.memory(
        _generatedBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return _fallback(showSpinner: _loading);
  }

  Widget _fallback({required bool showSpinner}) {
    return Container(
      color: Colors.black.withValues(alpha: widget.isDark ? 0.45 : 0.1),
      child: showSpinner
          ? Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BlueWaveTheme.primary.withValues(alpha: 0.85),
                ),
              ),
            )
          : null,
    );
  }
}

/// Network or bundled asset image for social feed cards.
bool _isBundledAsset(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  final decoded = Uri.decodeComponent(path);
  return url.startsWith('assets/') || decoded.startsWith('assets/');
}

String _bundledAssetPath(String url) {
  if (url.startsWith('assets/')) return url;
  final path = Uri.tryParse(url)?.path ?? url;
  return Uri.decodeComponent(path);
}

class _FeedImage extends StatelessWidget {
  final String imageUrl;
  final double height;
  final bool isDark;

  const _FeedImage({
    required this.imageUrl,
    required this.height,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (_isBundledAsset(imageUrl)) {
      return Image.asset(
        _bundledAssetPath(imageUrl),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        height: height,
        color: isDark ? const Color(0xFF13243D) : const Color(0xFFE8EDF3),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      height: height,
      width: double.infinity,
      color: isDark ? const Color(0xFF13243D) : const Color(0xFFE8EDF3),
      child: Icon(
        Icons.image_outlined,
        size: 48,
        color: isDark ? Colors.white38 : Colors.black26,
      ),
    );
  }
}

/// Horizontal strip for Discover tab — media cards with thumbnails when available.
class RecommendedDiscoverStrip extends StatelessWidget {
  final List<FeedItem> items;
  final bool isDark;
  final ValueChanged<FeedItem> onTap;

  const RecommendedDiscoverStrip({
    super.key,
    required this.items,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? Colors.white : fblaLightPrimaryText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended for you',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 208,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return _RecommendedDiscoverCard(
                item: item,
                isDark: isDark,
                onTap: () => onTap(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendedDiscoverCard extends StatelessWidget {
  final FeedItem item;
  final bool isDark;
  final VoidCallback onTap;

  const _RecommendedDiscoverCard({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final view = _RecommendedCardView.from(item);
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    final secondary = isDark ? Colors.white60 : fblaLightSecondaryText;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 156,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? BlueWaveTheme.primary.withValues(alpha: 0.2)
                : BlueWaveTheme.primary.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (view.showMedia)
              SizedBox(
                height: 118,
                width: double.infinity,
                child: _RecommendedMedia(
                  mediaUrl: view.mediaUrl,
                  isVideo: view.isVideo,
                  isDark: isDark,
                  platformIcon: view.platformIcon,
                  platformColor: view.platformColor,
                  logoAsset: view.logoAsset,
                ),
              )
            else
              Container(
                height: 72,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      view.platformColor.withValues(alpha: isDark ? 0.28 : 0.14),
                      isDark
                          ? const Color(0xFF0A1628)
                          : const Color(0xFFF4F8FC),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SocialPlatformLogo(
                      assetPath: view.logoAsset,
                      fallbackIcon: view.platformIcon,
                      color: view.platformColor,
                      size: 22,
                    ),
                    const Spacer(),
                    Text(
                      view.platformLabel,
                      style: TextStyle(
                        color: view.platformColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (view.showMedia)
                      Text(
                        view.platformLabel,
                        style: TextStyle(
                          color: view.platformColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (view.showMedia) const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        view.title,
                        maxLines: view.showMedia ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ),
                    Text(
                      'New for you',
                      style: TextStyle(
                        color: secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedMedia extends StatelessWidget {
  final String? mediaUrl;
  final bool isVideo;
  final bool isDark;
  final IconData platformIcon;
  final Color platformColor;
  final String? logoAsset;

  const _RecommendedMedia({
    required this.mediaUrl,
    required this.isVideo,
    required this.isDark,
    required this.platformIcon,
    required this.platformColor,
    this.logoAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (mediaUrl != null && mediaUrl!.isNotEmpty)
          _FeedImage(imageUrl: mediaUrl!, height: 118, isDark: isDark)
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  platformColor.withValues(alpha: 0.35),
                  isDark ? const Color(0xFF0A1628) : const Color(0xFFDCEEFF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SocialPlatformLogo(
              assetPath: logoAsset,
              fallbackIcon: platformIcon,
              color: platformColor,
              size: 36,
            ),
          ),
        if (isVideo)
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 26),
            ),
          ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isVideo ? 'Video' : 'Photo',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecommendedCardView {
  final String title;
  final String? mediaUrl;
  final bool isVideo;
  final bool showMedia;
  final String platformLabel;
  final IconData platformIcon;
  final Color platformColor;
  final String? logoAsset;

  const _RecommendedCardView({
    required this.title,
    this.mediaUrl,
    this.isVideo = false,
    this.showMedia = true,
    required this.platformLabel,
    required this.platformIcon,
    required this.platformColor,
    this.logoAsset,
  });

  static _RecommendedCardView from(FeedItem item) {
    switch (item.kind) {
      case FeedItemKind.blueWavePost:
      case FeedItemKind.blueWaveReel:
        final post = item.blueWave!;
        final hasImages = post.imageUrls.isNotEmpty;
        final hasVideo = post.hasVideo;
        final textOnly = !hasImages && !hasVideo;
        String? mediaUrl;
        if (hasImages || (hasVideo && post.videoCoverUrl != null)) {
          mediaUrl = post.videoCoverUrl ?? post.imageUrls.first;
        } else if (hasVideo && post.videoUrl != null && post.videoUrl!.startsWith('http')) {
          mediaUrl = post.videoUrl;
        }
        return _RecommendedCardView(
          title: post.text.isNotEmpty ? post.text : 'FBLA post',
          mediaUrl: mediaUrl,
          isVideo: hasVideo,
          showMedia: !textOnly,
          platformLabel: 'FBLA Social',
          platformIcon: Icons.waves_rounded,
          platformColor: BlueWaveTheme.primary,
        );
      case FeedItemKind.instagramPost:
        final ig = item.instagram!;
        return _RecommendedCardView(
          title: ig.caption.isNotEmpty ? ig.caption : 'Instagram post',
          mediaUrl: ig.imageUrl,
          isVideo: false,
          platformLabel: 'Instagram',
          platformIcon: Icons.camera_alt_rounded,
          platformColor: const Color(0xFFE1306C),
          logoAsset: AppAssets.instagramLogo,
        );
      case FeedItemKind.youtubeVideo:
        final video = item.youtube!;
        return _RecommendedCardView(
          title: video.title,
          mediaUrl: video.thumbnailUrl,
          isVideo: true,
          platformLabel: 'YouTube',
          platformIcon: Icons.smart_display_rounded,
          platformColor: const Color(0xFFFF0000),
          logoAsset: AppAssets.youtubeLogo,
        );
      case FeedItemKind.forumThread:
        final thread = item.forum!;
        return _RecommendedCardView(
          title: thread.title,
          showMedia: false,
          platformLabel: 'Forum',
          platformIcon: Icons.forum_outlined,
          platformColor: const Color(0xFF8B5CF6),
        );
      case FeedItemKind.newsItem:
        final news = item.news!;
        return _RecommendedCardView(
          title: news.title,
          showMedia: false,
          platformLabel: 'News',
          platformIcon: Icons.newspaper_rounded,
          platformColor: fblaGold,
        );
      default:
        return const _RecommendedCardView(
          title: 'Recommended',
          showMedia: false,
          platformLabel: 'Social',
          platformIcon: Icons.star_rounded,
          platformColor: BlueWaveTheme.primary,
        );
    }
  }
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.MMMd().format(time);
}

/// Full-tab loading state for the Social feed (initial load and refresh).
class SocialTabLoading extends StatelessWidget {
  const SocialTabLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        AppAssets.lottieSocialLoading,
        width: 180,
        height: 180,
        fit: BoxFit.contain,
        repeat: true,
        errorBuilder: (_, __, ___) => const CircularProgressIndicator(
          color: BlueWaveTheme.primary,
        ),
      ),
    );
  }
}
