import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/video_model.dart';

class YouTubeService {
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';

  static const String apiKey = String.fromEnvironment(
    'YOUTUBE_API_KEY',
    defaultValue: 'AIzaSyAZbFcu5hj6n7j7UddXA3e8WKQZpzTrQ9E',
  );
  static const String channelId = String.fromEnvironment(
    'YOUTUBE_CHANNEL_ID',
    defaultValue: 'UCt2JXOLNxqry7B_4rRZME3Q',
  );

  final http.Client _client;

  YouTubeService({http.Client? client}) : _client = client ?? http.Client();

  void _validateConfig() {
    if (apiKey.trim().isEmpty || apiKey == 'YOUR_API_KEY_HERE') {
      throw Exception('Missing YouTube API key. Set YOUTUBE_API_KEY.');
    }
    if (channelId.trim().isEmpty || channelId == 'YOUR_CHANNEL_ID_HERE') {
      throw Exception('Missing YouTube channel id. Set YOUTUBE_CHANNEL_ID.');
    }
  }

  Future<String> fetchUploadsPlaylistId() async {
    _validateConfig();

    final uri = Uri.parse(
      '$_baseUrl/channels?part=contentDetails&id=$channelId&key=$apiKey',
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception(_extractApiError(response.body, response.statusCode));
    }

    final Map<String, dynamic> decoded =
        jsonDecode(response.body) as Map<String, dynamic>;
    final items = (decoded['items'] as List?) ?? [];

    if (items.isEmpty) {
      throw Exception('Channel not found. Check your CHANNEL_ID.');
    }

    final first = items.first as Map<String, dynamic>;
    final contentDetails =
        (first['contentDetails'] as Map<String, dynamic>?) ?? {};
    final relatedPlaylists =
        (contentDetails['relatedPlaylists'] as Map<String, dynamic>?) ?? {};
    final uploads = (relatedPlaylists['uploads'] ?? '').toString();

    if (uploads.isEmpty) {
      throw Exception('Uploads playlist not available for this channel.');
    }

    return uploads;
  }

  Future<List<Video>> fetchVideos({int maxResults = 15}) async {
    final uploadsPlaylistId = await fetchUploadsPlaylistId();

    final uri = Uri.parse(
      '$_baseUrl/playlistItems?part=snippet,contentDetails&playlistId=$uploadsPlaylistId&maxResults=$maxResults&key=$apiKey',
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception(_extractApiError(response.body, response.statusCode));
    }

    final Map<String, dynamic> decoded =
        jsonDecode(response.body) as Map<String, dynamic>;
    final items = (decoded['items'] as List?) ?? [];

    return items
        .whereType<Map<String, dynamic>>()
        .map(Video.fromPlaylistItem)
        .where((video) => video.id.isNotEmpty)
        .toList(growable: false);
  }

  String _extractApiError(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      final message = (error?['message'] ?? '').toString();
      if (message.isNotEmpty) {
        return 'YouTube API error ($statusCode): $message';
      }
    } catch (_) {
      return 'YouTube API error ($statusCode).';
    }

    return 'YouTube API error ($statusCode).';
  }
}
