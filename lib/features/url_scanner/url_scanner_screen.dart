import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';

class UrlScannerScreen extends StatefulWidget {
  const UrlScannerScreen({super.key});

  @override
  State<UrlScannerScreen> createState() => _UrlScannerScreenState();
}

enum _ScanState { idle, scanning, done, error }

class _UrlScannerScreenState extends State<UrlScannerScreen> {
  final _controller = TextEditingController();
  _ScanState _state = _ScanState.idle;
  UrlResult? _result;
  String _statusMsg = '';
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
  ));

  @override
  void dispose() {
    _controller.dispose();
    _dio.close();
    super.dispose();
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _statusMsg = msg);
  }

  Future<void> _scan() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;

    final urlPattern = r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$';
    if (!RegExp(urlPattern, caseSensitive: false).hasMatch(raw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Bhai, kya type kar diya? Ye link toh is duniya mein exist hi nahi karta! Sahi URL dalo. 😂"),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();

    String url = raw;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url'; // Default to HTTPS for testing
    }

    setState(() {
      _state = _ScanState.scanning;
      _result = null;
      _statusMsg = 'Initializing deep scan...';
    });

    try {
      final result = await _analyzeUrl(url);

      // Save to Supabase
      try {
        await SupabaseService().saveScanHistory(
          scanType: 'URL',
          target: url,
          status: result.verdict == UrlVerdict.dangerous ? 'DANGER' : (result.verdict == UrlVerdict.caution ? 'WARNING' : 'SAFE'),
          details: {'riskScore': result.riskScore, 'domain': result.domain},
        );
      } catch (e) {
        debugPrint('Supabase save error: $e');
      }

      if (!mounted) return;
      setState(() {
        _state = _ScanState.done;
        _result = result;
        _statusMsg = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _result = UrlResult.error(url);
        _statusMsg = '';
      });
    }
  }

  String _getBaseDomain(String domain) {
    final parts = domain.split('.');
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
    }
    return domain;
  }

  // A hardcoded list of major trusted domains for India
  final _allowlist = {
    'google.com', 'youtube.com', 'facebook.com', 'instagram.com', 'whatsapp.com',
    'sbi.co.in', 'hdfcbank.com', 'icicibank.com', 'axisbank.com', 'kotak.com',
    'amazon.in', 'amazon.com', 'flipkart.com', 'myntra.com', 'meesho.com',
    'paytm.com', 'phonepe.com', 'gpay.app',
    'incometax.gov.in', 'uidai.gov.in', 'npci.org.in', 'rbi.org.in', 'onlinesbi.sbi',
    'irctc.co.in', 'nic.in', 'gov.in', 'india.gov.in', 'passportindia.gov.in',
    'bsnl.co.in', 'tatamotors.com', 'reliance.com', 'jio.com',
    'microsoft.com', 'apple.com', 'linkedin.com', 'twitter.com', 'x.com'
  };

  Future<UrlResult> _analyzeUrl(String url) async {
    final uri = Uri.tryParse(url) ?? Uri(host: url);
    final domain = uri.host.toLowerCase().replaceAll('www.', '');
    final baseDomain = _getBaseDomain(domain);
    
    final domainChecks = <DomainCheckItem>[];
    int riskScore = 0; // 0-100
    bool isAllowlisted = false;

    // 1. LOCAL ALLOWLIST CHECK
    _setStatus('Checking local trusted registry...');
    if (_allowlist.contains(baseDomain) || _allowlist.contains(domain) || domain.endsWith('.gov.in') || domain.endsWith('.nic.in')) {
      isAllowlisted = true;
      domainChecks.add(DomainCheckItem('Trusted Registry', true, 'Known safe organization/government domain.'));
    } else {
      domainChecks.add(DomainCheckItem('Trusted Registry', null, 'Not in local allowlist (Neutral).'));
    }

    // Parallel API Futures
    Future<_HttpsResult> httpsFuture = _checkHttps(url, domain);
    Future<_SafeBrowsingResult> safeBrowsingFuture = _checkSafeBrowsing(url);
    Future<_VirusTotalResult> vtFuture = _checkVirusTotal(domain);
    Future<_UrlHausResult> urlHausFuture = _checkUrlHaus(url);
    Future<_DomainAgeResult> ageFuture = _checkDomainAge(domain);
    Future<_SiteMetaResult> metaFuture = _fetchSiteMeta(url, domain);
    Future<_IpGeoResult> geoFuture = _fetchIpGeo(domain);
    Future<_HeadersResult> headersFuture = _fetchHeaders(url);
    Future<_DnsResult> dnsFuture = _fetchDnsRecords(domain);

    // Wait for all checks
    final results = await Future.wait([
      httpsFuture,
      safeBrowsingFuture,
      vtFuture,
      urlHausFuture,
      ageFuture,
      metaFuture,
      geoFuture,
      headersFuture,
      dnsFuture,
    ]);

    final https = results[0] as _HttpsResult;
    final sb = results[1] as _SafeBrowsingResult;
    final vt = results[2] as _VirusTotalResult;
    final urlHaus = results[3] as _UrlHausResult;
    final age = results[4] as _DomainAgeResult;
    final meta = results[5] as _SiteMetaResult;
    final geo = results[6] as _IpGeoResult;
    final headers = results[7] as _HeadersResult;
    final dns = results[8] as _DnsResult;

    // 2. HTTPS RESOLUTION CHECK
    if (https.isSecure) {
      domainChecks.add(DomainCheckItem('HTTPS Encryption', true, 'Valid SSL certificate verified.'));
    } else {
      riskScore += 20;
      domainChecks.add(DomainCheckItem('HTTPS Encryption', false, 'Missing or invalid SSL certificate. Unsafe for data.'));
    }

    // 2b. TYPOSQUATTING & BRAND SPOOFING CHECK
    final typosquat = _detectTyposquatting(domain);
    if (typosquat != null) {
      riskScore += 55;
      domainChecks.insert(0, DomainCheckItem('Phishing / Impersonation Alert', false, typosquat));
    }

    // 2c. CLOUDFLARE DoH DNS RECORD CHECKS
    if (dns.hasMx) {
      domainChecks.add(DomainCheckItem('Mail Server (MX)', true, 'Active corporate mail infrastructure (${dns.mxRecords.first}).'));
    } else if (!isAllowlisted) {
      riskScore += 10;
      domainChecks.add(DomainCheckItem('Mail Server (MX)', null, 'No mail exchange records — common with disposable phishing domains.'));
    }

    if (dns.hasDmarc) {
      domainChecks.add(DomainCheckItem('Email DMARC Security', true, 'DMARC policy active. Protected against email spoofing.'));
    } else {
      domainChecks.add(DomainCheckItem('Email DMARC Security', null, 'DMARC policy not found.'));
    }

    // 3. GOOGLE SAFE BROWSING
    if (sb.isMalicious) {
      riskScore += 60;
      domainChecks.add(DomainCheckItem('Google Safe Browsing', false, 'Flagged by Google as dangerous (${sb.threatType}).'));
    } else if (sb.apiFailed) {
      domainChecks.add(DomainCheckItem('Google Safe Browsing', null, 'API unavailable or missing key. Could not verify.'));
    } else {
      domainChecks.add(DomainCheckItem('Google Safe Browsing', true, 'Clean. No threats found by Google.'));
    }

    // 4. VIRUSTOTAL
    if (vt.maliciousCount > 0) {
      riskScore += 30;
      domainChecks.add(DomainCheckItem('VirusTotal Engine', false, 'Flagged by ${vt.maliciousCount} security vendors.'));
    } else if (vt.apiFailed) {
      domainChecks.add(DomainCheckItem('VirusTotal Engine', null, 'API unavailable or missing key. Could not verify.'));
    } else {
      domainChecks.add(DomainCheckItem('VirusTotal Engine', true, 'Clean across all major security vendors.'));
    }

    // 5. URLHAUS
    if (urlHaus.isListed) {
      riskScore += 50;
      domainChecks.add(DomainCheckItem('URLhaus Malware DB', false, 'Confirmed malware distribution site.'));
    } else if (urlHaus.apiFailed) {
      domainChecks.add(DomainCheckItem('URLhaus Malware DB', null, 'Service unreachable.'));
    } else {
      domainChecks.add(DomainCheckItem('URLhaus Malware DB', true, 'Not listed in malware databases.'));
    }

    // 6. DOMAIN AGE / WHOIS
    if (age.apiFailed) {
      domainChecks.add(DomainCheckItem('Domain Age (RDAP)', null, 'Could not fetch domain registration data.'));
    } else {
      if (age.daysOld >= 0 && age.daysOld < 30) {
        riskScore += 15;
        domainChecks.add(DomainCheckItem('Domain Age (RDAP)', false, 'Registered very recently (${age.daysOld} days ago). High risk of scam.'));
      } else if (age.daysOld >= 30) {
        domainChecks.add(DomainCheckItem('Domain Age (RDAP)', true, 'Established domain (${age.daysOld} days old).'));
      }
    }

    // 7. IP ADDRESS PATTERN
    final ipRegex = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
    if (ipRegex.hasMatch(domain)) {
      riskScore += 25;
      domainChecks.add(DomainCheckItem('Domain Structure', false, 'Using raw IP address instead of domain.'));
    }

    // 8. SCAM KEYWORDS
    final scamKeywords = ['prize', 'winner', 'free', 'lucky', 'jackpot', 'kyc', 'verify', 'urgent'];
    if (scamKeywords.any((k) => url.toLowerCase().contains(k))) {
      riskScore += 10;
      domainChecks.add(DomainCheckItem('URL Pattern', false, 'Suspicious keywords found in URL.'));
    }

    // Cap score at 100
    riskScore = riskScore.clamp(0, 100);

    // If it's a known top-level allowlisted domain, force score to 0 unless live APIs explicitly catch malware (highly unlikely for real google.com, but catches typos)
    if (isAllowlisted && riskScore < 60) {
      riskScore = 0;
    }

    final verdict = isAllowlisted && riskScore == 0
        ? UrlVerdict.safe
        : riskScore >= 51
            ? UrlVerdict.dangerous
            : riskScore >= 21
                ? UrlVerdict.caution
                : UrlVerdict.safe;

    return UrlResult(
      url: url,
      domain: domain,
      riskScore: riskScore,
      verdict: verdict,
      checks: {}, // Deprecated, keeping for model compatibility
      warnings: [], // Handled by domainChecks now
      positives: [], // Handled by domainChecks now
      domainChecks: domainChecks,
      isVerifiedSafe: isAllowlisted,
      siteTitle: meta.title,
      siteDescription: meta.description,
      serverCountry: geo.country,
      serverCity: geo.city,
      serverIsp: geo.isp,
      serverIp: geo.ip,
      serverSoftware: headers.server,
      poweredBy: headers.poweredBy,
      contentType: headers.contentType,
      securityHeaders: headers.securityHeadersPresent,
      aRecords: dns.aRecords,
      mxRecords: dns.mxRecords,
      nsRecords: dns.nsRecords,
      hasDmarc: dns.hasDmarc,
      typosquattingWarning: typosquat,
    );
  }

  // --- Pipeline Implementations ---

  Future<_HttpsResult> _checkHttps(String originalUrl, String domain) async {
    _setStatus('Verifying SSL Certificate...');
    try {
      final checkUrl = 'https://$domain';
      final response = await _dio.get(checkUrl, options: Options(
        validateStatus: (status) => true,
        receiveTimeout: const Duration(seconds: 4),
      ));
      return _HttpsResult(isSecure: response.statusCode != null);
    } catch (_) {
      return _HttpsResult(isSecure: false);
    }
  }

  Future<_SafeBrowsingResult> _checkSafeBrowsing(String url) async {
    _setStatus('Querying Google Safe Browsing...');
    if (AppConstants.googleSafeBrowsingApiKey.isEmpty) { 
      return _SafeBrowsingResult(apiFailed: true);
    }
    try {
      final body = {
        "client": {"clientId": "safesignal", "clientVersion": "1.0.0"},
        "threatInfo": {
          "threatTypes": ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE", "POTENTIALLY_HARMFUL_APPLICATION"],
          "platformTypes": ["ANY_PLATFORM"],
          "threatEntryTypes": ["URL"],
          "threatEntries": [{"url": url}]
        }
      };
      final response = await _dio.post(
        'https://safebrowsing.googleapis.com/v4/threatMatches:find?key=${AppConstants.googleSafeBrowsingApiKey}',
        data: jsonEncode(body),
        options: Options(receiveTimeout: const Duration(seconds: 4)),
      );
      if (response.statusCode == 200 && response.data != null && response.data['matches'] != null) {
        final matches = response.data['matches'] as List;
        if (matches.isNotEmpty) {
          return _SafeBrowsingResult(isMalicious: true, threatType: matches[0]['threatType']);
        }
      }
      return _SafeBrowsingResult(isMalicious: false);
    } catch (_) {
      return _SafeBrowsingResult(apiFailed: true);
    }
  }

  Future<_VirusTotalResult> _checkVirusTotal(String domain) async {
    _setStatus('Querying VirusTotal Engines...');
    if (AppConstants.virusTotalApiKey.isEmpty) {
      return _VirusTotalResult(apiFailed: true);
    }
    try {
      final response = await _dio.get(
        'https://www.virustotal.com/api/v3/domains/$domain',
        options: Options(
          headers: {'x-apikey': AppConstants.virusTotalApiKey},
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      if (response.statusCode == 200) {
        final stats = response.data['data']['attributes']['last_analysis_stats'];
        final malicious = stats['malicious'] as int? ?? 0;
        return _VirusTotalResult(maliciousCount: malicious);
      }
      return _VirusTotalResult(apiFailed: true);
    } catch (_) {
      return _VirusTotalResult(apiFailed: true);
    }
  }

  Future<_UrlHausResult> _checkUrlHaus(String url) async {
    _setStatus('Querying URLhaus Malware DB...');
    try {
      final response = await _dio.post(
        'https://urlhaus-api.abuse.ch/v1/url/',
        data: FormData.fromMap({'url': url}),
        options: Options(receiveTimeout: const Duration(seconds: 4)),
      );
      return _UrlHausResult(isListed: response.data['query_status'] == 'is_listed');
    } catch (_) {
      return _UrlHausResult(apiFailed: true);
    }
  }

  Future<_DomainAgeResult> _checkDomainAge(String domain) async {
    _setStatus('Checking RDAP for Domain Age...');
    try {
      final response = await _dio.get(
        'https://rdap.org/domain/$domain',
        options: Options(receiveTimeout: const Duration(seconds: 4)),
      );
      if (response.statusCode == 200 && response.data['events'] != null) {
        final events = response.data['events'] as List;
        for (var ev in events) {
          if (ev['eventAction'] == 'registration') {
            final dateStr = ev['eventDate'];
            final regDate = DateTime.parse(dateStr);
            final diff = DateTime.now().difference(regDate).inDays;
            return _DomainAgeResult(daysOld: diff);
          }
        }
      }
      return _DomainAgeResult(apiFailed: true);
    } catch (_) {
      return _DomainAgeResult(apiFailed: true);
    }
  }

  // ─── Site Meta (OG tags / HTML title scrape) ────────────────────────────────
  Future<_SiteMetaResult> _fetchSiteMeta(String url, String domain) async {
    _setStatus('Fetching site metadata...');
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {'User-Agent': 'Mozilla/5.0 (SafeSignal Security Scanner 1.0)'},
          receiveTimeout: const Duration(seconds: 5),
          validateStatus: (s) => s != null && s < 600,
        ),
      );
      final body = response.data?.toString() ?? '';

      // Extract OG title or HTML title
      String title = '';
      final ogTitleIdx = body.toLowerCase().indexOf('og:title');
      if (ogTitleIdx != -1) {
        final chunk = body.substring(ogTitleIdx, (ogTitleIdx + 300).clamp(0, body.length));
        final match = RegExp(r'''content=["']([^"']{1,120})["']''', caseSensitive: false).firstMatch(chunk);
        title = match?.group(1)?.trim() ?? '';
      }
      if (title.isEmpty) {
        final tOpen = body.toLowerCase().indexOf('<title');
        final tClose = body.toLowerCase().indexOf('</title>');
        if (tOpen != -1 && tClose > tOpen) {
          final tStart = body.indexOf('>', tOpen);
          if (tStart != -1 && tStart < tClose) {
            title = body.substring(tStart + 1, tClose).trim();
            if (title.length > 120) title = title.substring(0, 120);
          }
        }
      }

      // Extract OG description or meta description
      String description = '';
      final ogDescIdx = body.toLowerCase().indexOf('og:description');
      if (ogDescIdx != -1) {
        final chunk = body.substring(ogDescIdx, (ogDescIdx + 400).clamp(0, body.length));
        final match = RegExp(r'''content=["']([^"']{1,200})["']''', caseSensitive: false).firstMatch(chunk);
        description = match?.group(1)?.trim() ?? '';
      }
      if (description.isEmpty) {
        final descIdx = body.toLowerCase().indexOf('name="description"');
        final descIdx2 = body.toLowerCase().indexOf("name='description'");
        final dIdx = descIdx != -1 ? descIdx : descIdx2;
        if (dIdx != -1) {
          final chunk = body.substring(dIdx, (dIdx + 400).clamp(0, body.length));
          final match = RegExp(r'''content=["']([^"']{1,200})["']''', caseSensitive: false).firstMatch(chunk);
          description = match?.group(1)?.trim() ?? '';
        }
      }

      return _SiteMetaResult(title: title, description: description);
    } catch (_) {
      return _SiteMetaResult();
    }
  }

  // ─── IP Geolocation (ip-api.com — free, no key needed) ──────────────────────
  Future<_IpGeoResult> _fetchIpGeo(String domain) async {
    _setStatus('Resolving server location...');
    try {
      final response = await _dio.get(
        'http://ip-api.com/json/$domain?fields=status,country,city,isp,query',
        options: Options(receiveTimeout: const Duration(seconds: 4)),
      );
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return _IpGeoResult(
          country: response.data['country']?.toString() ?? '',
          city: response.data['city']?.toString() ?? '',
          isp: response.data['isp']?.toString() ?? '',
          ip: response.data['query']?.toString() ?? '',
        );
      }
      return _IpGeoResult();
    } catch (_) {
      return _IpGeoResult();
    }
  }

  // ─── HTTP Headers Analysis ───────────────────────────────────────────────────
  Future<_HeadersResult> _fetchHeaders(String url) async {
    _setStatus('Analyzing HTTP security headers...');
    try {
      final response = await _dio.head(
        url,
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          validateStatus: (s) => true,
          headers: {'User-Agent': 'Mozilla/5.0 (SafeSignal Security Scanner 1.0)'},
        ),
      );
      final h = response.headers;
      final server = h.value('server') ?? '';
      final poweredBy = h.value('x-powered-by') ?? '';
      final contentType = h.value('content-type') ?? '';
      // Security headers check
      final hasHsts = h.value('strict-transport-security') != null;
      final hasXfo = h.value('x-frame-options') != null;
      final hasCsp = h.value('content-security-policy') != null;
      final hasXcto = h.value('x-content-type-options') != null;
      final secCount = [hasHsts, hasXfo, hasCsp, hasXcto].where((b) => b).length;
      return _HeadersResult(
        server: server,
        poweredBy: poweredBy,
        contentType: contentType,
        securityHeadersPresent: secCount,
      );
    } catch (_) {
      return _HeadersResult();
    }
  }

  // ─── Cloudflare DoH (DNS-over-HTTPS) Reconnaissance ────────────────────────
  Future<_DnsResult> _fetchDnsRecords(String domain) async {
    _setStatus('Querying DNS Records via Cloudflare DoH...');
    final aRecs = <String>[];
    final mxRecs = <String>[];
    final txtRecs = <String>[];
    final nsRecs = <String>[];
    bool hasDmarc = false;

    try {
      final dohDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        headers: {'Accept': 'application/dns-json'},
      ));

      // Parallel DoH queries for A, MX, NS, and DMARC
      final responses = await Future.wait([
        dohDio.get('https://cloudflare-dns.com/dns-query?name=$domain&type=A').catchError((_) => Response(requestOptions: RequestOptions())),
        dohDio.get('https://cloudflare-dns.com/dns-query?name=$domain&type=MX').catchError((_) => Response(requestOptions: RequestOptions())),
        dohDio.get('https://cloudflare-dns.com/dns-query?name=$domain&type=NS').catchError((_) => Response(requestOptions: RequestOptions())),
        dohDio.get('https://cloudflare-dns.com/dns-query?name=_dmarc.$domain&type=TXT').catchError((_) => Response(requestOptions: RequestOptions())),
      ]);

      // Parse A (Type 1)
      if (responses[0].statusCode == 200 && responses[0].data is Map && responses[0].data['Answer'] is List) {
        for (final ans in responses[0].data['Answer']) {
          if (ans['data'] != null) aRecs.add(ans['data'].toString().trim());
        }
      }
      // Parse MX (Type 15)
      if (responses[1].statusCode == 200 && responses[1].data is Map && responses[1].data['Answer'] is List) {
        for (final ans in responses[1].data['Answer']) {
          if (ans['data'] != null) mxRecs.add(ans['data'].toString().trim());
        }
      }
      // Parse NS (Type 2)
      if (responses[2].statusCode == 200 && responses[2].data is Map && responses[2].data['Answer'] is List) {
        for (final ans in responses[2].data['Answer']) {
          if (ans['data'] != null) nsRecs.add(ans['data'].toString().trim());
        }
      }
      // Parse DMARC TXT (Type 16)
      if (responses[3].statusCode == 200 && responses[3].data is Map && responses[3].data['Answer'] is List) {
        for (final ans in responses[3].data['Answer']) {
          final d = ans['data']?.toString() ?? '';
          if (d.contains('v=DMARC1')) {
            hasDmarc = true;
            txtRecs.add(d);
          }
        }
      }
    } catch (_) {}

    return _DnsResult(
      aRecords: aRecs,
      mxRecords: mxRecs,
      txtRecords: txtRecs,
      nsRecords: nsRecs,
      hasDmarc: hasDmarc,
      hasMx: mxRecs.isNotEmpty,
    );
  }

  // ─── Indian Bank & Brand Typosquatting / Lookalike Detector ─────────────────
  static const _brandRegistry = {
    'sbi': 'onlinesbi.sbi',
    'statebank': 'sbi.co.in',
    'hdfc': 'hdfcbank.com',
    'icici': 'icicibank.com',
    'axis': 'axisbank.com',
    'kotak': 'kotak.com',
    'paytm': 'paytm.com',
    'phonepe': 'phonepe.com',
    'gpay': 'google.com',
    'google': 'google.com',
    'amazon': 'amazon.in',
    'flipkart': 'flipkart.com',
    'incometax': 'incometax.gov.in',
    'uidai': 'uidai.gov.in',
    'aadhaar': 'uidai.gov.in',
    'irctc': 'irctc.co.in',
    'whatsapp': 'whatsapp.com',
    'netflix': 'netflix.com',
    'jio': 'jio.com',
  };

  String? _detectTyposquatting(String domain) {
    final d = domain.toLowerCase();
    for (final entry in _brandRegistry.entries) {
      final brand = entry.key;
      final official = entry.value;

      if (d.contains(brand)) {
        // If domain contains the brand name, check if it's legitimately authorized
        final isAuth = d == official || 
                       d.endsWith('.$official') || 
                       (official == 'sbi.co.in' && (d == 'sbi.co.in' || d == 'onlinesbi.sbi' || d.endsWith('.sbi.co.in') || d.endsWith('.onlinesbi.sbi'))) ||
                       d.endsWith('.gov.in') || 
                       d.endsWith('.nic.in');
        if (!isAuth) {
          return 'Deceptive domain impersonating ${brand.toUpperCase()}! Official site is: $official';
        }
      }
    }
    return null;
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF06090F) : const Color(0xFFEBF3FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    
    // Determine gauge score and status text
    double gaugeScore = 0;
    String statusText = '';
    Color statusColor = Colors.transparent;

    if (_state == _ScanState.done && _result != null) {
      gaugeScore = _result!.riskScore.toDouble();
      if (_result!.verdict == UrlVerdict.dangerous) {
        statusText = 'Unsafe';
        statusColor = const Color(0xFFFF8A65); // Orange-red matching screenshot
      } else if (_result!.verdict == UrlVerdict.caution) {
        statusText = 'Suspicious';
        statusColor = const Color(0xFFFFB300);
      } else {
        statusText = 'Safe';
        statusColor = const Color(0xFF4CAF50);
      }
    } else if (_state == _ScanState.scanning) {
      statusText = _statusMsg.isNotEmpty ? _statusMsg : 'Scanning...';
      statusColor = AppTheme.primary;
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: IconButton(
              icon: const Icon(Icons.grid_view_rounded, color: Colors.white54, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Scan Link',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: textColor,
            fontFamily: 'serif', // Matching the screenshot's serif-like font for title
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Gauge
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: gaugeScore),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return SpeedometerGauge(score: value);
                },
              ),
              const SizedBox(height: 12),
              // Status Text
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'serif',
                ),
              ).animate(target: statusText.isNotEmpty ? 1 : 0).fadeIn(),
              
              const SizedBox(height: 32),

              // TextField mimicking the screenshot
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark ? Colors.white30 : Colors.black26,
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    TextField(
                      controller: _controller,
                      enabled: _state != _ScanState.scanning,
                      style: TextStyle(color: textColor, fontSize: 16),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.black54, size: 24),
                        ),
                      ),
                      onSubmitted: (_) => _scan(),
                    ),
                    Positioned(
                      left: 24,
                      top: -10,
                      child: Container(
                        color: bg,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          'Link',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),

              // Scan Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF29B6F6), Color(0xFF0D47A1)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _state == _ScanState.scanning ? null : _scan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 24), // Balance for centering
                      Expanded(
                        child: Center(
                          child: Text(
                            _state == _ScanState.scanning ? 'Scanning...' : 'Scan URL',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                        ),
                      ),
                      _state == _ScanState.scanning 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(Icons.language, color: isDark ? Colors.white : Colors.black87, size: 24),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 150.ms),

              if (_state == _ScanState.done && _result != null) ...[
                const SizedBox(height: 24),
                _buildAnalysisCards(_result!, isDark),
              ],

              if (_state == _ScanState.error)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'Network error. Please check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisCards(UrlResult result, bool isDark) {
    String siteGrade = result.verdict == UrlVerdict.dangerous ? 'E' : (result.verdict == UrlVerdict.caution ? 'C' : 'A');
    String secScore = result.riskScore > 50 ? '1' : (result.riskScore > 20 ? '5' : '9');
    
    // Extract registry date if possible
    String registryDate = 'Unknown';
    for(var c in result.domainChecks) {
       if(c.name.contains('Domain Age') && c.detail.contains('days old')) {
           final days = RegExp(r'(\d+) days old').firstMatch(c.detail)?.group(1) ?? '';
           registryDate = days.isNotEmpty ? '$days days ago' : c.detail;
       } else if (c.name.contains('Domain Age') && c.detail.contains('days ago')) {
           final days = RegExp(r'(\d+) days ago').firstMatch(c.detail)?.group(1) ?? '';
           registryDate = days.isNotEmpty ? '$days days ago' : c.detail;
       }
    }

    // Extract synopsis from failed checks
    String synopsis = result.domainChecks.where((c) => c.passed == false).map((c) => c.detail).join('. ');
    if (synopsis.isEmpty) synopsis = 'No major threats detected — all checks passed.';
    if (result.verdict == UrlVerdict.dangerous && synopsis.length < 20) {
      synopsis = 'Multiple security risks detected: possible phishing, suspicious domain structure, or flagged by threat intelligence databases.';
    }

    final outlineColor = result.verdict == UrlVerdict.dangerous
        ? const Color(0xFFFF8A65)
        : result.verdict == UrlVerdict.caution
            ? const Color(0xFFFFB300)
            : const Color(0xFF4CAF50);

    final cardStyle = BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: outlineColor, width: 1.5),
    );

    final labelStyle = TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.bold);
    final mutedStyle = TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13, height: 1.4);

    return Column(
      children: [

        // ── Card 1: Site Overview ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: cardStyle,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader('Site Overview', isDark),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Favicon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        'https://www.google.com/s2/favicons?domain=${result.domain}&sz=128',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            result.domain.isNotEmpty ? result.domain[0].toUpperCase() : 'A',
                            style: const TextStyle(fontSize: 28, color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.siteTitle.isNotEmpty ? result.siteTitle : result.domain,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0D1117),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (result.siteDescription.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(result.siteDescription, style: mutedStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _divider2(isDark),
              const SizedBox(height: 12),
              _buildRow('Site Grade', siteGrade, valueColor: outlineColor, isDark: isDark),
              _divider(),
              _buildRow('Security Score', '$secScore/10', valueColor: outlineColor, isDark: isDark),
              _divider(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: Text('Synopsis', style: labelStyle)),
                  Expanded(flex: 3, child: Text(synopsis, style: TextStyle(color: outlineColor, fontSize: 13, height: 1.4))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Card 2: Security Rating Breakdown ─────────────────────────────────
        Container(
          width: double.infinity,
          decoration: cardStyle,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader('Security Rating Breakdown', isDark),
              const SizedBox(height: 20),
              _buildRow('Phishing Check', result.verdict == UrlVerdict.dangerous ? 'Failed' : 'Passed',
                  valueColor: result.verdict == UrlVerdict.dangerous ? const Color(0xFFFF8A65) : const Color(0xFF4CAF50), isDark: isDark),
              _divider(),
              _buildRow('Malware Scan', result.verdict == UrlVerdict.dangerous ? 'Threat Found' : 'Clean',
                  valueColor: result.verdict == UrlVerdict.dangerous ? const Color(0xFFFF8A65) : const Color(0xFF4CAF50), isDark: isDark),
              _divider(),
              _buildRow('URLhaus DB', result.domainChecks.any((c) => c.name.contains('URLhaus') && c.passed == false) ? 'Listed' : 'Clean',
                  valueColor: result.domainChecks.any((c) => c.name.contains('URLhaus') && c.passed == false) ? const Color(0xFFFF8A65) : const Color(0xFF4CAF50), isDark: isDark),
              _divider(),
              _buildRow('Domain Trust', result.verdict == UrlVerdict.dangerous ? 'Low' : 'Established',
                  valueColor: result.verdict == UrlVerdict.dangerous ? const Color(0xFFFF8A65) : const Color(0xFF4CAF50), isDark: isDark),
              _divider(),
              // Security headers
              _buildRow(
                'Security Headers',
                '${result.securityHeaders}/4 present',
                valueColor: result.securityHeaders >= 3
                    ? const Color(0xFF4CAF50)
                    : result.securityHeaders >= 2
                        ? const Color(0xFFFFB300)
                        : const Color(0xFFFF8A65),
                isDark: isDark,
              ),
              _divider(),
              _buildRow('Final Score', '$secScore/10', valueColor: outlineColor, isDark: isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Card 3: Domain Reputation ─────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: cardStyle,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader('Domain Reputation', isDark),
              const SizedBox(height: 20),
              _buildRow('Domain', result.domain, valueColor: outlineColor, isDark: isDark),
              if (registryDate != 'Unknown') ...[
                _divider(),
                _buildRow('Registered', registryDate, valueColor: outlineColor, isDark: isDark),
              ],
              _divider(),
              _buildRow('In Allowlist', result.isVerifiedSafe ? 'Yes (Trusted)' : 'No',
                  valueColor: result.isVerifiedSafe ? const Color(0xFF4CAF50) : const Color(0xFFFF8A65), isDark: isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Card 4: Server Intelligence ───────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: cardStyle,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader('Server Intelligence', isDark),
              const SizedBox(height: 20),
              if (result.serverIp.isNotEmpty) ...[
                _buildRow('IP Address', result.serverIp, valueColor: outlineColor, isDark: isDark),
                _divider(),
              ],
              if (result.serverCountry.isNotEmpty) ...[
                _buildRow('Country', '${result.serverCity.isNotEmpty ? "${result.serverCity}, " : ""}${result.serverCountry}',
                    valueColor: outlineColor, isDark: isDark),
                _divider(),
              ],
              if (result.serverIsp.isNotEmpty) ...[
                _buildRow('ISP / Host', result.serverIsp, valueColor: outlineColor, isDark: isDark),
                _divider(),
              ],
              if (result.serverSoftware.isNotEmpty) ...[
                _buildRow('Server Software', result.serverSoftware, valueColor: outlineColor, isDark: isDark),
                _divider(),
              ],
              if (result.poweredBy.isNotEmpty) ...[
                _buildRow('Powered By', result.poweredBy, valueColor: outlineColor, isDark: isDark),
                _divider(),
              ],
              _buildRow('Safe for Payments', result.verdict == UrlVerdict.dangerous ? 'No — High Risk' : 'Yes (HTTPS Secured)',
                  valueColor: result.verdict == UrlVerdict.dangerous ? const Color(0xFFFF8A65) : const Color(0xFF4CAF50), isDark: isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Card 5: DNS & Mail Security (Cloudflare DoH) ─────────────────────
        Container(
          width: double.infinity,
          decoration: cardStyle,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader('DNS & Email Recon (Cloudflare DoH)', isDark),
              const SizedBox(height: 20),
              if (result.aRecords.isNotEmpty) ...[
                _buildRow('Resolved IPs (A)', result.aRecords.take(2).join(', '), valueColor: outlineColor, isDark: isDark),
                _divider(),
              ],
              _buildRow(
                'Mail Server (MX)',
                result.mxRecords.isNotEmpty ? result.mxRecords.first : 'No Mail Server (Phishing Suspect)',
                valueColor: result.mxRecords.isNotEmpty ? const Color(0xFF4CAF50) : const Color(0xFFFF8A65),
                isDark: isDark,
              ),
              _divider(),
              _buildRow(
                'DMARC Anti-Spoof',
                result.hasDmarc ? 'Enabled (Valid Policy)' : 'Not Configured (Spoofable)',
                valueColor: result.hasDmarc ? const Color(0xFF4CAF50) : const Color(0xFFFFB300),
                isDark: isDark,
              ),
              if (result.nsRecords.isNotEmpty) ...[
                _divider(),
                _buildRow('Nameservers (NS)', result.nsRecords.take(2).join(', '), valueColor: outlineColor, isDark: isDark),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Card 5: Threat Warning (only if dangerous/caution) ────────────────
        if (result.verdict == UrlVerdict.dangerous || result.verdict == UrlVerdict.caution)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: result.verdict == UrlVerdict.dangerous
                  ? const Color(0xFF3E120A)
                  : const Color(0xFF3E2A00),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      result.verdict == UrlVerdict.dangerous ? 'Suspected Fraud' : 'Use With Caution',
                      style: TextStyle(
                        color: result.verdict == UrlVerdict.dangerous ? const Color(0xFFFF8A65) : const Color(0xFFFFB300),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      result.verdict == UrlVerdict.dangerous ? Icons.warning_rounded : Icons.info_outline,
                      color: result.verdict == UrlVerdict.dangerous ? const Color(0xFFFF8A65) : const Color(0xFFFFB300),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  result.verdict == UrlVerdict.dangerous
                      ? 'Do NOT perform any financial transactions or share personal information on this site. Report to cybercrime.gov.in or call 1930.'
                      : 'Proceed with caution. Verify the website authenticity before sharing any personal or financial information.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 16),

        // ── Open Link Button ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white30 : Colors.black26, width: 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              if (result.url.isNotEmpty) {
                final uri = Uri.parse(result.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.language, color: isDark ? Colors.white : Colors.black87, size: 24),
                  Expanded(
                    child: Center(
                      child: Text('Open Link ↗', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _cardHeader(String title, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF5D1D05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _divider2(bool isDark) => Divider(
    color: isDark ? Colors.white12 : Colors.black12,
    height: 1,
    thickness: 1,
  );

  Widget _buildRow(String label, String value, {required Color valueColor, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, fontWeight: FontWeight.w600))),
          Expanded(flex: 3, child: Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Divider(color: Colors.white12, height: 1, thickness: 1),
    );
  }
}


class _HttpsResult {
  final bool isSecure;
  _HttpsResult({this.isSecure = false});
}

class _SafeBrowsingResult {
  final bool isMalicious;
  final String? threatType;
  final bool apiFailed;
  _SafeBrowsingResult({this.isMalicious = false, this.threatType, this.apiFailed = false});
}

class _VirusTotalResult {
  final int maliciousCount;
  final bool apiFailed;
  _VirusTotalResult({this.maliciousCount = 0, this.apiFailed = false});
}

class _UrlHausResult {
  final bool isListed;
  final bool apiFailed;
  _UrlHausResult({this.isListed = false, this.apiFailed = false});
}

class _DomainAgeResult {
  final int daysOld;
  final bool apiFailed;
  _DomainAgeResult({this.daysOld = -1, this.apiFailed = false});
}

enum UrlVerdict { safe, caution, dangerous }

class UrlResult {
  final String url;
  final String domain;
  final int riskScore;
  final UrlVerdict verdict;
  final Map<String, bool> checks;
  final List<String> warnings;
  final List<String> positives;
  final List<DomainCheckItem> domainChecks;
  final bool isVerifiedSafe;
  // ── New advanced fields ───────────────────────────────────────────────────
  final String siteTitle;
  final String siteDescription;
  final String serverCountry;
  final String serverCity;
  final String serverIsp;
  final String serverIp;
  final String serverSoftware;
  final String poweredBy;
  final String contentType;
  final int securityHeaders; // 0-4 count of security headers present

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
  });

  final List<String> aRecords;
  final List<String> mxRecords;
  final List<String> nsRecords;
  final bool hasDmarc;
  final String? typosquattingWarning;

  factory UrlResult.error(String url) {
    return UrlResult(
      url: url,
      domain: '',
      riskScore: 0,
      verdict: UrlVerdict.caution,
      checks: {},
      warnings: [],
      positives: [],
      domainChecks: [],
      isVerifiedSafe: false,
    );
  }
}

class _DnsResult {
  final List<String> aRecords;
  final List<String> mxRecords;
  final List<String> txtRecords;
  final List<String> nsRecords;
  final bool hasDmarc;
  final bool hasMx;
  _DnsResult({
    this.aRecords = const [],
    this.mxRecords = const [],
    this.txtRecords = const [],
    this.nsRecords = const [],
    this.hasDmarc = false,
    this.hasMx = false,
  });
}

class _SiteMetaResult {
  final String title;
  final String description;
  _SiteMetaResult({this.title = '', this.description = ''});
}

class _IpGeoResult {
  final String country;
  final String city;
  final String isp;
  final String ip;
  _IpGeoResult({this.country = '', this.city = '', this.isp = '', this.ip = ''});
}

class _HeadersResult {
  final String server;
  final String poweredBy;
  final String contentType;
  final int securityHeadersPresent; // 0-4
  _HeadersResult({this.server = '', this.poweredBy = '', this.contentType = '', this.securityHeadersPresent = 0});
}


class DomainCheckItem {
  final String name;
  final bool? passed; // null = neutral/unknown
  final String detail;

  DomainCheckItem(this.name, this.passed, this.detail);
}

class SpeedometerGauge extends StatelessWidget {
  final double score; // 0 to 100
  const SpeedometerGauge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 140, // Height is roughly half of width + padding for the needle base
      child: CustomPaint(
        painter: _SpeedometerPainter(score),
      ),
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double score;

  _SpeedometerPainter(this.score);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 20);
    final radius = size.width / 2;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.butt;
    
    // Draw the 3 arcs (Green, Orange, Red)
    final rect = Rect.fromCircle(center: center, radius: radius - 20);
    
    // Green (0 to 33)
    paint.color = Colors.greenAccent.shade400;
    canvas.drawArc(rect, 3.14159, 3.14159 / 3, false, paint);
    
    // Orange (33 to 66)
    paint.color = Colors.orangeAccent.shade400;
    canvas.drawArc(rect, 3.14159 + (3.14159 / 3), 3.14159 / 3, false, paint);
    
    // Red (66 to 100)
    paint.color = Colors.redAccent.shade400;
    canvas.drawArc(rect, 3.14159 + (2 * 3.14159 / 3), 3.14159 / 3, false, paint);
    
    // Draw needle
    // Map score (0-100) to angle (Pi to 2*Pi)
    // We map a bit inside the bounds so it doesn't go fully horizontal
    double clampedScore = score.clamp(0.0, 100.0);
    final angle = 3.14159 + (clampedScore / 100) * 3.14159;
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    
    final needlePaint = Paint()
      ..color = const Color(0xFFE0E0E0) // Light grey to work on both themes
      ..style = PaintingStyle.fill;
    
    // Draw needle triangle
    final path = Path();
    path.moveTo(0, -6);
    path.lineTo(radius - 10, 0);
    path.lineTo(0, 6);
    path.close();
    
    // Add shadow
    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, needlePaint);
    
    // Draw center circle
    canvas.drawCircle(const Offset(0, 0), 16, needlePaint);
    final innerCirclePaint = Paint()..color = Colors.grey.shade400;
    canvas.drawCircle(const Offset(0, 0), 10, innerCirclePaint);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
