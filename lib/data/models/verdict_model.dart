import 'package:hive/hive.dart';

part 'verdict_model.g.dart';

@HiveType(typeId: 0)
class VerdictModel extends HiveObject {
  @HiveField(0)
  final String checkId;

  @HiveField(1)
  final String verdict; // SCAM | LIKELY_SAFE | UNCERTAIN

  @HiveField(2)
  final double confidence; // 0.0–1.0

  @HiveField(3)
  final String scamType;

  @HiveField(4)
  final bool escalated;

  @HiveField(5)
  final List<String> why;

  @HiveField(6)
  final List<String> whatToDo;

  @HiveField(7)
  final String? trendNote;

  @HiveField(8)
  final String language;

  @HiveField(9)
  final String disclaimer;

  @HiveField(10)
  final String inputText;

  @HiveField(11)
  final DateTime checkedAt;

  VerdictModel({
    required this.checkId,
    required this.verdict,
    required this.confidence,
    required this.scamType,
    required this.escalated,
    required this.why,
    required this.whatToDo,
    this.trendNote,
    required this.language,
    required this.disclaimer,
    required this.inputText,
    required this.checkedAt,
  });

  factory VerdictModel.fromJson(
    Map<String, dynamic> json, {
    String inputText = '',
  }) {
    return VerdictModel(
      checkId: json['check_id'] ?? '',
      verdict: json['verdict'] ?? 'UNCERTAIN',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      scamType: json['scam_type'] ?? 'unknown',
      escalated: json['escalated'] ?? false,
      why: List<String>.from(json['why'] ?? []),
      whatToDo: List<String>.from(json['what_to_do'] ?? []),
      trendNote: json['trend_note'],
      language: json['language'] ?? 'en',
      disclaimer: json['disclaimer'] ?? '',
      inputText: inputText,
      checkedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'check_id': checkId,
      'verdict': verdict,
      'confidence': confidence,
      'scamType': scamType,
      'riskLevel': 'HIGH', // fallback or add to model if needed
      'escalated': escalated,
      'why': why,
      'what_to_do': whatToDo,
      'trend_note': trendNote,
      'language': language,
      'disclaimer': disclaimer,
      'inputText': inputText,
      'checked_at': checkedAt.toIso8601String(),
    };
  }

  // Mock verdicts for development
  static VerdictModel mockScam() => VerdictModel(
    checkId: 'mock_scam_001',
    verdict: 'SCAM',
    confidence: 0.94,
    scamType: 'digital_arrest',
    escalated: false,
    why: [
      'Police video call pe arrest nahi karti',
      'Paisa maangna fraud ka sign hai',
      'CBI direct contact nahi karti',
    ],
    whatToDo: [
      'Paisa mat bhejo',
      'Call turant kaat do',
      '1930 pe report karo',
      'Bank ko batao agar paisa bhej diya',
    ],
    trendNote: 'Ye scam aaj kal bahut dikh raha hai. Savdhan rahein.',
    language: 'hi',
    disclaimer: 'SafeSignal ek assistant hai, authority nahi.',
    inputText: 'CBI case hai, paisa bhejo warna arrest',
    checkedAt: DateTime.now(),
  );

  static VerdictModel mockSafe() => VerdictModel(
    checkId: 'mock_safe_001',
    verdict: 'LIKELY_SAFE',
    confidence: 0.88,
    scamType: 'none',
    escalated: false,
    why: [
      'Official bank communication style',
      'No request for personal information',
      'Legitimate OTP format',
    ],
    whatToDo: [
      'This appears to be a legitimate message',
      'Always verify directly with your bank if unsure',
    ],
    trendNote: null,
    language: 'en',
    disclaimer: 'SafeSignal is an assistant, not an authority.',
    inputText: 'Your OTP is 123456 for SBI transaction',
    checkedAt: DateTime.now(),
  );

  static VerdictModel mockCaution() => VerdictModel(
    checkId: 'mock_caution_001',
    verdict: 'UNCERTAIN',
    confidence: 0.65,
    scamType: 'lottery_prize',
    escalated: true,
    why: [
      'Lottery claim requires verification',
      'Link destination unclear',
      'Unsolicited prize notification',
    ],
    whatToDo: [
      'Do NOT click any links',
      'Do NOT share personal details',
      'Verify independently before acting',
      'Call 1930 if in doubt',
    ],
    trendNote: null,
    language: 'en',
    disclaimer: 'SafeSignal is an assistant, not an authority.',
    inputText: 'Congratulations! You won 50000 rupees lottery',
    checkedAt: DateTime.now(),
  );
}
