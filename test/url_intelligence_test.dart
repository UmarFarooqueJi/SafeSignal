import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/services/url_intelligence_engine.dart';
import 'package:safesignal/core/services/link_guard_service.dart';

void main() {
  group('UrlIntelligenceEngine - Canonicalization & Host Parsing', () {
    test('Standardizes bare domains to HTTPS', () {
      final uri = UrlIntelligenceEngine.canonicalizeUrl('sbi.co.in');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'sbi.co.in');
    });

    test('Identifies HTTP Basic Auth deception targeting legitimate brands', () {
      final uri = UrlIntelligenceEngine.canonicalizeUrl('https://google.com@phishing-target.net/login');
      expect(uri, isNotNull);
      expect(uri!.userInfo, 'google.com');
      expect(uri.host, 'phishing-target.net');
    });

    test('Correctly extracts two-level ccTLD base domains', () {
      expect(UrlIntelligenceEngine.extractBaseDomain('retail.onlinesbi.sbi'), 'onlinesbi.sbi');
      expect(UrlIntelligenceEngine.extractBaseDomain('netbanking.hdfcbank.com'), 'hdfcbank.com');
      expect(UrlIntelligenceEngine.extractBaseDomain('sub.portal.incometax.gov.in'), 'incometax.gov.in');
      expect(UrlIntelligenceEngine.extractBaseDomain('branch.sbi.co.in'), 'sbi.co.in');
    });
  });

  group('UrlIntelligenceEngine - SSRF & Internal IP Guard', () {
    test('Flags loopback, LAN, and link-local addresses as internal', () {
      expect(UrlIntelligenceEngine.isPrivateOrReservedHost('localhost'), isTrue);
      expect(UrlIntelligenceEngine.isPrivateOrReservedHost('127.0.0.1'), isTrue);
      expect(UrlIntelligenceEngine.isPrivateOrReservedHost('10.0.5.21'), isTrue);
      expect(UrlIntelligenceEngine.isPrivateOrReservedHost('192.168.1.1'), isTrue);
      expect(UrlIntelligenceEngine.isPrivateOrReservedHost('172.16.4.1'), isTrue);
      expect(UrlIntelligenceEngine.isPrivateOrReservedHost('169.254.169.254'), isTrue);
    });

    test('Public internet IP hosts are not marked as private SSRF', () {
      expect(UrlIntelligenceEngine.isPrivateOrReservedHost('8.8.8.8'), isFalse);
      expect(UrlIntelligenceEngine.isPrivateOrReservedHost('1.1.1.1'), isFalse);
      expect(UrlIntelligenceEngine.isPrivateOrReservedHost('google.com'), isFalse);
    });

    test('Internal host scan produces dangerous verdict and blocks egress', () async {
      final res = await UrlIntelligenceEngine.analyze('http://192.168.1.1/admin');
      expect(res.verdict, UrlVerdict.dangerous);
      expect(res.riskScore, greaterThanOrEqualTo(75));
      expect(res.serverCountry, 'Private Network');
    });
  });

  group('UrlIntelligenceEngine - Brand Impersonation & Zero False Positives', () {
    test('Zero false positive on official SBI domains', () async {
      final sbi1 = await UrlIntelligenceEngine.analyze('https://sbi.co.in');
      expect(sbi1.verdict, UrlVerdict.safe);
      expect(sbi1.typosquattingWarning, isNull);
      expect(sbi1.isVerifiedSafe, isTrue);

      final sbi2 = await UrlIntelligenceEngine.analyze('https://retail.onlinesbi.sbi');
      expect(sbi2.verdict, UrlVerdict.safe);
      expect(sbi2.typosquattingWarning, isNull);

      final sbi3 = await UrlIntelligenceEngine.analyze('https://onlinesbi.com');
      expect(sbi3.verdict, UrlVerdict.safe);
      expect(sbi3.typosquattingWarning, isNull);
    });

    test('Zero false positive on official Indian Government and Bank portals', () async {
      final itGov = await UrlIntelligenceEngine.analyze('https://eportal.incometax.gov.in/iec/foservices');
      expect(itGov.verdict, UrlVerdict.safe);
      expect(itGov.typosquattingWarning, isNull);
      expect(itGov.isVerifiedSafe, isTrue);

      final hdfc = await UrlIntelligenceEngine.analyze('https://netbanking.hdfcbank.com');
      expect(hdfc.verdict, UrlVerdict.safe);
      expect(hdfc.typosquattingWarning, isNull);

      final googleIn = await UrlIntelligenceEngine.analyze('https://www.google.co.in');
      expect(googleIn.verdict, UrlVerdict.safe);
      expect(googleIn.typosquattingWarning, isNull);
    });

    test('Correctly catches fraudulent brand impersonation domains', () async {
      final fakeSbi = await UrlIntelligenceEngine.analyze('https://sbi-kyc-verification.xyz/login');
      expect(fakeSbi.verdict, UrlVerdict.dangerous);
      expect(fakeSbi.typosquattingWarning, isNotNull);
      expect(fakeSbi.typosquattingWarning, contains('SBI'));

      final fakeHdfc = await UrlIntelligenceEngine.analyze('https://hdfc-bank-rewards.top');
      expect(fakeHdfc.verdict, UrlVerdict.dangerous);
      expect(fakeHdfc.typosquattingWarning, isNotNull);
      expect(fakeHdfc.typosquattingWarning, contains('HDFC'));

      final fakePaytm = await UrlIntelligenceEngine.analyze('https://paytm-lottery-cashback.xyz');
      expect(fakePaytm.verdict, UrlVerdict.dangerous);
      expect(fakePaytm.typosquattingWarning, isNotNull);
      expect(fakePaytm.typosquattingWarning, contains('PAYTM'));
    });
  });

  group('UrlIntelligenceEngine - Homograph & Malware Droppers', () {
    test('Detects punycode and homograph visual deception attacks', () async {
      expect(UrlIntelligenceEngine.detectHomographAttack('xn--sbi-8cd.co.in'), isTrue);
      // 'раypal.com' with Cyrillic 'а' (U+0430) and 'р' (U+0440)
      expect(UrlIntelligenceEngine.detectHomographAttack('\u0440\u0430ypal.com'), isTrue);

      final homographRes = await UrlIntelligenceEngine.analyze('https://xn--sbi-8cd.co.in');
      expect(homographRes.verdict, UrlVerdict.dangerous);
      expect(homographRes.riskScore, greaterThanOrEqualTo(50));
    });

    test('Flags direct mobile/executable dropper links as critical danger', () async {
      final apkDropper = await UrlIntelligenceEngine.analyze('https://update-security-patch.com/agent.apk');
      expect(apkDropper.verdict, UrlVerdict.dangerous);
      expect(apkDropper.riskScore, greaterThanOrEqualTo(65));
      expect(apkDropper.domainChecks.any((c) => c.name.contains('Dropper')), isTrue);
    });

    test('Identifies high-risk TLDs', () async {
      final tldRes = await UrlIntelligenceEngine.analyze('https://secure-auth.zip');
      expect(tldRes.domainChecks.any((c) => c.name.contains('Top-Level Domain') && c.passed == false), isTrue);
    });
  });

  group('LinkGuardService - Shared Intent URL Extraction', () {
    test('Extracts direct URLs', () {
      expect(LinkGuardService.extractUrl('https://example.com'), 'https://example.com');
      expect(LinkGuardService.extractUrl('http://sbi.co.in/path'), 'http://sbi.co.in/path');
    });

    test('Extracts URL embedded inside WhatsApp or SMS scam text message', () {
      const msg = 'Dear Customer, your electricity will be disconnected tonight! Update bill now at https://bijli-bill-pay.xyz/update immediately.';
      final extracted = LinkGuardService.extractUrl(msg);
      expect(extracted, 'https://bijli-bill-pay.xyz/update');
    });

    test('Extracts bare domain without explicit scheme', () {
      const msg = 'Claim Rs 5000 cashback at paytm-bonus.click/claim now';
      final extracted = LinkGuardService.extractUrl(msg);
      expect(extracted, 'https://paytm-bonus.click/claim');
    });

    test('Returns null on pure non-URL text', () {
      expect(LinkGuardService.extractUrl('Hello, this is just a normal text message.'), isNull);
    });
  });
}
