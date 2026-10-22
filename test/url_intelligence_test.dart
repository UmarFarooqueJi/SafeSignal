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

    test('Decouples unverified APK download from Trojan dropper (reports cautionary unverified status)', () async {
      final unverifiedApk = await UrlIntelligenceEngine.analyze('https://example-mirror.org/sample.apk');
      expect(unverifiedApk.verdict, UrlVerdict.caution);
      expect(unverifiedApk.riskLevel, UrlRiskLevel.suspicious);
      expect(unverifiedApk.riskScore, greaterThanOrEqualTo(25));
      expect(unverifiedApk.riskScore, lessThan(75));
      expect(unverifiedApk.riskExplanation, 'APK download detected; file security has not been verified.');
      expect(unverifiedApk.domainChecks.any((c) => c.name == 'Unverified APK Download'), isTrue);
    });

    test('Zero false positives on verified open-source APK repositories (F-Droid, Signal, GitHub)', () async {
      final fdroidApk = await UrlIntelligenceEngine.analyze('https://f-droid.org/F-Droid.apk');
      expect(fdroidApk.verdict, UrlVerdict.safe);
      expect(fdroidApk.domainChecks.any((c) => c.name.contains('Verified Software Repository APK')), isTrue);

      final signalApk = await UrlIntelligenceEngine.analyze('https://signal.org/android/apk/Signal-Android.apk');
      expect(signalApk.verdict, UrlVerdict.safe);
      expect(signalApk.domainChecks.any((c) => c.name.contains('Verified Software Repository APK')), isTrue);
    });

    test('Flags high-confidence malicious mobile droppers (scam lure or brand spoof + APK) as critical danger', () async {
      final maliciousApk = await UrlIntelligenceEngine.analyze('https://sbi-kyc-update.xyz/sbi.apk');
      expect(maliciousApk.verdict, UrlVerdict.dangerous);
      expect(maliciousApk.riskScore, greaterThanOrEqualTo(75));
      expect(maliciousApk.riskLevel, UrlRiskLevel.knownMalicious);
      expect(maliciousApk.domainChecks.any((c) => c.name.contains('Dropper')), isTrue);
    });

    test('Flags direct desktop executable binaries (.exe) as critical danger', () async {
      final exeDropper = await UrlIntelligenceEngine.analyze('https://update-security-patch.com/agent.exe');
      expect(exeDropper.verdict, UrlVerdict.dangerous);
      expect(exeDropper.riskScore, greaterThanOrEqualTo(65));
      expect(exeDropper.domainChecks.any((c) => c.name.contains('Dropper')), isTrue);
    });

    test('Identifies high-risk TLDs', () async {
      final tldRes = await UrlIntelligenceEngine.analyze('https://secure-auth.zip');
      expect(tldRes.domainChecks.any((c) => c.name.contains('Top-Level Domain') && c.passed == false), isTrue);
    });
  });

  group('UrlIntelligenceEngine - Open Redirect Defense & Destination Inspection', () {
    test('Critical Regression: Trusted host with unverified external redirect never forces Score 0', () async {
      final res = await UrlIntelligenceEngine.analyze('https://incometax.gov.in/redirect?url=https%3A%2F%2Fphishing.example');
      // Must NOT be safe or zero
      expect(res.riskScore, greaterThan(0));
      expect(res.verdict, isNot(UrlVerdict.safe));
      expect(res.riskLevel, UrlRiskLevel.suspicious);
      expect(res.isExternalRedirect, isTrue);
      expect(res.redirectTargetHost, 'phishing.example');
      expect(res.domainChecks.any((c) => c.name.contains('Open Redirect')), isTrue);
      expect(res.isVerifiedSafe, isFalse);
    });

    test('Critical Regression: Synthetic trusted host with external redirect analyzes destination safely without live probe', () async {
      final res = await UrlIntelligenceEngine.analyze('https://trusted.example/redirect?url=https%3A%2F%2Fphishing.example');
      expect(res.isExternalRedirect, isTrue);
      expect(res.redirectTargetHost, 'phishing.example');
      expect(res.riskScore, greaterThanOrEqualTo(25));
      expect(res.domainChecks.any((c) => c.name.contains('Open Redirect') && c.passed == false), isTrue);
    });

    test('External redirect pointing to malicious dropper receives critical danger verdict', () async {
      final res = await UrlIntelligenceEngine.analyze('https://incometax.gov.in/download?url=https%3A%2F%2Fmalware.top%2Fpayload.apk');
      expect(res.riskScore, greaterThanOrEqualTo(75));
      expect(res.verdict, UrlVerdict.dangerous);
      expect(res.riskLevel, UrlRiskLevel.knownMalicious);
      expect(res.isExternalRedirect, isTrue);
    });

    test('Benign internal redirect within same authority preserves low-risk rating', () async {
      final res = await UrlIntelligenceEngine.analyze('https://incometax.gov.in/login?return_to=https%3A%2F%2Fincometax.gov.in%2Fdashboard');
      expect(res.isExternalRedirect, isFalse);
      expect(res.riskScore, 0);
      expect(res.verdict, UrlVerdict.safe);
      expect(res.riskLevel, UrlRiskLevel.lowRisk);
      expect(res.domainChecks.any((c) => c.name == 'Redirection Integrity' && c.passed == true), isTrue);
    });
  });

  group('UrlIntelligenceEngine - Held-Out Benchmark & Metrics Validation', () {
    test('Calculates held-out benchmark: Precision, Recall, F1, and FPR', () async {
      // 10 Ground-Truth Benign URLs
      final benignFixtures = [
        'https://incometax.gov.in',
        'https://eportal.incometax.gov.in/iec/foservices',
        'https://uidai.gov.in',
        'https://sbi.co.in',
        'https://retail.onlinesbi.sbi',
        'https://netbanking.hdfcbank.com',
        'https://www.google.co.in',
        'https://whatsapp.com',
        'https://github.com',
        'https://incometax.gov.in/login?return_to=https%3A%2F%2Fincometax.gov.in%2Fportal',
      ];

      // 10 Ground-Truth Malicious / High-Risk URLs
      final maliciousFixtures = [
        'https://sbi-kyc-verification.xyz/login',
        'https://hdfc-bank-rewards.top/claim',
        'https://paytm-lottery-cashback.xyz',
        'https://update-security-patch.com/agent.apk',
        'https://xn--sbi-8cd.co.in',
        'http://192.168.1.1/admin',
        'https://google.com@phishing-target.net/login',
        'https://incometax.gov.in/redirect?url=https%3A%2F%2Fphishing.example',
        'https://incometax.gov.in/download?url=https%3A%2F%2Fmalware.top%2Fpayload.apk',
        'https://bank-urgent-aadhaar-link-immediate-refund.xyz/verify',
      ];

      int tp = 0; // True Positive
      int fp = 0; // False Positive
      int tn = 0; // True Negative
      int fn = 0; // False Negative

      final benignResults = await Future.wait(benignFixtures.map(UrlIntelligenceEngine.analyze));
      for (final res in benignResults) {
        if (res.verdict == UrlVerdict.safe) {
          tn++;
        } else {
          fp++;
        }
      }

      final maliciousResults = await Future.wait(maliciousFixtures.map(UrlIntelligenceEngine.analyze));
      for (final res in maliciousResults) {
        if (res.verdict != UrlVerdict.safe) {
          tp++;
        } else {
          fn++;
        }
      }

      final precision = tp / (tp + fp);
      final recall = tp / (tp + fn);
      final f1 = 2 * (precision * recall) / (precision + recall);
      final fpr = fp / (fp + tn);

      // Verify benchmark constraints
      expect(fp, 0, reason: 'False positives on authentic fixtures must be 0');
      expect(precision, 1.0, reason: 'Precision on benchmark corpus must be 1.0 (100%)');
      expect(recall, 1.0, reason: 'Recall on benchmark corpus must be 1.0 (100%)');
      expect(f1, 1.0, reason: 'F1 Score must be 1.0');
      expect(fpr, 0.0, reason: 'False positive rate must be 0.0%');
    }, timeout: const Timeout(Duration(minutes: 2)));
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

  group('UrlIntelligenceEngine - Malformed & Invalid URL Handling', () {
    test('Empty input returns invalidUrl status and cautious non-zero score', () async {
      final res = await UrlIntelligenceEngine.analyze('');
      expect(res.status, UrlInputStatus.invalidUrl);
      expect(res.riskScore, greaterThan(0));
      expect(res.isVerifiedSafe, isFalse);
      expect(res.verdict, UrlVerdict.caution);
      expect(res.riskLevel, UrlRiskLevel.unknown);
    });

    test('Missing authority or host returns invalidUrl status', () async {
      final res = await UrlIntelligenceEngine.analyze('http:///path/test');
      expect(res.status, UrlInputStatus.invalidUrl);
      expect(res.riskScore, greaterThan(0));
      expect(res.isVerifiedSafe, isFalse);
    });

    test('Invalid network port (>65535) returns invalidUrl status and cautions user', () async {
      final res = await UrlIntelligenceEngine.analyze('http://example.com:99999/test');
      expect(res.status, UrlInputStatus.invalidUrl);
      expect(res.riskScore, greaterThan(0));
      expect(res.isVerifiedSafe, isFalse);
      expect(res.warnings.any((w) => w.contains('port')), isTrue);
    });

    test('Broken IPv6 bracket syntax returns invalidUrl status', () async {
      final res = await UrlIntelligenceEngine.analyze('http://[:::1]/test');
      expect(res.status, UrlInputStatus.invalidUrl);
      expect(res.riskScore, greaterThan(0));
      expect(res.isVerifiedSafe, isFalse);
    });

    test('Malformed percent encoding returns invalidUrl status', () async {
      final res = await UrlIntelligenceEngine.analyze('http://example.com/%zz/test');
      expect(res.status, UrlInputStatus.invalidUrl);
      expect(res.riskScore, greaterThan(0));
      expect(res.isVerifiedSafe, isFalse);
    });

    test('Unsupported URI schemes (ftp, file, javascript) return unsupportedScheme status', () async {
      final ftpRes = await UrlIntelligenceEngine.analyze('ftp://ftp.example.com/file.zip');
      expect(ftpRes.status, UrlInputStatus.unsupportedScheme);
      expect(ftpRes.riskScore, greaterThan(0));
      expect(ftpRes.isVerifiedSafe, isFalse);
      expect(ftpRes.verdict, UrlVerdict.caution);

      final fileRes = await UrlIntelligenceEngine.analyze('file:///sdcard/download/app.apk');
      expect(fileRes.status, UrlInputStatus.unsupportedScheme);
      expect(fileRes.riskScore, greaterThan(0));

      final jsRes = await UrlIntelligenceEngine.analyze('javascript:alert(1)');
      expect(jsRes.status, UrlInputStatus.unsupportedScheme);
      expect(jsRes.riskScore, greaterThan(0));
    });

    test('ASCII control characters return invalidUrl status', () async {
      final res = await UrlIntelligenceEngine.analyze('http://example.com/\x00evil');
      expect(res.status, UrlInputStatus.invalidUrl);
      expect(res.riskScore, greaterThan(0));
      expect(res.isVerifiedSafe, isFalse);
    });

    test('Malformed host with unbracketed colons or consecutive dots returns invalidUrl', () async {
      final colonsRes = await UrlIntelligenceEngine.analyze('http://invalid:::host:::99999/malware');
      expect(colonsRes.status, UrlInputStatus.invalidUrl);
      expect(colonsRes.riskScore, greaterThan(0));

      final dotsRes = await UrlIntelligenceEngine.analyze('http://example..com/path');
      expect(dotsRes.status, UrlInputStatus.invalidUrl);
      expect(dotsRes.riskScore, greaterThan(0));
    });
  });
}
