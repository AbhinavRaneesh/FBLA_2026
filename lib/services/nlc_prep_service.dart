import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_service.dart';

/// NLC Ready prep data: Firestore profile fields + local daily task state.
class NlcPrepService {
  NlcPrepService._();

  static const _dailyKeyPrefix = 'nlc_daily_prep_';
  static const _dailyRewardKeyPrefix = 'nlc_daily_reward_';

  static DateTime get nlcStart => DateTime(2026, 6, 29);

  static int daysUntilNlc([DateTime? from]) {
    final today = DateTime(from?.year ?? DateTime.now().year,
        from?.month ?? DateTime.now().month, from?.day ?? DateTime.now().day);
    return nlcStart.difference(today).inDays;
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<List<String>> loadNlcEvents(String userId) async {
    return FirebaseService.getNlcEvents(userId);
  }

  static Future<void> saveNlcEvents(String userId, List<String> events) async {
    await FirebaseService.saveNlcEvents(userId, events);
  }

  static Future<int> loadPrepStreak(String userId) async {
    return FirebaseService.getNlcPrepStreak(userId);
  }

  static Future<DateTime?> loadLastPracticeDate(String userId) async {
    return FirebaseService.getLastNlcPracticeDate(userId);
  }

  static Future<void> recordPracticeSession(String userId) async {
    await FirebaseService.recordNlcPracticeSession(userId);
  }

  static Future<Set<String>> loadCompletedDailyTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_dailyKeyPrefix${_todayKey()}';
      return (prefs.getStringList(key) ?? const []).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> toggleDailyTask(String taskId, bool completed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_dailyKeyPrefix${_todayKey()}';
      final current = (prefs.getStringList(key) ?? []).toSet();
      if (completed) {
        current.add(taskId);
      } else {
        current.remove(taskId);
      }
      await prefs.setStringList(key, current.toList());
    } catch (_) {}
  }

  static Future<bool> claimDailyRewardIfEligible(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rewardKey = '$_dailyRewardKeyPrefix${_todayKey()}';
      if (prefs.getBool(rewardKey) == true) return false;

      final tasks = await loadCompletedDailyTasks();
      if (tasks.length < 3) return false;

      await prefs.setBool(rewardKey, true);
      await FirebaseService.awardPoints(userId, 25);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> pinCourseForResources(String courseName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final courses = prefs.getStringList('userCourses') ?? <String>[];
      if (!courses.contains(courseName)) {
        courses.add(courseName);
        await prefs.setStringList('userCourses', courses);
      }
      await prefs.setString('selectedCourse', courseName);
    } catch (_) {}
  }
}
