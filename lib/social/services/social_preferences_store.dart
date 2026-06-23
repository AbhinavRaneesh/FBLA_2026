import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/social_models.dart';

/// Persists onboarding preferences, interactions, and user-created BlueWave posts.
class SocialPreferencesStore {
  static const _prefsKey = 'social_user_preferences_v1';
  static const _interactionsKey = 'social_user_interactions_v1';
  static const _postsKey = 'social_bluewave_posts_v1';
  static const _wavedKey = 'social_waved_posts_v1';

  Future<UserPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return const UserPreferences();
    try {
      return UserPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const UserPreferences();
    }
  }

  Future<void> savePreferences(UserPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(preferences.toJson()));
  }

  Future<List<UserInteraction>> loadInteractions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_interactionsKey) ?? [];
    return raw
        .map((e) {
          try {
            return UserInteraction.fromJson(
              jsonDecode(e) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<UserInteraction>()
        .toList();
  }

  Future<void> saveInteraction(UserInteraction interaction) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadInteractions();
    final updated = [
      interaction,
      ...existing.where((e) => e.contentId != interaction.contentId),
    ].take(200).toList();
    await prefs.setStringList(
      _interactionsKey,
      updated.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<List<BlueWavePostData>> loadBlueWavePosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_postsKey) ?? [];
    return raw
        .map((e) {
          try {
            return BlueWavePostData.fromJson(
              jsonDecode(e) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<BlueWavePostData>()
        .toList();
  }

  Future<void> saveBlueWavePost(BlueWavePostData post) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadBlueWavePosts();
    final updated = [post, ...existing.where((p) => p.id != post.id)];
    await prefs.setStringList(
      _postsKey,
      updated.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<List<BlueWavePostData>> loadVideoPostsForUser(String userId) async {
    final all = await loadBlueWavePosts();
    return all
        .where(
          (p) =>
              p.author.id == userId &&
              (p.hasVideo ||
                  p.kind == BlueWavePostKind.video ||
                  p.kind == BlueWavePostKind.reel),
        )
        .toList();
  }

  Future<void> clearVideoPostsForUser(String userId) async {
    final all = await loadBlueWavePosts();
    final updated = all
        .where(
          (p) =>
              p.author.id != userId ||
              (!p.hasVideo &&
                  p.kind != BlueWavePostKind.video &&
                  p.kind != BlueWavePostKind.reel),
        )
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _postsKey,
      updated.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<Set<String>> loadWavedPostIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_wavedKey) ?? []).toSet();
  }

  Future<void> toggleWave(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final waved = await loadWavedPostIds();
    if (waved.contains(postId)) {
      waved.remove(postId);
    } else {
      waved.add(postId);
    }
    await prefs.setStringList(_wavedKey, waved.toList());
  }
}
