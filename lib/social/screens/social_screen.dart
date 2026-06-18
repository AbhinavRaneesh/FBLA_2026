import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart'
    show
        AppState,
        appBackgroundGradient,
        fblaLightBackground,
        fblaLightPrimaryText;
import '../../models/video_model.dart';
import '../../screens/find_members_screen.dart';
import '../../widgets/friend_picker_sheet.dart';
import '../../screens/instagram_feed_screen.dart';
import '../../screens/video_player_screen.dart';
import '../../services/firebase_service.dart';
import '../models/social_models.dart';
import '../providers/social_provider.dart';
import '../theme/bluewave_theme.dart';
import '../widgets/social_feed_widgets.dart';
import 'bluewave_compose_screen.dart';
import 'discord_hub_screen.dart';
import 'forum_screens.dart';
import 'local_video_player_screen.dart';
import 'social_messages_screen.dart';
import 'video_studio_screen.dart';

/// Flagship Social tab — unified BlueWave + external platforms feed with ML ranking.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  late final SocialProvider _socialProvider;
  final _searchController = TextEditingController();
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _socialProvider = SocialProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final app = context.read<AppState>();
    await _socialProvider.initialize(
      news: app.news,
      threads: app.threads,
      displayName: app.displayName,
      userId: app.firebaseUser?.uid ?? 'guest',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _socialProvider.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final app = context.read<AppState>();
    await _socialProvider.refresh(
      news: app.news,
      threads: app.threads,
      displayName: app.displayName,
      userId: app.firebaseUser?.uid ?? 'guest',
    );
  }

  void _openVideoStudio(
    BuildContext context, {
    VideoStudioLaunchMode launchMode = VideoStudioLaunchMode.none,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _socialProvider,
          child: VideoStudioScreen(launchMode: launchMode),
        ),
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F1C31) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Create',
                style: TextStyle(
                  color: isDark ? Colors.white : fblaLightPrimaryText,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BlueWaveTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.upload_file_rounded,
                      color: BlueWaveTheme.primary),
                ),
                title: const Text('Upload from Phone',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text(
                    'Pick a video from your gallery and post to BlueWave'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openVideoStudio(context, launchMode: VideoStudioLaunchMode.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BlueWaveTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.videocam_rounded,
                      color: BlueWaveTheme.primary),
                ),
                title: const Text('Video Studio',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Record, post, and upload to YouTube'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openVideoStudio(context);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BlueWaveTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.waves_rounded,
                      color: BlueWaveTheme.primary),
                ),
                title: const Text('Text Post',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Share an update on BlueWave'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: _socialProvider,
                        child: const BlueWaveComposeScreen(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider.value(
      value: _socialProvider,
      child: Scaffold(
        backgroundColor: isDark ? Colors.transparent : fblaLightBackground,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateOptions(context),
          backgroundColor: BlueWaveTheme.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Create',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark ? appBackgroundGradient : null,
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildAppBar(isDark),
                Consumer<SocialProvider>(
                  builder: (context, social, _) {
                    return SocialSearchBar(
                      controller: _searchController,
                      onChanged: (q) {
                        social.search(q);
                        setState(
                            () => _showSearchResults = q.trim().isNotEmpty);
                      },
                      onClear: () {
                        _searchController.clear();
                        social.clearSearch();
                        setState(() => _showSearchResults = false);
                      },
                    );
                  },
                ),
                Expanded(
                  child: _showSearchResults
                      ? _buildSearchResults(isDark)
                      : _buildFeed(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BlueWave & Social',
                  style: TextStyle(
                    color: primary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Unified chapter feed',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Messages',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SocialMessagesScreen()),
              );
            },
            icon: Icon(
              Icons.chat_bubble_outline_rounded,
              color: isDark ? BlueWaveTheme.waveGlow : BlueWaveTheme.primary,
            ),
          ),
          IconButton(
            tooltip: 'Find Members',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FindMembersScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.people_outline_rounded,
              color: isDark ? BlueWaveTheme.waveGlow : BlueWaveTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    return Consumer<SocialProvider>(
      builder: (context, social, _) {
        if (social.searchResults.isEmpty) {
          return Center(
            child: Text(
              'No results for "${social.searchQuery}"',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: social.searchResults.length,
          itemBuilder: (context, index) {
            final result = social.searchResults[index];
            return ListTile(
              leading: Icon(_iconForPlatform(result.platform)),
              title: Text(
                result.title,
                style: TextStyle(
                  color: isDark ? Colors.white : fblaLightPrimaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                result.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                final item = result.feedItem;
                if (item != null) _openFeedItem(context, item, isDark);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFeed(bool isDark) {
    return Consumer<SocialProvider>(
      builder: (context, social, _) {
        if (social.loading) {
          return const SocialTabLoading();
        }
        if (social.error != null) {
          return Center(
            child: Text(
              social.error!,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          color: BlueWaveTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: BlueWaveHeader()),
              if (social.recommended.isNotEmpty)
                SliverToBoxAdapter(
                  child: _RecommendedStrip(
                    items: social.recommended,
                    isDark: isDark,
                    onTap: (item) => _openFeedItem(context, item, isDark),
                  ),
                ),
              SliverToBoxAdapter(
                child: _PhoneVideoUploadBanner(
                  isDark: isDark,
                  onUpload: () => _openVideoStudio(
                    context,
                    launchMode: VideoStudioLaunchMode.gallery,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _QuickActionsRow(
                  onStartForum: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StartForumScreen(),
                      ),
                    );
                  },
                  onOpenVideoStudio: () => _openVideoStudio(context),
                  onUploadFromPhone: () => _openVideoStudio(
                    context,
                    launchMode: VideoStudioLaunchMode.gallery,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _DiscordBridgeCard(
                  isDark: isDark,
                  onOpenHub: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: _socialProvider,
                          child: const DiscordHubScreen(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 0, 10),
                  child: Text(
                    'Social Platforms',
                    style: TextStyle(
                      color: isDark ? Colors.white : fblaLightPrimaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 130,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: social.platformLinks.length,
                    itemBuilder: (context, index) {
                      final platform = social.platformLinks[index];
                      return SocialPlatformCard(
                        platform: platform,
                        isDark: isDark,
                        onTap: () => _openPlatform(platform),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Your Feed',
                    style: TextStyle(
                      color: isDark ? Colors.white : fblaLightPrimaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = social.feedItems[index];
                    return _FeedItemBuilder(
                      item: item,
                      isDark: isDark,
                      hasWaved: item.blueWave != null
                          ? social.hasWaved(item.blueWave!.id)
                          : false,
                      onWave: item.blueWave != null
                          ? () => social.toggleWave(item.blueWave!.id)
                          : null,
                      onShare: item.blueWave != null
                          ? () => _shareBlueWavePost(context, item.blueWave!)
                          : null,
                      onOpen: () => _openFeedItem(context, item, isDark),
                      onTrackView: () => social.trackView(item),
                    );
                  },
                  childCount: social.feedItems.length,
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        );
      },
    );
  }

  void _openFeedItem(BuildContext context, FeedItem item, bool isDark) {
    context.read<SocialProvider>().trackView(item);
    switch (item.kind) {
      case FeedItemKind.instagramPost:
        InstagramFeedScreen.open(context);
        break;
      case FeedItemKind.youtubeVideo:
        if (item.youtube != null) {
          final v = item.youtube!;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(
                video: Video(
                  id: v.id,
                  title: v.title,
                  description: '',
                  thumbnailUrl: v.thumbnailUrl,
                  publishedAt: v.publishedAt,
                ),
              ),
            ),
          );
        }
        break;
      case FeedItemKind.forumThread:
        if (item.forum != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ForumThreadDetailScreen(thread: item.forum!),
            ),
          );
        }
        break;
      case FeedItemKind.newsItem:
        if (item.news != null) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(item.news!.title),
              content: Text(item.news!.summary),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
        break;
      case FeedItemKind.blueWavePost:
      case FeedItemKind.blueWaveReel:
        if (item.blueWave != null) {
          final post = item.blueWave!;
          if (post.hasVideo && post.videoUrl != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LocalVideoPlayerScreen(
                  videoSource: post.videoUrl!,
                  title: post.text,
                ),
              ),
            );
          }
        }
        break;
      default:
        break;
    }
  }

  Future<void> _shareBlueWavePost(
    BuildContext context,
    BlueWavePostData post,
  ) async {
    final app = context.read<AppState>();
    final userId = app.firebaseUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to share posts with friends.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

    final payload = {
      'postId': post.id,
      'postKind': post.kind.name,
      'postText': post.text,
      if (post.videoUrl != null && post.videoUrl!.isNotEmpty)
        'postVideoUrl': post.videoUrl,
    };

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shared with ${picked.length} friend${picked.length == 1 ? '' : 's'} in chat.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openPlatform(SocialPlatformLink platform) async {
    if (platform.inApp) {
      InstagramFeedScreen.open(context);
      return;
    }
    final uri = Uri.parse(platform.url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  IconData _iconForPlatform(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.blueWave:
        return Icons.waves_rounded;
      case SocialPlatform.instagram:
        return Icons.camera_alt_rounded;
      case SocialPlatform.youtube:
        return Icons.smart_display_rounded;
      case SocialPlatform.forum:
        return Icons.forum_outlined;
      case SocialPlatform.news:
        return Icons.newspaper_rounded;
    }
  }
}

class _RecommendedStrip extends StatelessWidget {
  final List<FeedItem> items;
  final bool isDark;
  final ValueChanged<FeedItem> onTap;

  const _RecommendedStrip({
    required this.items,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            'Recommended for you',
            style: TextStyle(
              color: isDark ? Colors.white : fblaLightPrimaryText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final title = _titleFor(item);
              return GestureDetector(
                onTap: () => onTap(item),
                child: Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BlueWaveTheme.cardDecoration(isDark: isDark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New for you',
                        style: TextStyle(
                          color: BlueWaveTheme.waveGlow,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : fblaLightPrimaryText,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _titleFor(FeedItem item) {
    return item.blueWave?.text ??
        item.youtube?.title ??
        item.forum?.title ??
        item.news?.title ??
        item.instagram?.caption ??
        'Recommended';
  }
}

class _PhoneVideoUploadBanner extends StatelessWidget {
  final bool isDark;
  final VoidCallback onUpload;

  const _PhoneVideoUploadBanner({
    required this.isDark,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    final secondary = isDark ? Colors.white70 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onUpload,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        BlueWaveTheme.primary.withValues(alpha: 0.35),
                        const Color(0xFF0A1628),
                      ]
                    : [
                        const Color(0xFFD6F0FF),
                        const Color(0xFFF0F8FF),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: BlueWaveTheme.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: BlueWaveTheme.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.upload_file_rounded,
                    color: BlueWaveTheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload a video from your phone',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share on BlueWave now — upload to YouTube anytime',
                        style: TextStyle(color: secondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white54 : Colors.black38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onStartForum;
  final VoidCallback onOpenVideoStudio;
  final VoidCallback onUploadFromPhone;

  const _QuickActionsRow({
    required this.onStartForum,
    required this.onOpenVideoStudio,
    required this.onUploadFromPhone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onUploadFromPhone,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Upload'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BlueWaveTheme.waveGlow,
                side: BorderSide(
                  color: BlueWaveTheme.primary.withValues(alpha: 0.45),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onOpenVideoStudio,
              icon: const Icon(Icons.videocam_rounded, size: 18),
              label: const Text('Studio'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BlueWaveTheme.waveGlow,
                side: BorderSide(
                  color: BlueWaveTheme.primary.withValues(alpha: 0.45),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onStartForum,
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: const Text('Forum'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BlueWaveTheme.waveGlow,
                side: BorderSide(
                  color: BlueWaveTheme.primary.withValues(alpha: 0.45),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscordBridgeCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback onOpenHub;

  const _DiscordBridgeCard({
    required this.isDark,
    required this.onOpenHub,
  });

  @override
  Widget build(BuildContext context) {
    const discordBlurple = Color(0xFF5865F2);
    final primaryText = isDark ? Colors.white : fblaLightPrimaryText;
    final secondaryText = isDark ? Colors.white70 : Colors.black54;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  discordBlurple.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.06),
                ]
              : [
                  const Color(0xFFE8EAFF),
                  Colors.white,
                ],
        ),
        border: Border.all(color: discordBlurple.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: discordBlurple.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hub_rounded, color: discordBlurple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discord Bot Sync',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Post announcements, events, and BlueWave updates to your server.',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpenHub,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open Discord Hub'),
              style: FilledButton.styleFrom(
                backgroundColor: discordBlurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedItemBuilder extends StatefulWidget {
  final FeedItem item;
  final bool isDark;
  final bool hasWaved;
  final VoidCallback? onWave;
  final VoidCallback? onShare;
  final VoidCallback onOpen;
  final VoidCallback onTrackView;

  const _FeedItemBuilder({
    required this.item,
    required this.isDark,
    required this.hasWaved,
    required this.onOpen,
    required this.onTrackView,
    this.onWave,
    this.onShare,
  });

  @override
  State<_FeedItemBuilder> createState() => _FeedItemBuilderState();
}

class _FeedItemBuilderState extends State<_FeedItemBuilder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onTrackView());
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    switch (item.kind) {
      case FeedItemKind.blueWavePost:
      case FeedItemKind.blueWaveReel:
        final post = item.blueWave!;
        return BlueWavePostCard(
          post: item.isNewForYou
              ? BlueWavePostData(
                  id: post.id,
                  author: post.author,
                  text: post.text,
                  imageUrls: post.imageUrls,
                  videoUrl: post.videoUrl,
                  kind: post.kind,
                  createdAt: post.createdAt,
                  waveCount: post.waveCount,
                  commentCount: post.commentCount,
                  tags: post.tags,
                  isRecommended: true,
                )
              : post,
          isDark: widget.isDark,
          hasWaved: widget.hasWaved,
          onWave: widget.onWave ?? () {},
          onShare: widget.onShare,
          onAuthorTap: widget.onOpen,
        );
      case FeedItemKind.instagramPost:
        return InstagramPostCard(
          post: item.instagram!,
          isDark: widget.isDark,
          onOpen: widget.onOpen,
        );
      case FeedItemKind.youtubeVideo:
        return YouTubeVideoCard(
          video: item.youtube!,
          isDark: widget.isDark,
          onPlay: widget.onOpen,
        );
      case FeedItemKind.forumThread:
        return ForumThreadCard(
          thread: item.forum!,
          isDark: widget.isDark,
          onTap: widget.onOpen,
        );
      case FeedItemKind.newsItem:
        return NewsCard(
          news: item.news!,
          isDark: widget.isDark,
          onTap: widget.onOpen,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
