import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/services/local_rule_engine.dart';

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

    test('Zero false positives on verified TRAI banking transaction SMS', () {
      final sbiDebit = engine.analyze(
        'Dear SBI User, your A/C ending 4821 debited by Rs 2,500.00 on 21-Oct-26 by transfer to UPI/123456789. Available Bal Rs 45,210.00 - SBI',
        sender: 'AD-SBIINB',
      );
      expect(sbiDebit.isSafe, isTrue);
      expect(sbiDebit.riskScore, equals(0));
      expect(sbiDebit.reasons.first, contains('Verified legitimate Indian banking transactional notification'));

      final hdfcCredit = engine.analyze(
        'Rs 15,000.00 credited with Rs to your HDFC Bank A/C ending 9012 on 21-OCT-26 via NEFT transfer. Avl Bal: Rs 1,20,500.00. Ref no 987654321',
        sender: 'VK-HDFCBK',
      );
      expect(hdfcCredit.isSafe, isTrue);
      expect(hdfcCredit.riskScore, equals(0));
    });

    test('Flags spoofed bank notifications sent from personal mobile numbers', () {
      final spoofedBank = engine.analyze(
        'Dear customer your SBI NetBanking account will be blocked today due to pending KYC update immediately.',
        sender: '+919876543210',
      );
      expect(spoofedBank.isScam, isTrue);
      expect(spoofedBank.riskScore, greaterThanOrEqualTo(55));
      expect(spoofedBank.reasons.first, contains('SENDER SPOOFING'));
    });

    test('Detects call forwarding hijack codes', () {
      final forwarding = engine.analyze(
        'Dial *401*9876543210# to activate free unlimited 5G data on your SIM card!',
      );
      expect(forwarding.isScam, isTrue);
      expect(forwarding.reasons.first, contains('CALL FORWARDING HIJACK'));
    });

    test('Detects remote access tool installation traps', () {
      final remoteAccess = engine.analyze(
        'For customer support refund, install AnyDesk app and share 9 digit code.',
      );
      expect(remoteAccess.isScam, isTrue);
      expect(remoteAccess.reasons.first, contains('REMOTE ACCESS ATTACK'));
    });
  });
}
