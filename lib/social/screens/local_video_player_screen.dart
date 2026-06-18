import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../main.dart' show fblaNavy;

/// Full-screen playback for local files or network video URLs.
class LocalVideoPlayerScreen extends StatefulWidget {
  final String videoSource;
  final String title;

  const LocalVideoPlayerScreen({
    super.key,
    required this.videoSource,
    this.title = 'Video',
  });

  @override
  State<LocalVideoPlayerScreen> createState() => _LocalVideoPlayerScreenState();
}

class _LocalVideoPlayerScreenState extends State<LocalVideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _initializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final source = widget.videoSource;
      final controller = source.startsWith('http')
          ? VideoPlayerController.networkUrl(Uri.parse(source))
          : VideoPlayerController.file(File(source));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
      controller.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not play video.';
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: fblaNavy,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: Center(
        child: _initializing
            ? const CircularProgressIndicator(color: Colors.white)
            : _error != null
                ? Text(_error!, style: const TextStyle(color: Colors.white70))
                : c != null && c.value.isInitialized
                    ? GestureDetector(
                        onTap: _togglePlay,
                        child: AspectRatio(
                          aspectRatio: c.value.aspectRatio == 0
                              ? 16 / 9
                              : c.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(c),
                              if (!c.value.isPlaying)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
      ),
    );
  }
}
