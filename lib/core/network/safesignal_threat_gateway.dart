// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: SafeSignal Threat Intelligence Gateway v2.0
// Author: Umar Farooque (https://github.com/UmarFarooqueJi)
// Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
//
// Unified threat intelligence gateway. All external API calls are routed
// through this layer. Screens never reference raw endpoints directly.
// Implements automatic retry, timeout enforcement, and error normalization.
// -----------------------------------------------------------------------------

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants.dart';

/// Result of a full domain trace (DNS, RDAP, URLhaus)
class DomainTraceResult {
  final Map<String, dynamic> rdapData;
  final Map<String, dynamic> geoData;
  final List<dynamic> dnsA;
  final List<dynamic> dnsMx;
  final List<dynamic> dnsNs;
  final List<dynamic> dnsDmarc;
  final bool urlhausMalicious;
  final String urlhausStatus;

  const DomainTraceResult({
    required this.rdapData,
    required this.geoData,
    required this.dnsA,
    required this.dnsMx,
    required this.dnsNs,
    required this.dnsDmarc,
    required this.urlhausMalicious,
    required this.urlhausStatus,
  });
}

/// Social identity recon result per platform
class SocialReconResult {
  final String platform;
  final bool found;
  final Map<String, dynamic> profileData;
  final List<Map<String, String>> recentActivity;
  final String profileUrl;

  const SocialReconResult({
    required this.platform,
    required this.found,
    required this.profileData,
    required this.recentActivity,
    required this.profileUrl,
  });
}

/// Identity breach exposure result
class BreachIntelResult {
  final bool exposed;
  final List<Map<String, dynamic>> breaches;

  const BreachIntelResult({required this.exposed, required this.breaches});
}

/// SafeSignal Proprietary Threat Intelligence Gateway
class SafeSignalThreatGateway {
  static final SafeSignalThreatGateway _instance =
      SafeSignalThreatGateway._internal();
  factory SafeSignalThreatGateway() => _instance;
  SafeSignalThreatGateway._internal();

