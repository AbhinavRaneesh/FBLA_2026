import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart'
    show AppState, ProfileScreen, appBackgroundGradient, fblaLightBackground, fblaLightPrimaryText;
import '../../models/video_model.dart';
import '../../screens/find_members_screen.dart';
import '../../screens/instagram_feed_screen.dart';
import '../../screens/video_player_screen.dart';
import '../models/social_models.dart';
import '../providers/social_provider.dart';
import '../theme/bluewave_theme.dart';
import '../widgets/social_feed_widgets.dart';
import 'bluewave_compose_screen.dart';
import 'forum_screens.dart';
import 'onboarding_survey_modal.dart';
import 'social_messages_screen.dart';

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
    if (!mounted) return;
    if (_socialProvider.needsOnboarding) {
      await OnboardingSurveyModal.show(
        context,
        onComplete: _socialProvider.completeOnboarding,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider.value(
      value: _socialProvider,
      child: Scaffold(
        backgroundColor: isDark ? Colors.transparent : fblaLightBackground,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
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
                        setState(() => _showSearchResults = q.trim().isNotEmpty);
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
          return const Center(
            child: CircularProgressIndicator(color: BlueWaveTheme.primary),
          );
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
                child: _QuickActionsRow(
                  onStartForum: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StartForumScreen(),
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(),
            ),
          );
        }
        break;
      default:
        break;
    }
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

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onStartForum;

  const _QuickActionsRow({required this.onStartForum});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onStartForum,
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: const Text('Start Forum'),
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

class _FeedItemBuilder extends StatefulWidget {
  final FeedItem item;
  final bool isDark;
  final bool hasWaved;
  final VoidCallback? onWave;
  final VoidCallback onOpen;
  final VoidCallback onTrackView;

  const _FeedItemBuilder({
    required this.item,
    required this.isDark,
    required this.hasWaved,
    required this.onOpen,
    required this.onTrackView,
    this.onWave,
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
