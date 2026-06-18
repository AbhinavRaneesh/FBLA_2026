import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart'
    show
        AppState,
        fblaLightBackground,
        fblaLightBorder,
        fblaLightPrimaryText,
        fblaLightSecondaryText;
import '../../services/firebase_service.dart';
import '../../widgets/friend_picker_sheet.dart';
import '../models/discord_models.dart';
import '../models/social_models.dart';
import '../theme/bluewave_theme.dart';

enum _ShareDestination { chat, discord }

/// Share a feed post in-app (DMs) or queue it for the Discord bot.
class SocialPostShare {
  SocialPostShare._();

  static Future<void> showOptions(BuildContext context, FeedItem item) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final choice = await showModalBottomSheet<_ShareDestination>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F1C31) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Share post',
                style: TextStyle(
                  color: isDark ? Colors.white : fblaLightPrimaryText,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 14),
              _optionTile(
                ctx: ctx,
                isDark: isDark,
                icon: Icons.chat_bubble_outline_rounded,
                color: BlueWaveTheme.primary,
                title: 'Share in Chat',
                subtitle: 'Send to friends in DMs',
                onTap: () => Navigator.pop(ctx, _ShareDestination.chat),
              ),
              const SizedBox(height: 8),
              _optionTile(
                ctx: ctx,
                isDark: isDark,
                icon: Icons.hub_rounded,
                color: const Color(0xFF5865F2),
                title: 'Share to Discord',
                subtitle: 'Post to your chapter server via the bot',
                onTap: () => Navigator.pop(ctx, _ShareDestination.discord),
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || choice == null) return;

    if (choice == _ShareDestination.chat) {
      await shareInChat(context, item);
    } else {
      await shareToDiscord(context, item);
    }
  }

  static Widget _optionTile({
    required BuildContext ctx,
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : fblaLightBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : fblaLightBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : fblaLightPrimaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : fblaLightSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> shareInChat(BuildContext context, FeedItem item) async {
    final app = context.read<AppState>();
    final userId = app.firebaseUser?.uid;
    if (userId == null) {
      _snack(context, 'Sign in to share posts.');
      return;
    }

    final friends = await FirebaseService.getFriendsForUser(userId);
    if (!context.mounted) return;

    final picked = await FriendPickerSheet.show(
      context,
      friends: friends,
      title: 'Share with Friends',
      confirmLabel: 'Send',
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;

    final payload = _chatPayload(item);

    for (final friend in picked) {
      final friendId = (friend['id'] ?? '').toString();
      if (friendId.isEmpty) continue;
      await FirebaseService.sendPostShareMessage(
        fromUserId: userId,
        toUserId: friendId,
        fromUserName: app.resolvedDisplayName,
        postPayload: payload,
      );
    }

    if (!context.mounted) return;
    _snack(
      context,
      'Shared with ${picked.length} friend${picked.length == 1 ? '' : 's'} in chat.',
    );
  }

  static Future<void> shareToDiscord(BuildContext context, FeedItem item) async {
    final app = context.read<AppState>();
    if (app.firebaseUser?.uid == null) {
      _snack(context, 'Sign in to share to Discord.');
      return;
    }

    final discord = _discordPayload(item, app.resolvedDisplayName);
    if (discord == null) {
      _snack(context, 'This post cannot be shared to Discord.');
      return;
    }

    try {
      await FirebaseService.queueDiscordMessage(
        title: discord.title,
        body: discord.body,
        channel: discordChannelName(discord.channel),
        type: discordPostTypeName(discord.type),
        sourceId: discord.sourceId,
        authorName: app.resolvedDisplayName,
        imageUrl: discord.imageUrl,
        actionUrl: discord.actionUrl,
        actionLabel: discord.actionLabel,
      );
      if (!context.mounted) return;
      _snack(context, 'Queued for Discord — your bot will post it shortly.');
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Could not queue Discord post: $e');
    }
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  static Map<String, dynamic> _chatPayload(FeedItem item) {
    switch (item.kind) {
      case FeedItemKind.blueWavePost:
      case FeedItemKind.blueWaveReel:
        final post = item.blueWave!;
        return {
          'postId': post.id,
          'postKind': post.kind.name,
          'postText': post.text,
          'feedKind': item.kind.name,
          if (post.videoUrl != null && post.videoUrl!.isNotEmpty)
            'postVideoUrl': post.videoUrl,
          if (post.imageUrls.isNotEmpty) 'postImageUrl': post.imageUrls.first,
        };
      case FeedItemKind.forumThread:
        final thread = item.forum!;
        return {
          'postId': thread.id,
          'postKind': 'forum',
          'postText': thread.title,
          'feedKind': item.kind.name,
          if (thread.preview.isNotEmpty) 'postPreview': thread.preview,
        };
      case FeedItemKind.newsItem:
        final news = item.news!;
        return {
          'postId': news.id,
          'postKind': 'news',
          'postText': news.title,
          'feedKind': item.kind.name,
          'postPreview': news.summary,
        };
      case FeedItemKind.youtubeVideo:
        final video = item.youtube!;
        return {
          'postId': video.id,
          'postKind': 'youtube',
          'postText': video.title,
          'feedKind': item.kind.name,
          'postVideoUrl': 'https://www.youtube.com/watch?v=${video.id}',
        };
      case FeedItemKind.instagramPost:
        final ig = item.instagram!;
        return {
          'postId': ig.id,
          'postKind': 'instagram',
          'postText': ig.caption,
          'feedKind': item.kind.name,
          if (ig.permalink.isNotEmpty) 'postVideoUrl': ig.permalink,
          'postImageUrl': ig.imageUrl,
        };
      default:
        return {
          'postId': item.id,
          'postKind': item.kind.name,
          'postText': 'Shared from FBLA Social',
          'feedKind': item.kind.name,
        };
    }
  }

  static _DiscordPayload? _discordPayload(FeedItem item, String authorName) {
    switch (item.kind) {
      case FeedItemKind.blueWavePost:
      case FeedItemKind.blueWaveReel:
        final post = item.blueWave!;
        String? imageUrl;
        for (final url in post.imageUrls) {
          imageUrl = FirebaseService.discordSafeMediaUrl(url);
          if (imageUrl != null) break;
        }
        imageUrl ??= FirebaseService.discordSafeMediaUrl(post.videoUrl);
        return _DiscordPayload(
          title: 'BlueWave: ${post.text}',
          body: [
            if (post.tags.isNotEmpty) post.tags.join(' '),
            if (post.videoUrl != null) 'Watch in the FBLA app Social feed.',
            'Posted by ${post.author.name}',
          ].where((s) => s.isNotEmpty).join('\n\n'),
          channel: DiscordChannel.general,
          type: DiscordPostType.bluewave,
          sourceId: post.id,
          imageUrl: imageUrl,
        );
      case FeedItemKind.forumThread:
        final thread = item.forum!;
        return _DiscordPayload(
          title: 'Forum: ${thread.title}',
          body: [
            if (thread.preview.isNotEmpty) thread.preview,
            'Started by ${thread.author.name}',
            '${thread.replyCount} repl${thread.replyCount == 1 ? 'y' : 'ies'}',
          ].where((s) => s.isNotEmpty).join('\n\n'),
          channel: DiscordChannel.general,
          type: DiscordPostType.forum,
          sourceId: thread.id,
        );
      case FeedItemKind.newsItem:
        final news = item.news!;
        return _DiscordPayload(
          title: news.title,
          body: [
            news.summary,
            'Source: ${news.source}',
          ].join('\n\n'),
          channel: DiscordChannel.announcements,
          type: DiscordPostType.announcement,
          sourceId: news.id,
        );
      case FeedItemKind.youtubeVideo:
        final video = item.youtube!;
        final watchUrl = 'https://www.youtube.com/watch?v=${video.id}';
        return _DiscordPayload(
          title: video.title,
          body: [
            'Channel: ${video.channelName}',
            if (video.duration.isNotEmpty) 'Duration: ${video.duration}',
            watchUrl,
          ].where((s) => s.isNotEmpty).join('\n\n'),
          channel: DiscordChannel.general,
          type: DiscordPostType.generalUpdate,
          sourceId: video.id,
          imageUrl: FirebaseService.discordSafeMediaUrl(video.thumbnailUrl),
          actionUrl: watchUrl,
          actionLabel: 'Watch on YouTube',
        );
      case FeedItemKind.instagramPost:
        final ig = item.instagram!;
        return _DiscordPayload(
          title: 'Instagram post',
          body: [
            if (ig.caption.isNotEmpty) ig.caption,
            if (ig.permalink.isNotEmpty) ig.permalink,
          ].where((s) => s.isNotEmpty).join('\n\n'),
          channel: DiscordChannel.general,
          type: DiscordPostType.generalUpdate,
          sourceId: ig.id,
          imageUrl: FirebaseService.discordSafeMediaUrl(ig.imageUrl),
          actionUrl: FirebaseService.discordSafeMediaUrl(ig.permalink),
          actionLabel: 'View on Instagram',
        );
      default:
        return null;
    }
  }
}

class _DiscordPayload {
  final String title;
  final String body;
  final DiscordChannel channel;
  final DiscordPostType type;
  final String? sourceId;
  final String? imageUrl;
  final String? actionUrl;
  final String? actionLabel;

  const _DiscordPayload({
    required this.title,
    required this.body,
    required this.channel,
    required this.type,
    this.sourceId,
    this.imageUrl,
    this.actionUrl,
    this.actionLabel,
  });
}
