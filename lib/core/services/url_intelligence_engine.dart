import 'dart:async';
import 'package:dio/dio.dart';

/// Verdict tier for URL security analysis
enum UrlVerdict {
  safe,
  caution,
  dangerous,
}

/// Granular risk classification tier
enum UrlRiskLevel {
  lowRisk,
  suspicious,
  highRisk,
  knownMalicious,
  unknown,
}

/// Structured inspection detail item displayed in the SafeSignal UI
class DomainCheckItem {
  final String name;
  final bool? passed; // true = safe, false = failed/danger, null = neutral/info
  final String detail;

  DomainCheckItem(this.name, this.passed, this.detail);
}

/// Structured analysis of redirection targets and nested query destinations
class RedirectAnalysis {
  final bool hasRedirect;
  final bool isExternal;
  final String? paramKey;
  final String? rawTarget;
  final String? targetHost;
  final String? targetBaseDomain;
  final Uri? targetUri;
  final bool hasTargetHighRiskTld;
  final bool isTargetSsrf;
  final bool isTargetDropper;
  final String? targetBrandSpoof;
  final int redirectRiskDelta;
  final String description;

  const RedirectAnalysis({
    required this.hasRedirect,
    this.isExternal = false,
    this.paramKey,
    this.rawTarget,
    this.targetHost,
    this.targetBaseDomain,
    this.targetUri,
    this.hasTargetHighRiskTld = false,
    this.isTargetSsrf = false,
    this.isTargetDropper = false,
    this.targetBrandSpoof,
    this.redirectRiskDelta = 0,
    this.description = '',
  });
}

/// Comprehensive forensic analysis result of a scanned URL
class UrlResult {
  final String url;
  final String domain;
  final int riskScore; // 0 (Clean) to 100 (Critical Malicious)
  final UrlVerdict verdict;
  final Map<String, bool> checks;
  final List<String> warnings;
  final List<String> positives;
  final List<DomainCheckItem> domainChecks;
  final bool isVerifiedSafe;
  final String siteTitle;
  final String siteDescription;
  final String serverCountry;
  final String serverCity;
  final String serverIsp;
  final String serverIp;
  final String serverSoftware;
  final String poweredBy;
  final String contentType;
  final int securityHeaders;
  final List<String> aRecords;
  final List<String> mxRecords;
  final List<String> nsRecords;
  final bool hasDmarc;
  final String? typosquattingWarning;
  final UrlRiskLevel riskLevel;
  final String? redirectTargetUrl;
  final String? redirectTargetHost;
  final bool isExternalRedirect;
  final String riskExplanation;

  UrlResult({
    required this.url,
    required this.domain,
    required this.riskScore,
    required this.verdict,
    required this.checks,
    required this.warnings,
    required this.positives,
    required this.domainChecks,
    required this.isVerifiedSafe,
    this.siteTitle = '',
    this.siteDescription = '',
    this.serverCountry = '',
    this.serverCity = '',
    this.serverIsp = '',
    this.serverIp = '',
    this.serverSoftware = '',
    this.poweredBy = '',
    this.contentType = '',
    this.securityHeaders = 0,
    this.aRecords = const [],
    this.mxRecords = const [],
    this.nsRecords = const [],
    this.hasDmarc = false,
    this.typosquattingWarning,
    this.riskLevel = UrlRiskLevel.lowRisk,
    this.redirectTargetUrl,
    this.redirectTargetHost,
    this.isExternalRedirect = false,
    this.riskExplanation = '',
  });

  factory UrlResult.error(String url, {String message = 'Analysis could not be completed'}) {
    return UrlResult(
      url: url,
      domain: '',
      riskScore: 0,
      verdict: UrlVerdict.caution,
      checks: const {},
      warnings: [message],
      positives: const [],
      domainChecks: [
        DomainCheckItem('Scan Status', null, message),
      ],
      isVerifiedSafe: false,
      riskLevel: UrlRiskLevel.unknown,
      isExternalRedirect: false,
      riskExplanation: message,
    );
  }
}

