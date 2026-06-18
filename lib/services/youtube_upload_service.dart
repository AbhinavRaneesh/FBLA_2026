import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Uploads videos to the signed-in user's YouTube channel via OAuth.
class YouTubeUploadService {
  static const String uploadScope =
      'https://www.googleapis.com/auth/youtube.upload';
  static const String _serverClientId =
      '1023723280371-7o7ocf59j4iod547576cmonp6lgoncfb.apps.googleusercontent.com';

  final http.Client _client;
  GoogleSignIn? _googleSignIn;

  YouTubeUploadService({http.Client? client}) : _client = client ?? http.Client();

  GoogleSignIn get _signIn => _googleSignIn ??= GoogleSignIn(
        scopes: const [uploadScope],
        serverClientId: _serverClientId,
      );

  /// Silent check — does not show the sign-in UI.
  Future<String?> currentAccountEmail() async {
    try {
      final account = await _signIn.signInSilently();
      return account?.email;
    } catch (_) {
      return null;
    }
  }

  /// Returns the connected Google account email, or null if cancelled.
  Future<String?> ensureSignedIn() async {
    try {
      var account = await _signIn.signInSilently();
      account ??= await _signIn.signIn();
      return account?.email;
    } catch (e) {
      if (kDebugMode) print('YouTubeUploadService sign-in error: $e');
      rethrow;
    }
  }

  Future<String?> _accessToken() async {
    var account = await _signIn.signInSilently();
    account ??= await _signIn.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.accessToken;
  }

  /// Resumable upload to the user's YouTube channel.
  Future<YouTubeUploadResult> uploadVideo({
    required File videoFile,
    required String title,
    String description = '',
    String privacyStatus = 'public',
    void Function(double progress)? onProgress,
  }) async {
    final token = await _accessToken();
    if (token == null) {
      throw Exception('YouTube sign-in was cancelled.');
    }

    if (!await videoFile.exists()) {
      throw Exception('Video file not found.');
    }

    final fileLength = await videoFile.length();
    if (fileLength == 0) {
      throw Exception('Video file is empty.');
    }

    onProgress?.call(0.05);

    final initUri = Uri.parse(
      'https://www.googleapis.com/upload/youtube/v3/videos'
      '?uploadType=resumable&part=snippet,status',
    );

    final initBody = jsonEncode({
      'snippet': {
        'title': title.length > 100 ? title.substring(0, 100) : title,
        'description': description,
        'categoryId': '22',
      },
      'status': {
        'privacyStatus': privacyStatus,
        'selfDeclaredMadeForKids': false,
      },
    });

    final initResponse = await _client.post(
      initUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': 'video/*',
        'X-Upload-Content-Length': '$fileLength',
      },
      body: initBody,
    );

    if (initResponse.statusCode != 200) {
      throw Exception(_parseError(initResponse));
    }

    final uploadUrl = initResponse.headers['location'];
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw Exception('YouTube did not return an upload URL.');
    }

    onProgress?.call(0.15);

    final bytes = await videoFile.readAsBytes();
    onProgress?.call(0.35);

    final uploadResponse = await _client.put(
      Uri.parse(uploadUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'video/*',
        'Content-Length': '$fileLength',
      },
      body: bytes,
    );

    onProgress?.call(0.95);

    if (uploadResponse.statusCode != 200 && uploadResponse.statusCode != 201) {
      throw Exception(_parseError(uploadResponse));
    }

    final decoded = jsonDecode(uploadResponse.body) as Map<String, dynamic>;
    final videoId = decoded['id']?.toString() ?? '';
    if (videoId.isEmpty) {
      throw Exception('Upload succeeded but no video ID was returned.');
    }

    onProgress?.call(1.0);

    return YouTubeUploadResult(
      videoId: videoId,
      watchUrl: 'https://www.youtube.com/watch?v=$videoId',
    );
  }

  /// Download a remote video to a temp file for YouTube re-upload.
  Future<File> downloadToTempFile(String url, String postId) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Could not download video for YouTube upload.');
    }
    final file = File('${Directory.systemTemp.path}/bw_yt_$postId.mp4');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  Future<void> signOut() => _signIn.signOut();

  String _parseError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      final message = (error?['message'] ?? '').toString();
      if (message.isNotEmpty) {
        return 'YouTube upload failed (${response.statusCode}): $message';
      }
    } catch (_) {}
    return 'YouTube upload failed (${response.statusCode}).';
  }
}

class YouTubeUploadResult {
  final String videoId;
  final String watchUrl;

  const YouTubeUploadResult({
    required this.videoId,
    required this.watchUrl,
  });
}
