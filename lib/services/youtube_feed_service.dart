import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/youtube_video.dart';

class YouTubeFeedService {
  static const String _baseUrl =
      'https://www.youtube.com/feeds/videos.xml?channel_id=';

  static Future<List<YouTubeVideo>> getChannelVideos({
    required String channelId,
    int limit = 10,
  }) async {
    final uri = Uri.parse('$_baseUrl$channelId');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load YouTube feed (${response.statusCode})');
    }

    final document = XmlDocument.parse(response.body);
    final entries = document.findAllElements('entry');

    final videos = <YouTubeVideo>[];

    for (final entry in entries) {
      final videoId = _findText(entry, const ['yt:videoId', 'videoId']);
      final title = _findText(entry, const ['title']);
      final channelName =
          _findText(entry, const ['author', 'name']) ?? 'YouTube';
      final publishedText = _findText(entry, const ['published']);

      final videoLink = entry
          .findElements('link')
          .map((element) => element.getAttribute('href'))
          .whereType<String>()
          .firstWhere(
            (url) => url.contains('watch?v='),
            orElse: () => '',
          );

      final thumbnail = _findThumbnailUrl(entry);

      if (videoId == null || title == null) {
        continue;
      }

      videos.add(
        YouTubeVideo(
          id: videoId,
          title: title,
          channelName: channelName,
          videoUrl: videoLink.isNotEmpty
              ? videoLink
              : 'https://www.youtube.com/watch?v=$videoId',
          thumbnailUrl: thumbnail ?? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
          publishedAt:
              DateTime.tryParse(publishedText ?? '') ?? DateTime.now(),
        ),
      );

      if (videos.length >= limit) {
        break;
      }
    }

    return videos;
  }

  static String? _findText(XmlElement root, List<String> elementPath) {
    Iterable<XmlElement> current = [root];

    for (final tag in elementPath) {
      XmlElement? next;
      for (final node in current) {
        for (final child in node.children.whereType<XmlElement>()) {
          if (child.name.toString() == tag || child.name.local == tag) {
            next = child;
            break;
          }
        }
        if (next != null) {
          break;
        }
      }

      if (next == null) {
        return null;
      }

      current = [next];
    }

    final text = current.first.innerText.trim();
    return text.isEmpty ? null : text;
  }

  static String? _findThumbnailUrl(XmlElement entry) {
    for (final node in entry.descendants.whereType<XmlElement>()) {
      final name = node.name.toString();
      if (name == 'media:thumbnail' || node.name.local == 'thumbnail') {
        final url = node.getAttribute('url');
        if (url != null && url.isNotEmpty) {
          return url;
        }
      }
    }
    return null;
  }
}
