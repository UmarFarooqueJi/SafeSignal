import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/services/local_rule_engine.dart';
import 'package:safesignal/core/models/ai_verdict.dart';

void main() {
  group('LocalRuleEngine Tests', () {
    final engine = LocalRuleEngine();

    test('Detects scam urgency keywords and flag as suspicious or scam', () {
      final verdict = engine.analyze(
        'Your bank account blocked! Immediate KYC update required at http://bit.ly/fake-bank',
      );
      expect(verdict.isSuspicious || verdict.isScam, isTrue);
      expect(verdict.riskScore, greaterThan(30));
    });

    test('Identifies safe standard OTP pattern', () {
      final verdict = engine.analyze(
        'Your OTP is 492019 for transaction at HDFC Bank. Do not share with anyone.',
      );
      expect(verdict.isSafe, isTrue);
      expect(verdict.riskScore, equals(0));
    });

    test('High confidence scam detection on lottery and digital arrest', () {
      final verdict = engine.analyze(
        'Congratulations! You won prize lottery 100% return. Digital arrest police notice. Send OTP immediately to claim now: http://tinyurl.com/claim',
      );
      expect(verdict.isScam, isTrue);
      expect(verdict.riskScore, greaterThanOrEqualTo(60));
    });
  });
}
