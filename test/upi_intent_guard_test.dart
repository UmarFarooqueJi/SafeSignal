// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Test: Pre-PIN UPI Intent Guard & Fraud Shield Tests
// -----------------------------------------------------------------------------
import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/services/upi_intent_guard_service.dart';

void main() {
  group('UpiIntentGuardService - Reverse Payment & Mandate Fraud Tests', () {
    test('Flags reverse payment fraud where note promises refund but specifies debit amount', () {
      final scamUri = 'upi://pay?pa=scammer99@okaxis&pn=Customer+Helpdesk&am=5000&tn=Electricity+Bill+Refund';
      final res = UpiIntentGuardService.analyze(scamUri);

      expect(res.isFraud, isTrue);
      expect(res.severity, equals(UpiRiskSeverity.critical));
      expect(res.amount, equals('5000'));
      expect(res.warnings.any((w) => w.contains('REVERSE PAYMENT FRAUD DETECTED')), isTrue);
      expect(res.warnings.any((w) => w.contains('IMPERSONATED CUSTOMER CARE')), isTrue);
      expect(res.actionGuidance, contains('DO NOT PROCEED'));
    });

    test('Flags auto-debit / recurring mandate attempts disguised as UPI intents', () {
      final mandateUri = 'upi://mandate?pa=syndicate@ybl&pn=Streaming+Subscription&am=999';
      final res = UpiIntentGuardService.analyze(mandateUri);

      expect(res.isFraud, isTrue);
      expect(res.isRecurringMandate, isTrue);
      expect(res.warnings.any((w) => w.contains('RECURRING MANDATE')), isTrue);
    });

    test('Flags customer care impersonation handles (e.g. sbi.customercare@oksbi)', () {
      final fakeHelp = 'upi://pay?pa=sbicare.refunds@oksbi&pn=SBI+Helpdesk';
      final res = UpiIntentGuardService.analyze(fakeHelp);

      expect(res.isFraud, isTrue);
      expect(res.warnings.any((w) => w.contains('IMPERSONATED CUSTOMER CARE')), isTrue);
    });

    test('Zero false positive on genuine peer-to-peer or clean merchant payment intent', () {
      final cleanUri = 'upi://pay?pa=friend@okhdfcbank&pn=Rahul+Sharma&tn=Dinner+bill';
      final res = UpiIntentGuardService.analyze(cleanUri);

      expect(res.isFraud, isFalse);
      expect(res.severity, equals(UpiRiskSeverity.safe));
      expect(res.payeeName, equals('Rahul Sharma'));
      expect(res.warnings, isEmpty);
    });
  });
}