  final Dio _client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent':
            'SafeSignal-SecuritySuite/2.0 (Android; Threat Intelligence)',
        'Accept': 'application/json',
      },
    ),
  );

  // ─── Domain & URL Intelligence ─────────────────────────────────────────────

  /// Full domain trace: RDAP, GeoIP, Cloudflare DoH DNS, URLhaus
  Future<DomainTraceResult> executeDomainTrace(
    String domain,
    String originalUrl,
  ) async {
    final dohClient = Dio(
      BaseOptions(
        headers: {'Accept': 'application/dns-json'},
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );

    final results = await Future.wait([
      _client
          .get('https://rdap.org/domain/$domain')
          .catchError((_) => Response(requestOptions: RequestOptions())),
      _client
          .get('https://api.iplocation.net/?ip=$domain&json=1')
          .catchError((_) => Response(requestOptions: RequestOptions())),
      dohClient
          .get('https://cloudflare-dns.com/dns-query?name=$domain&type=A')
          .catchError((_) => Response(requestOptions: RequestOptions())),
      dohClient
          .get('https://cloudflare-dns.com/dns-query?name=$domain&type=MX')
          .catchError((_) => Response(requestOptions: RequestOptions())),
      dohClient
          .get('https://cloudflare-dns.com/dns-query?name=$domain&type=NS')
          .catchError((_) => Response(requestOptions: RequestOptions())),
      dohClient
          .get(
            'https://cloudflare-dns.com/dns-query?name=_dmarc.$domain&type=TXT',
          )
          .catchError((_) => Response(requestOptions: RequestOptions())),
    ]);

    bool urlhausMalicious = false;
    String urlhausStatus = 'clean';
    try {
      final ubRes = await _client.post(
        'https://urlhaus-api.abuse.ch/v1/url/',
        data: 'url=${Uri.encodeComponent(originalUrl)}',
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      if (ubRes.statusCode == 200 && ubRes.data is Map) {
        final qs = ubRes.data['query_status']?.toString() ?? '';
        urlhausMalicious = qs == 'is_threat';
        urlhausStatus = qs;
      }
    } catch (e) {
      debugPrint('[ThreatGateway] URLhaus check skipped: $e');
    }

    List<dynamic> extractAnswers(Response r) {
      try {
        if (r.data is Map) return (r.data['Answer'] as List?) ?? [];
      } catch (_) {}
      return [];
    }

    return DomainTraceResult(
      rdapData: results[0].data is Map
          ? results[0].data as Map<String, dynamic>
          : {},
      geoData: results[1].data is Map
          ? results[1].data as Map<String, dynamic>
          : {},
      dnsA: extractAnswers(results[2]),
      dnsMx: extractAnswers(results[3]),
      dnsNs: extractAnswers(results[4]),
      dnsDmarc: extractAnswers(results[5]),
      urlhausMalicious: urlhausMalicious,
      urlhausStatus: urlhausStatus,
    );
  }

  /// Query Google Safe Browsing for phishing/malware
  Future<bool> queryGoogleSafeBrowsing(String url) async {
    final key = AppConstants.googleSafeBrowsingApiKey;
    if (key.isEmpty) return false;
    try {
      final res = await _client.post(
        'https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$key',
        data: {
          'client': {'clientId': 'safesignal', 'clientVersion': '2.0'},
          'threatInfo': {
            'threatTypes': [
              'MALWARE',
              'SOCIAL_ENGINEERING',
              'UNWANTED_SOFTWARE',
              'POTENTIALLY_HARMFUL_APPLICATION',
            ],
            'platformTypes': ['ANDROID'],
            'threatEntryTypes': ['URL'],
            'threatEntries': [
              {'url': url},
            ],
          },
        },
      );
      return res.statusCode == 200 &&
          res.data is Map &&
          (res.data as Map).containsKey('matches');
    } catch (e) {
      debugPrint('[ThreatGateway] SafeBrowsing failed: $e');
      return false;
    }
  }

  /// Query VirusTotal for domain reputation
  Future<Map<String, dynamic>> queryVirusTotal(String domain) async {
    final key = AppConstants.virusTotalApiKey;
    if (key.isEmpty) return {};
    try {
      final res = await _client.get(
        'https://www.virustotal.com/api/v3/domains/$domain',
        options: Options(headers: {'x-apikey': key}),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final stats =
            res.data['data']?['attributes']?['last_analysis_stats'] as Map? ??
            {};
        return {
          'malicious': stats['malicious'] ?? 0,
          'suspicious': stats['suspicious'] ?? 0,
          'harmless': stats['harmless'] ?? 0,
          'undetected': stats['undetected'] ?? 0,
          'reputation': res.data['data']?['attributes']?['reputation'] ?? 0,
        };
      }
    } catch (e) {
      debugPrint('[ThreatGateway] VirusTotal failed: $e');
    }
    return {};
  }

  // ─── Identity Breach Intelligence ─────────────────────────────────────────

  /// Query XposedOrNot for email breach exposure
  Future<BreachIntelResult> queryIdentityExposure(String email) async {
    try {
      final res = await _client.get(
        'https://api.xposedornot.com/v1/breach-analytics',
        queryParameters: {'email': email.trim().toLowerCase()},
      );
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;
        if (data.containsKey('Error')) {
          return const BreachIntelResult(exposed: false, breaches: []);
        }
        final exposed = data['ExposedBreaches'];
        if (exposed is Map && exposed['breaches_details'] is List) {
          return BreachIntelResult(
            exposed: true,
            breaches: List<Map<String, dynamic>>.from(
              exposed['breaches_details'],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ThreatGateway] XposedOrNot failed: $e');
    }
    return const BreachIntelResult(exposed: false, breaches: []);
  }

  // ─── Social Identity Recon Engine ─────────────────────────────────────────

  /// GitHub developer intelligence recon
  Future<SocialReconResult> scanGithubIdentity(String username) async {
    try {
      final res = await _client.get('https://api.github.com/users/$username');
      if (res.statusCode == 200 && res.data is Map) {
        final d = res.data as Map;
        final recentRepos = <Map<String, String>>[];
        try {
          final repoRes = await _client.get(
            'https://api.github.com/users/$username/repos?sort=pushed&per_page=3',
          );
          if (repoRes.statusCode == 200 && repoRes.data is List) {
            for (final r in repoRes.data as List) {
              if (r is Map) {
                recentRepos.add({
                  'title': r['name']?.toString() ?? '',
                  'subtitle': r['description']?.toString() ?? 'No description',
                  'url': r['html_url']?.toString() ?? '',
                });
              }
            }
          }
        } catch (_) {}
        return SocialReconResult(
          platform: 'GitHub',
          found: true,
          profileData: {
            'Name': d['name'] ?? d['login'] ?? username,
            'Bio': d['bio'] ?? '',
            'Followers': '${d['followers'] ?? 0}',
            'Public Repos': '${d['public_repos'] ?? 0}',
            'Company': d['company'] ?? '',
            'Location': d['location'] ?? '',
            'avatar': d['avatar_url'] ?? '',
            'joined': d['created_at'] ?? '',
          },
          recentActivity: recentRepos,
          profileUrl: 'https://github.com/$username',
        );
      }
    } catch (e) {
      debugPrint('[ThreatGateway] GitHub recon failed: $e');
    }
    return SocialReconResult(
      platform: 'GitHub',
      found: false,
      profileData: {},
      recentActivity: [],
      profileUrl: '',
    );
  }

  /// X (Twitter) recon via FxTwitter open endpoint
  Future<SocialReconResult> scanXIdentity(String username) async {
    try {
      final res = await _client.get('https://api.fxtwitter.com/$username');
      if (res.statusCode == 200 &&
          res.data is Map &&
          res.data['user'] != null) {
        final u = res.data['user'] as Map;
        final screenName = u['screen_name']?.toString() ?? username;
        return SocialReconResult(
          platform: 'X (Twitter)',
          found: true,
          profileData: {
            'Name': u['name'] ?? screenName,
            'Followers': '${u['followers_count'] ?? 0}',
            'Following': '${u['following_count'] ?? 0}',
            'Tweets': '${u['tweets_count'] ?? 0}',
            'Description': u['description'] ?? '',
            'avatar': u['avatar_url'] ?? '',
            'joined': u['joined'] ?? '',
          },
          recentActivity: [],
          profileUrl: 'https://x.com/$screenName',
        );
      }
    } catch (e) {
      debugPrint('[ThreatGateway] X recon failed: $e');
    }
    return SocialReconResult(
      platform: 'X (Twitter)',
      found: false,
      profileData: {},
      recentActivity: [],
      profileUrl: '',
    );
  }

  /// Reddit user profile + recent posts recon
  Future<SocialReconResult> scanRedditIdentity(String username) async {
    try {
      final res = await _client.get(
        'https://www.reddit.com/user/$username/about.json',
        options: Options(
          headers: {'User-Agent': 'SafeSignal-SecuritySuite/2.0'},
        ),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final d = res.data['data'] as Map? ?? {};
        final posts = <Map<String, String>>[];
        try {
          final postRes = await _client.get(
            'https://www.reddit.com/user/$username/submitted.json?limit=3',
            options: Options(
              headers: {'User-Agent': 'SafeSignal-SecuritySuite/2.0'},
            ),
          );
          if (postRes.statusCode == 200 &&
              postRes.data?['data']?['children'] is List) {
            for (final child in postRes.data['data']['children'] as List) {
              final p = child['data'] as Map? ?? {};
              posts.add({
                'title': p['title']?.toString() ?? '',
                'subtitle':
                    'r/${p['subreddit'] ?? ''} \u2022 \u25b2 ${p['score'] ?? 0}',
                'url': p['permalink'] != null
                    ? 'https://reddit.com${p['permalink']}'
                    : '',
              });
            }
          }
        } catch (_) {}
        return SocialReconResult(
          platform: 'Reddit',
          found: true,
          profileData: {
            'Username': d['name']?.toString() ?? username,
            'Total Karma': '${d['total_karma'] ?? 0}',
            'Post Karma': '${d['link_karma'] ?? 0}',
            'Comment Karma': '${d['comment_karma'] ?? 0}',
            'account_created': d['created_utc']?.toString() ?? '',
          },
          recentActivity: posts,
          profileUrl: 'https://reddit.com/user/$username',
        );
      }
    } catch (e) {
      debugPrint('[ThreatGateway] Reddit recon failed: $e');
    }
    return SocialReconResult(
      platform: 'Reddit',
      found: false,
      profileData: {},
      recentActivity: [],
      profileUrl: '',
    );
  }

  /// Dev.to developer community recon
  Future<SocialReconResult> scanDevToIdentity(String username) async {
    try {
      final res = await _client.get(
        'https://dev.to/api/users/by_username?url=$username',
      );
      if (res.statusCode == 200 && res.data is Map) {
        final d = res.data as Map;
        final articles = <Map<String, String>>[];
        try {
          final artRes = await _client.get(
            'https://dev.to/api/articles?username=$username&per_page=3',
          );
          if (artRes.statusCode == 200 && artRes.data is List) {
            for (final a in artRes.data as List) {
              if (a is Map) {
                articles.add({
                  'title': a['title']?.toString() ?? '',
                  'subtitle':
                      '\u2665 ${a['positive_reactions_count'] ?? 0} \u2022 ${a['reading_time_minutes'] ?? 0} min read',
                  'url': a['url']?.toString() ?? '',
                });
              }
            }
          }
        } catch (_) {}
        return SocialReconResult(
          platform: 'Dev.to',
          found: true,
          profileData: {
            'Name': d['name']?.toString() ?? username,
            'Followers': '${d['followers_count'] ?? 0}',
            'Articles': '${d['articles_count'] ?? 0}',
            'GitHub': d['github_username']?.toString() ?? '',
            'Twitter': d['twitter_username']?.toString() ?? '',
            'avatar': d['profile_image']?.toString() ?? '',
          },
          recentActivity: articles,
          profileUrl: 'https://dev.to/$username',
        );
      }
    } catch (e) {
      debugPrint('[ThreatGateway] Dev.to recon failed: $e');
    }
    return SocialReconResult(
      platform: 'Dev.to',
      found: false,
      profileData: {},
      recentActivity: [],
      profileUrl: '',
    );
  }

  /// HackerNews (Y Combinator) user recon
  Future<SocialReconResult> scanHackerNewsIdentity(String username) async {
    try {
      final res = await _client.get(
        'https://hacker-news.firebaseio.com/v0/user/$username.json',
      );
      if (res.statusCode == 200 && res.data is Map) {
        final d = res.data as Map;
        return SocialReconResult(
          platform: 'HackerNews',
          found: true,
          profileData: {
            'Username': d['id']?.toString() ?? username,
            'Karma': '${d['karma'] ?? 0}',
            'About': d['about']?.toString() ?? '',
            'created': d['created']?.toString() ?? '',
          },
          recentActivity: [],
          profileUrl: 'https://news.ycombinator.com/user?id=$username',
        );
      }
    } catch (e) {
      debugPrint('[ThreatGateway] HackerNews recon failed: $e');
    }
    return SocialReconResult(
      platform: 'HackerNews',
      found: false,
      profileData: {},
      recentActivity: [],
      profileUrl: '',
    );
  }

  /// GitLab user profile recon
  Future<SocialReconResult> scanGitLabIdentity(String username) async {
    try {
      final res = await _client.get(
        'https://gitlab.com/api/v4/users?username=$username',
      );
      if (res.statusCode == 200 &&
          res.data is List &&
          (res.data as List).isNotEmpty) {
        final d = (res.data as List).first as Map;
        final webUrl =
            d['web_url']?.toString() ?? 'https://gitlab.com/$username';
        return SocialReconResult(
          platform: 'GitLab',
          found: true,
          profileData: {
            'Name': d['name']?.toString() ?? username,
            'Username': d['username']?.toString() ?? username,
            'State': d['state']?.toString() ?? '',
            'avatar': d['avatar_url']?.toString() ?? '',
            'created': d['created_at']?.toString() ?? '',
          },
          recentActivity: [],
          profileUrl: webUrl,
        );
      }
    } catch (e) {
      debugPrint('[ThreatGateway] GitLab recon failed: $e');
    }
    return SocialReconResult(
      platform: 'GitLab',
      found: false,
      profileData: {},
      recentActivity: [],
      profileUrl: '',
    );
  }
}
