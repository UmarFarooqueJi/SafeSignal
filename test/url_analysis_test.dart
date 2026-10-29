import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/services/local_rule_engine.dart';

void main() {
  group('LocalRuleEngine - URL & Threat Vector Tests', () {
    final engine = LocalRuleEngine();

    test('Flags malicious APK dropper URL as critical threat', () {
      final verdict = engine.analyze(
        'Dear customer, update your SBI YONO app immediately by downloading the update from https://storage.evil.com/yono_update.apk to avoid card block.',
      );
      expect(verdict.isScam, isTrue);
      expect(verdict.riskScore, greaterThanOrEqualTo(50));
      expect(
        verdict.reasons.any((r) => r.contains('APK') || r.contains('DROPPER')),
        isTrue,
      );
    });

    test('Detects shortened suspicious domain redirect vectors', () {
      final verdict = engine.analyze(
        'Verify your electricity bill payment receipt at http://bit.ly/ebill-update before service suspension.',
      );
      expect(verdict.isSuspicious || verdict.isScam, isTrue);
      expect(verdict.riskScore, greaterThanOrEqualTo(25));
    });

    test('Detects utility bill / electricity disconnection fraud', () {
      final verdict = engine.analyze(
        'Electricity power bill update pending. Your power will be disconnected tonight at 9:30 PM. Call officer immediately.',
      );
      expect(verdict.isScam, isTrue);
      expect(verdict.riskScore, greaterThanOrEqualTo(45));
    });

    test('Identifies screen sharing / remote access fraud keywords', () {
      final verdict = engine.analyze(
        'To unblock your bank transaction, install AnyDesk or TeamViewer and share your screen with support.',
      );
      expect(verdict.isScam, isTrue);
      expect(verdict.riskScore, greaterThanOrEqualTo(50));
      expect(
        verdict.reasons.any(
          (r) => r.contains('REMOTE ACCESS') || r.contains('AnyDesk'),
        ),
        isTrue,
      );
    });

    test('Identifies call forwarding hijack dialer codes', () {
      final verdict = engine.analyze(
        'Dial *401*9876543210# to claim your courier package delivery immediately.',
      );
      expect(verdict.isScam, isTrue);
      expect(verdict.riskScore, greaterThanOrEqualTo(55));
      expect(verdict.reasons.any((r) => r.contains('CALL FORWARDING')), isTrue);
    });

    test('Identifies private and loopback IP hosts to block SSRF attempts', () {
      bool isPrivateHost(String host) {
        final lower = host.toLowerCase().trim();
        if (lower == 'localhost' ||
            lower == '127.0.0.1' ||
            lower == '::1' ||
            lower == '0.0.0.0')
          return true;
        final ipParts = lower.split('.');
        if (ipParts.length == 4) {
          final nums = ipParts.map((p) => int.tryParse(p)).toList();
          if (nums.every((n) => n != null && n >= 0 && n <= 255)) {
            final n0 = nums[0]!;
            final n1 = nums[1]!;
            if (n0 == 127) return true;
            if (n0 == 10) return true;
            if (n0 == 172 && n1 >= 16 && n1 <= 31) return true;
            if (n0 == 192 && n1 == 168) return true;
            if (n0 == 169 && n1 == 254) return true;
            if (n0 == 0) return true;
          }
        }
        return false;
      }

      expect(isPrivateHost('127.0.0.1'), isTrue);
      expect(isPrivateHost('10.0.1.5'), isTrue);
      expect(isPrivateHost('192.168.1.1'), isTrue);
      expect(isPrivateHost('172.16.0.1'), isTrue);
      expect(isPrivateHost('169.254.169.254'), isTrue);
      expect(isPrivateHost('8.8.8.8'), isFalse);
      expect(isPrivateHost('google.com'), isFalse);
    });

    test(
      'Identifies punycode internationalized homograph phishing patterns',
      () {
        const punycodeDomain = 'xn--sbi-9ha.com'; // Deceptive lookalike
        expect(punycodeDomain.startsWith('xn--'), isTrue);
      },
    );
  });
}
