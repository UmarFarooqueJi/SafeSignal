import 'dart:convert';
import 'dart:io';
import 'package:safesignal/core/services/url_intelligence_engine.dart';

class Fixture {
  final String id;
  final String category;
  final String url;
  final bool isMalicious;
  final String description;

  const Fixture({
    required this.id,
    required this.category,
    required this.url,
    required this.isMalicious,
    required this.description,
  });
}

final List<Fixture> adversarialCorpus = [
  // 1. Genuine Benign Indian Government, Banking & Educational
  Fixture(id: "B-01", category: "Govt/Banking", url: "https://www.incometax.gov.in/iec/foportal/", isMalicious: false, description: "Official Income Tax e-filing portal"),
  Fixture(id: "B-02", category: "Govt/Banking", url: "https://www.onlinesbi.sbi/portal/", isMalicious: false, description: "Official SBI Internet banking"),
  Fixture(id: "B-03", category: "Govt/Banking", url: "https://uidai.gov.in/my-aadhaar.html", isMalicious: false, description: "Official UIDAI Aadhaar portal"),
  Fixture(id: "B-04", category: "Govt/Banking", url: "https://www.rbi.org.in/scripts/BS_PressReleaseDisplay.aspx", isMalicious: false, description: "Official Reserve Bank of India"),
  Fixture(id: "B-05", category: "Govt/Banking", url: "https://home.iitd.ac.in/academic.php", isMalicious: false, description: "IIT Delhi official portal"),

  // 2. Legitimate Redirects
  Fixture(id: "B-06", category: "Legitimate Redirect", url: "https://www.google.com/url?q=https%3A%2F%2Fen.wikipedia.org%2Fwiki%2FCybersecurity", isMalicious: false, description: "Google outbound search redirect to Wikipedia"),
  Fixture(id: "B-07", category: "Legitimate Redirect", url: "https://onlinesbi.sbi/login?redirect=https%3A%2F%2Fretail.onlinesbi.sbi%2Fdashboard", isMalicious: false, description: "Internal bank portal auth redirect"),

  // 3. Legitimate APK Downloads
  Fixture(id: "B-08", category: "Legitimate APK", url: "https://f-droid.org/repo/org.fdroid.fdroid_1020050.apk", isMalicious: false, description: "Official F-Droid client APK download"),
  Fixture(id: "B-09", category: "Legitimate APK", url: "https://signal.org/android/apk/Signal-Android-website-prod-universal-release-7.2.0.apk", isMalicious: false, description: "Official Signal Messenger website APK"),

  // 4. Unusual but Benign TLDs
  Fixture(id: "B-10", category: "Unusual TLD", url: "https://amsterdam.museum/en/exhibitions", isMalicious: false, description: "Legitimate .museum TLD"),
  Fixture(id: "B-11", category: "Unusual TLD", url: "https://cybersecurity.academy/courses", isMalicious: false, description: "Legitimate educational .academy TLD"),
  Fixture(id: "B-12", category: "Unusual TLD", url: "https://standards.international/specifications", isMalicious: false, description: "Legitimate .international TLD"),

  // 5. Query Parameter Mentioning URL without Redirecting
  Fixture(id: "B-13", category: "URL in Query Param", url: "https://stackoverflow.com/questions/12345/help?ref=https://github.com/flutter/flutter", isMalicious: false, description: "StackOverflow referrer parameter"),
  Fixture(id: "B-14", category: "URL in Query Param", url: "https://news.ycombinator.com/item?id=391234&url=https://arxiv.org/abs/2401.0001", isMalicious: false, description: "Hacker News submission tracking param"),

  // 6. Benign Authority & Social Media
  Fixture(id: "B-15", category: "General Web", url: "https://github.com/UmarFarooqueJi/SafeSignal", isMalicious: false, description: "SafeSignal GitHub repository"),
  Fixture(id: "B-16", category: "General Web", url: "https://en.wikipedia.org/wiki/Advanced_Encryption_Standard", isMalicious: false, description: "Wikipedia AES cryptography article"),

  // 7. Malicious Open Redirect (Trusted Host to External Dropper)
  Fixture(id: "M-01", category: "Open Redirect", url: "https://trusted-bank.example/redirect?target=https%3A%2F%2Fevil-c2.top%2Fpayload.apk", isMalicious: true, description: "Trusted host with open redirect to APK dropper"),
  Fixture(id: "M-02", category: "Open Redirect", url: "https://gov.in.portal.example/out?dest=https%3A%2F%2Fstealer-site.xyz%2Flogin.php", isMalicious: true, description: "Open redirect to high-risk TLD credential harvester"),

  // 8. Encoded and Double-Encoded Destinations
  Fixture(id: "M-03", category: "Double Encoding", url: "https://onlinesbi.sbi.auth-portal.com/forward?url=https%253A%252F%252Fdark-trojan.top%252Fbank.apk", isMalicious: true, description: "Double-encoded external dropper parameter"),

  // 9. URL Userinfo Confusion / Basic Auth Injection
  Fixture(id: "M-04", category: "Userinfo Deception", url: "https://sbi.co.in:secure-login@phishing-target.net/verify", isMalicious: true, description: "Basic auth userinfo spoofing SBI"),
  Fixture(id: "M-05", category: "Userinfo Deception", url: "https://incometax.gov.in:refund@tax-fraud-stealer.xyz/claim", isMalicious: true, description: "Basic auth userinfo spoofing Income Tax"),

  // 10. Hostname Suffix Tricks & Brand Impersonation
  Fixture(id: "M-06", category: "Suffix Trick", url: "https://onlinesbi.sbi.attacker-controlled.net/login", isMalicious: true, description: "Brand name in subdomain of attacker domain"),
  Fixture(id: "M-07", category: "Suffix Trick", url: "https://incometaxindia.gov.in.fake-refund.club/pan-update", isMalicious: true, description: "Govt domain in subdomain of .club TLD"),

  // 11. Punycode & Mixed-Script Homographs
  Fixture(id: "M-08", category: "Homograph", url: "http://xn--80ak6aa92e.com/secure-login", isMalicious: true, description: "Cyrillic homograph impersonating apple.com"),
  Fixture(id: "M-09", category: "Homograph", url: "http://xn--sbi-980a.in/retail", isMalicious: true, description: "Punycode spoof of SBI banking"),

  // 12. SSRF & Private/Internal Host Indicators
  Fixture(id: "M-10", category: "SSRF", url: "http://127.0.0.1:8080/actuator/env", isMalicious: true, description: "Loopback IPv4 SSRF probe"),
  Fixture(id: "M-11", category: "SSRF", url: "http://192.168.1.1/admin/network.cfg", isMalicious: true, description: "RFC-1918 LAN router SSRF probe"),
  Fixture(id: "M-12", category: "SSRF", url: "http://169.254.169.254/latest/meta-data/", isMalicious: true, description: "AWS/Cloud link-local metadata probe"),
  Fixture(id: "M-13", category: "SSRF", url: "http://[::1]:8000/debug", isMalicious: true, description: "IPv6 loopback SSRF probe"),

  // 13. Direct Malicious Malware Droppers
  Fixture(id: "M-14", category: "Dropper", url: "http://speed-cleaner-booster.top/app.apk", isMalicious: true, description: "Android APK dropper on high-risk TLD"),
  Fixture(id: "M-15", category: "Dropper", url: "http://free-cracked-software.xyz/payload.dex", isMalicious: true, description: "Dalvik executable DEX dropper"),

  // 14. Multiple Embedded Destinations
  Fixture(id: "M-16", category: "Multi-Redirect", url: "https://ad-network.example/click?r1=https://benign.com&r2=https://malicious.top/trojan.apk", isMalicious: true, description: "Multi-destination query parameter with dropper"),

  // 15. Excessively Long & Malformed Inputs
  Fixture(id: "M-17", category: "Excessively Long", url: "https://attacker.xyz/phish?data=" + "A" * 2048, isMalicious: true, description: "Excessively long URL buffer overflow vector"),
  Fixture(id: "M-18", category: "Malformed", url: "http://invalid:::host:::99999/malware", isMalicious: true, description: "Malformed authority and port syntax"),
];

