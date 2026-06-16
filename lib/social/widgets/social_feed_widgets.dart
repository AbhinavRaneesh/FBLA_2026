import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../main.dart' show fblaGold, fblaLightBorder, fblaLightPrimaryText, fblaLightSecondaryText, fblaNavy;
import '../models/social_models.dart';
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
          hintText: 'Search BlueWave, forums, news, members...',
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
                  'BlueWave',
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

  const FeedPlatformBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.showNew = false,
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
              Icon(icon, size: 14, color: color),
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
            label: isReel ? 'BlueWave Reel' : _kindLabel(post.kind),
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
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: post.imageUrls.first,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  height: 180,
                  color: BlueWaveTheme.deep,
                  child: const Icon(Icons.image_outlined, color: Colors.white54),
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
              if (onShare != null)
                InkWell(
                  onTap: onShare,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: BlueWaveTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                            BlueWaveTheme.primary.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isReel
                              ? Icons.ios_share_rounded
                              : Icons.share_rounded,
                          size: 16,
                          color: BlueWaveTheme.waveGlow,
                        ),
                        const SizedBox(width: 6),
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
                ),
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
        return 'BlueWave';
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

  const InstagramPostCard({
    super.key,
    required this.post,
    required this.isDark,
    required this.onOpen,
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
            child: const FeedPlatformBadge(
              label: 'Instagram',
              icon: Icons.camera_alt_rounded,
              color: Color(0xFFE1306C),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.zero),
            child: CachedNetworkImage(
              imageUrl: post.imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
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
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('View on Instagram'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE1306C),
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

class YouTubeVideoCard extends StatelessWidget {
  final YouTubeFeedData video;
  final bool isDark;
  final VoidCallback onPlay;

  const YouTubeVideoCard({
    super.key,
    required this.video,
    required this.isDark,
    required this.onPlay,
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
            child: const FeedPlatformBadge(
              label: 'YouTube',
              icon: Icons.smart_display_rounded,
              color: Color(0xFFFF0000),
            ),
          ),
          GestureDetector(
            onTap: onPlay,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
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

  const ForumThreadCard({
    super.key,
    required this.thread,
    required this.isDark,
    required this.onTap,
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

  const NewsCard({
    super.key,
    required this.news,
    required this.isDark,
    this.onTap,
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
            Text(
              DateFormat.yMMMd().format(news.date),
              style: TextStyle(
                color: secondary.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
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
              child: Icon(platform.icon, color: platform.color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              platform.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white : fblaLightPrimaryText,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                platform.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white60 : fblaLightSecondaryText,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.MMMd().format(time);
}