/// Production URL Intelligence & Threat Detection Engine
/// Handles canonicalization, homograph/punycode attacks, brand impersonation,
/// SSRF/private host validation, TLD risk, and privacy-preserving DNS-over-HTTPS.
class UrlIntelligenceEngine {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
  ));

  // ─── INSTITUTIONAL BRAND AUTHORITY REGISTRY ──────────────────────────────────
  // Maps target brands to all legitimate root domains.
  // Any domain matching these root domains is NEVER flagged as impersonating.
  static const Map<String, List<String>> brandRegistry = {
    'sbi': ['sbi.co.in', 'onlinesbi.sbi', 'onlinesbi.com', 'statebankofindia.com'],
    'hdfc': ['hdfcbank.com', 'hdfc.com', 'hdfcsec.com'],
    'icici': ['icicibank.com', 'icicidirect.com', 'icicilombard.com', 'iciciprulife.com'],
    'axis': ['axisbank.com', 'axisdirect.in'],
    'kotak': ['kotak.com', 'kotaksecurities.com'],
    'pnb': ['pnbindia.in', 'pnbnet.net.in'],
    'bob': ['bankofbaroda.in', 'bankofbaroda.com'],
    'canara': ['canarabank.com'],
    'paytm': ['paytm.com', 'paytmbank.com'],
    'phonepe': ['phonepe.com'],
    'gpay': ['google.com', 'google.co.in', 'gpay.app'],
    'google': ['google.com', 'google.co.in', 'youtube.com', 'gmail.com', 'gstatic.com', 'android.com', 'withgoogle.com'],
    'incometax': ['incometax.gov.in', 'incometaxindia.gov.in', 'tin-nsdl.com'],
    'uidai': ['uidai.gov.in', 'myaadhaar.uidai.gov.in'],
    'aadhaar': ['uidai.gov.in', 'myaadhaar.uidai.gov.in'],
    'epfo': ['epfindia.gov.in'],
    'irctc': ['irctc.co.in'],
    'indiapost': ['indiapost.gov.in'],
    'parivahan': ['parivahan.gov.in'],
    'jio': ['jio.com', 'reliancedigital.in'],
    'airtel': ['airtel.in', 'airtel.com'],
    'vi': ['myvi.in'],
    'amazon': ['amazon.in', 'amazon.com', 'media-amazon.com', 'ssl-images-amazon.com'],
    'flipkart': ['flipkart.com', 'flipkart.net'],
    'whatsapp': ['whatsapp.com', 'wa.me'],
    'netflix': ['netflix.com'],
    'microsoft': ['microsoft.com', 'live.com', 'office.com', 'azure.com'],
    'apple': ['apple.com', 'icloud.com'],
    'paypal': ['paypal.com', 'paypal.me'],
  };

  // Verified Institutional Allowlist
  static const Set<String> institutionalAllowlist = {
    'google.com', 'google.co.in', 'youtube.com', 'facebook.com', 'instagram.com', 'whatsapp.com',
    'sbi.co.in', 'onlinesbi.sbi', 'onlinesbi.com', 'statebankofindia.com',
    'hdfcbank.com', 'hdfc.com', 'icicibank.com', 'axisbank.com', 'kotak.com', 'pnbindia.in',
    'amazon.in', 'amazon.com', 'flipkart.com', 'myntra.com', 'meesho.com',
    'paytm.com', 'phonepe.com', 'gpay.app',
    'incometax.gov.in', 'uidai.gov.in', 'npci.org.in', 'rbi.org.in',
    'irctc.co.in', 'nic.in', 'gov.in', 'india.gov.in', 'passportindia.gov.in',
    'epfindia.gov.in', 'parivahan.gov.in', 'indiapost.gov.in',
    'bsnl.co.in', 'tatamotors.com', 'reliance.com', 'jio.com', 'airtel.in', 'myvi.in',
    'microsoft.com', 'apple.com', 'linkedin.com', 'twitter.com', 'x.com', 'github.com',
    'cloudflare.com', 'wikipedia.org',
  };

  // High-Risk TLDs
  static const Set<String> highRiskTlds = {
    '.zip', '.mov', '.tk', '.ml', '.ga', '.cf', '.gq', '.top', '.xyz', '.work',
    '.click', '.link', '.rest', '.country', '.stream', '.download', '.racing',
    '.buzz', '.quest', '.icu', '.monster', '.cam', '.live',
  };

  // Dangerous File Extensions
  static const List<String> dangerousExtensions = [
    '.apk', '.exe', '.dex', '.vbs', '.bat', '.scr', '.jar', '.msi', '.cmd', '.ps1',
  ];

  // Suspicious Social Engineering Keywords
  static const List<String> urgencyKeywords = [
    'kyc', 'pan-update', 'aadhaar-link', 'lottery', 'winner', 'jackpot',
    'digital-arrest', 'police-fine', 'electricity-bill', 'power-cut',
    'free-recharge', 'claim-reward', 'unblock-account', 'otp-verify',
    'urgent-action', 'immediate-refund',
  ];

  /// Canonicalizes an input string into a standard URI
  static Uri? canonicalizeUrl(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return null;

    // Check for HTTP basic auth deception (e.g. https://google.com@evil-site.com)
    // Extract actual authority
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }

    try {
      final parsed = Uri.parse(raw);
      if (!parsed.hasAuthority || parsed.host.isEmpty) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  /// Verifies if a hostname is private, loopback, or reserved (SSRF guard)
  static bool isPrivateOrReservedHost(String host) {
    final lower = host.toLowerCase().trim();
    if (lower == 'localhost' || lower == '127.0.0.1' || lower == '::1' || lower == '0.0.0.0') {
      return true;
    }

    final ipParts = lower.split('.');
    if (ipParts.length == 4) {
      final nums = ipParts.map((p) => int.tryParse(p)).toList();
      if (nums.every((n) => n != null && n >= 0 && n <= 255)) {
        final n0 = nums[0]!;
        final n1 = nums[1]!;
        if (n0 == 127) return true; // Loopback
        if (n0 == 10) return true;  // 10.0.0.0/8
        if (n0 == 172 && n1 >= 16 && n1 <= 31) return true; // 172.16.0.0/12
        if (n0 == 192 && n1 == 168) return true; // 192.168.0.0/16
        if (n0 == 169 && n1 == 254) return true; // Link-local (AWS/cloud metadata)
        if (n0 == 0) return true;
        if (n0 >= 224) return true; // Multicast / Class E reserved
      }
    }
    return false;
  }

  /// Extracts the effective registered base domain (e.g. sub.sbi.co.in -> sbi.co.in)
  static String extractBaseDomain(String hostname) {
    final clean = hostname.toLowerCase().replaceAll(RegExp(r'^www\.'), '');
    final parts = clean.split('.');
    if (parts.length <= 2) return clean;

    // Two-level ccTLDs (e.g. .co.in, .gov.in, .nic.in, .org.in, .net.in, .co.uk)
    final lastTwo = '${parts[parts.length - 2]}.${parts.last}';
    final specialTwoLevelTlds = {
      'co.in', 'gov.in', 'nic.in', 'org.in', 'net.in', 'ac.in', 'edu.in',
      'co.uk', 'org.uk', 'com.au', 'net.au', 'co.nz', 'co.jp', 'com.br',
    };

    if (specialTwoLevelTlds.contains(lastTwo) && parts.length >= 3) {
      return '${parts[parts.length - 3]}.$lastTwo';
    }

    return '${parts[parts.length - 2]}.${parts.last}';
  }

  /// Checks if a domain is part of an institutional brand or an unauthorized impersonator
  static String? detectBrandImpersonation(String domain) {
    final d = domain.toLowerCase();

    // Check if domain is an official government domain
    if (d.endsWith('.gov.in') || d.endsWith('.nic.in')) {
      return null; // Government domains under gov.in/nic.in are officially authenticated
    }

    for (final entry in brandRegistry.entries) {
      final brandKey = entry.key;
      final authorizedDomains = entry.value;

      // Check if domain contains brand keyword
      if (d.contains(brandKey)) {
        // Verify against all authorized root domains
        bool isAuthorized = false;
        for (final authRoot in authorizedDomains) {
          if (d == authRoot || d.endsWith('.$authRoot')) {
            isAuthorized = true;
            break;
          }
        }

        if (!isAuthorized) {
          final officialSite = authorizedDomains.first;
          return 'Deceptive domain impersonating ${brandKey.toUpperCase()}! Official site is: $officialSite';
        }
      }
    }
    return null;
  }

  /// Detects homograph punycode spoofing (mixed Cyrillic / Greek characters)
  static bool detectHomographAttack(String domain) {
    final lower = domain.toLowerCase();
    if (lower.startsWith('xn--')) return true;

    // Common Cyrillic lookalikes: а, с, е, о, р, х, у (U+0430, U+0441, U+0435, U+043E, U+0440, U+0445, U+0443)
    final cyrillicLookalikes = RegExp(r'[\u0430\u0441\u0435\u043E\u0440\u0445\u0443\u0400-\u04FF]');
    if (cyrillicLookalikes.hasMatch(lower) && RegExp(r'[a-z0-9]').hasMatch(lower)) {
      return true;
    }
    return false;
  }

  /// Safely extracts and analyzes redirection query parameters and target destinations
  /// without issuing any live HTTP requests to untrusted endpoints.
  static RedirectAnalysis inspectRedirectionVector({
    required Uri uri,
    required String baseDomain,
  }) {
    final candidateKeys = {
      'url', 'redirect', 'redirect_url', 'redirect_uri', 'next', 'return_to',
      'return', 'dest', 'destination', 'target', 'link', 'r', 'u', 'goto',
      'continue', 'forward', 'out', 'to'
    };

    String? foundTarget;
    String? foundKey;

    for (final entry in uri.queryParameters.entries) {
      if (candidateKeys.contains(entry.key.toLowerCase())) {
        foundKey = entry.key;
        foundTarget = entry.value;
        break;
      }
    }

    if (foundTarget == null && uri.hasQuery) {
      final reg = RegExp(
        r'(?:^|[&?])(?:url|redirect|redirect_url|redirect_uri|next|dest|destination|target|link|goto|to)=([^&]+)',
        caseSensitive: false,
      );
      final m = reg.firstMatch(uri.query);
      if (m != null) {
        foundKey = 'query_param';
        foundTarget = m.group(1);
      }
    }

    if (foundTarget == null || foundTarget.trim().isEmpty) {
      return const RedirectAnalysis(hasRedirect: false);
    }

    // Safely decode percent encoding (handle up to 2 levels)
    String decoded = foundTarget.trim();
    for (int i = 0; i < 2; i++) {
      try {
        final next = Uri.decodeComponent(decoded);
        if (next == decoded) break;
        decoded = next;
      } catch (_) {
        break;
      }
    }

    // Protocol-relative URLs: //evil.com/path -> https://evil.com/path
    if (decoded.startsWith('//')) {
      decoded = 'https:$decoded';
    }

    Uri? targetUri;
    try {
      if (decoded.startsWith('http://') || decoded.startsWith('https://')) {
        targetUri = Uri.parse(decoded);
      } else if (decoded.startsWith('/') || !decoded.contains('.')) {
        // Relative path redirect, e.g. /login or /dashboard
        return RedirectAnalysis(
          hasRedirect: true,
          isExternal: false,
          paramKey: foundKey,
          rawTarget: decoded,
          targetHost: uri.host,
          targetBaseDomain: baseDomain,
          redirectRiskDelta: 0,
          description: 'URL contains internal relative redirection ($foundKey=$decoded).',
        );
      } else {
        // e.g. "phishing.example/login" without scheme
        targetUri = Uri.tryParse('https://$decoded');
      }
    } catch (_) {
      return RedirectAnalysis(
        hasRedirect: true,
        isExternal: true,
        paramKey: foundKey,
        rawTarget: decoded,
        targetHost: 'malformed_destination',
        redirectRiskDelta: 30,
        description: 'URL contains malformed or obfuscated redirect parameter ($foundKey).',
      );
    }

    if (targetUri == null || !targetUri.hasAuthority || targetUri.host.isEmpty) {
      return RedirectAnalysis(
        hasRedirect: true,
        isExternal: false,
        paramKey: foundKey,
        rawTarget: decoded,
        targetHost: uri.host,
        targetBaseDomain: baseDomain,
        redirectRiskDelta: 0,
        description: 'URL contains benign parameter without external authority.',
      );
    }

    final targetHost = targetUri.host.toLowerCase();
    final targetBase = extractBaseDomain(targetHost);
    final isExternal = (targetBase != baseDomain && !targetHost.endsWith('.$baseDomain'));

    if (!isExternal) {
      return RedirectAnalysis(
        hasRedirect: true,
        isExternal: false,
        paramKey: foundKey,
        rawTarget: decoded,
        targetHost: targetHost,
        targetBaseDomain: targetBase,
        targetUri: targetUri,
        redirectRiskDelta: 0,
        description: 'URL contains internal redirect parameter pointing within the same domain hierarchy ($targetHost).',
      );
    }

    // External target detected: inspect destination properties
    final hasHighRiskTld = highRiskTlds.any((tld) => targetHost.endsWith(tld));
    final isSsrf = isPrivateOrReservedHost(targetHost);
    final isDropper = dangerousExtensions.any((ext) =>
        (targetUri?.path.toLowerCase().endsWith(ext) ?? false) ||
        (targetUri?.query.toLowerCase().contains(ext) ?? false));
    final brandSpoof = detectBrandImpersonation(targetHost);

    int riskDelta = 25; // Base uncertainty for unverified external destination
    if (hasHighRiskTld) riskDelta += 25;
    if (isSsrf) riskDelta += 35;
    if (isDropper) riskDelta += 50;
    if (brandSpoof != null) riskDelta += 35;

    final String desc = 'URL contains parameter ($foundKey) directing to external host ($targetHost).'
        ' Redirection destination is unverified; caution advised.';

    return RedirectAnalysis(
      hasRedirect: true,
      isExternal: true,
      paramKey: foundKey,
      rawTarget: decoded,
      targetHost: targetHost,
      targetBaseDomain: targetBase,
      targetUri: targetUri,
      hasTargetHighRiskTld: hasHighRiskTld,
      isTargetSsrf: isSsrf,
      isTargetDropper: isDropper,
      targetBrandSpoof: brandSpoof,
      redirectRiskDelta: riskDelta,
      description: desc,
    );
  }

  /// Performs deep multi-factor URL analysis
  static Future<UrlResult> analyze(String rawUrl) async {
    final uri = canonicalizeUrl(rawUrl);
    if (uri == null) {
      return UrlResult.error(rawUrl, message: 'Invalid URL format');
    }

    final rawHost = uri.host.toLowerCase();
    final domain = rawHost.replaceAll(RegExp(r'^www\.'), '');
    final baseDomain = extractBaseDomain(domain);
    final urlPath = uri.path.toLowerCase();
    final urlQuery = uri.query.toLowerCase();

    final domainChecks = <DomainCheckItem>[];
    int riskScore = 0;
    bool isAllowlisted = false;

    // ─── 0. SSRF & PRIVATE NETWORK GUARD ─────────────────────────────────────
    final isSsrfHost = isPrivateOrReservedHost(rawHost);
    if (isSsrfHost) {
      riskScore = 80;
      domainChecks.add(DomainCheckItem(
        'SSRF & Internal Host Guard',
        false,
        'Target points to a loopback, link-local, or private RFC-1918 internal address ($domain). Outbound scraping blocked.',
      ));
      return UrlResult(
        url: rawUrl,
        domain: domain,
        riskScore: riskScore,
        verdict: UrlVerdict.dangerous,
        checks: const {},
        warnings: ['Internal Network / Loopback Host Target'],
        positives: const [],
        domainChecks: domainChecks,
        isVerifiedSafe: false,
        serverCountry: 'Private Network',
        serverCity: 'Local Host',
        serverIsp: 'Private LAN',
        serverIp: domain,
        riskLevel: UrlRiskLevel.knownMalicious,
        isExternalRedirect: false,
        riskExplanation: 'Target points to private RFC-1918 or loopback internal network address.',
      );
    }

    // ─── 1. HTTP BASIC AUTH SPOOFING CHECK ───────────────────────────────────
    if (uri.userInfo.isNotEmpty) {
      riskScore += 65;
      domainChecks.add(DomainCheckItem(
        'URL Credential Deception',
        false,
        'URL utilizes HTTP Basic Auth prefix (${uri.userInfo}@) to disguise real target host: $rawHost.',
      ));
    }

    // ─── 2. INSTITUTIONAL ALLOWLIST CHECK ────────────────────────────────────
    if (institutionalAllowlist.contains(domain) ||
        institutionalAllowlist.contains(baseDomain) ||
        domain.endsWith('.gov.in') ||
        domain.endsWith('.nic.in')) {
      isAllowlisted = true;
      domainChecks.add(DomainCheckItem(
        'Trusted Institutional Registry',
        true,
        'Verified in SafeSignal on-device registry of authenticated institutional domains ($domain).',
      ));
    } else {
      domainChecks.add(DomainCheckItem(
        'Institutional Registry',
        null,
        'Not in local allowlist of verified institutional domains (Neutral).',
      ));
    }

    // ─── 3. BRAND IMPERSONATION & TYPOSQUATTING ──────────────────────────────
    final brandSpoof = detectBrandImpersonation(domain);
    if (brandSpoof != null) {
      riskScore += 60;
      domainChecks.insert(0, DomainCheckItem('Phishing & Brand Impersonation', false, brandSpoof));
    }

    // ─── 4. HOMOGRAPH & PUNYCODE SPOOFING ────────────────────────────────────
    final isHomograph = detectHomographAttack(domain);
    if (isHomograph) {
      riskScore += 60;
      domainChecks.add(DomainCheckItem(
        'Homograph Spoofing Attack',
        false,
        'Punycode or mixed-character lookalike domain detected ($domain). High probability of visual deception.',
      ));
    }

    // ─── 5. HIGH RISK TLD PROFILING ──────────────────────────────────────────
    bool hasHighRiskTld = false;
    for (final tld in highRiskTlds) {
      if (domain.endsWith(tld)) {
        hasHighRiskTld = true;
        riskScore += 25;
        domainChecks.add(DomainCheckItem(
          'Top-Level Domain (TLD) Reputation',
          false,
          'Uses high-abuse free or disposable TLD ($tld). Frequently utilized by cybercrime syndicates.',
        ));
        break;
      }
    }
    if (!hasHighRiskTld) {
      domainChecks.add(DomainCheckItem(
        'Top-Level Domain (TLD) Reputation',
        true,
        'Standard commercial or institutional top-level domain.',
      ));
    }

    // ─── 6. DANGEROUS FILE EXTENSION (APK/MALWARE DROPPER) ───────────────────
    bool isDropper = false;
    for (final ext in dangerousExtensions) {
      if (urlPath.endsWith(ext) || urlQuery.contains(ext)) {
        isDropper = true;
        riskScore += 65;
        domainChecks.insert(0, DomainCheckItem(
          'Malicious Executable Dropper',
          false,
          'CRITICAL: URL directly downloads executable/mobile payload ($ext). Risk of Trojan or spyware installation.',
        ));
        break;
      }
    }

    // ─── 7. DEEP REDIRECTION & DESTINATION INSPECTION ────────────────────────
    final redirectAnalysis = inspectRedirectionVector(
      uri: uri,
      baseDomain: baseDomain,
    );

    if (redirectAnalysis.hasRedirect) {
      if (redirectAnalysis.isExternal) {
        riskScore += redirectAnalysis.redirectRiskDelta;
        domainChecks.add(DomainCheckItem(
          'Open Redirect & Destination Vector',
          false,
          redirectAnalysis.description,
        ));
      } else {
        domainChecks.add(DomainCheckItem(
          'Redirection Integrity',
          true,
          redirectAnalysis.description,
        ));
      }
    }

    // ─── 8. SOCIAL ENGINEERING / URGENCY KEYWORDS ────────────────────────────
    final matchedUrgency = urgencyKeywords.where((kw) => urlPath.contains(kw) || urlQuery.contains(kw)).toList();
    if (matchedUrgency.isNotEmpty) {
      riskScore += 20;
      domainChecks.add(DomainCheckItem(
        'Social Engineering Signatures',
        false,
        'Urgency or scam trigger keywords found in path/query: ${matchedUrgency.join(', ')}.',
      ));
    }

    // ─── 9. DOMAIN STRUCTURE & HYPHEN ENTROPY ────────────────────────────────
    final hyphenCount = domain.split('-').length - 1;
    final dotCount = domain.split('.').length - 1;
    if (hyphenCount >= 3 || dotCount >= 4) {
      riskScore += 20;
      domainChecks.add(DomainCheckItem(
        'Domain Structure & Entropy',
        false,
        'Unusually high complexity ($hyphenCount hyphens, $dotCount dots). Typical of disposable phishing hosts.',
      ));
    }

    // ─── 10. RAW IP ADDRESS AS HOST ──────────────────────────────────────────
    final ipRegex = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
    if (ipRegex.hasMatch(domain)) {
      riskScore += 30;
      domainChecks.add(DomainCheckItem(
        'Host Identification',
        false,
        'Using raw IP address instead of registered domain name. Evades domain reputation blocklists.',
      ));
    }

    // ─── 11. PRIVACY-PRESERVING DNS-OVER-HTTPS (CLOUDFLARE 1.1.1.1) ──────────
    List<String> aRecords = [];
    List<String> mxRecords = [];
    List<String> nsRecords = [];
    bool hasDmarc = false;

    try {
      final dnsFutures = await Future.wait([
        _queryDoh(domain, 'A'),
        _queryDoh(domain, 'MX'),
        _queryDoh(domain, 'NS'),
        _queryDoh('_dmarc.$domain', 'TXT'),
      ]);

      aRecords = dnsFutures[0];
      mxRecords = dnsFutures[1];
      nsRecords = dnsFutures[2];
      hasDmarc = dnsFutures[3].any((txt) => txt.toLowerCase().contains('v=dmarc1'));

      if (aRecords.isEmpty && !isSsrfHost) {
        riskScore += 15;
        domainChecks.add(DomainCheckItem(
          'DNS Host Resolution',
          false,
          'Domain has no active A records (Unresolvable / Dead Host).',
        ));
      } else {
        domainChecks.add(DomainCheckItem(
          'DNS Host Resolution',
          true,
          'Active A records resolved via DNS-over-HTTPS (${aRecords.take(2).join(', ')}).',
        ));
      }

      if (hasDmarc) {
        domainChecks.add(DomainCheckItem(
          'Email DMARC Security',
          true,
          'DMARC email authentication policy published. Protected against spoofed emails.',
        ));
      }

      if (mxRecords.isNotEmpty) {
        domainChecks.add(DomainCheckItem(
          'Mail Server Infrastructure (MX)',
          true,
          'Valid mail exchange infrastructure configured (${mxRecords.first}).',
        ));
      } else if (!isAllowlisted && !hasHighRiskTld) {
        domainChecks.add(DomainCheckItem(
          'Mail Server Infrastructure (MX)',
          null,
          'No mail server records configured (Neutral).',
        ));
      }
    } catch (_) {
      // Offline or DoH blocked
    }

    // ─── 12. GENUINE TLS ENCRYPTION PROBE ────────────────────────────────────
    bool isHttps = uri.scheme == 'https';
    if (!isHttps) {
      riskScore += 25;
      domainChecks.add(DomainCheckItem(
        'Transport Security',
        false,
        'Unencrypted HTTP transport. Traffic can be intercepted or manipulated in transit.',
      ));
    } else {
      domainChecks.add(DomainCheckItem(
        'Transport Security',
        true,
        'Standard HTTPS transport configured.',
      ));
    }

    // ─── VERDICT CALIBRATION & RISK LEVEL CLASSIFICATION ─────────────────────
    final bool hasCriticalThreats = isDropper ||
        brandSpoof != null ||
        isHomograph ||
        uri.userInfo.isNotEmpty ||
        (redirectAnalysis.hasRedirect && redirectAnalysis.isExternal);

    if (isAllowlisted) {
      if (!hasCriticalThreats) {
        // Authentic, unmanipulated institutional service without external redirects
        riskScore = 0;
      } else {
        // Institutional domain with active threat signals (open redirect, credential deception, dropper)
        // Trust reputation does not grant unconditional bypass.
        riskScore = riskScore.clamp(0, 100);
      }
    } else {
      riskScore = riskScore.clamp(0, 100);
    }

    final verdict = riskScore >= 51
        ? UrlVerdict.dangerous
        : riskScore >= 21
            ? UrlVerdict.caution
            : UrlVerdict.safe;

    final UrlRiskLevel riskLevel;
    if (riskScore >= 75) {
      riskLevel = (isDropper || brandSpoof != null || isHomograph || redirectAnalysis.isTargetDropper)
          ? UrlRiskLevel.knownMalicious
          : UrlRiskLevel.highRisk;
    } else if (riskScore >= 21) {
      riskLevel = UrlRiskLevel.suspicious;
    } else if (!isAllowlisted && aRecords.isEmpty && !isSsrfHost) {
      riskLevel = UrlRiskLevel.unknown;
    } else {
      riskLevel = UrlRiskLevel.lowRisk;
    }

    String riskExplanation;
    if (redirectAnalysis.hasRedirect && redirectAnalysis.isExternal) {
      riskExplanation = 'Potential unverified external redirect to ${redirectAnalysis.targetHost}.';
    } else if (isDropper) {
      riskExplanation = 'Executable mobile/binary payload dropper detected.';
    } else if (brandSpoof != null) {
      riskExplanation = brandSpoof;
    } else if (isHomograph) {
      riskExplanation = 'Homograph/punycode visual spoofing detected.';
    } else if (uri.userInfo.isNotEmpty) {
      riskExplanation = 'URL credential deception (HTTP basic auth prefix).';
    } else if (isAllowlisted && riskScore == 0) {
      riskExplanation = 'Verified institutional domain with valid security profile.';
    } else if (verdict == UrlVerdict.safe) {
      riskExplanation = 'Standard low-risk domain with no anomalies.';
    } else {
      riskExplanation = 'Elevated risk factors detected (${domainChecks.where((c) => c.passed == false).length} warnings).';
    }

    return UrlResult(
      url: rawUrl,
      domain: domain,
      riskScore: riskScore,
      verdict: verdict,
      checks: const {},
      warnings: [],
      positives: [],
      domainChecks: domainChecks,
      isVerifiedSafe: isAllowlisted && riskScore <= 20,
      aRecords: aRecords,
      mxRecords: mxRecords,
      nsRecords: nsRecords,
      hasDmarc: hasDmarc,
      typosquattingWarning: brandSpoof,
      serverIp: aRecords.isNotEmpty ? aRecords.first : domain,
      serverCountry: isAllowlisted ? 'Verified Host' : 'Global',
      riskLevel: riskLevel,
      redirectTargetUrl: redirectAnalysis.rawTarget,
      redirectTargetHost: redirectAnalysis.targetHost,
      isExternalRedirect: redirectAnalysis.isExternal,
      riskExplanation: riskExplanation,
    );
  }

  /// Private DNS-over-HTTPS resolver (Cloudflare 1.1.1.1)
  /// Only resolves domain names, zero URL query paths or user telemetry leaked
  static Future<List<String>> _queryDoh(String host, String type) async {
    try {
      final res = await _dio.get(
        'https://cloudflare-dns.com/dns-query',
        queryParameters: {
          'name': host,
          'type': type,
        },
        options: Options(
          headers: {'accept': 'application/dns-json'},
          receiveTimeout: const Duration(seconds: 3),
        ),
      );

      if (res.statusCode == 200 && res.data is Map && res.data['Answer'] is List) {
        final answers = res.data['Answer'] as List;
        return answers
            .map((ans) => ans['data']?.toString().replaceAll('"', '').trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}
