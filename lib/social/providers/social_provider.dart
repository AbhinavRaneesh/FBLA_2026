import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../main.dart' show ChatThread, NewsItem;
import '../../services/youtube_upload_service.dart';
import '../models/social_models.dart';
import '../services/social_data_service.dart';
import '../services/social_ml_service.dart';
import '../services/social_preferences_store.dart';

/// Central state for the Social tab — loads content, applies ML ranking, tracks behavior.
class SocialProvider extends ChangeNotifier {
  SocialProvider({
    SocialPreferencesStore? store,
    SocialDataService? dataService,
    SocialMlService? mlService,
  })  : _store = store ?? SocialPreferencesStore(),
        _dataService = dataService ?? SocialDataService(),
        _mlService = mlService ?? SocialMlService();

  final SocialPreferencesStore _store;
  final SocialDataService _dataService;
  final SocialMlService _mlService;

  UserPreferences _preferences = const UserPreferences();
  List<UserInteraction> _interactions = [];
  List<FeedItem> _feedItems = [];
  List<FeedItem> _recommended = [];
  List<SocialSearchResult> _searchResults = [];
  Set<String> _wavedPostIds = {};
  List<BlueWavePostData> _myVideoPosts = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Async work (initialize, ranking, store I/O) can complete after the Social
  // screen is popped and this provider is disposed. Swallow notifications in
  // that window instead of throwing "used after being disposed".
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  UserPreferences get preferences => _preferences;
  List<FeedItem> get feedItems => _feedItems;
  List<FeedItem> get recommended => _recommended;
  List<SocialSearchResult> get searchResults => _searchResults;
  Set<String> get wavedPostIds => _wavedPostIds;
  List<BlueWavePostData> get myVideoPosts => _myVideoPosts;
  bool get loading => _loading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  bool get needsOnboarding => !_preferences.onboardingComplete;

  List<SocialPlatformLink> get platformLinks => _dataService.platformLinks();

