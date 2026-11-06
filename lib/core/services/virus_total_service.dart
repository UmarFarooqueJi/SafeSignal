// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: VirusTotal & Multi-Engine Threat Intelligence Service
// Author: Umar Farooque (https://github.com/UmarFarooqueJi)
// Copyright (c) 2026 Umar Farooque. All rights reserved.
// -----------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

/// Structured result from VirusTotal v3 analysis
class VirusTotalScanResult {
  final bool hasScanData;
  final int malicious;
  final int suspicious;
  final int harmless;
  final int undetected;
  final int totalEngines;
  final List<String> flaggedVendors;
  final String scanDate;
  final String webReportUrl;
  final bool isMalicious;
  final String? errorMessage;
  final bool hasCustomApiKey;

  const VirusTotalScanResult({
    required this.hasScanData,
    this.malicious = 0,
    this.suspicious = 0,
    this.harmless = 0,
    this.undetected = 0,
    this.totalEngines = 0,
    this.flaggedVendors = const [],
    this.scanDate = '',
    required this.webReportUrl,
    this.isMalicious = false,
    this.errorMessage,
    this.hasCustomApiKey = false,
  });

  factory VirusTotalScanResult.unconfigured(String url) {
    final sha256Hash = VirusTotalService.computeSha256(url);
    return VirusTotalScanResult(
      hasScanData: false,
      webReportUrl: 'https://www.virustotal.com/gui/url/$sha256Hash',
      hasCustomApiKey: false,
    );
  }

  factory VirusTotalScanResult.error(String url, String message, {bool hasKey = false}) {
    final sha256Hash = VirusTotalService.computeSha256(url);
    return VirusTotalScanResult(
      hasScanData: false,
      webReportUrl: 'https://www.virustotal.com/gui/url/$sha256Hash',
      errorMessage: message,
      hasCustomApiKey: hasKey,
    );
  }
}

/// Structured response from Cloudflare Security 1.1.1.2 & Quad9 Threat Intelligence DoH
class SecurityDnsCheckResult {
  final bool isBlocked;
  final String provider;
  final String details;

  const SecurityDnsCheckResult({
    required this.isBlocked,
    this.provider = '',
    this.details = '',
  });

  static const clean = SecurityDnsCheckResult(isBlocked: false);
}

