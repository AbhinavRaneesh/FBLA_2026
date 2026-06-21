import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart'
    show
        AppState,
        appBackgroundColor,
        appBackgroundGradient,
        fblaGold,
        fblaLightBackground,
        fblaLightBorder,
        fblaLightPrimaryText,
        fblaLightSecondaryText,
        fblaLightSurface,
        fblaNavy;
import '../../services/firebase_service.dart';
import '../../widgets/app_snackbar.dart';
import '../models/discord_models.dart';
import '../models/social_models.dart';
import '../providers/social_provider.dart';
import '../theme/bluewave_theme.dart';

/// Full Discord bot control center — queue posts, view history, join server.
class DiscordHubScreen extends StatefulWidget {
  const DiscordHubScreen({super.key});

  @override
  State<DiscordHubScreen> createState() => _DiscordHubScreenState();
}

class _DiscordHubScreenState extends State<DiscordHubScreen> {
  static const _discordBlurple = Color(0xFF5865F2);

  DiscordConfig _config = const DiscordConfig();
  bool _loadingConfig = true;
  bool _posting = false;
  bool _clearingFailed = false;
  bool _clearingAll = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await FirebaseService.getDiscordConfig();
    if (mounted) {
      setState(() {
        _config = config;
        _loadingConfig = false;
      });
    }
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

