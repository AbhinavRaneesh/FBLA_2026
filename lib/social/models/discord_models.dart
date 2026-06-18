import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../constants/discord_defaults.dart';

enum DiscordOutboxStatus { pending, sent, failed, unknown }

enum DiscordPostType {
  announcement,
  generalUpdate,
  event,
  bluewave,
  forum,
}

enum DiscordChannel {
  announcements,
  general,
  events,
}

@immutable
class DiscordConfig {
  final String inviteUrl;
  final String guildName;
  final bool botEnabled;

  const DiscordConfig({
    this.inviteUrl = '',
    this.guildName = 'FBLA Discord',
    this.botEnabled = true,
  });

  factory DiscordConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const DiscordConfig();
    return DiscordConfig(
      inviteUrl: (data['inviteUrl'] ?? '').toString(),
      guildName: (data['guildName'] ?? 'FBLA Discord').toString(),
      botEnabled: data['botEnabled'] != false,
    );
  }

  /// Prefer Firestore values; fill gaps from bundled chapter defaults.
  DiscordConfig withAppDefaults() {
    return DiscordConfig(
      inviteUrl: inviteUrl.isNotEmpty ? inviteUrl : DiscordDefaults.inviteUrl,
      guildName: guildName.isNotEmpty && guildName != 'FBLA Discord'
          ? guildName
          : DiscordDefaults.guildName,
      botEnabled: botEnabled,
    );
  }
}

@immutable
class DiscordOutboxItem {
  final String id;
  final String title;
  final String body;
  final String channel;
  final String type;
  final DiscordOutboxStatus status;
  final String? authorName;
  final String? sourceId;
  final String? error;
  final String? discordMessageId;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? postedAt;

  const DiscordOutboxItem({
    required this.id,
    required this.title,
    required this.body,
    required this.channel,
    required this.type,
    required this.status,
    this.authorName,
    this.sourceId,
    this.error,
    this.discordMessageId,
    this.createdBy,
    this.createdAt,
    this.postedAt,
  });

  factory DiscordOutboxItem.fromMap(String id, Map<String, dynamic> data) {
    return DiscordOutboxItem(
      id: id,
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      channel: (data['channel'] ?? 'general').toString(),
      type: (data['type'] ?? 'general_update').toString(),
      status: _parseStatus(data['status']),
      authorName: data['authorName']?.toString(),
      sourceId: data['sourceId']?.toString(),
      error: data['error']?.toString(),
      discordMessageId: data['discordMessageId']?.toString(),
      createdBy: data['createdBy']?.toString(),
      createdAt: _parseTimestamp(data['createdAt']),
      postedAt: _parseTimestamp(data['postedAt']),
    );
  }

  static DiscordOutboxStatus _parseStatus(dynamic value) {
    switch (value?.toString()) {
      case 'pending':
        return DiscordOutboxStatus.pending;
      case 'sent':
        return DiscordOutboxStatus.sent;
      case 'failed':
        return DiscordOutboxStatus.failed;
      default:
        return DiscordOutboxStatus.unknown;
    }
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String get statusLabel {
    switch (status) {
      case DiscordOutboxStatus.pending:
        return 'Queued';
      case DiscordOutboxStatus.sent:
        return 'Posted';
      case DiscordOutboxStatus.failed:
        return 'Failed';
      case DiscordOutboxStatus.unknown:
        return 'Unknown';
    }
  }
}

String discordChannelName(DiscordChannel channel) {
  switch (channel) {
    case DiscordChannel.announcements:
      return 'announcements';
    case DiscordChannel.general:
      return 'general';
    case DiscordChannel.events:
      return 'events';
  }
}

String discordPostTypeName(DiscordPostType type) {
  switch (type) {
    case DiscordPostType.announcement:
      return 'announcement';
    case DiscordPostType.generalUpdate:
      return 'general_update';
    case DiscordPostType.event:
      return 'event';
    case DiscordPostType.bluewave:
      return 'bluewave';
    case DiscordPostType.forum:
      return 'forum';
  }
}