void main() async {
  print('Starting SafeSignal Adversarial URL Testing (34 Fixtures)...');

  int tp = 0;
  int fp = 0;
  int tn = 0;
  int fn = 0;

  final results = <Map<String, dynamic>>[];

  for (final fixture in adversarialCorpus) {
    try {
      final res = await UrlIntelligenceEngine.analyze(fixture.url);
      final isDetectedAsThreat = (res.riskScore >= 60 || res.verdict == UrlVerdict.dangerous || res.riskLevel == UrlRiskLevel.highRisk || res.riskLevel == UrlRiskLevel.knownMalicious);

      if (fixture.isMalicious) {
        if (isDetectedAsThreat) {
          tp++;
        } else {
          fn++;
        }
      } else {
        if (!isDetectedAsThreat) {
          tn++;
        } else {
          fp++;
        }
      }

      results.add({
        'id': fixture.id,
        'category': fixture.category,
        'url': fixture.url.length > 80 ? fixture.url.substring(0, 77) + '...' : fixture.url,
        'ground_truth': fixture.isMalicious ? 'Malicious' : 'Benign',
        'threat_score': res.riskScore,
        'verdict': res.verdict.name,
        'risk_level': res.riskLevel.name,
        'is_detected_threat': isDetectedAsThreat,
        'warnings': res.warnings,
      });

      print('[${fixture.id}] Score: ${res.riskScore} | Level: ${res.riskLevel.name} | GT: ${fixture.isMalicious ? "MAL" : "BEN"} | Cat: ${fixture.category}');
    } catch (e) {
      print('[${fixture.id}] EXCEPTION: $e');
    }
  }

  final precision = (tp + fp) > 0 ? tp / (tp + fp) : 0.0;
  final recall = (tp + fn) > 0 ? tp / (tp + fn) : 0.0;
  final fpr = (fp + tn) > 0 ? fp / (fp + tn) : 0.0;
  final f1 = (precision + recall) > 0 ? 2 * (precision * recall) / (precision + recall) : 0.0;

  print('\n=== ADVERSARIAL BENCHMARK SUMMARY ===');
  print('Total Fixtures: ${adversarialCorpus.length}');
  print('True Positives (TP): $tp');
  print('True Negatives (TN): $tn');
  print('False Positives (FP): $fp');
  print('False Negatives (FN): $fn');
  print('Precision: ${(precision * 100).toStringAsFixed(2)}%');
  print('Recall: ${(recall * 100).toStringAsFixed(2)}%');
  print('F1-Score: ${f1.toStringAsFixed(4)}');
  print('False Positive Rate (FPR): ${(fpr * 100).toStringAsFixed(2)}%');

  final summaryFile = File('test/adversarial_url_results.json');
  summaryFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'total_fixtures': adversarialCorpus.length,
    'tp': tp,
    'tn': tn,
    'fp': fp,
    'fn': fn,
    'precision': precision,
    'recall': recall,
    'fpr': fpr,
    'f1_score': f1,
    'fixtures': results,
  }));
}