  Future<void> _queuePost({
    required String title,
    required String body,
    required DiscordChannel channel,
    required DiscordPostType type,
    String? sourceId,
    String? imageUrl,
  }) async {
    if (_posting) return;
    setState(() => _posting = true);
    try {
      final app = context.read<AppState>();
      await FirebaseService.queueDiscordMessage(
        title: title,
        body: body,
        channel: discordChannelName(channel),
        type: discordPostTypeName(type),
        sourceId: sourceId,
        authorName: app.resolvedDisplayName,
        imageUrl: imageUrl,
      );
      if (!mounted) return;
      _snack('Queued — your bot will post this to Discord shortly.');
    } catch (e) {
      if (!mounted) return;
      _snack('Could not queue post: $e');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _snack(String message) {
    AppSnackBar.show(context, message: message);
  }

  Future<void> _clearAllFailed(List<DiscordOutboxItem> items) async {
    if (context.read<AppState>().firebaseUser?.uid == null) {
      _snack('Sign in to clear failed posts.');
      return;
    }
    final deletable =
        items.where((i) => i.status == DiscordOutboxStatus.failed).length;
    if (deletable == 0) {
      _snack('No failed posts to clear.');
      return;
    }

    setState(() => _clearingFailed = true);
    try {
      final count = await FirebaseService.deleteFailedDiscordOutboxItems(items);
      if (!mounted) return;
      _snack('Removed $count failed post${count == 1 ? '' : 's'}.');
    } catch (e) {
      if (!mounted) return;
      _snack('Could not clear failed posts: $e');
    } finally {
      if (mounted) setState(() => _clearingFailed = false);
    }
  }

  Future<void> _clearQueuedAndFailed(List<DiscordOutboxItem> items) async {
    if (context.read<AppState>().firebaseUser?.uid == null) {
      _snack('Sign in to clear the queue.');
      return;
    }
    final removable = items
        .where(
          (i) =>
              i.status == DiscordOutboxStatus.pending ||
              i.status == DiscordOutboxStatus.failed,
        )
        .length;
    if (removable == 0) {
      _snack('Nothing to clear.');
      return;
    }

    setState(() => _clearingAll = true);
    try {
      final count = await FirebaseService.clearQueuedAndFailedOutbox(items);
      if (!mounted) return;
      _snack('Cleared $count queued/failed post${count == 1 ? '' : 's'}.');
    } catch (e) {
      if (!mounted) return;
      _snack('Could not clear queue: $e');
    } finally {
      if (mounted) setState(() => _clearingAll = false);
    }
  }

  Future<void> _postLatestAnnouncement() async {
    final app = context.read<AppState>();
    if (app.news.isEmpty) {
      _snack('No announcements available yet.');
      return;
    }
    final latest = [...app.news]..sort((a, b) => b.date.compareTo(a.date));
    final item = latest.first;
    await _queuePost(
      title: item.title,
      body: item.body,
      channel: DiscordChannel.announcements,
      type: DiscordPostType.announcement,
      sourceId: item.id,
    );
  }

  Future<void> _postNextEvent() async {
    final app = context.read<AppState>();
    final now = DateTime.now();
    final upcoming = app.events.where((e) => e.end.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    if (upcoming.isEmpty) {
      _snack('No upcoming events to share.');
      return;
    }

    final event = upcoming.first;
    final formatter = DateFormat('EEE, MMM d · h:mm a');
    await _queuePost(
      title: 'Upcoming: ${event.title}',
      body: [
        formatter.format(event.start),
        if (event.location.isNotEmpty) 'Location: ${event.location}',
        if (event.description.isNotEmpty) event.description,
      ].join('\n\n'),
      channel: DiscordChannel.events,
      type: DiscordPostType.event,
      sourceId: event.id,
    );
  }

  Future<void> _showGeneralUpdateSheet(bool isDark) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    var channel = DiscordChannel.general;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F1C31) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final canSend = titleController.text.trim().isNotEmpty &&
                  bodyController.text.trim().isNotEmpty;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Discord Post',
                    style: TextStyle(
                      color: isDark ? Colors.white : fblaLightPrimaryText,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: DiscordChannel.values.map((c) {
                      final selected = channel == c;
                      return ChoiceChip(
                        label: Text(_channelLabel(c)),
                        selected: selected,
                        onSelected: (_) => setSheetState(() => channel = c),
                        selectedColor: _discordBlurple,
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black54),
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bodyController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Message'),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: canSend && !_posting
                          ? () async {
                              Navigator.pop(ctx);
                              await _queuePost(
                                title: titleController.text,
                                body: bodyController.text,
                                channel: channel,
                                type: DiscordPostType.generalUpdate,
                              );
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _discordBlurple,
                      ),
                      child: const Text('Queue Post'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    titleController.dispose();
    bodyController.dispose();
  }

  Future<void> _postBlueWaveHighlight() async {
    final social = context.read<SocialProvider>();
    final posts = social.myVideoPosts;
    BlueWavePostData? post;

    if (posts.isNotEmpty) {
      post = posts.first;
    } else {
      final feedPosts = social.feedItems
          .where((i) => i.blueWave != null)
          .map((i) => i.blueWave!);
      if (feedPosts.isNotEmpty) {
        post = feedPosts.first;
      }
    }

    if (post == null) {
      _snack('No FBLA Social posts to share yet. Create one from the Social tab.');
      return;
    }

    String? highlightImage;
    for (final url in post.imageUrls) {
      highlightImage = FirebaseService.discordSafeMediaUrl(url);
      if (highlightImage != null) break;
    }

    await _queuePost(
      title: 'FBLA Social: ${post.text}',
      body: [
        if (post.tags.isNotEmpty) post.tags.join(' '),
        if (post.videoUrl != null) 'Watch in the FBLA app Social feed.',
        'Posted by ${post.author.name}',
      ].where((s) => s.isNotEmpty).join('\n\n'),
      channel: DiscordChannel.general,
      type: DiscordPostType.bluewave,
      sourceId: post.id,
      imageUrl: highlightImage,
    );
  }

  Future<void> _joinDiscord() async {
    final url = _config.inviteUrl.trim();
    if (url.isEmpty) {
      _snack('Ask your chapter officer to add the Discord invite link in Firebase.');
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _channelLabel(DiscordChannel channel) {
    switch (channel) {
      case DiscordChannel.announcements:
        return '#announcements';
      case DiscordChannel.general:
        return '#general';
      case DiscordChannel.events:
        return '#events';
    }
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
          'Discord Bot',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? appBackgroundGradient : null,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _statusHeader(isDark, primary, secondary),
            const SizedBox(height: 14),
            _quickActions(isDark, primary),
            const SizedBox(height: 20),
            _activityFeed(isDark, primary, secondary),
          ],
        ),
      ),
    );
  }

  Widget _statusHeader(bool isDark, Color primary, Color secondary) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  _discordBlurple.withValues(alpha: 0.35),
                  fblaNavy.withValues(alpha: 0.9),
                ]
              : [const Color(0xFFE8EAFF), Colors.white],
        ),
        border: Border.all(color: _discordBlurple.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _discordBlurple.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hub_rounded, color: _discordBlurple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loadingConfig ? 'Loading...' : _config.guildName,
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      _config.botEnabled
                          ? 'Bot sync active on Firebase Blaze'
                          : 'Bot sync paused',
                      style: TextStyle(color: secondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _config.inviteUrl.isNotEmpty ? _joinDiscord : null,
                  icon: const Icon(Icons.groups_rounded, size: 18),
                  label: const Text('Join Server'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _discordBlurple,
                    side: BorderSide(
                      color: _discordBlurple.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Posts queue in Firestore and your Cloud Function delivers them to Discord. The bot token never lives in the app.',
            style: TextStyle(color: secondary, fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _quickActions(bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Post to Discord',
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _actionTile(
            icon: Icons.campaign_rounded,
            color: fblaGold,
            title: 'Latest Announcement',
            subtitle: 'Post newest app news to #announcements',
            onTap: _posting ? null : _postLatestAnnouncement,
          ),
          _actionTile(
            icon: Icons.event_rounded,
            color: fblaNavy,
            title: 'Next Upcoming Event',
            subtitle: 'Share the next chapter event to #events',
            onTap: _posting ? null : _postNextEvent,
          ),
          _actionTile(
            icon: Icons.waves_rounded,
            color: BlueWaveTheme.primary,
            title: 'FBLA Social Highlight',
            subtitle: 'Share a recent FBLA Social post to #general',
            onTap: _posting ? null : _postBlueWaveHighlight,
          ),
          _actionTile(
            icon: Icons.edit_note_rounded,
            color: _discordBlurple,
            title: 'Custom Update',
            subtitle: 'Write your own message to any channel',
            onTap: _posting ? null : () => _showGeneralUpdateSheet(isDark),
          ),
          if (_posting) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(color: _discordBlurple),
          ],
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  Widget _activityFeed(bool isDark, Color primary, Color secondary) {
    final userId = context.read<AppState>().firebaseUser?.uid;

    return StreamBuilder<List<DiscordOutboxItem>>(
      stream: FirebaseService.watchDiscordOutbox(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final items = snapshot.data ?? [];
        final failedCount =
            items.where((i) => i.status == DiscordOutboxStatus.failed).length;
        final queuedCount =
            items.where((i) => i.status == DiscordOutboxStatus.pending).length;
        final clearableCount = failedCount + queuedCount;
        final busy = _clearingFailed || _clearingAll;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent Bot Activity',
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (clearableCount > 0)
                  TextButton.icon(
                    onPressed: busy ? null : () => _clearQueuedAndFailed(items),
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.clear_all_rounded, size: 18),
                    label: Text('Clear all ($clearableCount)'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFED4245),
                    ),
                  ),
              ],
            ),
            if (failedCount > 0 && queuedCount > 0) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy ? null : () => _clearAllFailed(items),
                  child: Text('Failed only ($failedCount)'),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (items.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: _panel(isDark),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 36,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No posts queued yet',
                      style: TextStyle(
                        color: secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...items.map(
                (item) => _OutboxTile(
                  item: item,
                  isDark: isDark,
                  userId: userId,
                  onRemoved: (label) => _snack('$label removed.'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OutboxTile extends StatefulWidget {
  final DiscordOutboxItem item;
  final bool isDark;
  final String? userId;
  final void Function(String label)? onRemoved;

  const _OutboxTile({
    required this.item,
    required this.isDark,
    this.userId,
    this.onRemoved,
  });

  @override
  State<_OutboxTile> createState() => _OutboxTileState();
}

class _OutboxTileState extends State<_OutboxTile> {
  bool _deleting = false;

  bool get _canCancel =>
      widget.userId != null &&
      widget.item.status == DiscordOutboxStatus.pending;

  bool get _canDeleteFailed =>
      widget.userId != null &&
      widget.item.status == DiscordOutboxStatus.failed;

  Future<void> _remove({required String label}) async {
    if (_deleting) return;
    if (!_canCancel && !_canDeleteFailed) return;

    setState(() => _deleting = true);
    try {
      await FirebaseService.deleteDiscordOutboxItem(widget.item.id);
      widget.onRemoved?.call(label);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not remove: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;
    final primary = isDark ? Colors.white : fblaLightPrimaryText;
    final secondary = isDark ? Colors.white70 : fblaLightSecondaryText;

    Color statusColor;
    IconData statusIcon;
    switch (item.status) {
      case DiscordOutboxStatus.sent:
        statusColor = const Color(0xFF57F287);
        statusIcon = Icons.check_circle_rounded;
        break;
      case DiscordOutboxStatus.failed:
        statusColor = const Color(0xFFED4245);
        statusIcon = Icons.error_rounded;
        break;
      case DiscordOutboxStatus.pending:
        statusColor = fblaGold;
        statusIcon = Icons.schedule_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BlueWaveTheme.cardDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                item.statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondary, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip('#${item.channel}', const Color(0xFF5865F2)),
              const SizedBox(width: 6),
              _chip(item.type.replaceAll('_', ' '), BlueWaveTheme.primary),
              if (item.authorName != null) ...[
                const Spacer(),
                Text(
                  item.authorName!,
                  style: TextStyle(color: secondary, fontSize: 10),
                ),
              ],
            ],
          ),
          if (item.status == DiscordOutboxStatus.failed &&
              item.error != null) ...[
            const SizedBox(height: 8),
            Text(
              item.error!,
              style: const TextStyle(
                color: Color(0xFFED4245),
                fontSize: 11,
              ),
            ),
          ],
          if (_canCancel || _canDeleteFailed) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _deleting
                    ? null
                    : () => _remove(
                          label: _canCancel ? 'Queued post' : 'Failed post',
                        ),
                icon: _deleting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _canCancel
                            ? Icons.cancel_outlined
                            : Icons.delete_outline_rounded,
                        size: 18,
                      ),
                label: Text(_canCancel ? 'Cancel' : 'Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: _canCancel
                      ? fblaGold
                      : const Color(0xFFED4245),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
