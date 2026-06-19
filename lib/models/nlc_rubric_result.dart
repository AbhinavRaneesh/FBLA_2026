import 'dart:convert';

class NlcRubricDimension {
  final String indicator;
  final int score;
  final String evidence;

  const NlcRubricDimension({
    required this.indicator,
    required this.score,
    required this.evidence,
  });

  Map<String, dynamic> toJson() => {
        'indicator': indicator,
        'score': score,
        'evidence': evidence,
      };

  factory NlcRubricDimension.fromJson(Map<String, dynamic> json) {
    return NlcRubricDimension(
      indicator: (json['indicator'] ?? '').toString(),
      score: _parseScore(json['score']),
      evidence: (json['evidence'] ?? '').toString(),
    );
  }

  static int _parseScore(dynamic value) {
    if (value is int) return value.clamp(1, 5);
    return (int.tryParse('$value') ?? 3).clamp(1, 5);
  }
}

class NlcRubricResult {
  final double overallScore;
  final List<NlcRubricDimension> dimensions;
  final String topFix;
  final String judgeQuestion;
  final bool offlineDemo;

  const NlcRubricResult({
    required this.overallScore,
    required this.dimensions,
    required this.topFix,
    required this.judgeQuestion,
    this.offlineDemo = false,
  });

  Map<String, dynamic> toJson() => {
        'overallScore': overallScore,
        'dimensions': dimensions.map((d) => d.toJson()).toList(),
        'topFix': topFix,
        'judgeQuestion': judgeQuestion,
        'offlineDemo': offlineDemo,
      };

  factory NlcRubricResult.fromJson(Map<String, dynamic> json) {
    final rawDims = json['dimensions'];
    final dims = rawDims is List
        ? rawDims
            .whereType<Map>()
            .map((e) =>
                NlcRubricDimension.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <NlcRubricDimension>[];

    return NlcRubricResult(
      overallScore: (json['overallScore'] is num)
          ? (json['overallScore'] as num).toDouble()
          : double.tryParse('${json['overallScore']}') ?? 3.0,
      dimensions: dims,
      topFix: (json['topFix'] ?? '').toString(),
      judgeQuestion: (json['judgeQuestion'] ?? '').toString(),
      offlineDemo: json['offlineDemo'] == true,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static NlcRubricResult? tryParse(String raw) {
    try {
      var text = raw.trim();
      final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true);
      final match = fence.firstMatch(text);
      if (match != null) {
        text = match.group(1)!.trim();
      }
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start >= 0 && end > start) {
        text = text.substring(start, end + 1);
      }
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return NlcRubricResult.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}
