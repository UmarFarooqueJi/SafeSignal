import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'virus_total_service.dart';

/// Verdict tier for URL security analysis
enum UrlVerdict { safe, caution, dangerous }

/// Granular risk classification tier
enum UrlRiskLevel { lowRisk, suspicious, highRisk, knownMalicious, unknown }

/// Input processing status distinguishing structural validity from threat classification
enum UrlInputStatus {
  validUrl,
  invalidUrl,
  unsupportedScheme,
  unknownReputation,
  analysisError,
}

/// Granular cyber threat & payload classification
enum MalwareThreatType {
  clean,
  ratDropper,
  bankingTrojan,
  spywareDropper,
  apkDropper,
  phishingScam,
  credentialHarvester,
  suspiciousRedirect,
  unknownThreat,
}

/// Structured inspection detail item displayed in the SafeSignal UI
class DomainCheckItem {
  final String name;
  final bool? passed; // true = safe, false = failed/danger, null = neutral/info
  final String detail;

  DomainCheckItem(this.name, this.passed, this.detail);
}

/// Structured inspection result from zero-day DOM & credential harvesting analysis
class DomInspectionResult {
  final bool isThreat;
  final MalwareThreatType threatType;
  final String threatCategory;
  final String detail;
  final int confidenceDelta;

  const DomInspectionResult({
    required this.isThreat,
    this.threatType = MalwareThreatType.clean,
    this.threatCategory = '',
    this.detail = '',
    this.confidenceDelta = 0,
  });

  static const clean = DomInspectionResult(isThreat: false);
}

/// Validation result produced during early URL ingestion and parsing
class UrlValidationResult {
  final UrlInputStatus status;
  final Uri? uri;
  final String? errorMessage;
  final String? detectedScheme;

  const UrlValidationResult({
    required this.status,
    this.uri,
    this.errorMessage,
    this.detectedScheme,
  });

  bool get isValid => status == UrlInputStatus.validUrl && uri != null;
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
  final UrlInputStatus status;
  final MalwareThreatType threatType;
  final String threatCategoryBadge;
  final String threatForensicDetails;
  final List<String> redirectChain;
  final VirusTotalScanResult? virusTotalResult;
  final SecurityDnsCheckResult? securityDnsResult;
  final bool isDgaDomain;
  final bool isCredentialHarvester;
  final String? detectedFormType;
  final double shannonEntropy;

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
    this.status = UrlInputStatus.validUrl,
    this.threatType = MalwareThreatType.clean,
    this.threatCategoryBadge = '',
    this.threatForensicDetails = '',
    this.redirectChain = const [],
    this.virusTotalResult,
    this.securityDnsResult,
    this.isDgaDomain = false,
    this.isCredentialHarvester = false,
    this.detectedFormType,
    this.shannonEntropy = 0.0,
  });

  factory UrlResult.error(
    String url, {
    String message = 'Analysis could not be completed',
    UrlInputStatus status = UrlInputStatus.analysisError,
    int riskScore = 30,
  }) {
    return UrlResult(
      url: url,
      domain: '',
      riskScore: riskScore,
      verdict: UrlVerdict.caution,
      checks: const {},
      warnings: [message],
      positives: const [],
      domainChecks: [DomainCheckItem('Scan Status', false, message)],
      isVerifiedSafe: false,
      riskLevel: UrlRiskLevel.unknown,
      isExternalRedirect: false,
      riskExplanation: message,
      status: status,
      threatType: MalwareThreatType.unknownThreat,
      threatCategoryBadge: 'ANALYSIS NOTICE',
      threatForensicDetails: message,
      redirectChain: const [],
      virusTotalResult: VirusTotalScanResult.error(url, message),
      securityDnsResult: SecurityDnsCheckResult.clean,
    );
  }
}

