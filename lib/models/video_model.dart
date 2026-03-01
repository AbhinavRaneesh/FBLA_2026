class Video {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final DateTime publishedAt;

  const Video({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.publishedAt,
  });

  factory Video.fromPlaylistItem(Map<String, dynamic> item) {
    final snippet = (item['snippet'] as Map<String, dynamic>?) ?? {};
    final contentDetails =
        (item['contentDetails'] as Map<String, dynamic>?) ?? {};

    final videoId =
        (contentDetails['videoId'] ?? snippet['resourceId']?['videoId'] ?? '')
            .toString();

    final thumbnails = (snippet['thumbnails'] as Map<String, dynamic>?) ?? {};
    final thumbnailUrl =
        (thumbnails['high']?['url'] ??
                thumbnails['medium']?['url'] ??
                thumbnails['default']?['url'] ??
                '')
            .toString();

    return Video(
      id: videoId,
      title: (snippet['title'] ?? '').toString(),
      description: (snippet['description'] ?? '').toString(),
      thumbnailUrl: thumbnailUrl,
      publishedAt:
          DateTime.tryParse((snippet['publishedAt'] ?? '').toString()) ??
              DateTime.now(),
    );
  }
}
