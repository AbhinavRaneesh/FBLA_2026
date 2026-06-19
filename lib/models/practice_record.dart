/// A single saved practice session for a performance-based FBLA event.
///
/// Performance events (roleplay, presentations) are practiced in
/// `EventPracticeScreen`. Previously nothing about a session was kept — the AI
/// feedback and self-assessment vanished on close. A [PracticeRecord] captures
/// each session so members can revisit past feedback and see their progress per
/// event ("Practiced Public Speaking 3×").
class PracticeRecord {
  /// The event practiced, e.g. "Public Speaking".
  final String eventName;

  /// The event's category/type, e.g. "Roleplay" or "Presentation".
  final String category;

  /// Which mode produced this record: 'coach', 'record', or 'live_sim'.
  final String type;

  /// When the session happened.
  final DateTime timestamp;

  /// AI feedback text, present for 'coach' sessions.
  final String? aiFeedback;

  /// Rubric indicators the member marked complete, for 'record' sessions.
  final int? rubricChecked;

  /// Total rubric indicators available, for 'record' sessions.
  final int? rubricTotal;

  /// Overall AI rubric score (1–5) for live_sim sessions.
  final double? rubricOverall;

  /// Serialized [NlcRubricResult] JSON for live_sim sessions.
  final String? rubricJson;

  const PracticeRecord({
    required this.eventName,
    required this.category,
    required this.type,
    required this.timestamp,
    this.aiFeedback,
    this.rubricChecked,
    this.rubricTotal,
    this.rubricOverall,
    this.rubricJson,
  });

  bool get isCoach => type == 'coach';
  bool get isRecord => type == 'record';
  bool get isLiveSim => type == 'live_sim';

  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'category': category,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'aiFeedback': aiFeedback,
        'rubricChecked': rubricChecked,
        'rubricTotal': rubricTotal,
        'rubricOverall': rubricOverall,
        'rubricJson': rubricJson,
      };

  factory PracticeRecord.fromJson(Map<String, dynamic> json) {
    return PracticeRecord(
      eventName: (json['eventName'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      type: (json['type'] ?? 'coach').toString(),
      timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      aiFeedback: json['aiFeedback']?.toString(),
      rubricChecked: json['rubricChecked'] is int
          ? json['rubricChecked'] as int
          : int.tryParse('${json['rubricChecked']}'),
      rubricTotal: json['rubricTotal'] is int
          ? json['rubricTotal'] as int
          : int.tryParse('${json['rubricTotal']}'),
      rubricOverall: json['rubricOverall'] is num
          ? (json['rubricOverall'] as num).toDouble()
          : double.tryParse('${json['rubricOverall']}'),
      rubricJson: json['rubricJson']?.toString(),
    );
  }
}
