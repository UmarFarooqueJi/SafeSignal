import 'package:flutter/material.dart';
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
  final String category; // 'Social Network', 'Microblogging', 'Code & DevOps', 'Discussions', etc.
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
  final _controller = TextEditingController();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 7),
    receiveTimeout: const Duration(seconds: 7),
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
  String _currentStep = '';

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

      final found = results.whereType<OsintProfile>().where((p) => p.isFound).toList();

      // Sort with top social & community networks prioritized
      found.sort((a, b) {
        final order = ['Instagram', 'X (Twitter)', 'Threads', 'YouTube', 'Telegram', 'GitHub', 'Reddit', 'Dev.to', 'Hacker News (YC)', 'Chess.com', 'GitLab'];
        final aIdx = order.indexOf(a.platform);
        final bIdx = order.indexOf(b.platform);
        return (aIdx == -1 ? 99 : aIdx).compareTo(bIdx == -1 ? 99 : bIdx);
      });

      _setStep('Compiling digital footprint matrix...');
      final unconfirmed = _generateUnconfirmedLinks(raw, found.map((f) => f.platform).toSet());

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
      String? avatar = imgMatch?.group(1);
      if (avatar != null) {
        avatar = avatar.replaceAll('&amp;', '&');
      }

      // Check if user actually exists on Instagram
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
      if (res.statusCode == 200 && res.data is Map && res.data['user'] != null) {
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
            'User-Agent': 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
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
      String? avatar = imgMatch?.group(1);
      if (avatar != null) {
        avatar = avatar.replaceAll('&amp;', '&');
      }

      if (rawTitle.toLowerCase().contains('threads') || rawDesc.contains('Followers')) {
        String name = user;
        final nameMatch = RegExp(r'^(.*?)\s*\((\@|\&#064;)', caseSensitive: false).firstMatch(rawTitle);
        if (nameMatch != null && nameMatch.group(1)!.trim().isNotEmpty) {
          name = _cleanHtml(nameMatch.group(1)!);
        }

        final statsMap = <String, String>{};
        final fMatch = RegExp(r'([0-9.,KMBkmb]+)\s+Followers').firstMatch(rawDesc);
        if (fMatch != null) statsMap['Followers'] = fMatch.group(1)!;

        final thMatch = RegExp(r'([0-9.,KMBkmb]+)\s+Threads').firstMatch(rawDesc);
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

      final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(body);
      final descMatch = RegExp(r'<meta property="og:description" content="([^"]+)"').firstMatch(body);
      final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);

      final title = titleMatch?.group(1);
      final desc = descMatch?.group(1);
      final img = imgMatch?.group(1);

      if (title != null && !title.toLowerCase().contains('404 not found') && !title.toLowerCase().contains('youtube')) {
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
          stats: {
            'Status': 'Public Channel',
          },
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
      if (body.contains('tgme_page_title') || body.contains('tgme_page_photo')) {
        final tMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(body);
        final dMatch = RegExp(r'<meta property="og:description" content="([^"]+)"').firstMatch(body);
        final iMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(body);

        final title = tMatch?.group(1);
        final desc = dMatch?.group(1);
        final img = iMatch?.group(1);

        if (title != null && !title.toLowerCase().contains('telegram: contact')) {
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
          final repoRes = await _dio.get('https://api.github.com/users/$user/repos?sort=pushed&per_page=3');
          if (repoRes.statusCode == 200 && repoRes.data is List) {
            for (final r in repoRes.data as List) {
              if (r is Map) {
                final rName = r['name']?.toString() ?? 'Repo';
                final rDesc = r['description']?.toString() ?? 'No description';
                final rStars = r['stargazers_count']?.toString() ?? '0';
                final rLang = r['language']?.toString() ?? 'Code';
                final rUrl = r['html_url']?.toString();
                posts.add(OsintPost(
                  title: rName,
                  subtitle: '$rLang • ★ $rStars • $rDesc',
                  url: rUrl,
                ));
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
          stats: {
            'Followers': followers,
            'Public Repos': repos,
          },
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
      if (res.statusCode == 200 && res.data is Map && res.data['data'] != null) {
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
          final dt = DateTime.fromMillisecondsSinceEpoch(createdUtc.toInt() * 1000);
          joined = DateFormat('MMM yyyy').format(dt);
        }

        // Fetch recent submissions
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
          stats: {
            'Karma Score': karma,
          },
          recentPosts: posts,
        );
      }
    } catch (_) {}
    return null;
  }

  // ─── 8. Dev.to Recon ────────────────────────────────────────────────────────
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
                final aTitle = a['title']?.toString() ?? 'Article';
                final aReactions = a['positive_reactions_count']?.toString() ?? '0';
                final aUrl = a['url']?.toString();
                posts.add(OsintPost(
                  title: aTitle,
                  subtitle: '❤️ $aReactions reactions',
                  url: aUrl,
                ));
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
          category: 'Tech & Startups',
          profileUrl: 'https://news.ycombinator.com/user?id=$user',
          icon: Icons.newspaper_rounded,
          brandColor: const Color(0xFFFF6600),
          isFound: true,
          displayName: user,
          handle: 'id: $user',
          bio: about != null ? _cleanHtml(about) : null,
          createdDate: joined != null ? 'Member since $joined' : null,
          stats: {
            'Karma Score': karma,
          },
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

  // ─── 11. GitLab Recon ───────────────────────────────────────────────────────
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
  List<OsintProfile> _generateUnconfirmedLinks(String user, Set<String> foundPlatforms) {
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

    return all.where((item) => !foundPlatforms.contains(item.platform)).toList();
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : const Color(0xFF0D1117), size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Social OSINT Recon',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF0D1117),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
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
                const SizedBox(height: 22),

                // Identified Profiles
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
                    'Social Recon',
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
                child: const Icon(Icons.radar_rounded, color: Color(0xFF2979FF), size: 24),
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
              prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF2979FF)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF2979FF)),
                onPressed: () => _startScan(),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0)),
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
            style: const TextStyle(fontSize: 13, color: Color(0xFF2979FF), fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Interrogating Instagram, X, Threads, YouTube, GitHub for "@$_activeQuery"...',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
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
      desc = 'This handle is indexed across multiple major social & developer platforms. High correlation footprint.';
    } else if (count >= 2) {
      levelColor = const Color(0xFFFFB300);
      levelText = 'MODERATE EXPOSURE';
      desc = 'Confirmed public accounts found across major social networks and code repositories.';
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
                  '$count Profiles Found',
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
                width: 56,
                height: 56,
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
                'OSINT Hygiene & Defense',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.amber),
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
          Icon(Icons.search_off_rounded, size: 40, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            'No Public Accounts Found on Core Index',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'This handle does not appear publicly on Instagram, X, Threads, YouTube, Telegram, or GitHub.',
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