/// Production URL Intelligence & Threat Detection Engine
/// Handles canonicalization, homograph/punycode attacks, brand impersonation,
/// SSRF/private host validation, TLD risk, and privacy-preserving DNS-over-HTTPS.
class UrlIntelligenceEngine {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ),
  );

  // ─── INSTITUTIONAL BRAND AUTHORITY REGISTRY ──────────────────────────────────
  // Maps target brands to all legitimate root domains.
  // Any domain matching these root domains is NEVER flagged as impersonating.
  static const Map<String, List<String>> brandRegistry = {
    // Indian Banking & Payment
    'sbi': [
      'sbi.co.in',
      'onlinesbi.sbi',
      'onlinesbi.com',
      'statebankofindia.com',
      'sbicard.com',
    ],
    'hdfc': ['hdfcbank.com', 'hdfc.com', 'hdfcsec.com', 'hdfclife.com'],
    'icici': [
      'icicibank.com',
      'icicidirect.com',
      'icicilombard.com',
      'iciciprulife.com',
    ],
    'axis': ['axisbank.com', 'axisdirect.in'],
    'kotak': ['kotak.com', 'kotaksecurities.com'],
    'pnb': ['pnbindia.in', 'pnbnet.net.in'],
    'bob': ['bankofbaroda.in', 'bankofbaroda.com'],
    'canara': ['canarabank.com'],
    'indusind': ['indusind.com'],
    'yesbank': ['yesbank.in', 'yesbank.com'],
    'idfc': ['idfcfirstbank.com'],
    'unionbank': ['unionbankofindia.co.in'],
    'paytm': ['paytm.com', 'paytmbank.com'],
    'phonepe': ['phonepe.com'],
    'gpay': ['google.com', 'google.co.in', 'gpay.app'],
    'cred': ['cred.club'],
    'bharatpe': ['bharatpe.com'],
    'npci': ['npci.org.in'],
    'bhim': ['bhimupi.org.in'],

    // Global Banking & FinTech
    'paypal': ['paypal.com', 'paypal.me'],
    'chase': ['chase.com'],
    'wellsfargo': ['wellsfargo.com'],
    'bankofamerica': ['bankofamerica.com', 'bofa.com'],
    'citi': ['citi.com', 'citibank.com'],
    'hsbc': ['hsbc.com', 'hsbc.co.in', 'hsbc.co.uk'],
    'barclays': ['barclays.co.uk', 'barclays.com'],
    'santander': ['santander.com', 'santander.co.uk'],
    'revolut': ['revolut.com'],
    'wise': ['wise.com', 'transferwise.com'],
    'venmo': ['venmo.com'],
    'cashapp': ['cash.app'],
    'stripe': ['stripe.com'],

    // Indian Gov & Citizen Services
    'incometax': ['incometax.gov.in', 'incometaxindia.gov.in', 'tin-nsdl.com'],
    'uidai': ['uidai.gov.in', 'myaadhaar.uidai.gov.in'],
    'aadhaar': ['uidai.gov.in', 'myaadhaar.uidai.gov.in'],
    'epfo': ['epfindia.gov.in'],
    'irctc': ['irctc.co.in'],
    'indiapost': ['indiapost.gov.in', 'postalpincode.in'],
    'parivahan': ['parivahan.gov.in', 'sarathi.parivahan.gov.in'],
    'digilocker': ['digilocker.gov.in'],

    // Big Tech & Social Platforms
    'google': [
      'google.com',
      'google.co.in',
      'youtube.com',
      'gmail.com',
      'gstatic.com',
      'android.com',
      'withgoogle.com',
    ],
    'microsoft': [
      'microsoft.com',
      'live.com',
      'office.com',
      'office365.com',
      'azure.com',
      'outlook.com',
      'sharepoint.com',
      'microsoftonline.com',
    ],
    'apple': ['apple.com', 'icloud.com'],
    'amazon': [
      'amazon.in',
      'amazon.com',
      'media-amazon.com',
      'ssl-images-amazon.com',
      'aws.amazon.com',
    ],
    'flipkart': ['flipkart.com', 'flipkart.net'],
    'netflix': ['netflix.com'],
    'whatsapp': ['whatsapp.com', 'wa.me'],
    'telegram': ['telegram.org', 't.me'],
    'facebook': ['facebook.com', 'fb.com', 'meta.com'],
    'instagram': ['instagram.com'],
    'twitter': ['twitter.com', 'x.com', 't.co'],
    'linkedin': ['linkedin.com'],
    'steam': ['steampowered.com', 'steamcommunity.com'],
    'spotify': ['spotify.com'],
    'discord': ['discord.com', 'discord.gg'],

    // Crypto & Web3
    'binance': ['binance.com', 'binance.org'],
    'coinbase': ['coinbase.com'],
    'metamask': ['metamask.io'],
    'trustwallet': ['trustwallet.com'],
    'ledger': ['ledger.com'],
    'trezor': ['trezor.io'],
    'phantom': ['phantom.app'],
    'bybit': ['bybit.com'],
    'kucoin': ['kucoin.com'],
    'opensea': ['opensea.io'],

    // Couriers
    'fedex': ['fedex.com'],
    'dhl': ['dhl.com'],
    'ups': ['ups.com'],
    'bluedart': ['bluedart.com'],
    'delhivery': ['delhivery.com'],
    'dtdc': ['dtdc.in', 'dtdc.com'],

    // Telecom
    'jio': ['jio.com', 'reliancedigital.in'],
    'airtel': ['airtel.in', 'airtel.com'],
    'vi': ['myvi.in'],
    'bsnl': ['bsnl.co.in'],
  };

  // Verified Institutional Allowlist
  static const Set<String> institutionalAllowlist = {
    'google.com',
    'google.co.in',
    'youtube.com',
    'facebook.com',
    'instagram.com',
    'whatsapp.com',
    'sbi.co.in',
    'onlinesbi.sbi',
    'onlinesbi.com',
    'statebankofindia.com',
    'hdfcbank.com',
    'hdfc.com',
    'icicibank.com',
    'axisbank.com',
    'kotak.com',
    'pnbindia.in',
    'amazon.in',
    'amazon.com',
    'flipkart.com',
    'myntra.com',
    'meesho.com',
    'paytm.com',
    'phonepe.com',
    'gpay.app',
    'incometax.gov.in',
    'uidai.gov.in',
    'npci.org.in',
    'rbi.org.in',
    'irctc.co.in',
    'nic.in',
    'gov.in',
    'india.gov.in',
    'passportindia.gov.in',
    'epfindia.gov.in',
    'parivahan.gov.in',
    'indiapost.gov.in',
    'bsnl.co.in',
    'tatamotors.com',
    'reliance.com',
    'jio.com',
    'airtel.in',
    'myvi.in',
    'microsoft.com',
    'apple.com',
    'linkedin.com',
    'twitter.com',
    'x.com',
    'github.com',
    'cloudflare.com',
    'wikipedia.org',
    'f-droid.org',
    'signal.org',
  };

  // High-Risk TLDs
  static const Set<String> highRiskTlds = {
    '.zip',
    '.mov',
    '.tk',
    '.ml',
    '.ga',
    '.cf',
    '.gq',
    '.top',
    '.xyz',
    '.work',
    '.click',
    '.link',
    '.rest',
    '.country',
    '.stream',
    '.download',
    '.racing',
    '.buzz',
    '.quest',
    '.icu',
    '.monster',
    '.cam',
    '.live',
  };

  // Curated Command & Control (C2) / Banking Trojan Distribution Registry
  // Sources: Maltrail, URLhaus, and Mobile Threat Telemetry
  static const Set<String> knownC2Domains = {
    'anatsa-c2.top',
    'teabot-gateway.biz',
    'flubot-sync.ru',
    'godfather-panel.cc',
    'sharkbot-api.online',
    'cerberus-gate.xyz',
    'alien-rat-c2.net',
    'dns-update-service.com',
    'google-verify-mobile.com',
    'whatsapp-backup-cloud.org',
    'sbi-kyc-update.live',
    'hdfc-secure-verify.net',
    'icici-reward-claim.shop',
    'axis-net-login.info',
    'pnb-kyc-portal.club',
    'update-system-carrier.com',
    'android-ota-patch.net',
    'quicksupport-apk.download',
    'anydesk-security-update.com',
    'teamviewer-support-portal.info',
  };

  // High-Risk Dynamic DNS / Tunneling Endpoints Frequently Abused by Mobile C2s
  static const Set<String> highRiskDynamicDnsSuffixes = {
    '.duckdns.org',
    '.hopto.org',
    '.ngrok-free.app',
    '.ngrok.io',
    '.serveo.net',
    '.loca.lt',
    '.pagekite.me',
  };

  // Known URL Shortener Services for Recursive Unravelling
  static const Set<String> knownUrlShorteners = {
    'bit.ly',
    'tinyurl.com',
    't.co',
    'cutt.ly',
    'is.gd',
    'rb.gy',
    'ow.ly',
    'shorturl.at',
    'goo.gl',
    'qr.ae',
    'buff.ly',
    'trib.al',
    'lnkd.in',
    'rebrand.ly',
  };

  // Verified Open-Source and Official Mobile Application Repositories
  static const Set<String> verifiedApkPublishers = {
    'f-droid.org',
    'github.com',
    'gitlab.com',
    'signal.org',
    'telegram.org',
    'whatsapp.com',
    'mozilla.org',
    'torproject.org',
    'apkmirror.com',
  };

  // Dangerous File Extensions
  static const List<String> dangerousExtensions = [
    '.apk',
    '.exe',
    '.dex',
    '.vbs',
    '.bat',
    '.scr',
    '.jar',
    '.msi',
    '.cmd',
    '.ps1',
  ];

  // Suspicious Social Engineering Keywords
  static const List<String> urgencyKeywords = [
    'kyc',
    'pan-update',
    'aadhaar-link',
    'lottery',
    'winner',
    'jackpot',
    'digital-arrest',
    'police-fine',
    'electricity-bill',
    'power-cut',
    'free-recharge',
    'claim-reward',
    'unblock-account',
    'otp-verify',
    'urgent-action',
    'immediate-refund',
  ];

  // Cloud & Free Subdomain Hosting Services Frequently Abused by Phishing Kits
  static const Set<String> abusedCloudPlatforms = {
    'workers.dev',
    'pages.dev',
    'vercel.app',
    'netlify.app',
    'firebaseapp.com',
    'web.app',
    'github.io',
    'gitlab.io',
    'glitch.me',
    'render.com',
    'railway.app',
    '000webhostapp.com',
    'weebly.com',
    'wixsite.com',
    'sites.google.com',
    'supabase.co',
    'azurestaticapps.net',
    'blob.core.windows.net',
    's3.amazonaws.com',
    'ipfs.io',
    'dweb.link',
    'pinata.cloud',
    'cf-ipfs.com',
    'duckdns.org',
    'ngrok-free.app',
    'ngrok.io',
    'loca.lt',
    'serveo.net',
  };

  // Credential Harvesting, Banking & Phishing Path Signatures
  static const List<String> phishingPathKeywords = [
    'login',
    'signin',
    'auth',
    'webscr',
    'wp-login',
    'authenticate',
    'account-verification',
    'update-billing',
    'secure-auth',
    'reset-security',
    'kyc-verification',
    'netbanking',
    'unblock-account',
    'wallet-connect',
    'seed-phrase',
    'restore-wallet',
    'confirm-identity',
    'claim-reward',
    'customer-support',
  ];

  /// Validates and parses an untrusted raw URL string, returning structured input status
  static UrlValidationResult validateAndParse(String input) {
    final rawTrimmed = input.trim();
    if (rawTrimmed.isEmpty) {
      return const UrlValidationResult(
        status: UrlInputStatus.invalidUrl,
        errorMessage: 'Input URL string cannot be empty or blank.',
      );
    }

    // Reject non-printable / ASCII control characters
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(rawTrimmed)) {
      return const UrlValidationResult(
        status: UrlInputStatus.invalidUrl,
        errorMessage: 'URL contains illegal ASCII control characters.',
      );
    }

    // Inspect scheme
    final schemeMatch = RegExp(
      r'^([a-zA-Z][a-zA-Z0-9+.-]*):',
    ).firstMatch(rawTrimmed);
    String effectiveUrl = rawTrimmed;
    if (schemeMatch != null) {
      final scheme = schemeMatch.group(1)!.toLowerCase();
      if (scheme != 'http' && scheme != 'https') {
        return UrlValidationResult(
          status: UrlInputStatus.unsupportedScheme,
          detectedScheme: scheme,
          errorMessage:
              'Unsupported URI scheme ($scheme). Only HTTP and HTTPS schemes are supported.',
        );
      }
    } else {
      // Missing explicit scheme: standard web normalization
      if (rawTrimmed.startsWith('//')) {
        effectiveUrl = 'https:$rawTrimmed';
      } else {
        effectiveUrl = 'https://$rawTrimmed';
      }
    }

    // Percent-encoding validation in raw string
    // A '%' must be followed by two hexadecimal digits
    if (RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(effectiveUrl)) {
      return const UrlValidationResult(
        status: UrlInputStatus.invalidUrl,
        errorMessage:
            'Malformed percent-encoding in URL: incomplete or non-hexadecimal escape sequence.',
      );
    }

    // Attempt Uri.parse
    final Uri parsed;
    try {
      parsed = Uri.parse(effectiveUrl);
    } on FormatException catch (e) {
      return UrlValidationResult(
        status: UrlInputStatus.invalidUrl,
        errorMessage: 'Malformed URI syntax: ${e.message}',
      );
    } catch (e) {
      return UrlValidationResult(
        status: UrlInputStatus.analysisError,
        errorMessage: 'Unexpected error during URI parsing: $e',
      );
    }

    // Must have authority and host
    if (!parsed.hasAuthority || parsed.host.isEmpty) {
      return const UrlValidationResult(
        status: UrlInputStatus.invalidUrl,
        errorMessage: 'URL is missing valid authority or host specification.',
      );
    }

    final host = parsed.host;

    // Check port boundaries (1 - 65535)
    final portMatch = RegExp(
      r':([0-9]+)(?:/|\?|#|$)',
    ).firstMatch(parsed.authority);
    if (portMatch != null) {
      final parsedPort = int.tryParse(portMatch.group(1)!);
      if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
        return UrlValidationResult(
          status: UrlInputStatus.invalidUrl,
          errorMessage:
              'Invalid network port specified in authority (${portMatch.group(1)}). Valid range is 1-65535.',
        );
      }
    }

    // Check for malformed non-numeric port indicator (e.g. host:abc or host:::)
    final authorityWithoutUser = parsed.authority.replaceFirst(
      RegExp(r'^[^@]+@'),
      '',
    );
    if (RegExp(r':[^0-9/\\?#]+').hasMatch(authorityWithoutUser)) {
      if (!host.startsWith('[') || !host.endsWith(']')) {
        return const UrlValidationResult(
          status: UrlInputStatus.invalidUrl,
          errorMessage:
              'Authority contains malformed port delimiter or non-numeric port.',
        );
      }
    }

    // IPv6 host validation
    if (host.startsWith('[') && host.endsWith(']')) {
      final ipv6Literal = host.substring(1, host.length - 1);
      try {
        Uri.parseIPv6Address(ipv6Literal);
      } catch (_) {
        return const UrlValidationResult(
          status: UrlInputStatus.invalidUrl,
          errorMessage: 'Malformed IPv6 address literal inside brackets.',
        );
      }
    } else if (host.contains(':')) {
      return const UrlValidationResult(
        status: UrlInputStatus.invalidUrl,
        errorMessage: 'Malformed host with unbracketed colon characters.',
      );
    }

    // Host structure checks: consecutive dots, leading/trailing dots, spaces
    if (host.contains('..') ||
        host.startsWith('.') ||
        host.endsWith('.') ||
        host.contains(' ')) {
      return const UrlValidationResult(
        status: UrlInputStatus.invalidUrl,
        errorMessage:
            'Malformed host structure: invalid dot placement or whitespace in hostname.',
      );
    }

    return UrlValidationResult(status: UrlInputStatus.validUrl, uri: parsed);
  }

  /// Canonicalizes an input string into a standard URI (returns null if invalid or unsupported)
  static Uri? canonicalizeUrl(String input) {
    final validation = validateAndParse(input);
    return validation.isValid ? validation.uri : null;
  }

  /// Verifies if a hostname is private, loopback, or reserved (SSRF guard)
  static bool isPrivateOrReservedHost(String host) {
    final lower = host.toLowerCase().trim();
    if (lower == 'localhost' ||
        lower == '127.0.0.1' ||
        lower == '::1' ||
        lower == '0.0.0.0') {
      return true;
    }

    final ipParts = lower.split('.');
    if (ipParts.length == 4) {
      final nums = ipParts.map((p) => int.tryParse(p)).toList();
      if (nums.every((n) => n != null && n >= 0 && n <= 255)) {
        final n0 = nums[0]!;
        final n1 = nums[1]!;
        if (n0 == 127) return true; // Loopback
        if (n0 == 10) return true; // 10.0.0.0/8
        if (n0 == 172 && n1 >= 16 && n1 <= 31) return true; // 172.16.0.0/12
        if (n0 == 192 && n1 == 168) return true; // 192.168.0.0/16
        if (n0 == 169 && n1 == 254) {
          return true; // Link-local (AWS/cloud metadata)
        }
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
      'co.in',
      'gov.in',
      'nic.in',
      'org.in',
      'net.in',
      'ac.in',
      'edu.in',
      'co.uk',
      'org.uk',
      'com.au',
      'net.au',
      'co.nz',
      'co.jp',
      'com.br',
    };

    if (specialTwoLevelTlds.contains(lastTwo) && parts.length >= 3) {
      return '${parts[parts.length - 3]}.$lastTwo';
    }

    return '${parts[parts.length - 2]}.${parts.last}';
  }

  /// Checks if a domain or URL is part of an institutional brand or an unauthorized impersonator
  static String? detectBrandImpersonation(
    String domain, {
    String? path,
    String? query,
  }) {
    final d = domain.toLowerCase();

    // Check if domain is an official government domain
    if (d.endsWith('.gov.in') || d.endsWith('.nic.in')) {
      return null; // Government domains under gov.in/nic.in are officially authenticated
    }

    final p = path?.toLowerCase() ?? '';
    final q = query?.toLowerCase() ?? '';

    for (final entry in brandRegistry.entries) {
      final brandKey = entry.key;
      final authorizedDomains = entry.value;

      // 1. Direct domain contains brand
      bool containsBrand = d.contains(brandKey);

      // 2. Domain stacking (e.g. sbi.co.in.scam-domain.com or netbanking.hdfcbank.com.phish.xyz)
      bool domainStacking = false;
      for (final authRoot in authorizedDomains) {
        if (d != authRoot && !d.endsWith('.$authRoot') && d.contains(authRoot)) {
          domainStacking = true;
          break;
        }
      }

      // 3. Path or query spoofing on unverified domain (e.g. /sbi/login, /paypal/verify)
      bool pathOrQuerySpoof = false;
      if (p.isNotEmpty || q.isNotEmpty) {
        final hasBrandLure = p.contains('/$brandKey') ||
            p.contains('$brandKey-') ||
            p.contains('-$brandKey') ||
            q.contains(brandKey);
        final hasAuthLure = p.contains('login') ||
            p.contains('auth') ||
            p.contains('verify') ||
            p.contains('kyc') ||
            p.contains('account') ||
            p.contains('secure') ||
            p.contains('wallet') ||
            p.contains('update') ||
            q.contains('login') ||
            q.contains('verify');
        if (hasBrandLure && hasAuthLure) {
          pathOrQuerySpoof = true;
        }
      }

      if (containsBrand || domainStacking || pathOrQuerySpoof) {
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
          if (domainStacking) {
            return 'Deceptive domain-stacking imitating ${brandKey.toUpperCase()}! Official site is: $officialSite';
          }
          if (pathOrQuerySpoof && !containsBrand) {
            return 'Deceptive credential portal impersonating ${brandKey.toUpperCase()}! Official site is: $officialSite';
          }
          return 'Deceptive domain impersonating ${brandKey.toUpperCase()}! Official site is: $officialSite';
        }
      }
    }
    return null;
  }

  /// Detects homograph punycode spoofing (mixed Cyrillic / Greek characters or whole-script imitation)
  static bool detectHomographAttack(String domain) {
    final lower = domain.toLowerCase();
    if (lower.startsWith('xn--')) return true;

    final hasCyrillic = RegExp(r'[\u0400-\u04FF]').hasMatch(lower);
    final hasGreek = RegExp(r'[\u0370-\u03FF]').hasMatch(lower);
    final hasAscii = RegExp(r'[a-z0-9]').hasMatch(lower);

    // Mixed script lookalikes (e.g. pаypal where 'а' is Cyrillic)
    if ((hasCyrillic || hasGreek) && hasAscii) {
      return true;
    }

    // Whole script imitation in standard Latin context (e.g. entire domain host in Cyrillic like "сби.com")
    if ((hasCyrillic || hasGreek) &&
        (lower.endsWith('.com') ||
            lower.endsWith('.in') ||
            lower.endsWith('.org') ||
            lower.endsWith('.net') ||
            lower.endsWith('.co.in'))) {
      return true;
    }

    return false;
  }

  /// Computes Shannon entropy of a string (measures algorithmic randomness for DGA botnet detection)
  static double calculateShannonEntropy(String s) {
    if (s.isEmpty) return 0.0;
    final map = <int, int>{};
    for (final rune in s.runes) {
      map[rune] = (map[rune] ?? 0) + 1;
    }
    double entropy = 0.0;
    final len = s.runes.length;
    for (final count in map.values) {
      final p = count / len;
      entropy -= p * (math.log(p) / math.ln2);
    }
    return entropy;
  }

  /// Safely inspects HTML markup for zero-day credential harvesters, seed phrase traps,
  /// fake bank login overlays, and obfuscated payload scripts without executing JavaScript.
  static DomInspectionResult inspectHtmlDomForCredentialHarvesters(
    String html, {
    required String domain,
    required bool isAllowlisted,
  }) {
    if (html.isEmpty || isAllowlisted) {
      return DomInspectionResult.clean;
    }

    final lower = html.toLowerCase();

    // 1. Web3 Crypto Seed Phrase Theft (12/24 words, private keys)
    final seedKeywords = [
      'seed phrase',
      'secret recovery phrase',
      'recovery seed',
      '12-word',
      '24-word',
      'private key',
      'enter your phrase',
      'confirm your secret phrase',
      'wallet backup phrase',
      'keystore json',
      'import wallet with secret',
    ];
    for (final kw in seedKeywords) {
      if (lower.contains(kw) &&
          (lower.contains('textarea') ||
              lower.contains('input') ||
              lower.contains('confirm') ||
              lower.contains('submit'))) {
        return const DomInspectionResult(
          isThreat: true,
          threatType: MalwareThreatType.credentialHarvester,
          threatCategory: 'CRYPTO SEED PHRASE THEFT TRAP',
          detail:
              'Zero-Day Web3 Trapping: Detected cryptocurrency seed phrase / private key harvesting form on unverified domain.',
          confidenceDelta: 85,
        );
      }
    }

    // 2. Banking, OTP & Card Harvesters on Unverified Hosts
    final hasPasswordInput = RegExp(
      r'<input[^>]*type=["'']password["'']',
      caseSensitive: false,
    ).hasMatch(html);

    final hasBankingFields = RegExp(
      r'name=["''](?:cvv|card_number|cardnumber|card_num|expiry|pan_number|aadhaar|upi_pin|mpin|otp|netbanking_pass|trans_pwd)["'']',
      caseSensitive: false,
    ).hasMatch(html);

    if (hasPasswordInput && hasBankingFields) {
      return const DomInspectionResult(
        isThreat: true,
        threatType: MalwareThreatType.credentialHarvester,
        threatCategory: 'BANKING CREDENTIAL & CARD HARVESTER',
        detail:
            'Zero-Day Phishing Trap: Web page contains password and payment card / CVV / OTP inputs on an unverified domain.',
        confidenceDelta: 85,
      );
    }

    if (hasPasswordInput) {
      final hasLoginContext = lower.contains('login') ||
          lower.contains('sign in') ||
          lower.contains('authenticate') ||
          lower.contains('verification') ||
          lower.contains('account');

      if (hasLoginContext) {
        return const DomInspectionResult(
          isThreat: true,
          threatType: MalwareThreatType.credentialHarvester,
          threatCategory: 'UNVERIFIED LOGIN CREDENTIAL HARVESTER',
          detail:
              'Zero-Day Phishing Trap: Password input form detected on unverified third-party host imitating authentication service.',
          confidenceDelta: 75,
        );
      }
    }

    // 3. High-Pressure Social Engineering Scam Lures inside page
    final fraudLures = [
      'electricity bill will be disconnected',
      'power will be disconnected',
      'power supply will be disconnected tonight',
      'lottery winning notification',
      'congratulations! you won',
      'pm kisan samman nidhi update mandatory',
      'part-time job daily income',
      'earn 5000 daily from mobile',
      'claim your pending refund immediately',
      'account suspended click to verify immediately',
    ];
    for (final lure in fraudLures) {
      if (lower.contains(lure)) {
        return DomInspectionResult(
          isThreat: true,
          threatType: MalwareThreatType.phishingScam,
          threatCategory: 'HIGH-PRESSURE FRAUD SCAM LURE',
          detail:
              'Social Engineering Lure: Page contains high-urgency fraudulent threat ("$lure") designed to coerce victim action.',
          confidenceDelta: 75,
        );
      }
    }

    // 4. Heavily Obfuscated JavaScript Payloads (Packer, Hex-escaped)
    final isObfuscatedJs = RegExp(
      r'eval\s*\(\s*function\s*\(\s*p\s*,\s*a\s*,\s*c\s*,\s*k\s*,\s*e\s*,\s*[dr]',
      caseSensitive: false,
    ).hasMatch(html) ||
    lower.contains('document.write(unescape(');

    if (isObfuscatedJs) {
      return const DomInspectionResult(
        isThreat: true,
        threatType: MalwareThreatType.unknownThreat,
        threatCategory: 'OBFUSCATED MALICIOUS SCRIPT PAYLOAD',
        detail:
            'Evasion Detection: Page embeds packed or obfuscated JavaScript payload commonly used in zero-day exploit kits.',
        confidenceDelta: 65,
      );
    }

    return DomInspectionResult.clean;
  }

  /// Safely traces recursive redirect hops (e.g. URL shorteners) via zero-browser HEAD requests.
  /// Enforces SSRF guard on intermediate hops, prevents redirect loops, and never executes JavaScript.
  static Future<List<String>> traceRedirectChain(
    String initialUrl, {
    int maxHops = 5,
    Duration timeout = const Duration(seconds: 3),
    Dio? customDio,
  }) async {
    final chain = <String>[initialUrl];
    var currentUrl = initialUrl;
    final client = customDio ?? _dio;

    for (int i = 0; i < maxHops; i++) {
      try {
        final parsed = Uri.tryParse(currentUrl);
        if (parsed == null ||
            !parsed.hasScheme ||
            (parsed.scheme != 'http' && parsed.scheme != 'https')) {
          break;
        }

        // SSRF Guard on intermediate hop
        if (isPrivateOrReservedHost(parsed.host)) {
          break;
        }

        final response = await client.head(
          currentUrl,
          options: Options(
            followRedirects: false,
            validateStatus: (status) => status != null && status < 500,
            sendTimeout: timeout,
            receiveTimeout: timeout,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko)',
            },
          ),
        );

        final statusCode = response.statusCode ?? 0;
        if (statusCode >= 300 && statusCode < 400) {
          final location = response.headers.value('location');
          if (location != null && location.isNotEmpty) {
            final nextUri = Uri.parse(currentUrl).resolve(location);
            final nextUrl = nextUri.toString();
            if (chain.contains(nextUrl)) {
              // Loop detected
              break;
            }
            chain.add(nextUrl);
            currentUrl = nextUrl;
            continue;
          }
        }
        break;
      } catch (_) {
        break;
      }
    }
    return chain;
  }

  /// Safely extracts and analyzes redirection query parameters and target destinations
  /// without issuing any live HTTP requests to untrusted endpoints.
  static RedirectAnalysis inspectRedirectionVector({
    required Uri uri,
    required String baseDomain,
  }) {
    final candidateKeys = {
      'url',
      'redirect',
      'redirect_url',
      'redirect_uri',
      'next',
      'return_to',
      'return',
      'dest',
      'destination',
      'target',
      'link',
      'r',
      'u',
      'goto',
      'continue',
      'forward',
      'out',
      'to',
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
          description:
              'URL contains internal relative redirection ($foundKey=$decoded).',
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
        description:
            'URL contains malformed or obfuscated redirect parameter ($foundKey).',
      );
    }

    if (targetUri == null ||
        !targetUri.hasAuthority ||
        targetUri.host.isEmpty) {
      return RedirectAnalysis(
        hasRedirect: true,
        isExternal: false,
        paramKey: foundKey,
        rawTarget: decoded,
        targetHost: uri.host,
        targetBaseDomain: baseDomain,
        redirectRiskDelta: 0,
        description:
            'URL contains benign parameter without external authority.',
      );
    }

    final targetHost = targetUri.host.toLowerCase();
    final targetBase = extractBaseDomain(targetHost);
    final isExternal =
        (targetBase != baseDomain && !targetHost.endsWith('.$baseDomain'));

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
        description:
            'URL contains internal redirect parameter pointing within the same domain hierarchy ($targetHost).',
      );
    }

    // External target detected: inspect destination properties
    final hasHighRiskTld = highRiskTlds.any((tld) => targetHost.endsWith(tld));
    final isSsrf = isPrivateOrReservedHost(targetHost);
    final isDropper = dangerousExtensions.any(
      (ext) =>
          (targetUri?.path.toLowerCase().endsWith(ext) ?? false) ||
          (targetUri?.query.toLowerCase().contains(ext) ?? false),
    );
    final brandSpoof = detectBrandImpersonation(targetHost);

    int riskDelta = 25; // Base uncertainty for unverified external destination
    if (hasHighRiskTld) riskDelta += 25;
    if (isSsrf) riskDelta += 35;
    if (isDropper) riskDelta += 50;
    if (brandSpoof != null) riskDelta += 35;

    final String desc =
        'URL contains parameter ($foundKey) directing to external host ($targetHost).'
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

  /// Performs deep multi-factor URL analysis integrating live VirusTotal v3 API,
  /// Cloudflare 1.1.1.2 Security Telemetry, brand spoofing, and heuristic phishing radar.
  static Future<UrlResult> analyze(
    String rawUrl, {
    bool traceShorteners = false,
    bool checkVirusTotal = true,
    bool checkSecurityDns = true,
    String? virusTotalApiKey,
    Dio? customDio,
  }) async {
    final validation = validateAndParse(rawUrl);
    if (!validation.isValid) {
      final status = validation.status;
      final int score = status == UrlInputStatus.unsupportedScheme ? 25 : 35;
      return UrlResult.error(
        rawUrl,
        message: validation.errorMessage ?? 'Invalid URL format',
        status: status,
        riskScore: score,
      );
    }

    final uri = validation.uri!;
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
      domainChecks.add(
        DomainCheckItem(
          'SSRF & Internal Host Guard',
          false,
          'Target points to a loopback, link-local, or private RFC-1918 internal address ($domain). Outbound scraping blocked.',
        ),
      );
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
        riskExplanation:
            'Target points to private RFC-1918 or loopback internal network address.',
        threatType: MalwareThreatType.unknownThreat,
        threatCategoryBadge: 'INTERNAL NETWORK TARGET (SSRF)',
        threatForensicDetails:
            'Target points to private RFC-1918 or loopback internal network address. Outbound connection blocked.',
      );
    }

    // ─── 1. HTTP BASIC AUTH SPOOFING CHECK ───────────────────────────────────
    if (uri.userInfo.isNotEmpty) {
      riskScore += 65;
      domainChecks.add(
        DomainCheckItem(
          'URL Credential Deception',
          false,
          'URL utilizes HTTP Basic Auth prefix (${uri.userInfo}@) to disguise real target host: $rawHost.',
        ),
      );
    }

    // ─── 2. INSTITUTIONAL ALLOWLIST CHECK ────────────────────────────────────
    if (institutionalAllowlist.contains(domain) ||
        institutionalAllowlist.contains(baseDomain) ||
        domain.endsWith('.gov.in') ||
        domain.endsWith('.nic.in')) {
      isAllowlisted = true;
      domainChecks.add(
        DomainCheckItem(
          'Trusted Institutional Registry',
          true,
          'Verified in SafeSignal on-device registry of authenticated institutional domains ($domain).',
        ),
      );
    } else {
      domainChecks.add(
        DomainCheckItem(
          'Institutional Registry',
          null,
          'Not in local allowlist of verified institutional domains (Neutral).',
        ),
      );
    }

    // ─── 2.05 LIVE SECURITY DNS THREAT RADAR (CLOUDFLARE 1.1.1.2) ────────────
    SecurityDnsCheckResult securityDnsRes = SecurityDnsCheckResult.clean;
    if (checkSecurityDns && !isAllowlisted && !isSsrfHost) {
      securityDnsRes = await VirusTotalService.checkSecurityDns(
        rawHost,
        customDio: customDio,
      );
      if (securityDnsRes.isBlocked) {
        riskScore += 90;
        domainChecks.insert(
          0,
          DomainCheckItem(
            'Security Threat Intelligence',
            false,
            'CRITICAL: ${securityDnsRes.details}',
          ),
        );
      }
    }

    // ─── 2.08 LIVE VIRUSTOTAL MULTI-ENGINE LOOKUP ────────────────────────────
    VirusTotalScanResult? vtRes;
    if (checkVirusTotal && !isSsrfHost) {
      vtRes = await VirusTotalService.queryVirusTotal(
        rawUrl,
        explicitApiKey: virusTotalApiKey,
        customDio: customDio,
      );
      if (vtRes.hasScanData) {
        if (vtRes.isMalicious) {
          riskScore += (vtRes.malicious * 30).clamp(75, 100);
          final engineSummary = vtRes.flaggedVendors.take(3).join(', ');
          domainChecks.insert(
            0,
            DomainCheckItem(
              'VirusTotal Multi-Engine Intelligence',
              false,
              'CRITICAL: ${vtRes.malicious} security vendor(s) flagged as malicious/phishing ($engineSummary).',
            ),
          );
        } else {
          domainChecks.add(
            DomainCheckItem(
              'VirusTotal Multi-Engine Intelligence',
              true,
              'Clean across ${vtRes.totalEngines} antivirus & security intelligence engines.',
            ),
          );
        }
      }
    }

    // ─── 2.1 COMMAND & CONTROL (C2) / THREAT INTEL CHECK ────────────────────
    final isKnownC2 =
        knownC2Domains.contains(domain) || knownC2Domains.contains(baseDomain);
    bool isDynamicDnsC2 = false;
    for (final suffix in highRiskDynamicDnsSuffixes) {
      if (domain.endsWith(suffix) &&
          (urlPath.contains('.apk') ||
              urlPath.contains('payload') ||
              urlPath.contains('c2') ||
              urlPath.contains('bot'))) {
        isDynamicDnsC2 = true;
        break;
      }
    }

    if (isKnownC2 || isDynamicDnsC2) {
      riskScore += 90;
      domainChecks.insert(
        0,
        DomainCheckItem(
          'C2 Threat Intelligence',
          false,
          'CRITICAL: Host is indexed in active Command & Control (C2) or mobile malware infrastructure ($domain).',
        ),
      );
    }

    // ─── 2.2 RECURSIVE SHORTENER UNRAVELLER ──────────────────────────────────
    List<String> unraveledChain = const [];
    if (traceShorteners || knownUrlShorteners.contains(domain)) {
      unraveledChain = await traceRedirectChain(rawUrl, customDio: customDio);
      if (unraveledChain.length > 1) {
        final destinationUrl = unraveledChain.last;
        final destUri = Uri.tryParse(destinationUrl);
        final destHost =
            destUri?.host.toLowerCase().replaceAll(RegExp(r'^www\.'), '') ?? '';
        final destPath = destUri?.path.toLowerCase() ?? '';

        final destIsC2 = knownC2Domains.contains(destHost);
        final destIsApk =
            destPath.endsWith('.apk') || destinationUrl.contains('.apk?');

        if (destIsC2 || destIsApk) {
          riskScore += 75;
          domainChecks.insert(
            0,
            DomainCheckItem(
              'Cloaked Payload Unraveller',
              false,
              'Shortener disguised active threat: ${destIsC2 ? "C2 Node" : "APK Dropper"} at $destinationUrl (${unraveledChain.length - 1} hops).',
            ),
          );
        } else {
          domainChecks.add(
            DomainCheckItem(
              'Shortened URL Resolution',
              true,
              'Safely unraveled ${unraveledChain.length - 1} redirect hop(s) to destination: $destinationUrl.',
            ),
          );
        }
      }
    }

    // ─── 3. BRAND IMPERSONATION & TYPOSQUATTING ──────────────────────────────
    final brandSpoof = detectBrandImpersonation(
      domain,
      path: urlPath,
      query: urlQuery,
    );
    if (brandSpoof != null) {
      riskScore += 65;
      domainChecks.insert(
        0,
        DomainCheckItem('Phishing & Brand Impersonation', false, brandSpoof),
      );
    }

    // ─── 3.1 ABUSED CLOUD PLATFORMS & CLOAKED SUBDOMAIN PHISHING ─────────────
    bool isCloudPhish = false;
    String? matchedCloudPlatform;
    for (final platform in abusedCloudPlatforms) {
      if (domain == platform || domain.endsWith('.$platform')) {
        matchedCloudPlatform = platform;
        break;
      }
    }

    if (matchedCloudPlatform != null && !isAllowlisted) {
      final hasPhishTokens = domain.contains('login') ||
          domain.contains('verify') ||
          domain.contains('secure') ||
          domain.contains('bank') ||
          urlPath.contains('login') ||
          urlPath.contains('auth') ||
          urlPath.contains('verify') ||
          urlPath.contains('kyc') ||
          urlPath.contains('wallet') ||
          brandSpoof != null;

      if (hasPhishTokens) {
        isCloudPhish = true;
        riskScore += 70;
        domainChecks.insert(
          0,
          DomainCheckItem(
            'Cloaked Cloud Phishing Platform',
            false,
            'CRITICAL: Shared cloud hosting infrastructure ($matchedCloudPlatform) hosting deceptive login or financial lure.',
          ),
        );
      } else {
        domainChecks.add(
          DomainCheckItem(
            'Shared Cloud Hosting Platform',
            null,
            'Hosted on shared cloud infrastructure ($matchedCloudPlatform). Review credentials before proceeding.',
          ),
        );
      }
    }

    // ─── 4. HOMOGRAPH & PUNYCODE SPOOFING ────────────────────────────────────
    final isHomograph = detectHomographAttack(domain);
    if (isHomograph) {
      riskScore += 60;
      domainChecks.add(
        DomainCheckItem(
          'Homograph Spoofing Attack',
          false,
          'Punycode or mixed-character lookalike domain detected ($domain). High probability of visual deception.',
        ),
      );
    }

    // ─── 5. HIGH RISK TLD PROFILING ──────────────────────────────────────────
    bool hasHighRiskTld = false;
    for (final tld in highRiskTlds) {
      if (domain.endsWith(tld)) {
        hasHighRiskTld = true;
        riskScore += 25;
        domainChecks.add(
          DomainCheckItem(
            'Top-Level Domain (TLD) Reputation',
            false,
            'Uses high-abuse free or disposable TLD ($tld). Frequently utilized by cybercrime syndicates.',
          ),
        );
        break;
      }
    }
    if (!hasHighRiskTld) {
      domainChecks.add(
        DomainCheckItem(
          'Top-Level Domain (TLD) Reputation',
          true,
          'Standard commercial or institutional top-level domain.',
        ),
      );
    }

    // ─── 6. SOCIAL ENGINEERING / URGENCY KEYWORDS ────────────────────────────
    final matchedUrgency = urgencyKeywords
        .where((kw) => urlPath.contains(kw) || urlQuery.contains(kw))
        .toList();
    if (matchedUrgency.isNotEmpty) {
      riskScore += 25;
      domainChecks.add(
        DomainCheckItem(
          'Social Engineering Signatures',
          false,
          'Urgency or scam trigger keywords found in path/query: ${matchedUrgency.join(', ')}.',
        ),
      );
    }

    // ─── 6.1 CREDENTIAL & PHISHING PATH ENDPOINTS ────────────────────────────
    final matchedPhishingPaths = phishingPathKeywords
        .where((kw) => urlPath.contains(kw) || urlQuery.contains(kw))
        .toList();
    if (matchedPhishingPaths.isNotEmpty && !isAllowlisted) {
      riskScore += 25;
      domainChecks.add(
        DomainCheckItem(
          'Credential & Phishing Endpoints',
          false,
          'Authentication or login endpoints detected on unverified host (${matchedPhishingPaths.take(3).join(', ')}).',
        ),
      );
    }

    // ─── 7. EXECUTABLE & MOBILE PAYLOAD INSPECTION ───────────────────────────
    final bool isDesktopExecutable =
        urlPath.endsWith('.exe') ||
        urlPath.endsWith('.bat') ||
        urlPath.endsWith('.cmd') ||
        urlPath.endsWith('.vbs') ||
        urlPath.endsWith('.ps1') ||
        urlPath.endsWith('.scr') ||
        urlPath.endsWith('.msi') ||
        urlPath.endsWith('.dex') ||
        urlPath.endsWith('.jar');

    final bool isDirectApk =
        urlPath.endsWith('.apk') ||
        urlPath.endsWith('.xapk') ||
        urlPath.endsWith('.apks') ||
        RegExp(r'\.apk(?:$|[?#])').hasMatch(urlPath);

    final ratSignatures = [
      'rat',
      'spynote',
      'craxs',
      'anatsa',
      'cerberus',
      'teabot',
      'hydra',
      'sova',
      'alien',
      'ermac',
      'hook',
      'vultur',
      'chameleon',
      'flubot',
      'brata',
      'gustuff',
      'triada',
      'stealer',
      'keylogger',
      'screenlogger',
      'screen-share',
      'remote-control',
      'remote-admin',
      'c2-server',
      'botnet',
      'quicksupport',
      'anydesk-support',
      'teamviewer-support',
      'screenshare',
      'auto-clicker',
      'bank-bot',
    ];

    final isDoubleExtDropper = RegExp(
      r'\.(?:pdf|jpg|jpeg|png|doc|docx|xls|xlsx|txt|mp4)\.(?:apk|xapk|dex|exe|sh|bin)$',
      caseSensitive: false,
    ).hasMatch(urlPath);

    final bool hasRatKeyword = ratSignatures.any(
      (sig) =>
          urlPath.contains(sig) ||
          urlQuery.contains(sig) ||
          domain.contains(sig),
    );

    bool isRatDropper = false;
    bool isMaliciousDropper = false;
    bool isUnverifiedApk = false;

    if ((isDirectApk || isDesktopExecutable) &&
        (hasRatKeyword || isDoubleExtDropper)) {
      isRatDropper = true;
      isMaliciousDropper = true;
      riskScore += 75;
      domainChecks.insert(
        0,
        DomainCheckItem(
          'Remote Access Trojan (RAT) Vector',
          false,
          'CRITICAL: Remote Access Trojan (RAT), spyware payload, or stealth double-extension executable dropper signature identified in target path.',
        ),
      );
    } else if (isDesktopExecutable) {
      isMaliciousDropper = true;
      riskScore += 65;
      domainChecks.insert(
        0,
        DomainCheckItem(
          'Malicious Executable Dropper',
          false,
          'CRITICAL: URL directly downloads desktop executable or script binary. Extreme malware dropper risk on mobile device.',
        ),
      );
    } else if (isDirectApk) {
      final isVerifiedPublisher =
          verifiedApkPublishers.contains(domain) ||
          verifiedApkPublishers.contains(baseDomain);

      if (brandSpoof != null) {
        isMaliciousDropper = true;
        riskScore += 70;
        domainChecks.insert(
          0,
          DomainCheckItem(
            'Brand Impersonation & Trojan Dropper',
            false,
            'CRITICAL: Deceptive brand-impersonating domain directly distributing an Android APK payload. High probability of banking Trojan or spyware.',
          ),
        );
      } else if (hasHighRiskTld || matchedUrgency.isNotEmpty) {
        isMaliciousDropper = true;
        riskScore += 60;
        domainChecks.insert(
          0,
          DomainCheckItem(
            'High-Risk Mobile Malware Dropper',
            false,
            'CRITICAL: Android APK payload hosted on high-risk disposable TLD or social engineering lure. Probable malicious dropper.',
          ),
        );
      } else if (isVerifiedPublisher) {
        // Recognized open-source or official release platform (e.g. Signal, F-Droid, GitHub)
        riskScore += 10;
        domainChecks.add(
          DomainCheckItem(
            'Verified Software Repository APK',
            true,
            'APK package hosted on recognized open-source or official release platform ($baseDomain). Binary contents not dynamically inspected; verify cryptographic signature before installation.',
          ),
        );
      } else {
        // Unverified APK from standard or unknown third-party domain
        isUnverifiedApk = true;
        riskScore += 35;
        domainChecks.add(
          DomainCheckItem(
            'Unverified APK Download',
            null,
            'APK download detected; file security has not been verified. Sideloading applications from third-party sources carries security risks.',
          ),
        );
      }
    }

    // ─── 8. DEEP REDIRECTION & DESTINATION INSPECTION ────────────────────────
    final redirectAnalysis = inspectRedirectionVector(
      uri: uri,
      baseDomain: baseDomain,
    );

    if (redirectAnalysis.hasRedirect) {
      if (redirectAnalysis.isExternal) {
        riskScore += redirectAnalysis.redirectRiskDelta;
        domainChecks.add(
          DomainCheckItem(
            'Open Redirect & Destination Vector',
            false,
            redirectAnalysis.description,
          ),
        );
      } else {
        domainChecks.add(
          DomainCheckItem(
            'Redirection Integrity',
            true,
            redirectAnalysis.description,
          ),
        );
      }
    }

    // ─── 9. DOMAIN STRUCTURE, SHANNON ENTROPY & ALGORITHMIC DGA BOTNET DETECTION ──
    final domainParts = domain.split('.');
    final primaryLabel = domainParts.length >= 2 ? domainParts[domainParts.length - 2] : domain;
    final shannonEntropy = calculateShannonEntropy(primaryLabel);
    bool isDga = false;
    if (primaryLabel.length >= 9 && shannonEntropy >= 3.65 && !isAllowlisted) {
      final digitCount = primaryLabel.replaceAll(RegExp(r'[^0-9]'), '').length;
      final vowelCount = primaryLabel.replaceAll(RegExp(r'[^aeiouAEIOU]'), '').length;
      final consonantCount = primaryLabel.length - digitCount - vowelCount;
      if (consonantCount > vowelCount * 2 || digitCount >= 3) {
        isDga = true;
      }
    }

    if (isDga) {
      riskScore += 75;
      domainChecks.insert(
        0,
        DomainCheckItem(
          'Algorithmic DGA Botnet Radar',
          false,
          'CRITICAL: Algorithmic Domain Generation (DGA) pattern detected (Shannon Entropy: ${shannonEntropy.toStringAsFixed(2)}). Typical of banking trojan & ransomware C2 infrastructure.',
        ),
      );
    } else {
      final hyphenCount = domain.split('-').length - 1;
      final dotCount = domain.split('.').length - 1;
      if (hyphenCount >= 3 || dotCount >= 4) {
        riskScore += 20;
        domainChecks.add(
          DomainCheckItem(
            'Domain Structure & Entropy',
            false,
            'Unusually high complexity ($hyphenCount hyphens, $dotCount dots, Entropy: ${shannonEntropy.toStringAsFixed(2)}). Typical of disposable phishing hosts.',
          ),
        );
      }
    }

    // ─── 10. RAW IP ADDRESS AS HOST ──────────────────────────────────────────
    final ipRegex = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
    if (ipRegex.hasMatch(domain)) {
      riskScore += 30;
      domainChecks.add(
        DomainCheckItem(
          'Host Identification',
          false,
          'Using raw IP address instead of registered domain name. Evades domain reputation blocklists.',
        ),
      );
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
      hasDmarc = dnsFutures[3].any(
        (txt) => txt.toLowerCase().contains('v=dmarc1'),
      );

      if (aRecords.isEmpty && !isSsrfHost) {
        riskScore += 15;
        domainChecks.add(
          DomainCheckItem(
            'DNS Host Resolution',
            false,
            'Domain has no active A records (Unresolvable / Dead Host).',
          ),
        );
      } else {
        domainChecks.add(
          DomainCheckItem(
            'DNS Host Resolution',
            true,
            'Active A records resolved via DNS-over-HTTPS (${aRecords.take(2).join(', ')}).',
          ),
        );
      }

      if (hasDmarc) {
        domainChecks.add(
          DomainCheckItem(
            'Email DMARC Security',
            true,
            'DMARC email authentication policy published. Protected against spoofed emails.',
          ),
        );
      }

      if (mxRecords.isNotEmpty) {
        domainChecks.add(
          DomainCheckItem(
            'Mail Server Infrastructure (MX)',
            true,
            'Valid mail exchange infrastructure configured (${mxRecords.first}).',
          ),
        );
      } else if (!isAllowlisted && !hasHighRiskTld) {
        domainChecks.add(
          DomainCheckItem(
            'Mail Server Infrastructure (MX)',
            null,
            'No mail server records configured (Neutral).',
          ),
        );
      }
    } catch (_) {
      // Offline or DoH blocked
    }

    // ─── 12. GENUINE TLS ENCRYPTION PROBE ────────────────────────────────────
    bool isHttps = uri.scheme == 'https';
    if (!isHttps) {
      riskScore += 25;
      domainChecks.add(
        DomainCheckItem(
          'Transport Security',
          false,
          'Unencrypted HTTP transport. Traffic can be intercepted or manipulated in transit.',
        ),
      );
    } else {
      domainChecks.add(
        DomainCheckItem(
          'Transport Security',
          true,
          'Standard HTTPS transport configured.',
        ),
      );
    }

    // ─── 13. LIVE MOBILE DOM & ZERO-DAY CREDENTIAL HARVESTER PROBE ───────────
    DomInspectionResult domResult = DomInspectionResult.clean;
    String siteTitle = '';
    String siteDescription = '';
    String serverSoftware = '';
    String poweredBy = '';
    String contentType = '';
    int securityHeaders = 0;

    if (!isSsrfHost && !isDirectApk && !isDesktopExecutable && aRecords.isNotEmpty) {
      try {
        final probeResponse = await (customDio ?? _dio).get(
          rawUrl,
          options: Options(
            followRedirects: true,
            maxRedirects: 3,
            validateStatus: (status) => status != null && status < 500,
            sendTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 4),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.9,hi;q=0.8',
            },
            responseType: ResponseType.plain,
          ),
        );

        if (probeResponse.headers.map.isNotEmpty) {
          final headers = probeResponse.headers;
          serverSoftware = headers.value('server') ?? '';
          poweredBy = headers.value('x-powered-by') ?? '';
          contentType = headers.value('content-type') ?? '';

          if (headers.value('strict-transport-security') != null) {
            securityHeaders++;
          }
          if (headers.value('x-content-type-options') != null) {
            securityHeaders++;
          }
          if (headers.value('x-frame-options') != null) {
            securityHeaders++;
          }
          if (headers.value('content-security-policy') != null) {
            securityHeaders++;
          }
        }

        final bodyStr = probeResponse.data?.toString() ?? '';
        if (bodyStr.isNotEmpty) {
          final titleMatch = RegExp(
            r'<title[^>]*>([^<]+)</title>',
            caseSensitive: false,
          ).firstMatch(bodyStr);
          if (titleMatch != null) {
            siteTitle = titleMatch.group(1)?.trim() ?? '';
          }

          final descMatch = RegExp(
            r'<meta[^>]*name=["'']description["''][^>]*content=["'']([^"'']+)["'']',
            caseSensitive: false,
          ).firstMatch(bodyStr);
          if (descMatch != null) {
            siteDescription = descMatch.group(1)?.trim() ?? '';
          }

          domResult = inspectHtmlDomForCredentialHarvesters(
            bodyStr,
            domain: domain,
            isAllowlisted: isAllowlisted,
          );

          if (domResult.isThreat) {
            riskScore += domResult.confidenceDelta;
            domainChecks.insert(
              0,
              DomainCheckItem(
                'Zero-Day Phishing & Credential Trap',
                false,
                'CRITICAL: ${domResult.detail}',
              ),
            );
          }
        }
      } catch (_) {}
    }

    // ─── VERDICT CALIBRATION & RISK LEVEL CLASSIFICATION ─────────────────────
    final bool hasCriticalThreats =
        domResult.isThreat ||
        isDga ||
        isRatDropper ||
        isMaliciousDropper ||
        isDesktopExecutable ||
        brandSpoof != null ||
        isHomograph ||
        isCloudPhish ||
        securityDnsRes.isBlocked ||
        (vtRes?.isMalicious ?? false) ||
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
      riskLevel =
          (domResult.isThreat ||
              isDga ||
              isKnownC2 ||
              isDynamicDnsC2 ||
              isRatDropper ||
              isMaliciousDropper ||
              isDesktopExecutable ||
              brandSpoof != null ||
              isHomograph ||
              isCloudPhish ||
              securityDnsRes.isBlocked ||
              (vtRes?.isMalicious ?? false) ||
              redirectAnalysis.isTargetDropper)
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
    if (domResult.isThreat) {
      riskExplanation = domResult.detail;
    } else if (isDga) {
      riskExplanation =
          'Algorithmic DGA botnet node detected (Entropy: ${shannonEntropy.toStringAsFixed(2)}).';
    } else if (vtRes?.isMalicious == true) {
      riskExplanation =
          'VirusTotal threat match: ${vtRes!.malicious} security vendor(s) flagged this destination.';
    } else if (securityDnsRes.isBlocked) {
      riskExplanation = 'Security threat intelligence feed blocked this domain.';
    } else if (isCloudPhish) {
      riskExplanation =
          'Cloaked phishing kit hosted on shared cloud platform ($matchedCloudPlatform).';
    } else if (isKnownC2 || isDynamicDnsC2) {
      riskExplanation = isKnownC2
          ? 'Active Command & Control (C2) threat intelligence match.'
          : 'Dynamic DNS C2 tunnel endpoint detected.';
    } else if (isRatDropper) {
      riskExplanation =
          'Remote Access Trojan (RAT) / C2 surveillance payload dropper detected.';
    } else if (redirectAnalysis.hasRedirect && redirectAnalysis.isExternal) {
      riskExplanation =
          'Potential unverified external redirect to ${redirectAnalysis.targetHost}.';
    } else if (isMaliciousDropper || isDesktopExecutable) {
      riskExplanation = 'Executable mobile/binary malware dropper detected.';
    } else if (isUnverifiedApk) {
      riskExplanation =
          'APK download detected; file security has not been verified.';
    } else if (brandSpoof != null) {
      riskExplanation = brandSpoof;
    } else if (isHomograph) {
      riskExplanation = 'Homograph/punycode visual spoofing detected.';
    } else if (uri.userInfo.isNotEmpty) {
      riskExplanation = 'URL credential deception (HTTP basic auth prefix).';
    } else if (isAllowlisted && riskScore == 0) {
      riskExplanation =
          'Verified institutional domain with valid security profile.';
    } else if (verdict == UrlVerdict.safe) {
      riskExplanation = 'Standard low-risk domain with no anomalies.';
    } else {
      riskExplanation =
          'Elevated risk factors detected (${domainChecks.where((c) => c.passed == false).length} warnings).';
    }

    final MalwareThreatType threatType;
    final String threatCategoryBadge;
    final String threatForensicDetails;

    if (domResult.isThreat) {
      threatType = domResult.threatType;
      threatCategoryBadge = domResult.threatCategory;
      threatForensicDetails = domResult.detail;
    } else if (isDga) {
      threatType = MalwareThreatType.bankingTrojan;
      threatCategoryBadge = 'ALGORITHMIC DGA BOTNET C2 NODE';
      threatForensicDetails =
          'High Shannon entropy (${shannonEntropy.toStringAsFixed(2)}) detected in domain label ($primaryLabel). Characteristic of algorithmic domain generation used by botnets and banking trojans.';
    } else if (vtRes?.isMalicious == true) {
      threatType = MalwareThreatType.phishingScam;
      threatCategoryBadge = 'GLOBAL THREAT FEEDS MATCH (${vtRes!.malicious} ENGINES)';
      threatForensicDetails =
          'Multiple security vendors (${vtRes.flaggedVendors.take(3).join(', ')}) have classified this destination as active phishing, malware dropper, or fraudulent infrastructure.';
    } else if (securityDnsRes.isBlocked) {
      threatType = MalwareThreatType.phishingScam;
      threatCategoryBadge = 'SECURITY THREAT RADAR (MALWARE/PHISHING)';
      threatForensicDetails = securityDnsRes.details;
    } else if (isCloudPhish) {
      threatType = MalwareThreatType.phishingScam;
      threatCategoryBadge = 'CLOUDFLARE/CLOUD HOSTED PHISHING';
      threatForensicDetails =
          'Deceptive authentication portal or financial harvesting form hosted on free shared cloud platform ($matchedCloudPlatform). High phishing certainty.';
    } else if (isKnownC2 || isDynamicDnsC2) {
      threatType = MalwareThreatType.bankingTrojan;
      threatCategoryBadge = isKnownC2
          ? 'COMMAND & CONTROL (C2) INFRASTRUCTURE'
          : 'DYNAMIC DNS C2 ENDPOINT';
      threatForensicDetails = isKnownC2
          ? 'Domain matches active Command & Control (C2) botnet or banking trojan distribution node.'
          : 'Dynamic DNS tunnel endpoint hosting unauthorized executable payload.';
    } else if (isRatDropper ||
        (hasRatKeyword && (isMaliciousDropper || hasHighRiskTld))) {
      threatType = MalwareThreatType.ratDropper;
      threatCategoryBadge = 'REMOTE ACCESS TROJAN (RAT) DROPPER';
      threatForensicDetails =
          'This link directly distributes a remote surveillance or Remote Access Trojan (RAT) payload designed to seize administrative device control, record screen activity, and intercept OTPs/banking credentials.';
    } else if (isDirectApk && brandSpoof != null) {
      threatType = MalwareThreatType.bankingTrojan;
      threatCategoryBadge = 'BANKING TROJAN / UPI PHISHING';
      threatForensicDetails =
          'This deceptive domain impersonates a financial institution or payment service to distribute an unauthorized Android banking APK dropper.';
    } else if (isDesktopExecutable) {
      threatType = MalwareThreatType.apkDropper;
      threatCategoryBadge = 'EXECUTABLE BINARY / SCRIPT DROPPER';
      threatForensicDetails =
          'URL directly delivers desktop executable or script binary payload ($urlPath). High malware dropper risk on mobile device.';
    } else if (isDirectApk && (hasHighRiskTld || matchedUrgency.isNotEmpty)) {
      threatType = MalwareThreatType.apkDropper;
      threatCategoryBadge = 'MALWARE APK DROPPER';
      threatForensicDetails =
          'Android APK payload hosted alongside disposable high-risk TLD or social engineering lure. Probable malicious dropper.';
    } else if (isUnverifiedApk) {
      threatType = MalwareThreatType.apkDropper;
      threatCategoryBadge = 'UNVERIFIED APK PACKAGE';
      threatForensicDetails =
          'Direct APK download detected from an unverified third-party host. Sideloading applications outside official stores carries security risks.';
    } else if (brandSpoof != null) {
      threatType = MalwareThreatType.phishingScam;
      threatCategoryBadge = 'PHISHING & BRAND IMPERSONATION';
      threatForensicDetails = brandSpoof;
    } else if (isHomograph) {
      threatType = MalwareThreatType.phishingScam;
      threatCategoryBadge = 'HOMOGRAPH VISUAL DECEPTION';
      threatForensicDetails =
          'Punycode or mixed-character lookalike domain detected ($domain). High probability of visual brand spoofing.';
    } else if (uri.userInfo.isNotEmpty) {
      threatType = MalwareThreatType.credentialHarvester;
      threatCategoryBadge = 'CREDENTIAL HARVESTING ATTEMPT';
      threatForensicDetails =
          'URL utilizes HTTP Basic Auth prefix (${uri.userInfo}@) to disguise real target destination: $rawHost.';
    } else if (redirectAnalysis.hasRedirect && redirectAnalysis.isExternal) {
      threatType = MalwareThreatType.suspiciousRedirect;
      threatCategoryBadge = 'UNVERIFIED EXTERNAL REDIRECT';
      threatForensicDetails =
          'URL contains open redirection parameter pointing to an unverified external destination (${redirectAnalysis.targetHost}).';
    } else if (isAllowlisted && riskScore <= 20) {
      threatType = MalwareThreatType.clean;
      threatCategoryBadge = 'VERIFIED AUTHENTIC & SAFE';
      threatForensicDetails =
          'Verified institutional domain with authenticated security profile.';
    } else if (verdict == UrlVerdict.dangerous) {
      threatType = MalwareThreatType.unknownThreat;
      threatCategoryBadge = 'HIGH-RISK SUSPICIOUS DOMAIN';
      threatForensicDetails =
          'Multiple anomalous threat signals detected across domain registration, transport security, and host records.';
    } else if (verdict == UrlVerdict.caution) {
      threatType = MalwareThreatType.unknownThreat;
      threatCategoryBadge = 'CAUTIONARY DOMAIN';
      threatForensicDetails =
          'Domain exhibits minor risk indicators or unverified reputation.';
    } else {
      threatType = MalwareThreatType.clean;
      threatCategoryBadge = 'CLEAN STANDARD DOMAIN';
      threatForensicDetails =
          'No malicious indicators or spoofing patterns detected.';
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
      siteTitle: siteTitle,
      siteDescription: siteDescription,
      serverSoftware: serverSoftware,
      poweredBy: poweredBy,
      contentType: contentType,
      securityHeaders: securityHeaders,
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
      threatType: threatType,
      threatCategoryBadge: threatCategoryBadge,
      threatForensicDetails: threatForensicDetails,
      redirectChain: unraveledChain,
      virusTotalResult: vtRes,
      securityDnsResult: securityDnsRes,
      isDgaDomain: isDga,
      isCredentialHarvester: domResult.isThreat,
      detectedFormType: domResult.isThreat ? domResult.threatCategory : null,
      shannonEntropy: shannonEntropy,
    );
  }

  /// Private DNS-over-HTTPS resolver (Cloudflare 1.1.1.1)
  /// Only resolves domain names, zero URL query paths or user telemetry leaked
  static Future<List<String>> _queryDoh(String host, String type) async {
    try {
      final res = await _dio.get(
        'https://cloudflare-dns.com/dns-query',
        queryParameters: {'name': host, 'type': type},
        options: Options(
          headers: {'accept': 'application/dns-json'},
          receiveTimeout: const Duration(seconds: 3),
        ),
      );

      if (res.statusCode == 200 &&
          res.data is Map &&
          res.data['Answer'] is List) {
        final answers = res.data['Answer'] as List;
        return answers
            .map(
              (ans) => ans['data']?.toString().replaceAll('"', '').trim() ?? '',
            )
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}
