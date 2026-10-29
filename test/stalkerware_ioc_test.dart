// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Test: Stalkerware & Mobile Spyware Forensic IoC Engine Tests
// -----------------------------------------------------------------------------
import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/services/app_risk_engine.dart';

void main() {
  group('StalkerwareIoCService - Forensic Signature & Hash Matching', () {
    test(
      'Detects exact commercial stalkerware package (mSpy, FlexiSPY, Cerberus)',
      () {
        final mspyRes = StalkerwareIoCService.evaluate(
          package: 'com.mspy.android.tracker',
          name: 'Device Update Service',
          permissions: [
            'android.permission.INTERNET',
            'android.permission.ACCESS_FINE_LOCATION',
          ],
          isSystem: false,
          installer: 'unknown',
          hasLauncher: true,
          hasAccessibility: true,
          hasDeviceAdmin: false,
        );

        expect(mspyRes.isMatch, isTrue);
        expect(mspyRes.threatFamily, contains('mSpy'));
        expect(mspyRes.severity, equals(StalkerwareSeverity.critical));
        expect(mspyRes.confidence, greaterThanOrEqualTo(0.95));

        final flexiRes = StalkerwareIoCService.evaluate(
          package: 'com.flexispy.sys',
          name: 'Sync Helper',
          permissions: ['android.permission.RECORD_AUDIO'],
          isSystem: false,
          installer: 'unknown',
          hasLauncher: false,
          hasAccessibility: false,
          hasDeviceAdmin: false,
        );

        expect(flexiRes.isMatch, isTrue);
        expect(flexiRes.threatFamily, contains('FlexiSPY'));
      },
    );

    test('Detects Amnesty Tech MVT Pegasus / Chrysaor and Predator IoCs', () {
      final chrysaorRes = StalkerwareIoCService.evaluate(
        package: 'com.apple.chrysaor',
        name: 'System Kernel Helper',
        permissions: ['android.permission.INTERNET'],
        isSystem: false,
        installer: 'unknown',
        hasLauncher: false,
        hasAccessibility: false,
        hasDeviceAdmin: false,
      );

      expect(chrysaorRes.isMatch, isTrue);
      expect(chrysaorRes.threatFamily, contains('Pegasus'));
      expect(chrysaorRes.threatType, contains('Targeted Government'));

      final predatorRes = StalkerwareIoCService.evaluate(
        package: 'com.wsandroid.suite',
        name: 'Android Service Framework',
        permissions: ['android.permission.INTERNET'],
        isSystem: false,
        installer: 'unknown',
        hasLauncher: false,
        hasAccessibility: false,
        hasDeviceAdmin: false,
      );

      expect(predatorRes.isMatch, isTrue);
      expect(predatorRes.threatFamily, contains('Predator'));
    });

    test(
      'Detects cryptographic Signing Certificate SHA-256 fingerprint regardless of renamed package',
      () {
        // Package name is completely disguised as a clean calculator, but signed with FlexiSPY's deployment cert
        final certMatch = StalkerwareIoCService.evaluate(
          package: 'com.simple.standard.calculator',
          name: 'Calculator Plus',
          certSha256:
              'c486e9275084964e7c7e91d84877bc954f92beee9370cb8f8b80e461239c57d3',
          permissions: ['android.permission.INTERNET'],
          isSystem: false,
          installer: 'unknown',
          hasLauncher: true,
          hasAccessibility: false,
          hasDeviceAdmin: false,
        );

        expect(certMatch.isMatch, isTrue);
        expect(certMatch.confidence, equals(1.0));
        expect(
          certMatch.threatFamily,
          contains('FlexiSPY Deployment Signature'),
        );
        expect(certMatch.threatType, contains('Cryptographically Verified'));
        expect(certMatch.remediation, contains('IMMEDIATE ACTION'));
      },
    );

    test(
      'Identifies deceptive Android / Google camouflage packages sideloaded with high privileges',
      () {
        final camouflageRes = StalkerwareIoCService.evaluate(
          package: 'com.google.android.sync.updater',
          name: 'Google Play Services',
          permissions: [
            'android.permission.INTERNET',
            'android.permission.RECEIVE_SMS',
            'android.permission.SYSTEM_ALERT_WINDOW',
          ],
          isSystem: false,
          installer:
              'unknown', // Sideloaded direct APK, not genuine Google Play Store!
          hasLauncher: false,
          hasAccessibility: true,
          hasDeviceAdmin: true,
        );

        expect(camouflageRes.isMatch, isTrue);
        expect(camouflageRes.threatType, equals('Trojanized System Disguise'));
        expect(camouflageRes.severity, equals(StalkerwareSeverity.critical));
      },
    );

    test(
      'Flags stealth implant heuristic: no launcher + accessibility + mic + gps + sideloaded',
      () {
        final covertRes = StalkerwareIoCService.evaluate(
          package: 'org.unmarked.service.worker',
          name: 'Service Node',
          permissions: [
            'android.permission.INTERNET',
            'android.permission.RECORD_AUDIO',
            'android.permission.ACCESS_FINE_LOCATION',
            'android.permission.RECEIVE_SMS',
          ],
          isSystem: false,
          installer: 'unknown',
          hasLauncher: false, // Hidden icon
          hasAccessibility: true, // Screen scraper
          hasDeviceAdmin: false,
        );

        expect(covertRes.isMatch, isTrue);
        expect(covertRes.threatType, equals('Covert Spyware Heuristic'));
        expect(covertRes.severity, equals(StalkerwareSeverity.critical));
      },
    );

    test('Zero false positive on legitimate verified store app', () {
      final cleanRes = StalkerwareIoCService.evaluate(
        package: 'com.whatsapp',
        name: 'WhatsApp',
        certSha256:
            '38a0f7d505fe180ee64996704324667954b04f023fb886ff2bc19cc118476235',
        permissions: [
          'android.permission.INTERNET',
          'android.permission.RECORD_AUDIO',
          'android.permission.CAMERA',
          'android.permission.READ_CONTACTS',
        ],
        isSystem: false,
        installer: 'com.android.vending',
        hasLauncher: true,
        hasAccessibility: false,
        hasDeviceAdmin: false,
      );

      expect(cleanRes.isMatch, isFalse);
      expect(cleanRes.severity, equals(StalkerwareSeverity.low));
    });
  });

  group('AppRiskEngine - Forensic IoC Integration & Risk Scoring', () {
    test(
      'AppRiskEngine flags certificate-matched stalkerware as Critical with 100 riskScore',
      () {
        final app = AppRiskEngine.analyze({
          'name': 'Clean Utility Note',
          'package': 'com.stealth.note',
          'versionName': '1.0.0',
          'installer': 'unknown',
          'targetSdk': 33,
          'hasLauncher': true,
          'hasAccessibility': false,
          'hasDeviceAdmin': false,
          'isSystem': false,
          'signingCertificateSha256':
              '4f82d334585c5b4e7a602164a2f8d3810168ebad6df6fa9b4e138b16bb9b0a32', // mSpy cert
          'permissions': ['android.permission.INTERNET'],
        });

        expect(app.riskScore, greaterThanOrEqualTo(95));
        expect(app.riskLevel, equals(RiskLevel.critical));
        expect(app.stalkerwareIoC, isNotNull);
        expect(app.stalkerwareIoC!.isMatch, isTrue);
        expect(
          app.riskReasons.any((r) => r.contains('CRITICAL STALKERWARE')),
          isTrue,
        );
        expect(
          app.riskReasons.any((r) => r.contains('Forensic Detail')),
          isTrue,
        );
      },
    );

    test('AppRiskEngine flags MVT Pegasus IoC package signature instantly', () {
      final app = AppRiskEngine.analyze({
        'name': 'System Agent',
        'package': 'com.apple.chrysaor',
        'versionName': '1.0.0',
        'installer': 'unknown',
        'targetSdk': 33,
        'hasLauncher': false,
        'hasAccessibility': false,
        'hasDeviceAdmin': false,
        'isSystem': false,
        'permissions': ['android.permission.INTERNET'],
      });

      expect(app.riskScore, greaterThanOrEqualTo(95));
      expect(app.riskLevel, equals(RiskLevel.critical));
      expect(app.stalkerwareIoC?.threatFamily, contains('Pegasus'));
    });
  });
}
