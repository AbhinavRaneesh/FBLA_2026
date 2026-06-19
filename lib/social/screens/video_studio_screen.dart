import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../main.dart'
    show
        AppState,
        appBackgroundColor,
        appBackgroundGradient,
        fblaBlue,
        fblaGold,
        fblaLightBackground,
        fblaLightBorder,
        fblaLightPrimaryText,
        fblaLightSecondaryText,
        fblaLightSurface,
        fblaNavy;
import '../../services/firebase_service.dart';
import '../../services/youtube_upload_service.dart';
import '../models/social_models.dart';
import '../providers/social_provider.dart';
import '../theme/bluewave_theme.dart';
import 'local_video_player_screen.dart';

/// How Video Studio opens (e.g. straight to phone gallery).
enum VideoStudioLaunchMode { none, gallery, camera }

/// Record or import a video, publish to BlueWave, and optionally upload to YouTube.
class VideoStudioScreen extends StatefulWidget {
  final VideoStudioLaunchMode launchMode;

  const VideoStudioScreen({
    super.key,
    this.launchMode = VideoStudioLaunchMode.none,
  });

  @override
  State<VideoStudioScreen> createState() => _VideoStudioScreenState();
}

class _VideoStudioScreenState extends State<VideoStudioScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _picker = ImagePicker();
  final _youtubeUpload = YouTubeUploadService();

  VideoPlayerController? _previewController;
  File? _videoFile;
  bool _busy = false;
  bool _alsoUploadToYouTube = false;
  double _uploadProgress = 0;
  String? _busyLabel;
  String? _youtubeAccountEmail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyPosts();
      _checkYouTubeSignIn();
      if (widget.launchMode == VideoStudioLaunchMode.gallery) {
        _pickVideo(ImageSource.gallery);
      } else if (widget.launchMode == VideoStudioLaunchMode.camera) {
        _pickVideo(ImageSource.camera);
      }
    });
  }

  Future<void> _loadMyPosts() async {
    final app = context.read<AppState>();
    final userId = app.firebaseUser?.uid ?? 'guest';
    await context.read<SocialProvider>().reloadMyVideoPosts(userId);
  }

  Future<void> _checkYouTubeSignIn() async {
    final email = await _youtubeUpload.currentAccountEmail();
    if (mounted && email != null) {
      setState(() => _youtubeAccountEmail = email);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  BoxDecoration _panel(bool isDark) => BoxDecoration(
        color: isDark ? null : fblaLightSurface,
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0F1C31), Color(0xFF0A1628)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : fblaLightBorder),
      );

  InputDecoration _fieldDecoration(String label, String hint, bool isDark) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : fblaLightBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : fblaLightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : fblaLightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? fblaGold : fblaNavy,
            width: 1.4,
          ),
        ),
      );

  Future<void> _pickVideo(ImageSource source) async {
    setState(() {
      _busy = true;
      _busyLabel = source == ImageSource.camera
          ? 'Opening camera...'
          : 'Opening gallery...';
    });
    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 10),
      );
      if (picked == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      await _previewController?.dispose();
      final file = File(picked.path);
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _videoFile = file;
        _previewController = controller;
        _busy = false;
        _busyLabel = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _busyLabel = null;
      });
      _snack('Could not load video: $e');
    }
  }

  void _togglePreviewPlay() {
    final c = _previewController;
    if (c == null) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  Future<void> _publishToBlueWave() async {
    if (_videoFile == null) {
      _snack('Choose a video from your phone or record one first.');
      return;
    }
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _snack('Add a title for your video.');
      return;
    }

    final app = context.read<AppState>();
    final firebaseUser = app.firebaseUser;
    if (firebaseUser == null) {
      _snack('Sign in to upload videos to BlueWave and YouTube.');
      return;
    }

    final social = context.read<SocialProvider>();
    final userId = firebaseUser.uid;
    final postId = 'bw_vid_${DateTime.now().millisecondsSinceEpoch}';
    final description = _descriptionController.text.trim();
    final alsoYouTube = _alsoUploadToYouTube;

    setState(() {
      _busy = true;
      _uploadProgress = 0;
      _busyLabel = 'Uploading video to BlueWave...';
    });

    try {
      final videoUrl = await FirebaseService.uploadBlueWaveVideo(
        userId,
        postId,
        _videoFile!,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _uploadProgress = p;
              _busyLabel =
                  'Uploading video... ${(p * 100).clamp(0, 100).round()}%';
            });
          }
        },
      );

      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .map((t) => t.startsWith('#') ? t : '#$t')
          .toList();

      final post = BlueWavePostData(
        id: postId,
        author: SocialAuthor(
          id: userId,
          name: app.displayName.isNotEmpty ? app.displayName : 'Member',
          photoUrl: app.userProfile?.photoUrl,
          role: app.userProfile?.officerPosition ?? 'Member',
        ),
        text: title,
        videoUrl: videoUrl,
        kind: BlueWavePostKind.video,
        createdAt: DateTime.now(),
        tags: tags,
      );

      await social.addBlueWavePost(post);
      await social.reloadMyVideoPosts(userId);

      if (!mounted) return;
      setState(() {
        _busy = false;
        _busyLabel = null;
        _uploadProgress = 0;
        _videoFile = null;
        _alsoUploadToYouTube = false;
        _titleController.clear();
        _descriptionController.clear();
        _tagsController.clear();
      });
      await _previewController?.dispose();
      _previewController = null;

      _snack('Video published to BlueWave!');
      if (alsoYouTube) {
        await _uploadToYouTube(post, description: description);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _busyLabel = null;
        _uploadProgress = 0;
      });
      _snack('Publish failed: $e');
    }
  }

  Future<void> _uploadToYouTube(
    BlueWavePostData post, {
    String description = '',
  }) async {
    final options = await _promptYouTubeUploadOptions();
    if (options == null || !mounted) return;

    final social = context.read<SocialProvider>();

    setState(() {
      _busy = true;
      _uploadProgress = 0;
      _busyLabel = 'Connecting to YouTube...';
    });

    try {
      final email = await _youtubeUpload.ensureSignedIn();
      if (email == null) {
        throw Exception('YouTube sign-in was cancelled.');
      }
      if (mounted) setState(() => _youtubeAccountEmail = email);

      final postWithDesc = description.isNotEmpty
          ? post.copyWith(text: '${post.text}\n\n$description')
          : post;

      final result = await social.uploadPostToYouTube(
        post: postWithDesc,
        uploadService: _youtubeUpload,
        privacyStatus: options.privacyStatus,
        uploadAsShort: options.asShort,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _uploadProgress = p;
              _busyLabel = 'Uploading to YouTube... ${(p * 100).round()}%';
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _busyLabel = null;
        _uploadProgress = 0;
      });

      _snack(
        options.asShort
            ? 'Short uploaded to YouTube (${options.isPublic ? 'Public' : 'Unlisted'})!'
            : 'Video uploaded to YouTube (${options.isPublic ? 'Public' : 'Unlisted'})!',
      );
      if (await canLaunchUrl(Uri.parse(result.watchUrl))) {
        await launchUrl(
          Uri.parse(result.watchUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _busyLabel = null;
        _uploadProgress = 0;
      });
      _snack('YouTube upload failed: $e');
    }
  }

  Future<YouTubeUploadOptions?> _promptYouTubeUploadOptions() async {
    var asShort = false;
    var privacy = 'public';

    return showModalBottomSheet<YouTubeUploadOptions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surface = isDark ? const Color(0xFF0F1C31) : fblaLightSurface;
        final primary = isDark ? Colors.white : fblaLightPrimaryText;
        final secondary = isDark ? Colors.white70 : fblaLightSecondaryText;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? Colors.white12 : fblaLightBorder,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: secondary.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.smart_display_rounded,
                            color: Color(0xFFFF0000),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'YouTube upload settings',
                            style: TextStyle(
                              color: primary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose how this upload should appear on your channel.',
                      style: TextStyle(color: secondary, height: 1.35),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Upload as',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ytChoiceTile(
                            selected: !asShort,
                            icon: Icons.movie_creation_outlined,
                            label: 'Video',
                            subtitle: 'Standard YouTube video',
                            onTap: () => setModalState(() => asShort = false),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ytChoiceTile(
                            selected: asShort,
                            icon: Icons.short_text_rounded,
                            label: 'Short',
                            subtitle: 'Vertical short (adds #Shorts)',
                            onTap: () => setModalState(() => asShort = true),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Who can view it?',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ytChoiceTile(
                            selected: privacy == 'public',
                            icon: Icons.public_rounded,
                            label: 'Public',
                            subtitle: 'Anyone can find and watch',
                            onTap: () =>
                                setModalState(() => privacy = 'public'),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ytChoiceTile(
                            selected: privacy == 'unlisted',
                            icon: Icons.link_rounded,
                            label: 'Unlisted',
                            subtitle: 'Only people with the link',
                            onTap: () =>
                                setModalState(() => privacy = 'unlisted'),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(
                              ctx,
                              YouTubeUploadOptions(
                                asShort: asShort,
                                privacyStatus: privacy,
                              ),
                            ),
                            icon: const Icon(Icons.upload_rounded, size: 20),
                            label: const Text(
                              'Upload to YouTube',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF0000),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _ytChoiceTile({
    required bool selected,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final accent = selected
        ? (isDark ? fblaGold : fblaBlue)
        : (isDark ? Colors.white38 : Colors.black38);
    final border = selected
        ? (isDark ? fblaGold : fblaBlue)
        : (isDark ? Colors.white12 : fblaLightBorder);
    final fill = selected
        ? (isDark ? fblaGold.withValues(alpha: 0.12) : fblaBlue.withValues(alpha: 0.08))
        : (isDark ? Colors.white.withValues(alpha: 0.04) : fblaLightBackground);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: selected ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white : fblaLightPrimaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? Colors.white54 : fblaLightSecondaryText,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    final secondary = isDark ? Colors.white70 : fblaLightSecondaryText;

    return Scaffold(
      backgroundColor: isDark ? appBackgroundColor : fblaLightBackground,
      appBar: AppBar(
        backgroundColor: fblaNavy,
        foregroundColor: Colors.white,
        title: const Text(
          'Video Studio',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: isDark ? appBackgroundGradient : null,
              color: isDark ? null : fblaLightBackground,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _heroBanner(isDark, primary, secondary),
                const SizedBox(height: 14),
                _createSection(isDark, primary, secondary),
                const SizedBox(height: 24),
                _myPostsSection(isDark, primary, secondary),
              ],
            ),
          ),
          if (_busy) _busyOverlay(isDark),
        ],
      ),
    );
  }

  Widget _heroBanner(bool isDark, Color primary, Color secondary) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  BlueWaveTheme.primary.withValues(alpha: 0.35),
                  fblaNavy.withValues(alpha: 0.9),
                ]
              : [
                  const Color(0xFFE0F4FE),
                  const Color(0xFFF5F8FC),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: BlueWaveTheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: BlueWaveTheme.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: BlueWaveTheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create & share your story',
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload from your phone to BlueWave, then share to YouTube when you are ready.',
                  style: TextStyle(color: secondary, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _createSection(bool isDark, Color primary, Color secondary) {
    final preview = _previewController;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Video',
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : () => _pickVideo(ImageSource.gallery),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text(
                'Upload from Phone',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: BlueWaveTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (preview != null && preview.value.isInitialized)
            GestureDetector(
              onTap: _togglePreviewPlay,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: preview.value.aspectRatio == 0
                      ? 16 / 9
                      : preview.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(preview),
                      if (!preview.value.isPlaying)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(14),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _busy ? null : () => _pickVideo(ImageSource.gallery),
              child: Container(
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : fblaLightBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : fblaLightBorder,
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_android_rounded,
                    size: 44,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap to choose a video from your phone',
                    style: TextStyle(color: secondary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MP4, MOV, and other gallery videos up to 10 min',
                    style: TextStyle(color: secondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pickVideo(ImageSource.camera),
                  icon: const Icon(Icons.videocam_rounded, size: 20),
                  label: const Text('Record'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BlueWaveTheme.primary,
                    side: BorderSide(
                      color: BlueWaveTheme.primary.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pickVideo(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 20),
                  label: const Text('From Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: fblaBlue,
                    side: BorderSide(color: fblaBlue.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            style: TextStyle(color: primary),
            decoration: _fieldDecoration('Video title', 'My FBLA chapter update', isDark),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            style: TextStyle(color: primary),
            decoration: _fieldDecoration(
              'Description (optional)',
              'Tell viewers what your video is about...',
              isDark,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tagsController,
            style: TextStyle(color: primary),
            decoration: _fieldDecoration('Tags', 'Competition, Leadership, NLC', isDark),
          ),
          if (_youtubeAccountEmail != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.smart_display_rounded,
                      color: Color(0xFFFF0000), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'YouTube: $_youtubeAccountEmail',
                      style: TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _alsoUploadToYouTube,
            onChanged: _busy
                ? null
                : (value) =>
                    setState(() => _alsoUploadToYouTube = value ?? false),
            activeColor: const Color(0xFFFF0000),
            checkColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'Also upload to YouTube after publishing',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              'Or upload later from View Your Posts below',
              style: TextStyle(color: secondary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _publishToBlueWave,
              icon: const Icon(Icons.waves_rounded),
              label: const Text(
                'Publish to BlueWave',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: fblaGold,
                foregroundColor: fblaNavy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _myPostsSection(bool isDark, Color primary, Color secondary) {
    return Consumer<SocialProvider>(
      builder: (context, social, _) {
        final posts = social.myVideoPosts;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'View Your Posts',
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  '${posts.length} video${posts.length == 1 ? '' : 's'}',
                  style: TextStyle(color: secondary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (posts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: _panel(isDark),
                child: Column(
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      size: 40,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your video posts will appear here',
                      style: TextStyle(
                        color: secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Record a video above and publish to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: secondary, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ...posts.map(
                (post) => _MyVideoPostCard(
                  post: post,
                  isDark: isDark,
                  onUploadYouTube: _busy ? null : () => _uploadToYouTube(post),
                  onOpenYouTube: post.youtubeWatchUrl != null
                      ? () => launchUrl(
                            Uri.parse(post.youtubeWatchUrl!),
                            mode: LaunchMode.externalApplication,
                          )
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _busyOverlay(bool isDark) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1C31) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white12 : fblaLightBorder,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: BlueWaveTheme.primary,
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _busyLabel ?? 'Working...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : fblaLightPrimaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyVideoPostCard extends StatelessWidget {
  final BlueWavePostData post;
  final bool isDark;
  final VoidCallback? onUploadYouTube;
  final VoidCallback? onOpenYouTube;

  const _MyVideoPostCard({
    required this.post,
    required this.isDark,
    this.onUploadYouTube,
    this.onOpenYouTube,
  });

  void _playVideo(BuildContext context) {
    if (post.videoUrl == null) return;
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

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    final secondary = isDark ? Colors.white70 : fblaLightSecondaryText;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BlueWaveTheme.cardDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: BlueWaveTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  onPressed: () => _playVideo(context),
                  icon: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: BlueWaveTheme.primary,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(post.createdAt),
                      style: TextStyle(color: secondary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _statusChip(
                          'BlueWave',
                          BlueWaveTheme.primary,
                          Icons.waves_rounded,
                        ),
                        if (post.isOnYouTube)
                          _statusChip(
                            'YouTube',
                            const Color(0xFFFF0000),
                            Icons.smart_display_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: post.tags
                  .map(
                    (t) => Text(
                      t,
                      style: const TextStyle(
                        color: BlueWaveTheme.waveGlow,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (!post.isOnYouTube && onUploadYouTube != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onUploadYouTube,
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: const Text('Upload to YouTube'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0000),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (post.isOnYouTube && onOpenYouTube != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenYouTube,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('View on YouTube'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF0000),
                      side: const BorderSide(color: Color(0xFFFF0000)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
