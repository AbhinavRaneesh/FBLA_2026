import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart'
    show
        AppState,
        appBackgroundColor,
        appBackgroundGradient,
        fblaGold,
        fblaLightBackground,
        fblaLightBorder,
        fblaLightPrimaryText,
        fblaLightSecondaryText,
        fblaLightSurface,
        fblaNavy;
import '../../models/video_model.dart';
import '../../screens/find_members_screen.dart';
import '../../screens/instagram_feed_screen.dart';
import '../../screens/linkedin_feed_screen.dart';
import '../../screens/video_player_screen.dart';
import '../models/social_models.dart';
import '../providers/social_provider.dart';
import '../theme/bluewave_theme.dart';
import '../widgets/post_share_sheet.dart';
import '../widgets/social_feed_widgets.dart';
import 'bluewave_compose_screen.dart';
import 'discord_hub_screen.dart';
import 'forum_screens.dart';
import 'local_video_player_screen.dart';
import 'social_messages_screen.dart';
import 'video_studio_screen.dart';

/// Flagship Social tab — two-pane: Feed | Discover.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final SocialProvider _socialProvider;
  late final TabController _tabController;

  // Search overlay state
  bool _searchOpen = false;
  final _searchController = TextEditingController();
  bool _showSearchResults = false;
  bool _showCreateFab = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _showCreateFab = _tabController.index == 0);
      }
    });
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
    _tabController.dispose();
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

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        _socialProvider.clearSearch();
        _showSearchResults = false;
      }
    });
  }

  void _showCreateOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
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
                'Create',
                style: TextStyle(
                  color: isDark ? Colors.white : fblaLightPrimaryText,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              _sheetTile(
                ctx: ctx,
                isDark: isDark,
                icon: Icons.upload_file_rounded,
                color: BlueWaveTheme.primary,
                title: 'Upload from Phone',
                subtitle: 'Pick a video from your gallery',
                onTap: () {
                  Navigator.pop(ctx);
                  _openVideoStudio(context,
                      launchMode: VideoStudioLaunchMode.gallery);
                },
              ),
              _sheetTile(
                ctx: ctx,
                isDark: isDark,
                icon: Icons.videocam_rounded,
                color: BlueWaveTheme.primary,
                title: 'Video Studio',
                subtitle: 'Record, edit, and publish to FBLA or YouTube',
                onTap: () {
                  Navigator.pop(ctx);
                  _openVideoStudio(context);
                },
              ),
              _sheetTile(
                ctx: ctx,
                isDark: isDark,
                icon: Icons.waves_rounded,
                color: BlueWaveTheme.primary,
                title: 'Text Post',
                subtitle: 'Share a text update on FBLA Social',
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
              _sheetTile(
                ctx: ctx,
                isDark: isDark,
                icon: Icons.forum_outlined,
                color: fblaGold,
                title: 'Start Forum Thread',
                subtitle: 'Open a discussion with your chapter',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const StartForumScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile({
    required BuildContext ctx,
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: TextStyle(
            color: isDark ? Colors.white : fblaLightPrimaryText,
            fontWeight: FontWeight.w800,
          )),
      subtitle: Text(subtitle,
          style: TextStyle(
              color: isDark ? Colors.white54 : fblaLightSecondaryText,
              fontSize: 12)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider.value(
      value: _socialProvider,
      child: Scaffold(
        backgroundColor: isDark ? appBackgroundColor : fblaLightBackground,
        floatingActionButton: _showCreateFab
            ? FloatingActionButton(
                onPressed: () => _showCreateOptions(context),
                backgroundColor: BlueWaveTheme.primary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add_rounded),
              )
            : null,
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark ? appBackgroundGradient : null,
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(isDark),
                if (_searchOpen) _buildSearchBar(isDark),
                _buildTabBar(isDark),
                Expanded(
                  child: _showSearchResults
                      ? _buildSearchResults(isDark)
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _FeedTab(
                              onRefresh: _refresh,
                              onOpenFeedItem: (item) =>
                                  _openFeedItem(context, item, isDark),
                              onWave: (id) =>
                                  _socialProvider.toggleWave(id),
                              onShare: (item) => _shareFeedItem(context, item),
                            ),
                            _DiscoverTab(
                              isDark: isDark,
                              onOpenVideoStudio: () =>
                                  _openVideoStudio(context),
                              onTextPost: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChangeNotifierProvider.value(
                                    value: _socialProvider,
                                    child: const BlueWaveComposeScreen(),
                                  ),
                                ),
                              ),
                              onStartForum: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const StartForumScreen()),
                              ),
                              onOpenDiscord: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChangeNotifierProvider.value(
                                    value: _socialProvider,
                                    child: const DiscordHubScreen(),
                                  ),
                                ),
                              ),
                              onOpenPlatform: _openPlatform,
                              onConnectLinkedIn: () => _openLinkedIn(context),
                              onTapRecommended: (item) =>
                                  _openFeedItem(context, item, isDark),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
      child: Row(
        children: [
          // Logo mark + title
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: BlueWaveTheme.waveAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.waves_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'Social Platform',
            style: TextStyle(
              color: primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // Search
          _HeaderIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Search',
            active: _searchOpen,
            isDark: isDark,
            onTap: _toggleSearch,
          ),
          // Messages
          _HeaderIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            tooltip: 'Messages',
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SocialMessagesScreen()),
            ),
          ),
          // Members
          _HeaderIconButton(
            icon: Icons.people_outline_rounded,
            tooltip: 'Members',
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FindMembersScreen()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar (appears below header when active) ──────────────────────────

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : fblaLightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? BlueWaveTheme.primary.withValues(alpha: 0.3)
                : fblaLightBorder,
          ),
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(
            color: isDark ? Colors.white : fblaLightPrimaryText,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          onChanged: (q) {
            _socialProvider.search(q);
            setState(() => _showSearchResults = q.trim().isNotEmpty);
          },
          decoration: InputDecoration(
            hintText: 'Search posts, forums, news…',
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : fblaLightSecondaryText,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: isDark ? BlueWaveTheme.waveGlow : BlueWaveTheme.primary,
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _socialProvider.clearSearch();
                      setState(() => _showSearchResults = false);
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
          ),
        ),
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          onTap: (_) {
            // Close search if tab changes
            if (_searchOpen) _toggleSearch();
          },
          indicator: BoxDecoration(
            color: BlueWaveTheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor:
              isDark ? Colors.white60 : fblaLightPrimaryText.withValues(alpha: 0.6),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Feed'),
            Tab(text: 'Discover'),
          ],
        ),
      ),
    );
  }

  // ── Search results ─────────────────────────────────────────────────────────

  Widget _buildSearchResults(bool isDark) {
    return Consumer<SocialProvider>(
      builder: (context, social, _) {
        if (social.searchResults.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off_rounded,
                    size: 48,
                    color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(height: 12),
                Text(
                  'No results for "${social.searchQuery}"',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : fblaLightSecondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: social.searchResults.length,
          separatorBuilder: (_, __) => Divider(
            color: isDark ? Colors.white10 : fblaLightBorder,
            height: 1,
          ),
          itemBuilder: (context, index) {
            final result = social.searchResults[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BlueWaveTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconForPlatform(result.platform),
                  color: BlueWaveTheme.primary,
                  size: 18,
                ),
              ),
              title: Text(
                result.title,
                style: TextStyle(
                  color: isDark ? Colors.white : fblaLightPrimaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                result.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white54 : fblaLightSecondaryText,
                  fontSize: 12,
                ),
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

  // ── Helpers ────────────────────────────────────────────────────────────────

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
              builder: (_) =>
                  ForumThreadDetailScreen(thread: item.forum!),
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

  Future<void> _shareFeedItem(BuildContext context, FeedItem item) async {
    await SocialPostShare.showOptions(context, item);
  }

  Future<void> _openPlatform(SocialPlatformLink platform) async {
    if (platform.inApp) {
      switch (platform.name) {
        case 'Instagram':
          InstagramFeedScreen.open(context);
          return;
        case 'LinkedIn':
          LinkedInFeedScreen.open(context);
          return;
      }
    }
    final uri = Uri.parse(platform.url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openLinkedIn(BuildContext context) {
    LinkedInFeedScreen.open(context);
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

// ════════════════════════════════════════════════════════════════════════════
// Feed Tab — clean scrollable list of all feed items
// ════════════════════════════════════════════════════════════════════════════

class _FeedTab extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final void Function(FeedItem) onOpenFeedItem;
  final void Function(String postId) onWave;
  final void Function(FeedItem item) onShare;

  const _FeedTab({
    required this.onRefresh,
    required this.onOpenFeedItem,
    required this.onWave,
    required this.onShare,
  });

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<SocialProvider>(
      builder: (context, social, _) {
        if (social.loading) return const SocialTabLoading();

        if (social.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 48,
                      color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 12),
                  Text(
                    social.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : fblaLightSecondaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: widget.onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: FilledButton.styleFrom(
                        backgroundColor: BlueWaveTheme.primary),
                  ),
                ],
              ),
            ),
          );
        }

        if (social.feedItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_rounded,
                    size: 52,
                    color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(height: 12),
                Text(
                  'Nothing in your feed yet.',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : fblaLightSecondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          color: BlueWaveTheme.primary,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: social.feedItems.length,
            itemBuilder: (context, index) {
              final item = social.feedItems[index];
              return _FeedItemBuilder(
                item: item,
                isDark: isDark,
                hasWaved: item.blueWave != null
                    ? social.hasWaved(item.blueWave!.id)
                    : false,
                onWave: item.blueWave != null
                    ? () => widget.onWave(item.blueWave!.id)
                    : null,
                onShare: () => widget.onShare(item),
                onOpen: () => widget.onOpenFeedItem(item),
                onTrackView: () => social.trackView(item),
              );
            },
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Discover Tab — create, upload, discord, social platforms, recommended
// ════════════════════════════════════════════════════════════════════════════

class _DiscoverTab extends StatefulWidget {
  final bool isDark;
  final VoidCallback onOpenVideoStudio;
  final VoidCallback onTextPost;
  final VoidCallback onStartForum;
  final VoidCallback onOpenDiscord;
  final VoidCallback onConnectLinkedIn;
  final Future<void> Function(SocialPlatformLink) onOpenPlatform;
  final void Function(FeedItem) onTapRecommended;

  const _DiscoverTab({
    required this.isDark,
    required this.onOpenVideoStudio,
    required this.onTextPost,
    required this.onStartForum,
    required this.onOpenDiscord,
    required this.onConnectLinkedIn,
    required this.onOpenPlatform,
    required this.onTapRecommended,
  });

  @override
  State<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<_DiscoverTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    final secondary = isDark ? Colors.white60 : fblaLightSecondaryText;

    return Consumer<SocialProvider>(
      builder: (context, social, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            if (social.recommended.isNotEmpty) ...[
              RecommendedDiscoverStrip(
                items: social.recommended,
                isDark: isDark,
                onTap: widget.onTapRecommended,
              ),
              const SizedBox(height: 22),
            ],

            // ── Create section ──────────────────────────────────────────────
            _sectionLabel('Create', primary),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: [
                _ActionCard(
                  isDark: isDark,
                  icon: Icons.videocam_rounded,
                  color: BlueWaveTheme.primary,
                  label: 'Video Studio',
                  onTap: widget.onOpenVideoStudio,
                ),
                _ActionCard(
                  isDark: isDark,
                  icon: Icons.hub_rounded,
                  color: const Color(0xFF5865F2),
                  label: 'Discord',
                  onTap: widget.onOpenDiscord,
                ),
                _ActionCard(
                  isDark: isDark,
                  icon: Icons.waves_rounded,
                  color: BlueWaveTheme.waveGlow,
                  label: 'Text Post',
                  onTap: widget.onTextPost,
                ),
                _ActionCard(
                  isDark: isDark,
                  icon: Icons.forum_outlined,
                  color: fblaGold,
                  label: 'Forum Thread',
                  onTap: widget.onStartForum,
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ── LinkedIn ──────────────────────────────────────────────────
            _sectionLabel('LinkedIn', primary),
            const SizedBox(height: 10),
            _ConnectLinkedInCard(
              isDark: isDark,
              primary: primary,
              secondary: secondary,
              onTap: widget.onConnectLinkedIn,
            ),

            const SizedBox(height: 22),

            // ── Social platforms ────────────────────────────────────────────
            if (social.platformLinks.isNotEmpty) ...[
              _sectionLabel('Platforms', primary),
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: social.platformLinks.length,
                  itemBuilder: (context, index) {
                    final platform = social.platformLinks[index];
                    return SocialPlatformCard(
                      platform: platform,
                      isDark: isDark,
                      onTap: () => widget.onOpenPlatform(platform),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: 15,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _ConnectLinkedInCard extends StatelessWidget {
  final bool isDark;
  final Color primary;
  final Color secondary;
  final VoidCallback onTap;

  static const Color _linkedInBlue = Color(0xFF0A66C2);

  const _ConnectLinkedInCard({
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : fblaLightBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _linkedInBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: _linkedInBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect to LinkedIn',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Follow FBLA and explore career updates in the app',
                      style: TextStyle(
                        color: secondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Reusable widgets
// ════════════════════════════════════════════════════════════════════════════

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDark;
  final bool active;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isDark,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? BlueWaveTheme.primaryDark : BlueWaveTheme.primary;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 22),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({
    required this.isDark,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? color.withValues(alpha: 0.2)
                  : color.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white : fblaLightPrimaryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Feed item builder (unchanged logic, kept here)
// ════════════════════════════════════════════════════════════════════════════

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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onTrackView());
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
          onShare: widget.onShare,
        );
      case FeedItemKind.youtubeVideo:
        return YouTubeVideoCard(
          video: item.youtube!,
          isDark: widget.isDark,
          onPlay: widget.onOpen,
          onShare: widget.onShare,
        );
      case FeedItemKind.forumThread:
        return ForumThreadCard(
          thread: item.forum!,
          isDark: widget.isDark,
          onTap: widget.onOpen,
          onShare: widget.onShare,
        );
      case FeedItemKind.newsItem:
        return NewsCard(
          news: item.news!,
          isDark: widget.isDark,
          onTap: widget.onOpen,
          onShare: widget.onShare,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
