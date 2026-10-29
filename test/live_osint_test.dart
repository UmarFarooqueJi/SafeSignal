import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/services/live_osint_service.dart';
import 'package:safesignal/core/services/hibp_service.dart';

void main() {
  group('LiveOsintService - IntelBase OSINT & Exposure Scoring', () {
    late LiveOsintService service;

    setUp(() {
      service = LiveOsintService();
    });

    test('analyzes personal established Gmail domain correctly', () async {
      final profile = await service.performFullLookup('testuser@gmail.com', []);

      expect(profile.domainIntel.isFreeProvider, isTrue);
      expect(profile.domainIntel.isDisposable, isFalse);
      expect(profile.domainIntel.acceptsMail, isTrue);
      expect(profile.domainIntel.mailProvider, contains('Google'));
      expect(profile.authenticity.score, greaterThan(40));
      expect(profile.exposure.score, equals(0));
      expect(profile.exposure.band, equals('clean'));
    });

    test(
      'penalizes disposable burner emails with very low authenticity',
      () async {
        final profile = await service.performFullLookup(
          'throwaway@10minutemail.com',
          [],
        );

        expect(profile.domainIntel.isDisposable, isTrue);
        expect(profile.authenticity.score, lessThan(25));
        expect(profile.authenticity.band, equals('very_low'));
        expect(
          profile.authenticity.reasons.any(
            (r) => r.label.contains('disposable'),
          ),
          isTrue,
        );
      },
    );

    test(
      'calculates critical exposure score when infostealer logs and breaches are present',
      () async {
        final List<BreachInfo> mockBreaches = [
          const BreachInfo(
            title: 'RedLine Stealer Log Drop',
            domain: 'redline.c2',
            breachDate: '2023-08-15',
            pwnCount: 450000,
            description:
                'Infostealer malware log containing browser autofill and passwords',
            dataClasses: ['Passwords', 'Browser autofill', 'IP addresses'],
            isVerified: true,
            logoPath: '',
            passwordRisk: 'Plaintext',
          ),
          const BreachInfo(
            title: 'Canva',
            domain: 'canva.com',
            breachDate: '2019-05-24',
            pwnCount: 137000000,
            description: 'Compromised customer database',
            dataClasses: ['Passwords', 'Email addresses', 'Usernames'],
            isVerified: true,
            logoPath: '',
            passwordRisk: 'Salted SHA-256',
          ),
        ];

        final profile = await service.performFullLookup(
          'victim@targetcorp.com',
          mockBreaches,
        );

        expect(profile.exposure.score, greaterThan(60));
        expect(profile.stealerReport.hasStealerExposure, isTrue);
        expect(
          profile.stealerReport.stealerFamilies,
          contains('RedLine Stealer'),
        );
        expect(profile.passwordReuseCount, equals(2));
        expect(profile.timeline.isNotEmpty, isTrue);
      },
    );

    test(
      'formats handle to likely owner name when no public profile found',
      () async {
        final profile = await service.performFullLookup(
          'rahul.verma@example.com',
          [],
        );

        expect(profile.likelyOwner, equals('Rahul Verma'));
      },
    );
  });
}
