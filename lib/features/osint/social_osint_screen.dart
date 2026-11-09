// SafeSignal Mobile Security Suite
// Module: Digital OSINT Suite (Username & Visual Reverse Search)
// Author: Umar Farooque (https://github.com/UmarFarooqueJi)
// Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/services/phone_breach_service.dart';

enum _OsintTab { username, phone }

class SocialOsintScreen extends StatefulWidget {
  final int initialTab;
  const SocialOsintScreen({super.key, this.initialTab = 0});

  @override
  State<SocialOsintScreen> createState() => _SocialOsintScreenState();
}

enum _ScanState { idle, scanning, done, error }

class OsintPost {
  final String title;
  final String? url;
  final String? subtitle;
  final String? date;

  const OsintPost({required this.title, this.url, this.subtitle, this.date});
}

class OsintProfile {
  final String platform;
  final String
  category; // 'Social Network', 'Microblogging', 'Code & DevOps', 'Discussions', etc.
  final String profileUrl;
  final IconData icon;
  final Color brandColor;
  final bool isFound;
  final String? avatarUrl;
  final String? displayName;
  final String? handle;
  final String? bio;
  final Map<String, String> stats;
  final String? createdDate;
  final List<OsintPost> recentPosts;

  const OsintProfile({
    required this.platform,
    required this.category,
    required this.profileUrl,
    required this.icon,
    required this.brandColor,
    required this.isFound,
    this.avatarUrl,
    this.displayName,
    this.handle,
    this.bio,
    this.stats = const {},
    this.createdDate,
    this.recentPosts = const [],
  });
}

class _SocialOsintScreenState extends State<SocialOsintScreen> {
  late _OsintTab _activeTab;

  final _controller = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneService = PhoneBreachService();

