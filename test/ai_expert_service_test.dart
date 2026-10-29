import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/services/ai_expert_service.dart';

void main() {
  group('AiExpertService - On-Device Forensic AI Advisor Tests', () {
    final aiService = AiExpertService();

    test('Generates contextual analysis for malicious dropper URLs', () async {
      final analysisEn = await aiService.explainWithExpert(
        domain: 'url',
        context:
            'Scan result: Dangerous URL pointing to malicious APK dropper payload.apk',
        language: 'en',
      );

      expect(analysisEn, contains('CRITICAL ALERT'));
      expect(analysisEn, contains('APK dropper'));
      expect(analysisEn, contains('banking trojan'));

      final analysisHi = await aiService.explainWithExpert(
        domain: 'url',
        context:
            'Scan result: Dangerous URL pointing to malicious APK dropper payload.apk',
        language: 'hi',
      );
      expect(analysisHi, contains('executable APK'));
    });

    test('Generates brand impersonation warning for deceptive domains', () async {
      final analysis = await aiService.explainWithExpert(
        domain: 'url',
        context:
            'Deceptive domain impersonating SBI with phishing patterns and typosquatting alert',
        language: 'en',
      );

      expect(analysis, contains('BRAND IMPERSONATION'));
      expect(analysis, contains('NetBanking'));
    });

    test(
      'Generates captive portal and SSL tampering warnings for Wi-Fi',
      () async {
        final wifiTamper = await aiService.explainWithExpert(
          domain: 'wifi',
          context:
              'WiFi scan result: SSL tampering detected, captive portal interception active',
          language: 'en',
        );

        expect(wifiTamper, contains('NETWORK TAMPERING'));
        expect(wifiTamper, contains('SSL'));

        final wifiOpen = await aiService.explainWithExpert(
          domain: 'wifi',
          context: 'WiFi network open without encryption',
          language: 'hi',
        );
        expect(wifiOpen, contains('UNENCRYPTED OPEN NETWORK'));
        expect(wifiOpen, contains('VPN'));
      },
    );

    test('Explains mobile spyware and stalkerware app threats', () async {
      final appAnalysis = await aiService.explainWithExpert(
        domain: 'app',
        context:
            'Package flagged with critical stalkerware signature and hidden icon',
        language: 'en',
      );

      expect(appAnalysis, contains('STALKERWARE'));
      expect(appAnalysis, contains('surveillance'));
      expect(appAnalysis, contains('Uninstall'));
    });

    test('Provides clear UPI fraud defense guidance', () async {
      final upiAnalysis = await aiService.explainWithExpert(
        domain: 'upi',
        context:
            'Suspicious UPI collect request or refund message asking to enter PIN',
        language: 'en',
      );

      expect(upiAnalysis, contains('UPI PIN'));
      expect(upiAnalysis, contains('DEBITING'));
      expect(upiAnalysis, contains('1930'));
    });
  });
}
