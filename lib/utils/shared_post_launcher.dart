import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/video_model.dart';
import '../screens/instagram_feed_screen.dart';
import '../screens/video_player_screen.dart';
import '../social/screens/local_video_player_screen.dart';
import '../widgets/app_snackbar.dart';

/// UI labels/icons for a shared post card in chat.
class SharedPostPresentation {
  final IconData icon;
  final String typeLabel;
  final String actionLabel;

  const SharedPostPresentation({
    required this.icon,
    required this.typeLabel,
    required this.actionLabel,
  });

  factory SharedPostPresentation.fromPayload(Map<String, dynamic> payload) {
    final postKind = (payload['postKind'] ?? 'post').toString();
    final feedKind = (payload['feedKind'] ?? '').toString();
    final videoUrl = (payload['postVideoUrl'] ?? '').toString();

    if (_isYouTubeShare(postKind, feedKind, videoUrl)) {
      return const SharedPostPresentation(
        icon: Icons.play_circle_filled_rounded,
        typeLabel: 'YouTube video',
        actionLabel: 'Watch on YouTube',
      );
    }
    if (postKind == 'instagram' || feedKind == 'instagramPost') {
      return const SharedPostPresentation(
        icon: Icons.camera_alt_outlined,
        typeLabel: 'Instagram post',
        actionLabel: 'View on Instagram',
      );
    }
    if (postKind == 'forum' || feedKind == 'forumThread') {
      return const SharedPostPresentation(
        icon: Icons.forum_outlined,
        typeLabel: 'forum thread',
        actionLabel: 'View Thread',
      );
    }
    if (postKind == 'news' || feedKind == 'newsItem') {
      return const SharedPostPresentation(
        icon: Icons.newspaper_outlined,
        typeLabel: 'news update',
        actionLabel: 'Read Update',
      );
    }
    if (postKind == 'reel' || feedKind == 'blueWaveReel') {
      return const SharedPostPresentation(
        icon: Icons.play_circle_outline_rounded,
        typeLabel: 'reel',
        actionLabel: 'View Reel',
      );
    }
    return const SharedPostPresentation(
      icon: Icons.waves_rounded,
      typeLabel: 'post',
      actionLabel: 'View Post',
    );
  }
}

String? youtubeIdFromUrl(String url) {
  if (url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  if (uri.host.contains('youtu.be')) {
    final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    return id.isNotEmpty ? id : null;
  }

  if (uri.host.contains('youtube.com') || uri.host.contains('youtube-nocookie.com')) {
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;
    if (uri.pathSegments.contains('shorts') && uri.pathSegments.length > 1) {
      return uri.pathSegments.last;
    }
    if (uri.pathSegments.contains('embed') && uri.pathSegments.length > 1) {
      return uri.pathSegments.last;
    }
  }

  return null;
}

bool _isYouTubeShare(String postKind, String feedKind, String videoUrl) {
  return postKind == 'youtube' ||
      feedKind == 'youtubeVideo' ||
      youtubeIdFromUrl(videoUrl) != null;
}

bool _isInstagramShare(String postKind, String feedKind, String videoUrl) {
  return postKind == 'instagram' ||
      feedKind == 'instagramPost' ||
      videoUrl.contains('instagram.com');
}

Future<void> openSharedPost(
  BuildContext context,
  Map<String, dynamic> payload,
) async {
  final postKind = (payload['postKind'] ?? '').toString();
  final feedKind = (payload['feedKind'] ?? '').toString();
  final videoUrl = (payload['postVideoUrl'] ?? '').toString();
  final text = (payload['postText'] ?? '').toString();
  final postId = (payload['postId'] ?? '').toString();
  final imageUrl = (payload['postImageUrl'] ?? '').toString();
  final preview = (payload['postPreview'] ?? '').toString();

  if (_isYouTubeShare(postKind, feedKind, videoUrl)) {
    final youtubeId = youtubeIdFromUrl(videoUrl) ??
        (postId.isNotEmpty ? postId : null);
    if (youtubeId != null && youtubeId.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            video: Video(
              id: youtubeId,
              title: text.isNotEmpty ? text : 'YouTube video',
              description: '',
              thumbnailUrl: imageUrl,
              publishedAt: DateTime.now(),
            ),
          ),
        ),
      );
      return;
    }
  }

  if (_isInstagramShare(postKind, feedKind, videoUrl)) {
    if (videoUrl.isNotEmpty) {
      final uri = Uri.tryParse(videoUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (!context.mounted) return;
    InstagramFeedScreen.open(context);
    return;
  }

  if (videoUrl.isNotEmpty &&
      !_isYouTubeShare(postKind, feedKind, videoUrl) &&
      !_isInstagramShare(postKind, feedKind, videoUrl)) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocalVideoPlayerScreen(
          videoSource: videoUrl,
          title: text.isNotEmpty ? text : 'Video',
        ),
      ),
    );
    return;
  }

  if (postKind == 'forum' || feedKind == 'forumThread') {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(text.isNotEmpty ? text : 'Forum thread'),
        content: SingleChildScrollView(
          child: Text(
            preview.isNotEmpty
                ? preview
                : 'Open the Social Platform tab to join the discussion.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    return;
  }

  if (postKind == 'news' || feedKind == 'newsItem') {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(text.isNotEmpty ? text : 'News update'),
        content: SingleChildScrollView(
          child: Text(
            preview.isNotEmpty ? preview : 'Shared from FBLA Social.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    return;
  }

  if (videoUrl.isNotEmpty) {
    final uri = Uri.tryParse(videoUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  }

  if (!context.mounted) return;
  AppSnackBar.info(
    context,
    text.isNotEmpty
        ? 'This shared post is no longer available.'
        : 'Unable to open this shared item.',
  );
}