  bool _isPhoneScanning = false;
  String _phoneScanStep = '';
  PhoneIntelligenceResult? _phoneResult;
  String _selectedCountryCode = '+91';

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 7),
      receiveTimeout: const Duration(seconds: 7),
      validateStatus: (s) => s != null && s < 500,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/html, */*',
      },
    ),
  );

  _ScanState _state = _ScanState.idle;
  String _activeQuery = '';
  List<OsintProfile> _foundProfiles = [];
  List<OsintProfile> _unconfirmedLinks = [];
  String _currentStep = '';

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab == 1 ? _OsintTab.phone : _OsintTab.username;
  }

  @override
  void dispose() {
    _controller.dispose();
    _phoneController.dispose();
    _dio.close();
    super.dispose();
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12, color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    _showToast('$label copied to clipboard');
  }

  Future<void> _scanPhone([String? sampleNumber]) async {
    final query = (sampleNumber ?? _phoneController.text).trim();
    if (query.isEmpty) {
      _showToast('Please enter a phone number to scan');
      return;
    }

    if (sampleNumber != null) {
      _phoneController.text = sampleNumber;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    setState(() {
      _isPhoneScanning = true;
      _phoneResult = null;
      _phoneScanStep = 'Parsing E.164 syntax & routing telecom telemetry...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 140));
      if (mounted) setState(() => _phoneScanStep = 'Resolving DoT NNP carrier & circle allocation series...');

      await Future.delayed(const Duration(milliseconds: 140));
      if (mounted) setState(() => _phoneScanStep = 'Auditing dark-web CAF leaks & breach databases...');

      await Future.delayed(const Duration(milliseconds: 140));
      if (mounted) setState(() => _phoneScanStep = 'Resolving UPI banking VPAs & fraud radar score...');

      final fullNumber = query.startsWith('+') ? query : '$_selectedCountryCode$query';
      final res = await _phoneService.scanPhoneNumber(fullNumber);

      if (mounted) {
        setState(() {
          _phoneResult = res;
          _isPhoneScanning = false;
          _phoneScanStep = '';
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPhoneScanning = false;
          _phoneScanStep = '';
        });
        _showToast('Phone recon error: $e');
      }
    }
  }

  void _exportPhoneIntelligenceReport() {
    if (_phoneResult == null) return;
    final r = _phoneResult!;
    final buffer = StringBuffer();
    buffer.writeln('====================================================');
    buffer.writeln('SAFESIGNAL TITAN TELECOM & PHONE OSINT INTELLIGENCE REPORT');
    buffer.writeln('Target Number: ${r.formattedNumber}');
    buffer.writeln('====================================================\n');
    buffer.writeln('1. TELECOM NETWORK TELEMETRY');
    buffer.writeln('Carrier    : ${r.carrier} (Allocated: ${r.allocatedCarrier ?? r.carrier})');
    buffer.writeln('Circle/LSA : ${r.circle}');
    buffer.writeln('Line Type  : ${r.telemetry.lineType}');
    buffer.writeln('Series Era : ${r.seriesEraLabel}');
    buffer.writeln('DND Status : ${r.telemetry.dndStatus}');
    buffer.writeln('MNC/MCC    : ${r.telemetry.mncMcc}\n');
    buffer.writeln('2. SPAM & FRAUD CLASSIFICATION');
    buffer.writeln('Threat Score: ${r.spam.spamScore}/100 (${r.spam.threatLevel})');
    buffer.writeln('Category    : ${r.spam.category}');
    buffer.writeln('Abuse Tags  : ${r.spam.tags.join(", ")}');
    buffer.writeln('Advisory    : ${r.spam.advisorySummary}\n');
    if (r.upiFootprints.isNotEmpty) {
      buffer.writeln('3. UPI BANKING RAIL RESOLUTION (REVERSE IDENTITY)');
      for (final upi in r.upiFootprints) {
        buffer.writeln('- [${upi.appName}] ${upi.vpa} (${upi.bankName})');
      }
      buffer.writeln('');
    }
    buffer.writeln('4. DARK-WEB BREACH EXPOSURES (${r.breaches.length})');
    for (final b in r.breaches) {
      buffer.writeln('- [${b.severity}] ${b.title} (${b.breachDate}): ${b.dataClasses.join(", ")}');
    }
    if (r.leakedDossier != null) {
      final d = r.leakedDossier!;
      buffer.writeln('\n5. LEAKED CAF DOSSIER ARCHIVE');
      buffer.writeln('Subscriber : ${d.subscriberName}');
      buffer.writeln('Father     : ${d.fatherName}');
      buffer.writeln('Billing Add: ${d.rawCafAddress}');
      buffer.writeln('Alternate  : ${d.alternateNumber}');
    }
    buffer.writeln('\n====================================================');
    buffer.writeln('Report this evidence to National Cyber Crime Portal (1930 / cybercrime.gov.in)');

    _copyToClipboard(buffer.toString(), 'Phone Intelligence Report');
  }

  void _setStep(String step) {
    if (mounted) setState(() => _currentStep = step);
  }

  String _cleanHtml(String text) {
    return text
        .replaceAll('&#064;', '@')
        .replaceAll('&amp;', '&')
        .replaceAll('&#x2022;', '•')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  String _formatCount(dynamic val) {
    if (val == null) return '0';
    int n = 0;
    if (val is int) {
      n = val;
    } else {
      n = int.tryParse(val.toString()) ?? 0;
    }
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }

  Future<void> _startScan([String? query]) async {
    final raw = (query ?? _controller.text).trim().replaceAll('@', '');
    if (raw.isEmpty) return;

    if (query != null) {
      _controller.text = query;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _activeQuery = raw;
      _state = _ScanState.scanning;
      _foundProfiles = [];
      _unconfirmedLinks = [];
      _currentStep = 'Initializing deep OSINT recon...';
    });

    try {
      _setStep('Interrogating top social & developer networks...');

      // Concurrently query multi-platform public intelligence endpoints
      final results = await Future.wait([
        _scanInstagram(raw),
        _scanXTwitter(raw),
        _scanThreads(raw),
        _scanYouTube(raw),
        _scanTelegram(raw),
        _scanGitHub(raw),
        _scanReddit(raw),
        _scanDevTo(raw),
        _scanHackerNews(raw),
        _scanChessCom(raw),
        _scanGitLab(raw),
      ]);

      final found = results
          .whereType<OsintProfile>()
          .where((p) => p.isFound)
          .toList();

      // Sort with top social & community networks prioritized
      found.sort((a, b) {
        final order = [
          'Instagram',
          'X (Twitter)',
          'Threads',
          'YouTube',
          'Telegram',
          'GitHub',
          'Reddit',
          'Dev.to',
          'Hacker News (YC)',
          'Chess.com',
          'GitLab',
        ];
        final aIdx = order.indexOf(a.platform);
        final bIdx = order.indexOf(b.platform);
        return (aIdx == -1 ? 99 : aIdx).compareTo(bIdx == -1 ? 99 : bIdx);
      });

      _setStep('Compiling digital footprint matrix...');
      final unconfirmed = _generateUnconfirmedLinks(
        raw,
        found.map((f) => f.platform).toSet(),
      );

      setState(() {
        _foundProfiles = found;
        _unconfirmedLinks = unconfirmed;
        _state = _ScanState.done;
      });
    } catch (e) {
      debugPrint('OSINT Scan error: $e');
      setState(() => _state = _ScanState.error);
    }
  }

  // ─── 1. Instagram Recon ─────────────────────────────────────────────────────
  Future<OsintProfile?> _scanInstagram(String user) async {
    try {
      final res = await _dio.get(
        'https://www.instagram.com/$user/',
        options: Options(
          headers: {
            'User-Agent':
                'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );
      final body = res.data?.toString() ?? '';
      if (body.isEmpty || res.statusCode == 404) return null;

      final descMatch = RegExp(
        r'<meta property="og:description" content="([^"]+)"',
      ).firstMatch(body);
      final titleMatch = RegExp(
        r'<meta property="og:title" content="([^"]+)"',
      ).firstMatch(body);
      final imgMatch = RegExp(
        r'<meta property="og:image" content="([^"]+)"',
      ).firstMatch(body);

      final rawDesc = descMatch?.group(1) ?? '';
      final rawTitle = titleMatch?.group(1) ?? '';
      String? avatar = imgMatch?.group(1);
      if (avatar != null) {
        avatar = avatar.replaceAll('&amp;', '&');
      }

      // Check if user actually exists on Instagram
      if (rawDesc.contains('Followers') ||
          rawTitle.contains('Instagram photos and videos')) {
        String name = user;
        final nameMatch = RegExp(
          r'^(.*?)\s*\((\@|\&#064;)',
          caseSensitive: false,
        ).firstMatch(rawTitle);
        if (nameMatch != null && nameMatch.group(1)!.trim().isNotEmpty) {
          name = _cleanHtml(nameMatch.group(1)!);
        }

        final statsMap = <String, String>{};
        final statsRegex = RegExp(
          r'([0-9.,KMBkmb]+)\s+Followers,\s+([0-9.,KMBkmb]+)\s+Following,\s+([0-9.,KMBkmb]+)\s+Posts',
        );
        final m = statsRegex.firstMatch(rawDesc);
        if (m != null) {
          statsMap['Followers'] = m.group(1)!;
          statsMap['Following'] = m.group(2)!;
          statsMap['Posts'] = m.group(3)!;
        }

        return OsintProfile(
          platform: 'Instagram',
          category: 'Social Media & Photos',
          profileUrl: 'https://www.instagram.com/$user/',
          icon: Icons.camera_alt_rounded,
          brandColor: const Color(0xFFE1306C),
          isFound: true,
          avatarUrl: avatar,
          displayName: name,
          handle: '@$user',
          bio: 'Verified active Instagram profile account.',
          stats: statsMap,
        );
      }
    } catch (_) {}
    return null;
  }

  // ─── 2. X / Twitter Recon ───────────────────────────────────────────────────
  Future<OsintProfile?> _scanXTwitter(String user) async {
    try {
      final res = await _dio.get('https://api.fxtwitter.com/$user');
      if (res.statusCode == 200 &&
          res.data is Map &&
          res.data['user'] != null) {
        final u = res.data['user'] as Map;
        final name = u['name']?.toString() ?? user;
        final screenName = u['screen_name']?.toString() ?? user;
        String? avatar = u['avatar_url']?.toString();
        if (avatar != null && avatar.contains('_normal')) {
          avatar = avatar.replaceAll('_normal', '_400x400');
        }
        final desc = u['description']?.toString();
        final followers = _formatCount(u['followers']);
        final following = _formatCount(u['following']);
        final tweets = _formatCount(u['tweets']);
        final joined = u['joined']?.toString();
        String? memberSince;
        if (joined != null && joined.isNotEmpty) {
          try {
            // "Tue Jun 02 20:12:29 +0000 2009"
            final parts = joined.split(' ');
            if (parts.length >= 6) {
              memberSince = 'Joined ${parts[1]} ${parts[5]}';
            }
          } catch (_) {}
        }

        return OsintProfile(
          platform: 'X (Twitter)',
          category: 'Microblogging & Social',
          profileUrl: 'https://x.com/$screenName',
          icon: Icons.alternate_email_rounded,
          brandColor: Colors.black,
          isFound: true,
          avatarUrl: avatar,
          displayName: name,
          handle: '@$screenName',
          bio: desc != null && desc.isNotEmpty ? desc : null,
          createdDate: memberSince,
          stats: {
            'Followers': followers,
            'Following': following,
            'Posts / Tweets': tweets,
          },
        );
      }
    } catch (_) {}
    return null;
  }

  // ─── 3. Threads Recon ───────────────────────────────────────────────────────
  Future<OsintProfile?> _scanThreads(String user) async {
    try {
      final res = await _dio.get(
        'https://www.threads.net/@$user',
        options: Options(
          headers: {
            'User-Agent':
                'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
          },
        ),
      );
      final body = res.data?.toString() ?? '';
      if (body.isEmpty || res.statusCode == 404) return null;

      final descMatch = RegExp(
        r'<meta property="og:description" content="([^"]+)"',
      ).firstMatch(body);
      final titleMatch = RegExp(
        r'<meta property="og:title" content="([^"]+)"',
      ).firstMatch(body);
      final imgMatch = RegExp(
        r'<meta property="og:image" content="([^"]+)"',
      ).firstMatch(body);

      final rawDesc = descMatch?.group(1) ?? '';
      final rawTitle = titleMatch?.group(1) ?? '';
      String? avatar = imgMatch?.group(1);
      if (avatar != null) {
        avatar = avatar.replaceAll('&amp;', '&');
      }

      if (rawTitle.toLowerCase().contains('threads') ||
          rawDesc.contains('Followers')) {
        String name = user;
        final nameMatch = RegExp(
          r'^(.*?)\s*\((\@|\&#064;)',
          caseSensitive: false,
        ).firstMatch(rawTitle);
        if (nameMatch != null && nameMatch.group(1)!.trim().isNotEmpty) {
          name = _cleanHtml(nameMatch.group(1)!);
        }

        final statsMap = <String, String>{};
        final fMatch = RegExp(
          r'([0-9.,KMBkmb]+)\s+Followers',
        ).firstMatch(rawDesc);
        if (fMatch != null) statsMap['Followers'] = fMatch.group(1)!;

        final thMatch = RegExp(
          r'([0-9.,KMBkmb]+)\s+Threads',
        ).firstMatch(rawDesc);
        if (thMatch != null) statsMap['Threads'] = thMatch.group(1)!;

        return OsintProfile(
          platform: 'Threads',
          category: 'Social Conversations',
          profileUrl: 'https://www.threads.net/@$user',
          icon: Icons.alternate_email_rounded,
          brandColor: const Color(0xFF101010),
          isFound: true,
          avatarUrl: avatar,
          displayName: name,
          handle: '@$user',
          bio: _cleanHtml(rawDesc),
          stats: statsMap,
        );
      }
    } catch (_) {}
    return null;
  }

  // ─── 4. YouTube Channel Recon ───────────────────────────────────────────────
  Future<OsintProfile?> _scanYouTube(String user) async {
    try {
      final res = await _dio.get('https://www.youtube.com/@$user');
      final body = res.data?.toString() ?? '';
      if (body.isEmpty || res.statusCode == 404) return null;

      final titleMatch = RegExp(
        r'<meta property="og:title" content="([^"]+)"',
      ).firstMatch(body);
      final descMatch = RegExp(
        r'<meta property="og:description" content="([^"]+)"',
      ).firstMatch(body);
      final imgMatch = RegExp(
        r'<meta property="og:image" content="([^"]+)"',
      ).firstMatch(body);

      final title = titleMatch?.group(1);
      final desc = descMatch?.group(1);
      final img = imgMatch?.group(1);

      if (title != null &&
          !title.toLowerCase().contains('404 not found') &&
          !title.toLowerCase().contains('youtube')) {
        return OsintProfile(
          platform: 'YouTube',
          category: 'Video & Streaming',
          profileUrl: 'https://www.youtube.com/@$user',
          icon: Icons.play_circle_fill_rounded,
          brandColor: const Color(0xFFFF0000),
          isFound: true,
          avatarUrl: img,
          displayName: _cleanHtml(title),
          handle: '@$user',
          bio: desc != null && desc.isNotEmpty ? _cleanHtml(desc) : null,
          stats: {'Status': 'Public Channel'},
        );
      }
    } catch (_) {}
    return null;
  }

  // ─── 5. Telegram Recon ──────────────────────────────────────────────────────
  Future<OsintProfile?> _scanTelegram(String user) async {
    try {
      final res = await _dio.get('https://t.me/$user');
      final body = res.data?.toString() ?? '';
      if (body.contains('tgme_page_title') ||
          body.contains('tgme_page_photo')) {
        final tMatch = RegExp(
          r'<meta property="og:title" content="([^"]+)"',
        ).firstMatch(body);
        final dMatch = RegExp(
          r'<meta property="og:description" content="([^"]+)"',
        ).firstMatch(body);
        final iMatch = RegExp(
          r'<meta property="og:image" content="([^"]+)"',
        ).firstMatch(body);

        final title = tMatch?.group(1);
        final desc = dMatch?.group(1);
        final img = iMatch?.group(1);

        if (title != null &&
            !title.toLowerCase().contains('telegram: contact')) {
          return OsintProfile(
            platform: 'Telegram',
            category: 'Encrypted Messaging',
            profileUrl: 'https://t.me/$user',
            icon: Icons.send_rounded,
            brandColor: const Color(0xFF24A1DE),
            isFound: true,
            displayName: _cleanHtml(title),
            handle: '@$user',
            bio: desc != null ? _cleanHtml(desc) : null,
            avatarUrl: img,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── 6. GitHub Recon ────────────────────────────────────────────────────────
  Future<OsintProfile?> _scanGitHub(String user) async {
    try {
      final res = await _dio.get('https://api.github.com/users/$user');
      if (res.statusCode == 200 && res.data is Map) {
        final d = res.data as Map;
        final name = d['name']?.toString() ?? d['login']?.toString() ?? user;
        final bio = d['bio']?.toString();
        final avatar = d['avatar_url']?.toString();
        final followers = _formatCount(d['followers']);
        final repos = d['public_repos']?.toString() ?? '0';
        final createdAt = d['created_at']?.toString();
        String? joined;
        if (createdAt != null) {
          try {
            joined = DateFormat('MMM yyyy').format(DateTime.parse(createdAt));
          } catch (_) {}
        }

        // Fetch recent repos
        final posts = <OsintPost>[];
        try {
          final repoRes = await _dio.get(
            'https://api.github.com/users/$user/repos?sort=pushed&per_page=3',
          );
          if (repoRes.statusCode == 200 && repoRes.data is List) {
            for (final r in repoRes.data as List) {
              if (r is Map) {
                final rName = r['name']?.toString() ?? 'Repo';
                final rDesc = r['description']?.toString() ?? 'No description';
                final rStars = r['stargazers_count']?.toString() ?? '0';
                final rLang = r['language']?.toString() ?? 'Code';
                final rUrl = r['html_url']?.toString();
                posts.add(
                  OsintPost(
                    title: rName,
                    subtitle: '$rLang • ★ $rStars • $rDesc',
                    url: rUrl,
                  ),
                );
              }
            }
          }
        } catch (_) {}

        return OsintProfile(
          platform: 'GitHub',
          category: 'Code & Repositories',
          profileUrl: 'https://github.com/$user',
          icon: Icons.code_rounded,
          brandColor: const Color(0xFF24292E),
          isFound: true,
          avatarUrl: avatar,
          displayName: name,
          handle: '@$user',
          bio: bio,
          createdDate: joined != null ? 'Joined $joined' : null,
          stats: {'Followers': followers, 'Public Repos': repos},
          recentPosts: posts,
        );
      }
    } catch (_) {}
    return null;
  }

  // ─── 7. Reddit Recon ────────────────────────────────────────────────────────
  Future<OsintProfile?> _scanReddit(String user) async {
    try {
      final res = await _dio.get(
        'https://www.reddit.com/user/$user/about.json',
        options: Options(headers: {'User-Agent': 'SafeSignal-OSINT/2.0'}),
      );
      if (res.statusCode == 200 &&
          res.data is Map &&
          res.data['data'] != null) {
        final d = res.data['data'] as Map;
        final name = d['name']?.toString() ?? user;
        final karma = _formatCount(d['total_karma']);
        final sub = d['subreddit'] as Map?;
        final title = sub?['title']?.toString();
        final publicDesc = sub?['public_description']?.toString();
        String? icon = sub?['icon_img']?.toString();
        if (icon != null && icon.contains('?')) {
          icon = icon.split('?').first;
        }

        final createdUtc = d['created_utc'];
        String? joined;
        if (createdUtc is num) {
          final dt = DateTime.fromMillisecondsSinceEpoch(
            createdUtc.toInt() * 1000,
          );
          joined = DateFormat('MMM yyyy').format(dt);
        }

        // Fetch recent submissions
        final posts = <OsintPost>[];
        try {
          final postRes = await _dio.get(
            'https://www.reddit.com/user/$user/submitted.json?limit=3',
            options: Options(headers: {'User-Agent': 'SafeSignal-OSINT/2.0'}),
          );
          if (postRes.statusCode == 200 &&
              postRes.data is Map &&
              postRes.data['data']?['children'] != null) {
            for (final c in postRes.data['data']['children'] as List) {
              final p = c['data'] as Map?;
              if (p != null) {
                final pTitle = p['title']?.toString() ?? 'Post';
                final pSub =
                    p['subreddit_name_prefixed']?.toString() ?? 'r/reddit';
                final pScore = p['score']?.toString() ?? '0';
                final pPerma = p['permalink']?.toString();
                posts.add(
                  OsintPost(
                    title: pTitle,
                    subtitle: '$pSub • ▲ $pScore upvotes',
                    url: pPerma != null ? 'https://reddit.com$pPerma' : null,
                  ),
                );
              }
            }
          }
        } catch (_) {}

        return OsintProfile(
          platform: 'Reddit',
          category: 'Discussions & Communities',
          profileUrl: 'https://reddit.com/user/$user',
          icon: Icons.forum_rounded,
          brandColor: const Color(0xFFFF4500),
          isFound: true,
          avatarUrl: icon,
          displayName: title != null && title.isNotEmpty ? title : 'u/$name',
          handle: 'u/$name',
          bio: publicDesc,
          createdDate: joined != null ? 'Redditor since $joined' : null,
          stats: {'Karma Score': karma},
          recentPosts: posts,
        );
      }
    } catch (_) {}
    return null;
  }

  // ─── 8. Dev.to Recon ────────────────────────────────────────────────────────
  Future<OsintProfile?> _scanDevTo(String user) async {
    try {
      final res = await _dio.get(
        'https://dev.to/api/users/by_username?url=$user',
      );
      if (res.statusCode == 200 && res.data is Map) {
        final d = res.data as Map;
        final name = d['name']?.toString() ?? user;
        final bio = d['summary']?.toString();
        final avatar = d['profile_image']?.toString();
        final joined = d['joined_at']?.toString();

        final posts = <OsintPost>[];
        try {
          final artRes = await _dio.get(
            'https://dev.to/api/articles?username=$user&per_page=3',
          );
          if (artRes.statusCode == 200 && artRes.data is List) {
            for (final a in artRes.data as List) {
              if (a is Map) {
                final aTitle = a['title']?.toString() ?? 'Article';
                final aReactions =
                    a['positive_reactions_count']?.toString() ?? '0';
                final aUrl = a['url']?.toString();
                posts.add(
                  OsintPost(
                    title: aTitle,
                    subtitle: '❤️ $aReactions reactions',
                    url: aUrl,
                  ),
                );
              }
            }
          }
        } catch (_) {}

        return OsintProfile(
          platform: 'Dev.to Community',
          category: 'Tech Publishing',
          profileUrl: 'https://dev.to/$user',
          icon: Icons.article_rounded,
          brandColor: const Color(0xFF0A0A0A),
          isFound: true,
          avatarUrl: avatar,
          displayName: name,
          handle: '@$user',
          bio: bio,
          createdDate: joined != null ? 'Joined $joined' : null,
          recentPosts: posts,
        );
      }
    } catch (_) {}
    return null;
  }

  // ─── 9. HackerNews Recon ────────────────────────────────────────────────────
  Future<OsintProfile?> _scanHackerNews(String user) async {
    try {
      final res = await _dio.get(
        'https://hacker-news.firebaseio.com/v0/user/$user.json',
      );
      if (res.statusCode == 200 && res.data is Map) {
        final d = res.data as Map;
        final karma = d['karma']?.toString() ?? '0';
        final about = d['about']?.toString();
        final created = d['created'];
        String? joined;
        if (created is num) {
          final dt = DateTime.fromMillisecondsSinceEpoch(
            created.toInt() * 1000,
          );
          joined = DateFormat('MMM yyyy').format(dt);
        }

        return OsintProfile(
          platform: 'Hacker News (YC)',
          category: 'Tech & Startups',
          profileUrl: 'https://news.ycombinator.com/user?id=$user',
          icon: Icons.newspaper_rounded,
          brandColor: const Color(0xFFFF6600),
          isFound: true,
          displayName: user,
          handle: 'id: $user',
          bio: about != null ? _cleanHtml(about) : null,
          createdDate: joined != null ? 'Member since $joined' : null,
          stats: {'Karma Score': karma},
        );
      }
    } catch (_) {}
    return null;
  }

  // ─── 10. Chess.com Recon ────────────────────────────────────────────────────
  Future<OsintProfile?> _scanChessCom(String user) async {
    try {
      final res = await _dio.get('https://api.chess.com/pub/player/$user');
      if (res.statusCode == 200 && res.data is Map) {
        final d = res.data as Map;
        final name = d['name']?.toString() ?? d['username']?.toString() ?? user;
        final avatar = d['avatar']?.toString();
        final followers = _formatCount(d['followers']);
        final title = d['title']?.toString();
        final joinedSec = d['joined'];
        String? joined;
        if (joinedSec is num) {
          final dt = DateTime.fromMillisecondsSinceEpoch(
            joinedSec.toInt() * 1000,
          );
          joined = DateFormat('MMM yyyy').format(dt);
        }

        return OsintProfile(
          platform: 'Chess.com',
          category: 'Gaming & Strategy',
          profileUrl: 'https://www.chess.com/member/$user',
          icon: Icons.games_rounded,
          brandColor: const Color(0xFF6DA544),
          isFound: true,
          avatarUrl: avatar,
          displayName: title != null ? '[$title] $name' : name,
          handle: '@$user',
          createdDate: joined != null ? 'Playing since $joined' : null,
          stats: {
            'Followers': followers,
            'Status': d['status']?.toString() ?? 'Active',
          },
        );
      }
    } catch (_) {}
    return null;
  }

  // ─── 11. GitLab Recon ───────────────────────────────────────────────────────
  Future<OsintProfile?> _scanGitLab(String user) async {
    try {
      final res = await _dio.get(
        'https://gitlab.com/api/v4/users?username=$user',
      );
      if (res.statusCode == 200 &&
          res.data is List &&
          (res.data as List).isNotEmpty) {
        final d = (res.data as List).first as Map;
        final name = d['name']?.toString() ?? user;
        final avatar = d['avatar_url']?.toString();
        final bio = d['bio']?.toString();
        final webUrl = d['web_url']?.toString() ?? 'https://gitlab.com/$user';

        return OsintProfile(
          platform: 'GitLab',
          category: 'DevOps & Source Code',
          profileUrl: webUrl,
          icon: Icons.integration_instructions_rounded,
          brandColor: const Color(0xFFFC6D26),
          isFound: true,
          avatarUrl: avatar,
          displayName: name,
          handle: '@$user',
          bio: bio,
        );
      }
    } catch (_) {}
    return null;
  }

  // ─── Generate Remaining Links ───────────────────────────────────────────────
  List<OsintProfile> _generateUnconfirmedLinks(
    String user,
    Set<String> foundPlatforms,
  ) {
    final all = [
      OsintProfile(
        platform: 'TikTok',
        category: 'Short Video',
        profileUrl: 'https://www.tiktok.com/@$user',
        icon: Icons.music_note_rounded,
        brandColor: const Color(0xFF010101),
        isFound: false,
      ),
      OsintProfile(
        platform: 'LinkedIn',
        category: 'Professional Network',
        profileUrl: 'https://www.linkedin.com/in/$user',
        icon: Icons.business_rounded,
        brandColor: const Color(0xFF0077B5),
        isFound: false,
      ),
      OsintProfile(
        platform: 'Pinterest',
        category: 'Visual Boards',
        profileUrl: 'https://www.pinterest.com/$user/',
        icon: Icons.push_pin_rounded,
        brandColor: const Color(0xFFBD081C),
        isFound: false,
      ),
      OsintProfile(
        platform: 'Linktree',
        category: 'Bio Landing Page',
        profileUrl: 'https://linktr.ee/$user',
        icon: Icons.link_rounded,
        brandColor: const Color(0xFF43E660),
        isFound: false,
      ),
      OsintProfile(
        platform: 'Medium',
        category: 'Blogging & Stories',
        profileUrl: 'https://medium.com/@$user',
        icon: Icons.menu_book_rounded,
        brandColor: const Color(0xFF292929),
        isFound: false,
      ),
    ];

    return all
        .where((item) => !foundPlatforms.contains(item.platform))
        .toList();
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF06090F) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 42,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : const Color(0xFF0D1117),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Digital OSINT Suite',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF0D1117),
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _activeTab == _OsintTab.username
                  ? 'Public Handles & Profile Intel'
                  : 'Telecom & UPI Intelligence',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (_activeTab == _OsintTab.phone && _phoneResult != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Export Phone Intelligence Report',
              icon: const Icon(Icons.share_outlined, color: Color(0xFF00E5FF), size: 19),
              onPressed: _exportPhoneIntelligenceReport,
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Clear & Reset',
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white60 : Colors.black54,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                if (_activeTab == _OsintTab.username) {
                  _controller.clear();
                  _state = _ScanState.idle;
                  _foundProfiles.clear();
                  _unconfirmedLinks.clear();
                } else {
                  _phoneController.clear();
                  _phoneResult = null;
                  _isPhoneScanning = false;
                }
              });
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tab Selector
              _buildTabSelector(isDark),
              const SizedBox(height: 18),

              // Username Recon Tab
              if (_activeTab == _OsintTab.username) ...[
                _buildSearchCard(isDark),
                const SizedBox(height: 16),

                if (_state == _ScanState.scanning) _buildScanningProgress(isDark),
                if (_state == _ScanState.error) _buildErrorCard(isDark),
                if (_state == _ScanState.done) ...[
                  _buildExposureSummaryHeader(isDark),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'CONFIRMED PUBLIC PROFILES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2979FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_foundProfiles.length}',
                          style: const TextStyle(
                            color: Color(0xFF2979FF),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_foundProfiles.isEmpty)
                    _buildNoProfilesFoundCard(isDark)
                  else
                    ..._foundProfiles.map((p) => _buildProfileCard(p, isDark)),

                  const SizedBox(height: 24),

                  if (_unconfirmedLinks.isNotEmpty) ...[
                    Text(
                      'ADDITIONAL PLATFORM DIRECT PROBES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to inspect if this handle is registered on other networks.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 14),

                    _buildQuickProbeGrid(isDark),
                    const SizedBox(height: 24),
                  ],

                  _buildThreatInsightCard(isDark),
                  const SizedBox(height: 40),
                ],
              ],

              // Phone Number OSINT Tab
              if (_activeTab == _OsintTab.phone) ...[
                _buildPhoneSearchCard(isDark),
                const SizedBox(height: 16),

                if (_isPhoneScanning) _buildPhoneScanningProgress(isDark),

                if (_phoneResult != null) ...[
                  _buildPhoneResultsSection(_phoneResult!, isDark),
                  const SizedBox(height: 40),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Search Card Widget ─────────────────────────────────────────────────────
  Widget _buildSearchCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2979FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  color: Color(0xFF2979FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Digital Identity Recon',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cross-platform handle & footprint scanner',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (val) => _startScan(val),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Enter username (e.g. uf_times, torvalds)...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: const Icon(
                Icons.alternate_email_rounded,
                color: Color(0xFF2979FF),
              ),
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF2979FF),
                ),
                onPressed: () => _startScan(),
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF0A0E17)
                  : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF232D42)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF232D42)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF2979FF),
                  width: 1.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Example chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Try:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              _buildExampleChip('uf_times', isDark),
              _buildExampleChip('torvalds', isDark),
              _buildExampleChip('spez', isDark),
              _buildExampleChip('carryminati', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExampleChip(String handle, bool isDark) {
    return InkWell(
      onTap: () => _startScan(handle),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '@$handle',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  // ─── Scanning State Card ────────────────────────────────────────────────────
  Widget _buildScanningProgress(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              color: Color(0xFF2979FF),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Reconnaissance in Progress',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currentStep,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2979FF),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Interrogating Instagram, X, Threads, YouTube, GitHub for "@$_activeQuery"...',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  // ─── Exposure Summary (Fixed Overflow) ──────────────────────────────────────
  Widget _buildExposureSummaryHeader(bool isDark) {
    final count = _foundProfiles.length;
    Color levelColor;
    String levelText;
    String desc;

    if (count >= 5) {
      levelColor = const Color(0xFFEF5350);
      levelText = 'HIGH DIGITAL EXPOSURE';
      desc =
          'This handle is indexed across multiple major social & developer platforms. High correlation footprint.';
    } else if (count >= 2) {
      levelColor = const Color(0xFFFFB300);
      levelText = 'MODERATE EXPOSURE';
      desc =
          'Confirmed public accounts found across major social networks and code repositories.';
    } else if (count == 1) {
      levelColor = const Color(0xFF4CAF50);
      levelText = 'LOW / ISOLATED EXPOSURE';
      desc = 'Only one confirmed profile found matching this username.';
    } else {
      levelColor = Colors.grey;
      levelText = 'MINIMAL PUBLIC TRACE';
      desc = 'No confirmed public profiles found matching this handle.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: levelColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: levelColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: levelColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  levelText,
                  style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count Profiles Found',
                  style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  // ─── Profile Card ───────────────────────────────────────────────────────────
  Widget _buildProfileCard(OsintProfile p, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Platform Header Banner
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: p.brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: p.brandColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(p.icon, size: 14, color: p.brandColor),
                    const SizedBox(width: 5),
                    Text(
                      p.platform.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: p.brandColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.category,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Open Link Icon
              InkWell(
                onTap: () => _openUrl(p.profileUrl),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: p.brandColor,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 14,
                        color: p.brandColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // User Info Row: Avatar + Name + Handle
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.brandColor.withValues(alpha: 0.12),
                  border: Border.all(
                    color: p.brandColor.withValues(alpha: 0.35),
                    width: 1.8,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: p.avatarUrl != null && p.avatarUrl!.isNotEmpty
                    ? Image.network(
                        p.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(p.icon, color: p.brandColor, size: 28),
                        ),
                      )
                    : Center(
                        child: Icon(p.icon, color: p.brandColor, size: 28),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.displayName ?? p.platform,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16.5,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF2979FF),
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (p.handle != null)
                      Text(
                        p.handle!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    if (p.createdDate != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            p.createdDate!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Bio / Description
          if (p.bio != null && p.bio!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A0E17)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E2638)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                p.bio!.trim(),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // Stats chips
          if (p.stats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: p.stats.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: p.brandColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: p.brandColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entry.key}: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // Recent Public Posts / Repos
          if (p.recentPosts.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'RECENT POSTS & PUBLIC ARTIFACTS',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 8),
            ...p.recentPosts.map(
              (post) => InkWell(
                onTap: post.url != null ? () => _openUrl(post.url!) : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.arrow_right_rounded,
                          size: 16,
                          color: Color(0xFF2979FF),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.title,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: post.url != null
                                    ? (isDark
                                          ? const Color(0xFF82B1FF)
                                          : const Color(0xFF1565C0))
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (post.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                post.subtitle!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black45,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Quick Probe Grid ───────────────────────────────────────────────────────
  Widget _buildQuickProbeGrid(bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _unconfirmedLinks.length,
      itemBuilder: (context, index) {
        final item = _unconfirmedLinks[index];
        return InkWell(
          onTap: () => _openUrl(item.profileUrl),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131926) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF232D42)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: item.brandColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.platform,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Threat Insight Card ────────────────────────────────────────────────────
  Widget _buildThreatInsightCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.security_update_warning_rounded,
                color: Colors.amber,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'OSINT Hygiene & Defense',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Reusing identical usernames allows scammers to bridge your Instagram photos, X opinions, GitHub commits, and Telegram handle into a targeted spear-phishing profile. For high-risk accounts, use unique pseudonyms and decoupled recovery emails.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoProfilesFoundCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            'No Public Accounts Found on Core Index',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This handle does not appear publicly on Instagram, X, Threads, YouTube, Telegram, or GitHub.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Failed to complete OSINT scan. Check network connection and retry.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Visual OSINT Widgets ───────────────────────────────────────────────────

  Widget _buildTabSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF232D42) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              title: 'Username Recon',
              icon: Icons.person_search_rounded,
              isSelected: _activeTab == _OsintTab.username,
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeTab = _OsintTab.username);
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabItem(
              title: 'Phone Recon',
              icon: Icons.contact_phone_rounded,
              isSelected: _activeTab == _OsintTab.phone,
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeTab = _OsintTab.phone);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2979FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2979FF).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ─── ULTRA-LEVEL PHONE NUMBER OSINT & TELECOM RECON WIDGETS ────────────────
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildPhoneSearchCard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF131926) : Colors.white;
    final borderColor = isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.phone_in_talk_rounded,
                  color: Color(0xFF00E5FF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Global Telecom & Number OSINT',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'E.164 parsing, DoT NNP routing, UPI reverse identity & threat radar',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Country Code Selector Chips
          Text(
            'SELECT JURISDICTION / COUNTRY CODE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCountryChip('+91', '🇮🇳 India', isDark),
                const SizedBox(width: 8),
                _buildCountryChip('+1', '🇺🇸 US/CA', isDark),
                const SizedBox(width: 8),
                _buildCountryChip('+44', '🇬🇧 UK', isDark),
                const SizedBox(width: 8),
                _buildCountryChip('+971', '🇦🇪 UAE', isDark),
                const SizedBox(width: 8),
                _buildCountryChip('+92', '🇵🇰 PK', isDark),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Phone Number Text Field
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _scanPhone(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: 0.5,
            ),
            decoration: InputDecoration(
              hintText: _selectedCountryCode == '+91'
                  ? '98765 43210 or +919876543210'
                  : 'Enter phone number...',
              hintStyle: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.white38 : Colors.black38,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCountryCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 1,
                      height: 20,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ],
                ),
              ),
              suffixIcon: _phoneController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _phoneController.clear();
                        setState(() {});
                      },
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF00E5FF),
                      ),
                      onPressed: () => _scanPhone(),
                    ),
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF00E5FF),
                  width: 1.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Investigative Presets / Sample Numbers
          Text(
            'INVESTIGATIVE BENCHMARKS / THREAT SAMPLES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPhoneQuickSampleChip(
                '🚨 Digital Arrest Scam',
                '9876543210',
                const Color(0xFFFF5252),
                isDark,
                countryCode: '+91',
              ),
              _buildPhoneQuickSampleChip(
                '☁️ Twilio VoIP Threat',
                '+12025550199',
                const Color(0xFFFF9100),
                isDark,
                countryCode: '+1',
              ),
              _buildPhoneQuickSampleChip(
                '🏛️ Clean Enterprise (Jio)',
                '9820012345',
                const Color(0xFF00E676),
                isDark,
                countryCode: '+91',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Scan Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isPhoneScanning ? null : () => _scanPhone(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF06090F),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _isPhoneScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF06090F),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.radar_rounded, size: 18),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Trace Telecom & Threat Identity',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryChip(String code, String label, bool isDark) {
    final isSelected = _selectedCountryCode == code;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedCountryCode = code);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? const Color(0xFF00E5FF)
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneQuickSampleChip(
    String label,
    String number,
    Color color,
    bool isDark, {
    required String countryCode,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedCountryCode = countryCode);
        _scanPhone(number);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneScanningProgress(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Color(0xFF00E5FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _phoneScanStep.isNotEmpty
                      ? _phoneScanStep
                      : 'Querying telecom registries & financial rails...',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00E5FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              backgroundColor: Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ─── PHONE RESULTS COMPREHENSIVE VIEW ─────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildPhoneResultsSection(PhoneIntelligenceResult res, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Executive Telemetry Overview Banner
        _buildExecutiveOverviewBanner(res, isDark),
        const SizedBox(height: 16),

        // 2. Fraud & Spam Classification Radar Card
        _buildSpamRadarCard(res, isDark),
        const SizedBox(height: 16),

        // 3. NPCI UPI Financial Rail Reverse Identity Card
        if (res.upiFootprints.isNotEmpty) ...[
          _buildUpiResolutionCard(res.upiFootprints, isDark),
          const SizedBox(height: 16),
        ],

        // 4. Telecom Telemetry & Infrastructure Card
        _buildTelecomTelemetryCard(res, isDark),
        const SizedBox(height: 16),

        // 5. Live Communication & Investigation Probes
        _buildMessagingProbesCard(res.formattedNumber, isDark),
        const SizedBox(height: 16),

        // 6. Investigative OSINT Dorks
        _buildOsintDorksCard(res.formattedNumber, isDark),
        const SizedBox(height: 16),

        // 7. Dark-Web Breach & CAF Dossier Archive
        _buildBreachAndDossierCard(res, isDark),
      ],
    );
  }

  // ─── 1. Executive Banner ───────────────────────────────────────────────────

  Widget _buildExecutiveOverviewBanner(PhoneIntelligenceResult res, bool isDark) {
    final spam = res.spam;
    final isHighRisk = spam.spamScore >= 60 || res.telemetry.isVoip;
    final isModerate = spam.spamScore >= 30 && spam.spamScore < 60;
    final accentColor = isHighRisk
        ? const Color(0xFFFF5252)
        : (isModerate ? const Color(0xFFFF9100) : const Color(0xFF00E676));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                res.telemetry.countryFlag,
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.formattedNumber,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${res.carrier} • ${res.circle}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy Number',
                onPressed: () => _copyToClipboard(res.formattedNumber, 'Phone number'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              // Threat Score Badge
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isHighRisk
                            ? Icons.warning_rounded
                            : (isModerate ? Icons.info_outline : Icons.shield_rounded),
                        size: 13,
                        color: accentColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${spam.spamScore}/100 ${spam.threatLevel}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Line type chip
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    res.telemetry.lineType,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 2. Spam & Fraud Radar Card ────────────────────────────────────────────

  Widget _buildSpamRadarCard(PhoneIntelligenceResult res, bool isDark) {
    final spam = res.spam;
    final isHigh = spam.spamScore >= 60;
    final color = isHigh
        ? const Color(0xFFFF5252)
        : (spam.spamScore >= 30 ? const Color(0xFFFF9100) : const Color(0xFF00E676));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radar_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SPAM & FRAUD CLASSIFICATION RADAR',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Category & Report Count
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spam.category,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${spam.reportCount} crowdsourced complaints & forensic flags',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      '${spam.spamScore}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    Text(
                      'RISK',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tags
          if (spam.tags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: spam.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Advisory Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    spam.advisorySummary,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Actions: Truecaller & Cybercrime Portal
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.search, size: 14),
                  label: const Text('Truecaller Web', style: TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2979FF),
                    side: const BorderSide(color: Color(0xFF2979FF)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _openUrl(spam.truecallerWebUrl),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.gavel_rounded, size: 14),
                  label: const Text('Report 1930', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5252),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _openUrl(spam.nationalCyberCrimeUrl),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 3. NPCI UPI Financial Rail Reverse Identity Card ──────────────────────

  Widget _buildUpiResolutionCard(List<PhoneUpiFootprint> upiList, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF00E676).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Color(0xFF00E676), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'NPCI UPI REVERSE IDENTITY RESOLUTION',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFF00E676),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${upiList.length} VPAs',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00E676),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Mobile numbers map directly to bank VPAs. Tap "Verify VPA" to trigger a 0-rupee identity check in your banking app to reveal the verified account holder name.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),

          // VPA List
          ...upiList.map((upi) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      size: 18,
                      color: Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          upi.appName,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          upi.vpa,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E5FF),
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          upi.bankName,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: 'Copy VPA',
                    onPressed: () => _copyToClipboard(upi.vpa, '${upi.appName} VPA'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: const Color(0xFF06090F),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _openUrl(upi.deepLink),
                    child: const Text(
                      'Verify',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 4. Telecom Telemetry Card ─────────────────────────────────────────────

  Widget _buildTelecomTelemetryCard(PhoneIntelligenceResult res, bool isDark) {
    final t = res.telemetry;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cell_tower_rounded, color: Color(0xFF2979FF), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'TELECOM NETWORK TELEMETRY & CIRCLE ALLOCATION',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFF2979FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildTelemetryRow(
            'Country / Jurisdiction',
            '${t.countryFlag} ${t.countryName} (${t.countryCode})',
            Icons.public_rounded,
            const Color(0xFF00E5FF),
            isDark,
          ),
          _buildTelemetryRow(
            'Allocated Carrier',
            res.allocatedCarrier != null && res.allocatedCarrier != res.carrier
                ? '${res.carrier} (Series: ${res.allocatedCarrier})'
                : res.carrier,
            Icons.signal_cellular_alt_rounded,
            const Color(0xFF00E676),
            isDark,
          ),
          _buildTelemetryRow(
            'DoT LSA Circle',
            res.circle,
            Icons.location_on_rounded,
            const Color(0xFFFF9100),
            isDark,
          ),
          _buildTelemetryRow(
            'Line Classification',
            t.lineType,
            Icons.phone_android_rounded,
            t.isVoip ? const Color(0xFFFF5252) : const Color(0xFF2979FF),
            isDark,
            trailing: t.isVoip
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'VOIP ALERT',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF5252),
                      ),
                    ),
                  )
                : null,
          ),
          _buildTelemetryRow(
            'TRAI DND Registry',
            t.dndStatus,
            Icons.do_not_disturb_on_total_silence_rounded,
            t.dndStatus.contains('Active')
                ? const Color(0xFF00E676)
                : const Color(0xFFFF9100),
            isDark,
          ),
          _buildTelemetryRow(
            'Series Era Vintage',
            res.seriesEraLabel,
            Icons.history_rounded,
            const Color(0xFFB388FF),
            isDark,
          ),
          _buildTelemetryRow(
            'MNC / MCC Identifier',
            t.mncMcc,
            Icons.tag_rounded,
            isDark ? Colors.white54 : Colors.black45,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryRow(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          if (trailing != null) ...[
            trailing,
            const SizedBox(width: 4),
          ],
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 5. Messaging Probes Card ──────────────────────────────────────────────

  Widget _buildMessagingProbesCard(String cleanNumber, bool isDark) {
    final digitsOnly = cleanNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_rounded, color: Color(0xFF00E5FF), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'COMMUNICATION & IDENTITY PROBES',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFF00E5FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Test live messaging endpoints to inspect profile pictures, bio descriptions, and active status.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildProbeActionBtn(
                icon: Icons.chat_bubble_rounded,
                label: 'WhatsApp Probe',
                color: const Color(0xFF25D366),
                onTap: () => _openUrl('https://wa.me/$digitsOnly'),
                isDark: isDark,
              ),
              _buildProbeActionBtn(
                icon: Icons.send_rounded,
                label: 'Telegram Lookup',
                color: const Color(0xFF229ED9),
                onTap: () => _openUrl('https://t.me/+$digitsOnly'),
                isDark: isDark,
              ),
              _buildProbeActionBtn(
                icon: Icons.search_rounded,
                label: 'Truecaller Direct',
                color: const Color(0xFF2979FF),
                onTap: () => _openUrl('https://www.truecaller.com/search/in/$digitsOnly'),
                isDark: isDark,
              ),
              _buildProbeActionBtn(
                icon: Icons.sms_rounded,
                label: 'Send SMS',
                color: const Color(0xFFFF9100),
                onTap: () => _openUrl('sms:$cleanNumber'),
                isDark: isDark,
              ),
              _buildProbeActionBtn(
                icon: Icons.phone_rounded,
                label: 'Open Dialer',
                color: const Color(0xFF00E676),
                onTap: () => _openUrl('tel:$cleanNumber'),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProbeActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 6. Investigative OSINT Dorks Card ─────────────────────────────────────

  Widget _buildOsintDorksCard(String cleanNumber, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.travel_explore_rounded, color: Color(0xFFFF9100), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'INVESTIGATIVE GOOGLE DORKS',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFFFF9100),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Targeted search operators to find mentions in leaked PDFs, FIR filings, and cybercrime complaint forums.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),

          _buildDorkTile(
            title: 'Leaked Logs & Spreadsheets',
            desc: 'Finds PDFs, XLSX, and CSV documents indexing this phone number',
            query: '"$cleanNumber" filetype:pdf OR filetype:xlsx OR filetype:csv',
            icon: Icons.description_rounded,
            isDark: isDark,
          ),
          _buildDorkTile(
            title: 'Cybercrime Complaints & FIRs',
            desc: 'Checks if this number is reported in online scam registries',
            query: '"$cleanNumber" scam OR fraud OR fir OR complaint OR cybercrime',
            icon: Icons.warning_amber_rounded,
            isDark: isDark,
          ),
          _buildDorkTile(
            title: 'Social Footprints & Bio Mentions',
            desc: 'Scans Facebook, Instagram, LinkedIn & X for contact info matches',
            query: '"$cleanNumber" site:facebook.com OR site:instagram.com OR site:linkedin.com',
            icon: Icons.public_rounded,
            isDark: isDark,
          ),
          _buildDorkTile(
            title: 'Classifieds & Buyer/Seller Forums',
            desc: 'Finds OLX, Quikr, and eCommerce forum listings',
            query: '"$cleanNumber" site:olx.in OR site:quikr.com OR forum',
            icon: Icons.forum_rounded,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDorkTile({
    required String title,
    required String desc,
    required String query,
    required IconData icon,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        final url = 'https://www.google.com/search?q=${Uri.encodeComponent(query)}';
        _openUrl(url);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFFFF9100)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFFFF9100)),
          ],
        ),
      ),
    );
  }

  // ─── 7. Dark-Web Breach & CAF Dossier Archive ──────────────────────────────

  Widget _buildBreachAndDossierCard(PhoneIntelligenceResult res, bool isDark) {
    final hasBreaches = res.breaches.isNotEmpty;
    final badgeColor = hasBreaches ? const Color(0xFFFF5252) : const Color(0xFF00E676);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_shared_rounded, color: badgeColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DARK-WEB BREACH & CAF DOSSIER ARCHIVE',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: badgeColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasBreaches
                      ? '${res.breaches.length} BREACHES'
                      : 'NO BREACHES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (hasBreaches) ...[
            ...res.breaches.map((b) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            b.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Text(
                          b.breachDate,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Exposed: ${b.dataClasses.join(", ")}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFFFF5252),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),
          ],

          // CAF Dossier
          if (res.leakedDossier != null) ...[
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'LEAKED CUSTOMER ACQUISITION FORM (CAF) SNAPSHOT',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 8),
            _buildDossierField('Subscriber Name', res.leakedDossier!.subscriberName, isDark),
            _buildDossierField('Father / Relative', res.leakedDossier!.fatherName, isDark),
            _buildDossierField('CAF Billing Address', res.leakedDossier!.rawCafAddress, isDark),
            _buildDossierField('Alternate Number', res.leakedDossier!.alternateNumber, isDark),
            _buildDossierField('ID Proof Document', res.leakedDossier!.idProofToken, isDark),
            _buildDossierField('CAF Origin / Retailer', res.leakedDossier!.cafRetailerOrigin, isDark),
            _buildDossierField('Breach Incident Date', res.leakedDossier!.breachIncidentDate, isDark),
          ],

          const SizedBox(height: 12),
          // Export report button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.share_outlined, size: 15),
              label: const Text('Export & Copy Full Dossier Report', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00E5FF),
                side: const BorderSide(color: Color(0xFF00E5FF)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _exportPhoneIntelligenceReport,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDossierField(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
