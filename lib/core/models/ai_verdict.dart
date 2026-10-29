/// Standard normalized verdict that every LLM/rule-engine produces.
/// App logic never depends on which provider ran — only this model.
class AiVerdict {
  final String verdict; // 'SCAM' | 'SUSPICIOUS' | 'SAFE'
  final int riskScore; // 0–100
  final List<String> reasons; // Human-readable red flags (min 1)
  final List<String> whatToDo; // Actionable steps
  final String summary; // One-line summary
  final double confidence; // 0.0–1.0
  final String provider; // 'gemini' | 'openai' | 'rule_engine'
  final bool isOffline; // True if rule-engine fallback used

  const AiVerdict({
    required this.verdict,
    required this.riskScore,
    required this.reasons,
    required this.whatToDo,
    required this.summary,
    required this.confidence,
    required this.provider,
    this.isOffline = false,
  });

  bool get isScam => verdict == 'SCAM';
  bool get isSuspicious => verdict == 'SUSPICIOUS';
  bool get isSafe => verdict == 'SAFE';

  /// Risk color: red for scam, orange for suspicious, green for safe
  String get emoji {
    if (isScam) return '🚨';
    if (isSuspicious) return '⚠️';
    return '✅';
  }

  factory AiVerdict.fromJson(Map<String, dynamic> json) {
    String rawVerdict = (json['verdict'] as String? ?? 'SUSPICIOUS')
        .toUpperCase();
    // Normalize: LIKELY_SAFE → SAFE, UNCERTAIN → SUSPICIOUS
    if (rawVerdict == 'LIKELY_SAFE') rawVerdict = 'SAFE';
    if (rawVerdict == 'UNCERTAIN') rawVerdict = 'SUSPICIOUS';

    int score = json['riskScore'] as int? ?? _verdictToScore(rawVerdict);
    if (json['risk_score'] != null) score = json['risk_score'] as int;

    return AiVerdict(
      verdict: rawVerdict,
      riskScore: score,
      reasons: List<String>.from(
        json['reasons'] as List? ??
            json['why'] as List? ??
            ['No specific reason provided'],
      ),
      whatToDo: List<String>.from(json['whatToDo'] as List? ?? []),
      summary: json['summary'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.7,
      provider: json['provider'] as String? ?? 'unknown',
      isOffline: json['isOffline'] as bool? ?? false,
    );
  }

  static int _verdictToScore(String verdict) {
    switch (verdict) {
      case 'SCAM':
        return 85;
      case 'SUSPICIOUS':
        return 55;
      default:
        return 10;
    }
  }

  AiVerdict copyWith({String? provider, bool? isOffline}) {
    return AiVerdict(
      verdict: verdict,
      riskScore: riskScore,
      reasons: reasons,
      whatToDo: whatToDo,
      summary: summary,
      confidence: confidence,
      provider: provider ?? this.provider,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}