  Future<void> initialize({
    required List<dynamic> news,
    required List<dynamic> threads,
    required String displayName,
    required String userId,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _preferences = await _store.loadPreferences();
      _interactions = await _store.loadInteractions();
      _wavedPostIds = await _store.loadWavedPostIds();

      final savedPosts = await _store.loadBlueWavePosts();
      final seedPosts = _dataService.seedBlueWavePosts();
      final blueWave = [...savedPosts, ...seedPosts];

      final instagram = await _dataService.fetchInstagramPosts();
      final youtube = await _dataService.fetchYouTubeVideos();
      final forums = _dataService.buildForumThreads(
        threads.cast<ChatThread>(),
      );
      final newsItems = _dataService.buildNewsItems(news.cast<NewsItem>());

      final raw = _dataService.assembleRawFeed(
        blueWavePosts: blueWave,
        instagramPosts: instagram,
        youtubeVideos: youtube,
        forumThreads: forums,
        newsItems: newsItems,
      );

      _recommended = _mlService.getRecommendedContent(
        preferences: _preferences,
        interactions: _interactions,
        allContent: raw,
      );

      _feedItems = _mlService.rankFeedItems(
        preferences: _preferences,
        interactions: _interactions,
        items: raw,
      );
      _myVideoPosts = await _store.loadVideoPostsForUser(userId);
    } catch (e) {
      _error = 'Could not load social feed.';
      if (kDebugMode) {
        print('SocialProvider initialize error: $e');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding(UserPreferences updated) async {
    _preferences = updated.copyWith(onboardingComplete: true);
    await _store.savePreferences(_preferences);
    notifyListeners();
    // Re-rank with new weights from survey responses.
    await _refreshRanking();
  }

  Future<void> _refreshRanking() async {
    final raw = _feedItems
        .where((i) =>
            i.kind != FeedItemKind.sectionHeader &&
            i.kind != FeedItemKind.recommendedHeader)
        .toList();
    _recommended = _mlService.getRecommendedContent(
      preferences: _preferences,
      interactions: _interactions,
      allContent: raw,
    );
    _feedItems = _mlService.rankFeedItems(
      preferences: _preferences,
      interactions: _interactions,
      items: raw,
    );
    notifyListeners();
  }

  Future<void> trackView(FeedItem item) async {
    final interaction = UserInteraction(
      contentId: item.id,
      platform: item.metadata.platform,
      timestamp: DateTime.now(),
      viewed: true,
      secondsViewed: 8,
    );
    await _store.saveInteraction(interaction);
    _interactions = await _store.loadInteractions();
  }

  Future<void> toggleWave(String postId) async {
    await _store.toggleWave(postId);
    _wavedPostIds = await _store.loadWavedPostIds();

    final interaction = UserInteraction(
      contentId: postId,
      platform: SocialPlatform.blueWave,
      timestamp: DateTime.now(),
      reacted: !_wavedPostIds.contains(postId),
    );
    await _store.saveInteraction(interaction);
    _interactions = await _store.loadInteractions();
    notifyListeners();
  }

  bool hasWaved(String postId) => _wavedPostIds.contains(postId);

  Future<void> addBlueWavePost(BlueWavePostData post) async {
    await _store.saveBlueWavePost(post);
    final isReel = post.kind == BlueWavePostKind.reel;
    final newItem = FeedItem(
      id: post.id,
      kind: isReel ? FeedItemKind.blueWaveReel : FeedItemKind.blueWavePost,
      metadata: ContentMetadata(
        id: post.id,
        platform: SocialPlatform.blueWave,
        contentTypeLabel: isReel ? 'Reel' : post.kind.name,
        tags: post.tags,
        likes: post.waveCount,
        comments: post.commentCount,
        views: 0,
        publishedAt: post.createdAt,
        authorId: post.author.id,
      ),
      blueWave: post,
    );
    final raw = [newItem, ..._feedItems];
    _feedItems = _mlService.rankFeedItems(
      preferences: _preferences,
      interactions: _interactions,
      items: raw,
    );
    if (post.hasVideo ||
        post.kind == BlueWavePostKind.video ||
        post.kind == BlueWavePostKind.reel) {
      _myVideoPosts = [post, ..._myVideoPosts.where((p) => p.id != post.id)];
    }
    notifyListeners();
  }

  Future<void> updateBlueWavePost(BlueWavePostData post) async {
    await _store.saveBlueWavePost(post);
    _feedItems = _feedItems.map((item) {
      if (item.blueWave?.id == post.id) {
        final isReel = post.kind == BlueWavePostKind.reel;
        return FeedItem(
          id: post.id,
          kind: isReel ? FeedItemKind.blueWaveReel : FeedItemKind.blueWavePost,
          metadata: item.metadata,
          blueWave: post,
        );
      }
      return item;
    }).toList();
    _myVideoPosts =
        _myVideoPosts.map((p) => p.id == post.id ? post : p).toList();
    notifyListeners();
  }

  Future<List<BlueWavePostData>> reloadMyVideoPosts(String userId) async {
    _myVideoPosts = await _store.loadVideoPostsForUser(userId);
    notifyListeners();
    return _myVideoPosts;
  }

  Future<YouTubeUploadResult> uploadPostToYouTube({
    required BlueWavePostData post,
    required YouTubeUploadService uploadService,
    String privacyStatus = 'public',
    bool uploadAsShort = false,
    void Function(double progress)? onProgress,
  }) async {
    if (post.isOnYouTube) {
      throw Exception('This video is already on YouTube.');
    }
    if (post.videoUrl == null || post.videoUrl!.isEmpty) {
      throw Exception('No video file found for this post.');
    }

    onProgress?.call(0.02);
    final url = post.videoUrl!;
    late final File videoFile;
    var deleteTempAfter = false;

    if (url.startsWith('http')) {
      videoFile = await uploadService.downloadToTempFile(url, post.id);
      deleteTempAfter = true;
    } else {
      videoFile = File(url);
      if (!await videoFile.exists()) {
        throw Exception(
          'Video file is no longer on this device. Re-record and publish again.',
        );
      }
    }

    try {
      final result = await uploadService.uploadVideo(
        videoFile: videoFile,
        title: post.text.isNotEmpty ? post.text : 'FBLA BlueWave Video',
        description: [
          post.text,
          if (post.tags.isNotEmpty) post.tags.join(' '),
          '#FBLA #BlueWave',
        ].where((s) => s.isNotEmpty).join('\n\n'),
        privacyStatus: privacyStatus,
        uploadAsShort: uploadAsShort,
        onProgress: (p) => onProgress?.call(0.05 + p * 0.95),
      );

      final updated = post.copyWith(youtubeVideoId: result.videoId);
      await updateBlueWavePost(updated);
      return result;
    } finally {
      if (deleteTempAfter && await videoFile.exists()) {
        await videoFile.delete();
      }
    }
  }

  void search(String query, {List<SocialAuthor> members = const []}) {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _searchResults = _mlService.searchContent(
      query: query,
      preferences: _preferences,
      interactions: _interactions,
      items: _feedItems,
      members: members,
    );
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }

  Future<void> refresh({
    required List<dynamic> news,
    required List<dynamic> threads,
    required String displayName,
    required String userId,
  }) async {
    await initialize(
      news: news,
      threads: threads,
      displayName: displayName,
      userId: userId,
    );
  }
}