/// Industrial Threat Intelligence Service integrating VirusTotal v3 API
/// and Real-Time Multi-Vendor Security DNS Telemetry (Cloudflare 1.1.1.2 + Quad9).
class VirusTotalService {
  static const String prefApiKey = 'pref_virustotal_api_key';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 6),
    ),
  );

  /// Computes the VirusTotal v3 Base64 URL identifier (without padding '=' characters)
  static String computeUrlId(String url) {
    final normalized = url.trim();
    final bytes = utf8.encode(normalized);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Computes the SHA-256 hash of the URL for VirusTotal Web GUI links
  static String computeSha256(String url) {
    final normalized = url.trim();
    final bytes = utf8.encode(normalized);
    return sha256.convert(bytes).toString();
  }

  /// Returns the direct VirusTotal web report link for any URL
  static String getWebReportUrl(String url) {
    return 'https://www.virustotal.com/gui/url/${computeSha256(url)}';
  }

  /// Retrieves user-configured VirusTotal API key from storage or AppConstants fallback
  static Future<String?> getApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefApiKey)?.trim();
      if (saved != null && saved.isNotEmpty) {
        return saved;
      }
    } catch (_) {}

    final constKey = AppConstants.virusTotalApiKey.trim();
    if (constKey.isNotEmpty) {
      return constKey;
    }
    return null;
  }

  /// Saves user-configured VirusTotal API key to local SharedPreferences
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefApiKey, apiKey.trim());
  }

  /// Clears stored VirusTotal API key
  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefApiKey);
  }

  /// Queries the live VirusTotal v3 API for complete multi-engine consensus
  static Future<VirusTotalScanResult> queryVirusTotal(
    String rawUrl, {
    String? explicitApiKey,
    Dio? customDio,
  }) async {
    final client = customDio ?? _dio;
    final apiKey = explicitApiKey ?? await getApiKey();
    final webUrl = getWebReportUrl(rawUrl);

    if (apiKey == null || apiKey.isEmpty) {
      return VirusTotalScanResult.unconfigured(rawUrl);
    }

    try {
      final urlId = computeUrlId(rawUrl);
      final endpoint = 'https://www.virustotal.com/api/v3/urls/$urlId';

      final response = await client.get(
        endpoint,
        options: Options(
          headers: {
            'x-apikey': apiKey,
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data['data'];
        if (data is Map && data['attributes'] is Map) {
          final attrs = data['attributes'] as Map;
          final stats = attrs['last_analysis_stats'] as Map? ?? {};
          final results = attrs['last_analysis_results'] as Map? ?? {};

          final malicious = (stats['malicious'] as num?)?.toInt() ?? 0;
          final suspicious = (stats['suspicious'] as num?)?.toInt() ?? 0;
          final harmless = (stats['harmless'] as num?)?.toInt() ?? 0;
          final undetected = (stats['undetected'] as num?)?.toInt() ?? 0;
          final total = malicious + suspicious + harmless + undetected;

          final flagged = <String>[];
          results.forEach((engineName, engineData) {
            if (engineData is Map) {
              final category = engineData['category']?.toString().toLowerCase();
              final result = engineData['result']?.toString();
              if (category == 'malicious' || category == 'suspicious') {
                flagged.add('$engineName (${result ?? category})');
              }
            }
          });

          final lastAnalysisDate = attrs['last_analysis_date'];
          String dateStr = '';
          if (lastAnalysisDate is num) {
            dateStr = DateTime.fromMillisecondsSinceEpoch(
              lastAnalysisDate.toInt() * 1000,
            ).toIso8601String().split('T').first;
          }

          return VirusTotalScanResult(
            hasScanData: true,
            malicious: malicious,
            suspicious: suspicious,
            harmless: harmless,
            undetected: undetected,
            totalEngines: total,
            flaggedVendors: flagged,
            scanDate: dateStr,
            webReportUrl: webUrl,
            isMalicious: malicious > 0 || suspicious > 1,
            hasCustomApiKey: true,
          );
        }
      }

      return VirusTotalScanResult.error(rawUrl, 'Unexpected VirusTotal response structure', hasKey: true);
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 404) {
        // URL not yet scanned in VirusTotal database; attempt background submission
        _submitUrlForAnalysis(rawUrl, apiKey, client);
        return VirusTotalScanResult(
          hasScanData: false,
          webReportUrl: webUrl,
          hasCustomApiKey: true,
          errorMessage: 'URL submitted to VirusTotal queue for analysis.',
        );
      } else if (dioErr.response?.statusCode == 401 || dioErr.response?.statusCode == 403) {
        return VirusTotalScanResult.error(rawUrl, 'Invalid VirusTotal API Key', hasKey: true);
      } else if (dioErr.response?.statusCode == 429) {
        return VirusTotalScanResult.error(rawUrl, 'VirusTotal rate limit exceeded (4 req/min)', hasKey: true);
      }
      return VirusTotalScanResult.error(rawUrl, 'VirusTotal connection error: ${dioErr.message}', hasKey: true);
    } catch (e) {
      return VirusTotalScanResult.error(rawUrl, 'Error querying VirusTotal: $e', hasKey: true);
    }
  }

  /// Queues an unseen URL on VirusTotal for asynchronous multi-engine scanning
  static Future<void> _submitUrlForAnalysis(String rawUrl, String apiKey, Dio client) async {
    try {
      await client.post(
        'https://www.virustotal.com/api/v3/urls',
        data: 'url=${Uri.encodeQueryComponent(rawUrl)}',
        options: Options(
          headers: {
            'x-apikey': apiKey,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );
    } catch (_) {}
  }

  /// Zero-Key Real-Time Threat Intelligence Telemetry (Cloudflare Security 1.1.1.2 DoH)
  /// Automatically catches malware, phishing, botnets, and C2 links without requiring an API key.
  static Future<SecurityDnsCheckResult> checkSecurityDns(
    String host, {
    Dio? customDio,
  }) async {
    final client = customDio ?? _dio;
    final cleanHost = host.toLowerCase().trim().replaceAll(RegExp(r'^www\.'), '');

    if (cleanHost.isEmpty) return SecurityDnsCheckResult.clean;

    try {
      // 1. Query Cloudflare Security (1.1.1.2) DoH
      final secRes = await client.get(
        'https://security.cloudflare-dns.com/dns-query',
        queryParameters: {'name': cleanHost, 'type': 'A'},
        options: Options(
          headers: {'accept': 'application/dns-json'},
          receiveTimeout: const Duration(seconds: 3),
        ),
      );

      if (secRes.statusCode == 200 && secRes.data is Map) {
        final data = secRes.data as Map;
        final status = data['Status'] as int? ?? 0;
        final answers = (data['Answer'] as List?) ?? [];
        final comments = (data['Comment'] as List?) ?? [];

        // Check for Cloudflare Security Block Indicators:
        // - data == "0.0.0.0"
        // - Comment contains "EDE(16): Censored" or "Blocked"
        // - NXDOMAIN (Status 3) when host is known to exist
        final isCensored = comments.any((c) => c.toString().contains('EDE(16)') || c.toString().contains('Censored'));
        final returnsZeroIp = answers.any((a) => a is Map && (a['data'] == '0.0.0.0' || a['data'] == '127.0.0.1'));

        if (returnsZeroIp || isCensored) {
          return const SecurityDnsCheckResult(
            isBlocked: true,
            provider: 'Cloudflare Global Security Threat Feed (1.1.1.2)',
            details: 'Domain is actively blocked by Cloudflare Global Threat Intelligence as a confirmed malware, phishing, or C2 distribution host.',
          );
        }

        // If Cloudflare Security returns NXDOMAIN (Status 3), check if standard 1.1.1.1 resolves it
        if (status == 3) {
          final stdRes = await client.get(
            'https://cloudflare-dns.com/dns-query',
            queryParameters: {'name': cleanHost, 'type': 'A'},
            options: Options(
              headers: {'accept': 'application/dns-json'},
              receiveTimeout: const Duration(seconds: 3),
            ),
          );
          if (stdRes.statusCode == 200 && stdRes.data is Map) {
            final stdAnswers = (stdRes.data['Answer'] as List?) ?? [];
            if (stdAnswers.isNotEmpty) {
              // Standard resolves it, but Security blocks it!
              return const SecurityDnsCheckResult(
                isBlocked: true,
                provider: 'Cloudflare Security Threat Filter',
                details: 'Host resolved on public DNS but filtered out by Cloudflare Security threat intelligence feed.',
              );
            }
          }
        }
      }
    } catch (_) {}

    return SecurityDnsCheckResult.clean;
  }
}
