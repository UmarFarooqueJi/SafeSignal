import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/features/app_scanner/app_scanner_screen.dart';

void main() {
  group('RiskEngine.analyze security heuristic tests', () {
    test('Play Store app with SMS + Overlay is not granted immunity', () {
      final app = RiskEngine.analyze({
        'name': 'Banking Utility Helper',
        'package': 'com.sample.fakehelper',
        'versionName': '1.0.0',
        'installer': 'com.android.vending',
        'targetSdk': 34,
        'hasLauncher': true,
        'hasAccessibility': false,
        'hasDeviceAdmin': false,
        'isSystem': false,
        'permissions': [
          'android.permission.INTERNET',
          'android.permission.READ_SMS',
          'android.permission.SYSTEM_ALERT_WINDOW',
        ],
      });

      expect(app.riskScore, greaterThan(38));
      expect(app.riskLevel, isNot(RiskLevel.safe));
      expect(
        app.riskReasons.any((r) => r.contains('SMS + Screen Overlay')),
        isTrue,
      );
    });

    test('Stalkerware signature hits trigger Critical risk regardless of installer', () {
      final app = RiskEngine.analyze({
        'name': 'Parental Tracking Tool',
        'package': 'com.mspy.android.tracker',
        'versionName': '4.2.1',
        'installer': 'com.android.vending',
        'targetSdk': 33,
        'hasLauncher': true,
        'hasAccessibility': true,
        'hasDeviceAdmin': false,
        'isSystem': false,
        'permissions': [
          'android.permission.INTERNET',
          'android.permission.ACCESS_FINE_LOCATION',
        ],
      });

      expect(app.riskScore, greaterThanOrEqualTo(90));
      expect(app.riskLevel, equals(RiskLevel.critical));
      expect(
        app.riskReasons.any((r) => r.contains('STALKERWARE')),
        isTrue,
      );
    });

    test('Benign verified store app with minimal permissions remains safe', () {
      final app = RiskEngine.analyze({
        'name': 'Simple Calculator',
        'package': 'com.calc.clean',
        'versionName': '2.0.0',
        'installer': 'com.android.vending',
        'targetSdk': 34,
        'hasLauncher': true,
        'hasAccessibility': false,
        'hasDeviceAdmin': false,
        'isSystem': false,
        'permissions': [
          'android.permission.VIBRATE',
        ],
      });

      expect(app.riskScore, lessThan(20));
      expect(app.riskLevel, equals(RiskLevel.safe));
    });

    test('Sideloaded APK with banking trojan pattern receives maximum critical severity', () {
      final app = RiskEngine.analyze({
        'name': 'Update Manager',
        'package': 'org.malicious.dropper',
        'versionName': '0.9.1',
        'installer': 'unknown',
        'targetSdk': 26,
        'hasLauncher': true,
        'hasAccessibility': false,
        'hasDeviceAdmin': false,
        'isSystem': false,
        'permissions': [
          'android.permission.INTERNET',
          'android.permission.RECEIVE_SMS',
          'android.permission.SYSTEM_ALERT_WINDOW',
        ],
      });

      expect(app.riskScore, greaterThanOrEqualTo(75));
      expect(app.riskLevel, equals(RiskLevel.critical));
      expect(
        app.riskReasons.any((r) => r.contains('Classic Banking Trojan Pattern')),
        isTrue,
      );
    });

    test('Stealth APK hiding launcher icon with microphone access is flagged high risk', () {
      final app = RiskEngine.analyze({
        'name': 'Audio Core Service',
        'package': 'com.hidden.mic',
        'versionName': '1.0.0',
        'installer': 'unknown',
        'targetSdk': 33,
        'hasLauncher': false,
        'hasAccessibility': false,
        'hasDeviceAdmin': false,
        'isSystem': false,
        'permissions': [
          'android.permission.RECORD_AUDIO',
        ],
      });

      expect(app.riskScore, greaterThanOrEqualTo(50));
      expect(app.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
      expect(
        app.riskReasons.any((r) => r.contains('Stealth package hiding launcher icon')),
        isTrue,
      );
    });

    test('Spoofed brand package name (com.sbi.fakebank) with unverified installer is flagged sideloaded and critical with trojan perms', () {
      final app = RiskEngine.analyze({
        'name': 'SBI Quick Auth',
        'package': 'com.sbi.fakebank.auth',
        'versionName': '3.1.0',
        'installer': 'unknown',
        'targetSdk': 28,
        'hasLauncher': true,
        'hasAccessibility': false,
        'hasDeviceAdmin': false,
        'isSystem': false,
        'permissions': [
          'android.permission.INTERNET',
          'android.permission.RECEIVE_SMS',
          'android.permission.SYSTEM_ALERT_WINDOW',
        ],
      });

      expect(app.isSideloaded, isTrue);
      expect(app.riskScore, greaterThanOrEqualTo(75));
      expect(app.riskLevel, equals(RiskLevel.critical));
      expect(
        app.riskReasons.any((r) => r.contains('Sideloaded App')),
        isTrue,
      );
    });

    test('Spoofed Google package name (com.google.updater) without verified store installer does not receive ecosystem immunity', () {
      final app = RiskEngine.analyze({
        'name': 'Google Play Services Patch',
        'package': 'com.google.updater.quickpatch',
        'versionName': '1.0.0',
        'installer': 'browser_download',
        'targetSdk': 25,
        'hasLauncher': true,
        'hasAccessibility': false,
        'hasDeviceAdmin': true,
        'isSystem': false,
        'permissions': [
          'android.permission.INTERNET',
          'android.permission.READ_CONTACTS',
        ],
      });

      expect(app.isSideloaded, isTrue);
      expect(app.riskReasons.any((r) => r.contains('Sideloaded App')), isTrue);
      expect(app.riskReasons.any((r) => r.contains('Outdated SDK')), isTrue);
      expect(app.riskReasons.any((r) => r.contains('Device Admin')), isTrue);
      expect(app.riskScore, greaterThan(38));
    });
  });
}
