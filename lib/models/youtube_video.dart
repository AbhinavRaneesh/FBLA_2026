class YouTubeVideo {
  final String id;
  final String title;
  final String channelName;
  final String videoUrl;
  final String thumbnailUrl;
  final DateTime publishedAt;

  const YouTubeVideo({
    required this.id,
    required this.title,
    required this.channelName,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.publishedAt,
  });
}
