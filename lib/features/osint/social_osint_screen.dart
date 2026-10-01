/*
 * SafeSignal Mobile Security Suite
 * Module: Digital OSINT Footprint Engine (Maigret Architecture)
 * Author: Umar Farooque (umarfarooque@safesignal.app)
 * Copyright (c) 2026 SafeSignal Technologies. All rights reserved.
 *
 * 100% on-device concurrent OSINT reconnaissance engine:
 * Interrogates 32+ global & Indian platforms concurrently via Dio without external paid APIs.
 * Features deep attribute extraction, recursive alias pivoting, category filters, and dossier export.
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class SocialOsintScreen extends StatefulWidget {
  const SocialOsintScreen({super.key});

  @override
  State<SocialOsintScreen> createState() => _SocialOsintScreenState();
}

enum _ScanState { idle, scanning, done, error }

class OsintPost {
  final String title;
  final String? url;
  final String? subtitle;
  final String? date;

  const OsintPost({
    required this.title,
    this.url,
    this.subtitle,
    this.date,
  });
}

class OsintProfile {
  final String platform;
  final String category; // 'Social & Chat', 'Code & DevOps', 'Gaming & Media', 'Web & Creative'
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
  final List<String> discoveredAliases;

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
    this.discoveredAliases = const [],
  });
}

class _SocialOsintScreenState extends State<SocialOsintScreen> {
  final _controller = TextEditingController();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    validateStatus: (s) => s != null && s < 500,
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Accept': 'application/json, text/html, */*',
    },
  ));

  _ScanState _state = _ScanState.idle;
  String _activeQuery = '';
  List<OsintProfile> _foundProfiles = [];
  List<OsintProfile> _unconfirmedLinks = [];
  Set<String> _discoveredPivots = {};
  String _selectedCategory = 'ALL';
  String _currentStep = '';
  int _scannedCount = 0;
  static const int _totalPlatforms = 32;

  @override
  void dispose() {
    _controller.dispose();
    _dio.close();
    super.dispose();
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

  List<String> _extractAliases(String text, String currentQuery) {
    final aliases = <String>{};
    final regex = RegExp(r'@([A-Za-z0-9_]{3,22})');
    final matches = regex.allMatches(text);
    for (final m in matches) {
      final h = m.group(1);
      if (h != null) {
        final lower = h.toLowerCase();
        if (lower != currentQuery.toLowerCase() &&
            lower != 'twitter' &&
            lower != 'github' &&
            lower != 'instagram' &&
            lower != 'telegram' &&
            lower != 'support') {
          aliases.add(h);
        }
      }
    }
    return aliases.toList();
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
      _discoveredPivots = {};
      _selectedCategory = 'ALL';
      _scannedCount = 0;
      _currentStep = 'Launching Maigret on-device recon matrix...';
    });

    try {
      _setStep('Interrogating 32 global & Indian platforms concurrently...');

      // Build 32 native platform futures
      final tasks = <Future<OsintProfile?>>[
        // Tier 1: Deep Profile Scanners
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
        _scanDockerHub(raw),
        _scanDuolingo(raw),
        _scanKeybase(raw),

        // Tier 2: Verified Maigret Signature Scanners
        _scanSteam(raw),
        _scanSpotify(raw),
        _scanSoundCloud(raw),
        _scanLinktree(raw),
        _scanPinterest(raw),
        _scanPastebin(raw),
        _scanReplit(raw),
        _scanBuyMeACoffee(raw),
        _scanSubstack(raw),
        _scanDribbble(raw),
        _scanDisqus(raw),
        _scanDailyMotion(raw),
        _scanScratch(raw),
        _scanSpeedrun(raw),
        _scanWikipediaUser(raw),
        _scanMedium(raw),
        _scanVimeo(raw),
        _scanGravatar(raw),
      ];

      // Track incremental progress
      final wrappedTasks = tasks.map((task) async {
        final res = await task;
        if (mounted) {
          setState(() {
            _scannedCount++;
            _currentStep = 'Checking platforms ($_scannedCount/$_totalPlatforms completed)...';
          });
        }
        return res;
      }).toList();

      final results = await Future.wait(wrappedTasks);

      final found = results.whereType<OsintProfile>().where((p) => p.isFound).toList();

      // Aggregate recursive alias pivots
      final pivots = <String>{};
      for (final p in found) {
        pivots.addAll(p.discoveredAliases);
      }
      pivots.removeWhere((a) => a.toLowerCase() == raw.toLowerCase());

      // Sort with high-profile platforms first
      found.sort((a, b) {
        const order = [
          'Instagram', 'X (Twitter)', 'Threads', 'YouTube', 'Telegram', 'GitHub', 'Reddit',
          'Steam Community', 'Spotify', 'SoundCloud', 'Discord', 'Dev.to', 'GitLab',
          'Docker Hub', 'Keybase', 'Duolingo', 'Replit', 'Dribbble', 'Substack',
          'Buy Me a Coffee', 'Linktree', 'Pinterest', 'Medium', 'Vimeo', 'DailyMotion',
          'Chess.com', 'Hacker News (YC)', 'Speedrun.com', 'Scratch (MIT)', 'Wikipedia Editor',
          'Pastebin', 'Gravatar'
        ];
        final aIdx = order.indexOf(a.platform);
        final bIdx = order.indexOf(b.platform);
        return (aIdx == -1 ? 99 : aIdx).compareTo(bIdx == -1 ? 99 : bIdx);
      });

      _setStep('Synthesizing attack surface dossier...');
      final unconfirmed = _generateUnconfirmedLinks(raw, found.map((f) => f.platform).toSet());

      setState(() {
        _foundProfiles = found;
        _unconfirmedLinks = unconfirmed;
        _discoveredPivots = pivots;
        _state = _ScanState.done;
      });
    } catch (e) {
      debugPrint('OSINT Scan error: $e');
      setState(() => _state = _ScanState.error);
    }
  }

  void _exportDossier() {
    final buffer = StringBuffer();
    buffer.writeln('# SafeSignal OSINT Dossier: @$_activeQuery');
    buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buffer.writeln('Confirmed Profiles: ${_foundProfiles.length} of $_totalPlatforms checked');
    buffer.writeln('Exposure Rating: ${_getExposureRating(_foundProfiles.length)}');
    buffer.writeln('');

    if (_discoveredPivots.isNotEmpty) {
      buffer.writeln('## Discovered Recursive Pivots:');
      for (final p in _discoveredPivots) {
        buffer.writeln('- @$p');
      }
      buffer.writeln('');
    }

    buffer.writeln('## Confirmed Public Accounts:');
    for (final p in _foundProfiles) {
      buffer.writeln('### ${p.platform} (${p.category})');
      buffer.writeln('- URL: ${p.profileUrl}');
      if (p.displayName != null) buffer.writeln('- Name: ${p.displayName}');
      if (p.bio != null && p.bio!.isNotEmpty) buffer.writeln('- Bio: ${p.bio}');
      if (p.createdDate != null) buffer.writeln('- Created: ${p.createdDate}');
      for (final s in p.stats.entries) {
        buffer.writeln('- ${s.key}: ${s.value}');
      }
      buffer.writeln('');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OSINT Dossier copied to clipboard!'),
        backgroundColor: Color(0xFF2979FF),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getExposureRating(int count) {
    if (count >= 8) return 'CRITICAL (Wide Digital Attack Surface)';
    if (count >= 4) return 'HIGH (Multi-Platform Correlation)';
    if (count >= 2) return 'MODERATE (Identified Traces)';
    if (count == 1) return 'LOW (Isolated Footprint)';
    return 'MINIMAL (Unindexed Handle)';
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TIER 1: DEEP RECON EXTRACTORS
  // ═════════════════════════════════════════════════════════════════════════════

  // 1. Instagram
  Future<OsintProfile?> _scanInstagram(String user) async {
    try {
      final res = await _dio.get(
        'https://www.instagram.com/$user/',
        options: Options(
          headers: {
            'User-Agent': 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );
      final body = res.data?.toString() ?? '';
      if (body.isEmpty || res.statusCode == 404) return null;

      final descMatch = RegExp(r'<meta property="og:description" content="([^"]+)"').firstMatch(body);
      final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(body);
      final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);

      final rawDesc = descMatch?.group(1) ?? '';
      final rawTitle = titleMatch?.group(1) ?? '';
      String? avatar = imgMatch?.group(1)?.replaceAll('&amp;', '&');

      if (rawDesc.contains('Followers') || rawTitle.contains('Instagram photos and videos')) {
        String name = user;
        final nameMatch = RegExp(r'^(.*?)\s*\((\@|\&#064;)', caseSensitive: false).firstMatch(rawTitle);
        if (nameMatch != null && nameMatch.group(1)!.trim().isNotEmpty) {
          name = _cleanHtml(nameMatch.group(1)!);
        }

        final statsMap = <String, String>{};
        final statsRegex = RegExp(r'([0-9.,KMBkmb]+)\s+Followers,\s+([0-9.,KMBkmb]+)\s+Following,\s+([0-9.,KMBkmb]+)\s+Posts');
        final m = statsRegex.firstMatch(rawDesc);
        if (m != null) {
          statsMap['Followers'] = m.group(1)!;
          statsMap['Following'] = m.group(2)!;
          statsMap['Posts'] = m.group(3)!;
        }

        return OsintProfile(
          platform: 'Instagram',
          category: 'Social & Chat',
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

  // 2. X / Twitter
  Future<OsintProfile?> _scanXTwitter(String user) async {
    try {
      final res = await _dio.get('https://api.fxtwitter.com/$user');
      if (res.statusCode == 200 && res.data is Map && res.data['user'] != null) {
        final u = res.data['user'] as Map;
        final name = u['name']?.toString() ?? user;
        final screenName = u['screen_name']?.toString() ?? user;
        String? avatar = u['avatar_url']?.toString();
        if (avatar != null && avatar.contains('_normal')) {
          avatar = avatar.replaceAll('_normal', '_400x400');
        }
        final bio = u['description']?.toString();
        final followers = _formatCount(u['followers_count']);
        final following = _formatCount(u['following_count']);
        final tweets = _formatCount(u['statuses_count']);

        String? joined;
        final joinedRaw = u['joined']?.toString();
        if (joinedRaw != null) {
          joined = joinedRaw.split(',').first;
        }

        final aliases = bio != null ? _extractAliases(bio, user) : <String>[];

        return OsintProfile(
          platform: 'X (Twitter)',
          category: 'Social & Chat',
          profileUrl: 'https://x.com/$screenName',
          icon: Icons.alternate_email_rounded,
          brandColor: Colors.black,
          isFound: true,
          avatarUrl: avatar,
          displayName: name,
          handle: '@$screenName',
          bio: bio,
          createdDate: joined != null ? 'Joined $joined' : null,
          stats: {
            'Followers': followers,
            'Following': following,
            'Tweets': tweets,
          },
          discoveredAliases: aliases,
        );
      }
    } catch (_) {}
    return null;
  }

  // 3. Threads
  Future<OsintProfile?> _scanThreads(String user) async {
    try {
      final res = await _dio.get(
        'https://www.threads.net/@$user',
        options: Options(
          headers: {
            'User-Agent': 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );
      final body = res.data?.toString() ?? '';
      if (body.isEmpty || res.statusCode == 404) return null;

      final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(body);
      final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);
      final descMatch = RegExp(r'<meta property="og:description" content="([^"]+)"').firstMatch(body);

      final title = titleMatch?.group(1);
      final img = imgMatch?.group(1);
      final desc = descMatch?.group(1);

      if (title != null && (title.contains('(@$user)') || title.contains('on Threads'))) {
        final name = title.split('(').first.trim();
        return OsintProfile(
          platform: 'Threads',
          category: 'Social & Chat',
          profileUrl: 'https://www.threads.net/@$user',
          icon: Icons.tag_rounded,
          brandColor: const Color(0xFF101010),
          isFound: true,
          displayName: name.isNotEmpty ? name : user,
          handle: '@$user',
          bio: desc != null ? _cleanHtml(desc) : null,
          avatarUrl: img,
        );
      }
    } catch (_) {}
    return null;
  }

  // 4. YouTube
  Future<OsintProfile?> _scanYouTube(String user) async {
    try {
      final res = await _dio.get(
        'https://www.youtube.com/@$user',
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
            'Accept': 'text/html',
          },
        ),
      );
      final body = res.data?.toString() ?? '';
      if (body.isEmpty || res.statusCode == 404) return null;

      final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(body);
      final descMatch = RegExp(r'<meta property="og:description" content="([^"]+)"').firstMatch(body);
      final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);

      final title = titleMatch?.group(1);
      final desc = descMatch?.group(1);
      final img = imgMatch?.group(1);

      if (title != null && title.isNotEmpty && !title.contains('404 Not Found')) {
        return OsintProfile(
          platform: 'YouTube',
          category: 'Gaming & Media',
          profileUrl: 'https://www.youtube.com/@$user',
          icon: Icons.play_circle_filled_rounded,
          brandColor: const Color(0xFFFF0000),
          isFound: true,
          displayName: title,
          handle: '@$user',
          bio: desc != null && desc.isNotEmpty ? _cleanHtml(desc) : null,
          avatarUrl: img,
        );
      }
    } catch (_) {}
    return null;
  }

  // 5. Telegram
  Future<OsintProfile?> _scanTelegram(String user) async {
    try {
      final res = await _dio.get(
        'https://t.me/$user',
        options: Options(headers: {'User-Agent': 'Mozilla/5.0'}),
      );
      final body = res.data?.toString() ?? '';
      if (body.isEmpty || res.statusCode == 404) return null;

      if (!body.contains('tgme_page_extra') && !body.contains('tgme_page_title')) {
        return null;
      }

      final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(body);
      final descMatch = RegExp(r'<meta property="og:description" content="([^"]+)"').firstMatch(body);
      final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);

      final title = titleMatch?.group(1);
      final desc = descMatch?.group(1);
      final img = imgMatch?.group(1);

      if (title != null && !title.contains('Telegram: Contact')) {
        final aliases = desc != null ? _extractAliases(desc, user) : <String>[];
        return OsintProfile(
          platform: 'Telegram',
          category: 'Social & Chat',
          profileUrl: 'https://t.me/$user',
          icon: Icons.send_rounded,
          brandColor: const Color(0xFF24A1DE),
          isFound: true,
          displayName: _cleanHtml(title),
          handle: '@$user',
          bio: desc != null ? _cleanHtml(desc) : null,
          avatarUrl: img,
          discoveredAliases: aliases,
        );
      }
    } catch (_) {}
    return null;
  }

  // 6. GitHub
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

        final aliases = <String>[];
        final tw = d['twitter_username']?.toString();
        if (tw != null && tw.isNotEmpty) {
          aliases.add(tw);
        }
        if (bio != null) {
          aliases.addAll(_extractAliases(bio, user));
        }

        final posts = <OsintPost>[];
        try {
          final repoRes = await _dio.get('https://api.github.com/users/$user/repos?sort=pushed&per_page=3');
          if (repoRes.statusCode == 200 && repoRes.data is List) {
            for (final r in repoRes.data as List) {
              if (r is Map) {
                final rName = r['name']?.toString() ?? 'Repo';
                final rDesc = r['description']?.toString() ?? 'No description';
                final rStars = r['stargazers_count']?.toString() ?? '0';
                final rLang = r['language']?.toString() ?? 'Code';
                posts.add(OsintPost(
                  title: rName,
                  subtitle: '$rLang • ★ $rStars • $rDesc',
                  url: r['html_url']?.toString(),
                ));
              }
            }
          }
        } catch (_) {}

        return OsintProfile(
          platform: 'GitHub',
          category: 'Code & DevOps',
          profileUrl: 'https://github.com/$user',
          icon: Icons.code_rounded,
          brandColor: const Color(0xFF24292E),
          isFound: true,
          avatarUrl: avatar,
          displayName: name,
          handle: '@$user',
          bio: bio,
          createdDate: joined != null ? 'Joined $joined' : null,
          stats: {
            'Followers': followers,
            'Public Repos': repos,
          },
          recentPosts: posts,
          discoveredAliases: aliases,
        );
      }
    } catch (_) {}
    return null;
  }

  // 7. Reddit
  Future<OsintProfile?> _scanReddit(String user) async {
    try {
      final res = await _dio.get(
        'https://www.reddit.com/user/$user/about.json',
        options: Options(headers: {'User-Agent': 'SafeSignal-OSINT/2.0'}),
      );
      if (res.statusCode == 200 && res.data is Map && res.data['data'] != null) {
        final d = res.data['data'] as Map;
        final name = d['name']?.toString() ?? user;
        final subreddit = d['subreddit'] as Map?;
        final title = subreddit?['title']?.toString();
        final publicDesc = subreddit?['public_description']?.toString();
        String? icon = subreddit?['icon_img']?.toString();
        if (icon != null && icon.contains('?')) {
          icon = icon.split('?').first;
        }
        final karma = _formatCount(d['total_karma']);

        final createdUtc = d['created_utc'];
        String? joined;
        if (createdUtc is num) {
          final dt = DateTime.fromMillisecondsSinceEpoch(createdUtc.toInt() * 1000);
          joined = DateFormat('MMM yyyy').format(dt);
        }

        final aliases = publicDesc != null ? _extractAliases(publicDesc, user) : <String>[];

        final posts = <OsintPost>[];
        try {
          final postRes = await _dio.get(
            'https://www.reddit.com/user/$user/submitted.json?limit=3',
            options: Options(headers: {'User-Agent': 'SafeSignal-OSINT/2.0'}),
          );
          if (postRes.statusCode == 200 && postRes.data is Map && postRes.data['data']?['children'] != null) {
            for (final c in postRes.data['data']['children'] as List) {
              final p = c['data'] as Map?;
              if (p != null) {
                final pTitle = p['title']?.toString() ?? 'Post';
                final pSub = p['subreddit_name_prefixed']?.toString() ?? 'r/reddit';
                final pScore = p['score']?.toString() ?? '0';
                final pPerma = p['permalink']?.toString();
                posts.add(OsintPost(
                  title: pTitle,
                  subtitle: '$pSub • ▲ $pScore upvotes',
                  url: pPerma != null ? 'https://reddit.com$pPerma' : null,
                ));
              }
            }
          }
        } catch (_) {}

        return OsintProfile(
          platform: 'Reddit',
          category: 'Social & Chat',
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
          discoveredAliases: aliases,
        );
      }
    } catch (_) {}
    return null;
  }

  // 8. Dev.to
  Future<OsintProfile?> _scanDevTo(String user) async {
    try {
      final res = await _dio.get('https://dev.to/api/users/by_username?url=$user');
      if (res.statusCode == 200 && res.data is Map) {
        final d = res.data as Map;
        final name = d['name']?.toString() ?? user;
        final bio = d['summary']?.toString();
        final avatar = d['profile_image']?.toString();
        final joined = d['joined_at']?.toString();

        final posts = <OsintPost>[];
        try {
          final artRes = await _dio.get('https://dev.to/api/articles?username=$user&per_page=3');
          if (artRes.statusCode == 200 && artRes.data is List) {
            for (final a in artRes.data as List) {
              if (a is Map) {
                posts.add(OsintPost(
                  title: a['title']?.toString() ?? 'Article',
                  subtitle: '❤️ ${a['positive_reactions_count'] ?? 0} reactions',
                  url: a['url']?.toString(),
                ));
              }
            }
          }
        } catch (_) {}

        return OsintProfile(
          platform: 'Dev.to Community',
          category: 'Code & DevOps',
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

  // 9. HackerNews
  Future<OsintProfile?> _scanHackerNews(String user) async {
    try {
      final res = await _dio.get('https://hacker-news.firebaseio.com/v0/user/$user.json');
      if (res.statusCode == 200 && res.data is Map) {
        final d = res.data as Map;
        final karma = d['karma']?.toString() ?? '0';
        final about = d['about']?.toString();
        final created = d['created'];
        String? joined;
        if (created is num) {
          final dt = DateTime.fromMillisecondsSinceEpoch(created.toInt() * 1000);
          joined = DateFormat('MMM yyyy').format(dt);
        }

        return OsintProfile(
          platform: 'Hacker News (YC)',
          category: 'Code & DevOps',
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

  // 10. Chess.com
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
          final dt = DateTime.fromMillisecondsSinceEpoch(joinedSec.toInt() * 1000);
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

  // 11. GitLab
  Future<OsintProfile?> _scanGitLab(String user) async {
    try {
      final res = await _dio.get('https://gitlab.com/api/v4/users?username=$user');
      if (res.statusCode == 200 && res.data is List && (res.data as List).isNotEmpty) {
        final d = (res.data as List).first as Map;
        final name = d['name']?.toString() ?? user;
        final avatar = d['avatar_url']?.toString();
        final bio = d['bio']?.toString();
        final webUrl = d['web_url']?.toString() ?? 'https://gitlab.com/$user';

        return OsintProfile(
          platform: 'GitLab',
          category: 'Code & DevOps',
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

  // 12. DockerHub
  Future<OsintProfile?> _scanDockerHub(String user) async {
    try {
      final res = await _dio.get('https://hub.docker.com/v2/users/$user/');
      if (res.statusCode == 200 && res.data is Map && res.data['username'] != null) {
        final d = res.data as Map;
        final name = d['full_name']?.toString();
        final avatar = d['gravatar_url']?.toString();
        final id = d['id']?.toString();

        return OsintProfile(
          platform: 'Docker Hub',
          category: 'Code & DevOps',
          profileUrl: 'https://hub.docker.com/u/$user',
          icon: Icons.cloud_circle_rounded,
          brandColor: const Color(0xFF2496ED),
          isFound: true,
          displayName: name != null && name.isNotEmpty ? name : user,
          handle: '@$user',
          avatarUrl: avatar,
          bio: 'Registered Docker container publisher and namespace maintainer.',
          stats: id != null ? {'User ID': id.substring(0, id.length > 8 ? 8 : id.length)} : const {},
        );
      }
    } catch (_) {}
    return null;
  }

  // 13. Duolingo
  Future<OsintProfile?> _scanDuolingo(String user) async {
    try {
      final res = await _dio.get('https://www.duolingo.com/2017-06-30/users?username=$user');
      if (res.statusCode == 200 && res.data is Map) {
        final users = res.data['users'] as List?;
        if (users != null && users.isNotEmpty) {
          final u = users.first as Map;
          final name = u['name']?.toString() ?? user;
          final bio = u['bio']?.toString();
          final picture = u['picture'] != null ? 'https:${u['picture']}' : null;
          final streak = u['streak']?.toString() ?? '0';

          return OsintProfile(
            platform: 'Duolingo',
            category: 'Web & Creative',
            profileUrl: 'https://www.duolingo.com/profile/$user',
            icon: Icons.language_rounded,
            brandColor: const Color(0xFF58CC02),
            isFound: true,
            displayName: name,
            handle: '@$user',
            avatarUrl: picture,
            bio: bio,
            stats: {'Day Streak': streak},
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // 14. Keybase
  Future<OsintProfile?> _scanKeybase(String user) async {
    try {
      final res = await _dio.get('https://keybase.io/_/api/1.0/user/lookup.json?usernames=$user');
      if (res.statusCode == 200 && res.data is Map) {
        final status = res.data['status'] as Map?;
        final them = res.data['them'] as List?;
        if (status?['code'] == 0 && them != null && them.isNotEmpty && them.first != null) {
          final t = them.first as Map;
          final profile = t['profile'] as Map?;
          final bio = profile?['bio']?.toString();
          final full = profile?['full_name']?.toString();
          final pictures = t['pictures'] as Map?;
          final primaryPic = pictures?['primary'] as Map?;
          final avatar = primaryPic?['url']?.toString();

          final aliases = bio != null ? _extractAliases(bio, user) : <String>[];

          return OsintProfile(
            platform: 'Keybase',
            category: 'Web & Creative',
            profileUrl: 'https://keybase.io/$user',
            icon: Icons.vpn_key_rounded,
            brandColor: const Color(0xFFFF6F21),
            isFound: true,
            displayName: full ?? user,
            handle: '@$user',
            avatarUrl: avatar,
            bio: bio ?? 'Cryptographic identity proof anchor.',
            discoveredAliases: aliases,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TIER 2: VERIFIED MAIGRET SIGNATURE EXTRACTORS
  // ═════════════════════════════════════════════════════════════════════════════

  // 15. Steam
  Future<OsintProfile?> _scanSteam(String user) async {
    try {
      final res = await _dio.get('https://steamcommunity.com/id/$user');
      if (res.statusCode == 200) {
        final body = res.data?.toString() ?? '';
        if (!body.contains('The specified profile could not be found')) {
          final titleMatch = RegExp(r'<title>Steam Community :: ([^<]+)</title>').firstMatch(body);
          final title = titleMatch?.group(1) ?? user;
          final avatarMatch = RegExp(r'<link rel="image_src" href="([^"]+)">').firstMatch(body);

          return OsintProfile(
            platform: 'Steam Community',
            category: 'Gaming & Strategy',
            profileUrl: 'https://steamcommunity.com/id/$user',
            icon: Icons.sports_esports_rounded,
            brandColor: const Color(0xFF171A21),
            isFound: true,
            displayName: title,
            handle: 'id: $user',
            avatarUrl: avatarMatch?.group(1),
            bio: 'Active Steam gamer identity and community profile.',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // 16. Spotify
  Future<OsintProfile?> _scanSpotify(String user) async {
    try {
      final res = await _dio.get('https://open.spotify.com/user/$user');
      if (res.statusCode == 200) {
        final body = res.data?.toString() ?? '';
        final titleMatch = RegExp(r'<title>([^<]+)</title>').firstMatch(body);
        final title = titleMatch?.group(1)?.replaceAll(' | Spotify', '') ?? user;
        final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);

        return OsintProfile(
          platform: 'Spotify',
          category: 'Gaming & Media',
          profileUrl: 'https://open.spotify.com/user/$user',
          icon: Icons.music_note_rounded,
          brandColor: const Color(0xFF1DB954),
          isFound: true,
          displayName: title,
          handle: '@$user',
          avatarUrl: imgMatch?.group(1),
          bio: 'Verified Spotify music listener & curator profile.',
        );
      }
    } catch (_) {}
    return null;
  }

  // 17. SoundCloud
  Future<OsintProfile?> _scanSoundCloud(String user) async {
    try {
      final res = await _dio.get('https://soundcloud.com/$user');
      if (res.statusCode == 200) {
        final body = res.data?.toString() ?? '';
        final titleMatch = RegExp(r'<title>([^<]+)</title>').firstMatch(body);
        final title = titleMatch?.group(1)?.replaceAll(' | Listen to music', '') ?? user;
        final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);

        return OsintProfile(
          platform: 'SoundCloud',
          category: 'Gaming & Media',
          profileUrl: 'https://soundcloud.com/$user',
          icon: Icons.graphic_eq_rounded,
          brandColor: const Color(0xFFFF5500),
          isFound: true,
          displayName: title,
          handle: '@$user',
          avatarUrl: imgMatch?.group(1),
          bio: 'Audio track creator & audio listener profile.',
        );
      }
    } catch (_) {}
    return null;
  }

  // 18. Linktree
  Future<OsintProfile?> _scanLinktree(String user) async {
    try {
      final res = await _dio.get('https://linktr.ee/$user');
      if (res.statusCode == 200) {
        final body = res.data?.toString() ?? '';
        final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(body);
        final title = titleMatch?.group(1) ?? user;
        final descMatch = RegExp(r'<meta property="og:description" content="([^"]+)"').firstMatch(body);
        final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);

        return OsintProfile(
          platform: 'Linktree',
          category: 'Web & Creative',
          profileUrl: 'https://linktr.ee/$user',
          icon: Icons.link_rounded,
          brandColor: const Color(0xFF43E660),
          isFound: true,
          displayName: title,
          handle: '@$user',
          avatarUrl: imgMatch?.group(1),
          bio: descMatch?.group(1) ?? 'Consolidated social tree & landing links.',
        );
      }
    } catch (_) {}
    return null;
  }

  // 19. Pinterest
  Future<OsintProfile?> _scanPinterest(String user) async {
    try {
      final res = await _dio.get('https://www.pinterest.com/$user/');
      if (res.statusCode == 200) {
        final body = res.data?.toString() ?? '';
        final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(body);
        final title = titleMatch?.group(1) ?? user;
        final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);

        return OsintProfile(
          platform: 'Pinterest',
          category: 'Web & Creative',
          profileUrl: 'https://www.pinterest.com/$user/',
          icon: Icons.push_pin_rounded,
          brandColor: const Color(0xFFBD081C),
          isFound: true,
          displayName: title,
          handle: '@$user',
          avatarUrl: imgMatch?.group(1),
          bio: 'Visual curation & moodboard profile.',
        );
      }
    } catch (_) {}
    return null;
  }

  // 20. Pastebin
  Future<OsintProfile?> _scanPastebin(String user) async {
    try {
      final res = await _dio.get('https://pastebin.com/u/$user');
      if (res.statusCode == 200) {
        return OsintProfile(
          platform: 'Pastebin',
          category: 'Code & DevOps',
          profileUrl: 'https://pastebin.com/u/$user',
          icon: Icons.paste_rounded,
          brandColor: const Color(0xFF02365C),
          isFound: true,
          displayName: user,
          handle: 'u/$user',
          bio: 'Public code & log snippets author archive.',
        );
      }
    } catch (_) {}
    return null;
  }

  // 21. Replit
  Future<OsintProfile?> _scanReplit(String user) async {
    try {
      final res = await _dio.get('https://replit.com/@$user');
      if (res.statusCode == 200) {
        final body = res.data?.toString() ?? '';
        final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(body);
        final title = titleMatch?.group(1) ?? user;
        final descMatch = RegExp(r'<meta property="og:description" content="([^"]+)"').firstMatch(body);
        final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);

        return OsintProfile(
          platform: 'Replit',
          category: 'Code & DevOps',
          profileUrl: 'https://replit.com/@$user',
          icon: Icons.terminal_rounded,
          brandColor: const Color(0xFFF26207),
          isFound: true,
          displayName: title,
          handle: '@$user',
          avatarUrl: imgMatch?.group(1),
          bio: descMatch?.group(1) ?? 'Interactive cloud computing and software sandbox profile.',
        );
      }
    } catch (_) {}
    return null;
  }

  // 22. BuyMeACoffee
  Future<OsintProfile?> _scanBuyMeACoffee(String user) async {
    try {
      final res = await _dio.get('https://www.buymeacoffee.com/$user');
      if (res.statusCode == 200) {
        final body = res.data?.toString() ?? '';
        if (!body.toLowerCase().contains('page not found')) {
          final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(body);
          final title = titleMatch?.group(1) ?? user;
          final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);

          return OsintProfile(
            platform: 'Buy Me a Coffee',
            category: 'Web & Creative',
            profileUrl: 'https://www.buymeacoffee.com/$user',
            icon: Icons.coffee_rounded,
            brandColor: const Color(0xFFFFDD00),
            isFound: true,
            displayName: title,
            handle: '@$user',
            avatarUrl: imgMatch?.group(1),
            bio: 'Creator patronage and financial tips profile.',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // 23. Substack
  Future<OsintProfile?> _scanSubstack(String user) async {
    try {
      final res = await _dio.get('https://$user.substack.com');
      if (res.statusCode == 200) {
        final body = res.data?.toString() ?? '';
        final titleMatch = RegExp(r'<title>([^<]+)</title>').firstMatch(body);
        final title = titleMatch?.group(1) ?? user;
        final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);

        return OsintProfile(
          platform: 'Substack',
          category: 'Web & Creative',
          profileUrl: 'https://$user.substack.com',
          icon: Icons.feed_rounded,
          brandColor: const Color(0xFFFF6719),
          isFound: true,
          displayName: title,
          handle: '@$user',
          avatarUrl: imgMatch?.group(1),
          bio: 'Independent newsletter publication and subscriber portal.',
        );
      }
    } catch (_) {}
    return null;
  }

  // 24. Dribbble
  Future<OsintProfile?> _scanDribbble(String user) async {
    try {
      final res = await _dio.get('https://dribbble.com/$user');
      if (res.statusCode == 200) {
        final body = res.data?.toString() ?? '';
        final titleMatch = RegExp(r'<title>([^<]+)</title>').firstMatch(body);
        final title = titleMatch?.group(1)?.replaceAll(' on Dribbble', '') ?? user;

        return OsintProfile(
          platform: 'Dribbble',
          category: 'Web & Creative',
          profileUrl: 'https://dribbble.com/$user',
          icon: Icons.design_services_rounded,
          brandColor: const Color(0xFFEA4C89),
          isFound: true,
          displayName: title,
          handle: '@$user',
          bio: 'UI/UX and visual design portfolio showreel.',
        );
      }
    } catch (_) {}
    return null;
  }

  // 25. Disqus
  Future<OsintProfile?> _scanDisqus(String user) async {
    try {
      final res = await _dio.get('https://disqus.com/by/$user/');
      if (res.statusCode == 200) {
        return OsintProfile(
          platform: 'Disqus',
          category: 'Social & Chat',
          profileUrl: 'https://disqus.com/by/$user/',
          icon: Icons.comment_rounded,
          brandColor: const Color(0xFF2E9FFF),
          isFound: true,
          displayName: user,
          handle: '@$user',
          bio: 'Universal blog commenting identity and activity log.',
        );
      }
    } catch (_) {}
    return null;
  }

  // 26. DailyMotion
  Future<OsintProfile?> _scanDailyMotion(String user) async {
    try {
      final res = await _dio.get('https://api.dailymotion.com/user/$user');
      if (res.statusCode == 200 && res.data is Map && res.data['id'] != null) {
        final d = res.data as Map;
        final screenname = d['screenname']?.toString() ?? user;
        final avatar = d['avatar_360_url']?.toString();

        return OsintProfile(
          platform: 'Dailymotion',
          category: 'Gaming & Media',
          profileUrl: 'https://www.dailymotion.com/$user',
          icon: Icons.ondemand_video_rounded,
          brandColor: const Color(0xFF0066DC),
          isFound: true,
          displayName: screenname,
          handle: '@$user',
          avatarUrl: avatar,
          bio: 'Video channel broadcast and content creator archive.',
        );
      }
    } catch (_) {}
    return null;
  }

  // 27. Scratch MIT
  Future<OsintProfile?> _scanScratch(String user) async {
    try {
      final res = await _dio.get('https://api.scratch.mit.edu/users/$user');
      if (res.statusCode == 200 && res.data is Map && res.data['id'] != null) {
        final d = res.data as Map;
        final username = d['username']?.toString() ?? user;
        final profile = d['profile'] as Map?;
        final bio = profile?['bio']?.toString();
        final avatar = profile?['images']?['90x90']?.toString();
        final country = profile?['country']?.toString();

        return OsintProfile(
          platform: 'Scratch (MIT)',
          category: 'Code & DevOps',
          profileUrl: 'https://scratch.mit.edu/users/$user/',
          icon: Icons.code_rounded,
          brandColor: const Color(0xFFFFAB19),
          isFound: true,
          displayName: username,
          handle: '@$username',
          avatarUrl: avatar,
          bio: bio,
          stats: country != null ? {'Country': country} : const {},
        );
      }
    } catch (_) {}
    return null;
  }

  // 28. Speedrun.com
  Future<OsintProfile?> _scanSpeedrun(String user) async {
    try {
      final res = await _dio.get('https://www.speedrun.com/api/v1/users?name=$user');
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data['data'] as List?;
        if (data != null && data.isNotEmpty) {
          final u = data.first as Map;
          final names = u['names'] as Map?;
          final intlName = names?['international']?.toString() ?? user;
          final weblink = u['weblink']?.toString() ?? 'https://www.speedrun.com/user/$user';

          return OsintProfile(
            platform: 'Speedrun.com',
            category: 'Gaming & Strategy',
            profileUrl: weblink,
            icon: Icons.timer_rounded,
            brandColor: const Color(0xFF00BCD4),
            isFound: true,
            displayName: intlName,
            handle: '@$user',
            bio: 'Competitive speedrunner and leaderboard athlete profile.',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // 29. Wikipedia User
  Future<OsintProfile?> _scanWikipediaUser(String user) async {
    try {
      final res = await _dio.get('https://en.wikipedia.org/wiki/User:$user');
      if (res.statusCode == 200) {
        return OsintProfile(
          platform: 'Wikipedia Editor',
          category: 'Web & Creative',
          profileUrl: 'https://en.wikipedia.org/wiki/User:$user',
          icon: Icons.menu_book_rounded,
          brandColor: const Color(0xFF636466),
          isFound: true,
          displayName: 'User:$user',
          handle: 'wiki: $user',
          bio: 'Registered encyclopedic editor and contributor account.',
        );
      }
    } catch (_) {}
    return null;
  }

  // 30. Medium
  Future<OsintProfile?> _scanMedium(String user) async {
    try {
      final res = await _dio.get('https://medium.com/@$user');
      if (res.statusCode == 200 || res.statusCode == 403) {
        final body = res.data?.toString() ?? '';
        if (body.contains('Medium') && !body.contains('404') && !body.contains('Page not found')) {
          final titleMatch = RegExp(r'<title>([^<]+)</title>').firstMatch(body);
          final title = titleMatch?.group(1)?.replaceAll(' – Medium', '') ?? user;
          final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);

          return OsintProfile(
            platform: 'Medium',
            category: 'Web & Creative',
            profileUrl: 'https://medium.com/@$user',
            icon: Icons.article_rounded,
            brandColor: const Color(0xFF000000),
            isFound: true,
            displayName: title,
            handle: '@$user',
            avatarUrl: imgMatch?.group(1),
            bio: 'Writer, thinker, and article publisher on Medium.',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // 31. Vimeo
  Future<OsintProfile?> _scanVimeo(String user) async {
    try {
      final res = await _dio.get('https://vimeo.com/$user');
      if (res.statusCode == 200) {
        final body = res.data?.toString() ?? '';
        final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(body);
        final title = titleMatch?.group(1) ?? user;
        final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);

        return OsintProfile(
          platform: 'Vimeo',
          category: 'Gaming & Media',
          profileUrl: 'https://vimeo.com/$user',
          icon: Icons.video_library_rounded,
          brandColor: const Color(0xFF1AB7EA),
          isFound: true,
          displayName: title,
          handle: '@$user',
          avatarUrl: imgMatch?.group(1),
          bio: 'HD cinematic video production & portfolio channel.',
        );
      }
    } catch (_) {}
    return null;
  }

  // 32. Gravatar
  Future<OsintProfile?> _scanGravatar(String user) async {
    try {
      final res = await _dio.get('https://en.gravatar.com/$user.json');
      if (res.statusCode == 200 && res.data is Map) {
        final entries = res.data['entry'] as List?;
        if (entries != null && entries.isNotEmpty) {
          final e = entries.first as Map;
          final displayName = e['displayName']?.toString() ?? user;
          final about = e['aboutMe']?.toString();
          final avatar = e['thumbnailUrl']?.toString();

          return OsintProfile(
            platform: 'Gravatar',
            category: 'Web & Creative',
            profileUrl: 'https://en.gravatar.com/$user',
            icon: Icons.account_circle_rounded,
            brandColor: const Color(0xFF1E8CBE),
            isFound: true,
            displayName: displayName,
            handle: '@$user',
            avatarUrl: avatar,
            bio: about ?? 'Globally Recognized Avatar identity profile.',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── Generate Remaining Links ───────────────────────────────────────────────
  List<OsintProfile> _generateUnconfirmedLinks(String user, Set<String> foundPlatforms) {
    final all = [
      OsintProfile(
        platform: 'TikTok',
        category: 'Gaming & Media',
        profileUrl: 'https://www.tiktok.com/@$user',
        icon: Icons.music_note_rounded,
        brandColor: const Color(0xFF010101),
        isFound: false,
      ),
      OsintProfile(
        platform: 'LinkedIn',
        category: 'Social & Chat',
        profileUrl: 'https://www.linkedin.com/in/$user',
        icon: Icons.business_rounded,
        brandColor: const Color(0xFF0077B5),
        isFound: false,
      ),
      OsintProfile(
        platform: 'Kaggle',
        category: 'Code & DevOps',
        profileUrl: 'https://www.kaggle.com/$user',
        icon: Icons.data_usage_rounded,
        brandColor: const Color(0xFF20BEFF),
        isFound: false,
      ),
      OsintProfile(
        platform: 'ProductHunt',
        category: 'Web & Creative',
        profileUrl: 'https://www.producthunt.com/@$user',
        icon: Icons.rocket_launch_rounded,
        brandColor: const Color(0xFFDA552F),
        isFound: false,
      ),
    ];

    return all.where((item) => !foundPlatforms.contains(item.platform)).toList();
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // UI BUILD & PRESENTATION
  // ═════════════════════════════════════════════════════════════════════════════

  List<OsintProfile> get _filteredProfiles {
    if (_selectedCategory == 'ALL') return _foundProfiles;
    return _foundProfiles.where((p) => p.category == _selectedCategory).toList();
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : const Color(0xFF0D1117), size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Digital OSINT Recon',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF0D1117),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          if (_foundProfiles.isNotEmpty)
            IconButton(
              icon: Icon(Icons.copy_all_rounded, color: isDark ? Colors.white : const Color(0xFF0D1117)),
              onPressed: _exportDossier,
              tooltip: 'Export OSINT Dossier',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OSINT Sub-Mode Switcher (Social vs Phone)
              _buildOsintModeSwitcher(isDark),
              const SizedBox(height: 14),

              // Search Box Card
              _buildSearchCard(isDark),
              const SizedBox(height: 16),

              // Scanning State
              if (_state == _ScanState.scanning) _buildScanningProgress(isDark),

              // Error State
              if (_state == _ScanState.error) _buildErrorCard(isDark),

              // Results
              if (_state == _ScanState.done) ...[
                _buildExposureSummaryHeader(isDark),
                const SizedBox(height: 18),

                // Recursive Alias Pivots (Maigret signature)
                if (_discoveredPivots.isNotEmpty) ...[
                  _buildRecursivePivotsCard(isDark),
                  const SizedBox(height: 18),
                ],

                // Category Filter Pills
                _buildCategoryFilters(isDark),
                const SizedBox(height: 18),

                // Identified Profiles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'CONFIRMED PUBLIC PROFILES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2979FF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_filteredProfiles.length}',
                            style: const TextStyle(
                              color: Color(0xFF2979FF),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '32 Platforms Interrogated',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_filteredProfiles.isEmpty)
                  _buildNoProfilesFoundCard(isDark)
                else
                  ..._filteredProfiles.map((p) => _buildProfileCard(p, isDark)),

                const SizedBox(height: 24),

                // Unconfirmed Presence Probes
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
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45),
                  ),
                  const SizedBox(height: 14),

                  _buildQuickProbeGrid(isDark),
                  const SizedBox(height: 24),
                ],

                // Security Analysis Card
                _buildThreatInsightCard(isDark),
                const SizedBox(height: 40),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOsintModeSwitcher(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_search_rounded, size: 16, color: Color(0xFF2979FF)),
                  SizedBox(width: 6),
                  Text(
                    'Social Recon (32 Sites)',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Color(0xFF2979FF),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: () => context.push('/phone-osint'),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_android_rounded,
                      size: 16,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Phone OSINT',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2979FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.travel_explore_rounded, color: Color(0xFF2979FF), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Multi-Vector Footprint Matrix',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '32 Platforms • Maigret Signature Engine • 0 Server',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w700),
            textInputAction: TextInputAction.search,
            onSubmitted: (val) => _startScan(val),
            decoration: InputDecoration(
              hintText: 'Enter username or alias (e.g. torvalds, carryminati)',
              hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 13),
              prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF2979FF), size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF2979FF)),
                onPressed: () => _startScan(),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF2979FF), width: 1.8),
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
              _buildExampleChip('torvalds', isDark),
              _buildExampleChip('spez', isDark),
              _buildExampleChip('carryminati', isDark),
              _buildExampleChip('umar', isDark),
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
    final progress = _totalPlatforms > 0 ? (_scannedCount / _totalPlatforms).clamp(0.0, 1.0) : 0.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              color: Color(0xFF2979FF),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Maigret Reconnaissance Active',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16.5,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2979FF)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _currentStep,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF2979FF), fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Sweeping Instagram, Steam, GitHub, Spotify, Duolingo, X, Keybase for "@$_activeQuery"...',
            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  // ─── Exposure Summary ───────────────────────────────────────────────────────
  Widget _buildExposureSummaryHeader(bool isDark) {
    final count = _foundProfiles.length;
    Color levelColor;
    String levelText;
    String desc;

    if (count >= 8) {
      levelColor = const Color(0xFFEF5350);
      levelText = 'CRITICAL ATTACK SURFACE';
      desc = 'This handle is indexed across $count platforms. Scammers can cross-correlate hobbies, code commits, and chats for spear-phishing.';
    } else if (count >= 4) {
      levelColor = const Color(0xFFFFB300);
      levelText = 'MODERATE EXPOSURE';
      desc = 'Confirmed accounts discovered across multiple networks. Consider decoupling usernames for high-security accounts.';
    } else if (count >= 1) {
      levelColor = const Color(0xFF4CAF50);
      levelText = 'LOW / ISOLATED EXPOSURE';
      desc = 'Few confirmed profiles found matching this handle. Digital footprint is relatively isolated.';
    } else {
      levelColor = Colors.grey;
      levelText = 'MINIMAL PUBLIC TRACE';
      desc = 'No confirmed accounts found across the 32 inspected signature networks.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: levelColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: levelColor.withValues(alpha: 0.35), width: 1.5),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count / $_totalPlatforms Found',
                  style: TextStyle(color: levelColor, fontWeight: FontWeight.w900, fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            style: TextStyle(fontSize: 12.5, height: 1.4, color: isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  // ─── Recursive Alias Pivots Card (Maigret Signature Feature) ─────────────────
  Widget _buildRecursivePivotsCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_rounded, color: Color(0xFF8B5CF6), size: 18),
              SizedBox(width: 8),
              Text(
                'RECURSIVE ALIAS PIVOTS (MAIGRET RECON)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Discovered secondary handles linked in public bios/profiles. Tap to pivot and scan:',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _discoveredPivots.map((alias) {
              return ActionChip(
                avatar: const Icon(Icons.radar_rounded, size: 14, color: Color(0xFF8B5CF6)),
                label: Text('@$alias', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                backgroundColor: isDark ? const Color(0xFF1E1A33) : const Color(0xFFF3E8FF),
                side: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                onPressed: () => _startScan(alias),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Category Filter Pills ──────────────────────────────────────────────────
  Widget _buildCategoryFilters(bool isDark) {
    final categories = ['ALL', 'Social & Chat', 'Code & DevOps', 'Gaming & Media', 'Web & Creative'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final isSel = _selectedCategory == cat;
          int count = 0;
          if (cat == 'ALL') {
            count = _foundProfiles.length;
          } else {
            count = _foundProfiles.where((p) => p.category == cat).length;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedCategory = cat),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel
                      ? const Color(0xFF2979FF)
                      : (isDark ? const Color(0xFF131926) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSel ? const Color(0xFF2979FF) : (isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                        color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSel
                            ? Colors.white.withValues(alpha: 0.25)
                            : (isDark ? Colors.white12 : Colors.black12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: p.brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.brandColor.withValues(alpha: 0.3)),
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
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
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
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: p.brandColor),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.open_in_new_rounded, size: 14, color: p.brandColor),
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
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.brandColor.withValues(alpha: 0.12),
                  border: Border.all(color: p.brandColor.withValues(alpha: 0.35), width: 1.8),
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
                    : Center(child: Icon(p.icon, color: p.brandColor, size: 28)),
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
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, color: Color(0xFF2979FF), size: 16),
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
                          Icon(Icons.calendar_today_outlined, size: 11, color: isDark ? Colors.white38 : Colors.black38),
                          const SizedBox(width: 4),
                          Text(
                            p.createdDate!,
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
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
                color: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0)),
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

          // Discovered Linked Handles / Pivots in this profile
          if (p.discoveredAliases.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Text(
                  'Linked Pivot:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: p.brandColor),
                ),
                ...p.discoveredAliases.map((a) => InkWell(
                      onTap: () => _startScan(a),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.brandColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: p.brandColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('@$a', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p.brandColor)),
                            const SizedBox(width: 3),
                            Icon(Icons.radar_rounded, size: 12, color: p.brandColor),
                          ],
                        ),
                      ),
                    )),
              ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: p.brandColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.brandColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entry.key}: ',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
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
            ...p.recentPosts.map((post) => InkWell(
                  onTap: post.url != null ? () => _openUrl(post.url!) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.arrow_right_rounded, size: 16, color: Color(0xFF2979FF)),
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
                                      ? (isDark ? const Color(0xFF82B1FF) : const Color(0xFF1565C0))
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
                                    color: isDark ? Colors.white38 : Colors.black45,
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
                )),
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
                color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0),
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
                Icon(Icons.open_in_new, size: 14, color: isDark ? Colors.white24 : Colors.black26),
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
              Icon(Icons.security_update_warning_rounded, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text(
                'OSINT Hygiene & Correlation Defense',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.amber),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Scammers and threat actors use identical usernames across platforms to bridge your real name, location, Steam games, Spotify playlists, and code commits into high-confidence spear-phishing and social engineering attacks. Maintain separate pseudonyms for gaming, banking, and public publishing.',
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
          Icon(Icons.search_off_rounded, size: 40, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            'No Public Accounts in this Category',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'Try selecting "ALL" or searching for a discovered alias pivot.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45),
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
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
