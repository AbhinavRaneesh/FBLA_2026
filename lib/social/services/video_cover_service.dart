import 'dart:typed_data';

import 'package:video_thumbnail/video_thumbnail.dart';

/// Generates JPEG cover frames from local or remote video sources.
class VideoCoverService {
  VideoCoverService._();

  static Future<Uint8List?> thumbnailBytesForFile(String filePath) {
    return VideoThumbnail.thumbnailData(
      video: filePath,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 720,
      quality: 82,
      timeMs: 750,
    );
  }

  static Future<Uint8List?> thumbnailBytesForUrl(String videoUrl) {
    return VideoThumbnail.thumbnailData(
      video: videoUrl,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 720,
      quality: 82,
      timeMs: 750,
    );
  }
}
