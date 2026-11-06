import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/visual_osint_engine.dart';
import '../url_scanner/in_app_browser_screen.dart';

enum _OsintTab { username, reverseImage }

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
  final _imagePicker = ImagePicker();
  final _imageUrlController = TextEditingController();
  final _compareHashController = TextEditingController();

  bool _isImageAnalyzing = false;
  String _imageScanStep = '';
  VisualOsintResult? _imageResult;
  String? _selectedImagePath;
  String? _activeImageUrl;
  double? _comparedSimilarity;

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
    _activeTab = widget.initialTab == 1 ? _OsintTab.reverseImage : _OsintTab.username;
  }

  @override
  void dispose() {
    _controller.dispose();
    _imageUrlController.dispose();
    _compareHashController.dispose();
    _dio.close();
    super.dispose();
  }

  void _setImageStep(String step) {
    if (mounted) setState(() => _imageScanStep = step);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      HapticFeedback.lightImpact();
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );

      if (picked != null) {
        setState(() {
          _selectedImagePath = picked.path;
          _activeImageUrl = null;
          _imageResult = null;
          _comparedSimilarity = null;
        });
        await _analyzeLocalFile(picked.path);
      }
    } catch (e) {
      _showToast('Failed to access camera/gallery: $e');
    }
  }

  Future<void> _analyzeLocalFile(String filePath) async {
    setState(() {
      _isImageAnalyzing = true;
      _imageScanStep = 'Computing cryptographic hashes & 64-bit dHash...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 150));
      _setImageStep('Running on-device OCR & scam entity detection...');
      final res = await VisualOsintEngine.analyze(localFilePath: filePath);
      if (mounted) {
        setState(() {
          _imageResult = res;
          _isImageAnalyzing = false;
          _imageScanStep = '';
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImageAnalyzing = false;
          _imageScanStep = '';
        });
        _showToast('Analysis error: $e');
      }
    }
  }

  Future<void> _analyzeImageUrl(String url) async {
    final clean = url.trim();
    if (clean.isEmpty || (!clean.startsWith('http://') && !clean.startsWith('https://'))) {
      _showToast('Please enter a valid HTTP/HTTPS image URL');
      return;
    }

    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    setState(() {
      _isImageAnalyzing = true;
      _selectedImagePath = null;
      _activeImageUrl = clean;
      _imageResult = null;
      _comparedSimilarity = null;
      _imageScanStep = 'Fetching remote image bytes securely...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      _setImageStep('Generating multi-engine queries across 6 search indices...');
      final res = await VisualOsintEngine.analyze(imageUrl: clean);
      if (mounted) {
        setState(() {
          _imageResult = res;
          _isImageAnalyzing = false;
          _imageScanStep = '';
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImageAnalyzing = false;
          _imageScanStep = '';
        });
        _showToast('Failed to download image: $e');
      }
    }
  }

  void _loadSampleScamNotice() {
    const sampleText = '''
CENTRAL BUREAU OF INVESTIGATION (CBI) - CYBER CRIME CELL
NEW DELHI HEADQUARTERS
NOTICE OF DIGITAL ARREST & NON-BAILABLE WARRANT
Case Reference: PMLA/NCB/2026/09428-B
To: Accused Person
You are placed under immediate DIGITAL ARREST under Section 420 IPC and IT Act Section 66D.
Money laundering and illegal narcotics trafficking detected via your Aadhaar linked bank accounts.
Do not disconnect video call verification. Transfer security clearance deposit to verified RBI vault:
Target UPI ID: centralvault.clearance@okhdfcbank
Penalty Amount: ₹98,500
Failure to comply will lead to immediate physical property attachment.
    ''';

    setState(() {
      _selectedImagePath = null;
      _activeImageUrl = null;
      _isImageAnalyzing = true;
      _imageScanStep = 'Emulating forensic sample scan...';
    });

    Future.delayed(const Duration(milliseconds: 250), () async {
      const hashes = VisualHashReport(
        sha256: '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
        md5: '5d41402abc4b2a76b9719d911017c592',
        sha1: '2fd4e1c67a2d28fced849ee1bb76e7391b93eb12',
        dHash: 'F8C0E0E0E0C08000',
        fileSizeBytes: 245600,
        width: 1080,
        height: 1920,
        mimeType: 'image/jpeg',
      );

      final ocr = VisualOsintEngine.inspectTextForensics(sampleText);
      final queries = VisualOsintEngine.generateEngineQueries('https://via.placeholder.com/1080x1920.png?text=CBI+Sample');
      final assess = VisualOsintEngine.evaluateThreat(hashes, ocr, 'https://via.placeholder.com/1080x1920.png');

      if (mounted) {
        setState(() {
          _imageResult = VisualOsintResult(
            imageUrl: 'https://via.placeholder.com/1080x1920.png?text=CBI+Sample',
            hashes: hashes,
            ocrEntities: ocr,
            engineQueries: queries,
            assessment: assess,
            inspectedAt: DateTime.now(),
          );
          _isImageAnalyzing = false;
          _imageScanStep = '';
        });
      }
    });
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

  void _exportImageForensicReport() {
    if (_imageResult == null) return;
    final r = _imageResult!;
    final buffer = StringBuffer();
    buffer.writeln('====================================================');
    buffer.writeln('SAFESIGNAL TITAN VISUAL OSINT & FORENSIC EVIDENCE REPORT');
    buffer.writeln('Generated: ${r.inspectedAt.toIso8601String()}');
    buffer.writeln('====================================================\n');
    buffer.writeln('1. CRYPTOGRAPHIC INTEGRITY');
    buffer.writeln('SHA-256 : ${r.hashes.sha256}');
    buffer.writeln('MD5     : ${r.hashes.md5}');
    buffer.writeln('64-dHash: ${r.hashes.dHash}');
    buffer.writeln('Size    : ${(r.hashes.fileSizeBytes / 1024).toStringAsFixed(1)} KB');
    buffer.writeln('Format  : ${r.hashes.mimeType} (${r.hashes.width ?? "?"}x${r.hashes.height ?? "?"}px)\n');
    buffer.writeln('2. THREAT ASSESSMENT');
    buffer.writeln('Verdict : ${r.assessment.verdictTitle}');
    buffer.writeln('Score   : ${r.assessment.threatScore}/100 (${r.assessment.threatLevel.name.toUpperCase()})');
    buffer.writeln('Category: ${r.assessment.primaryThreatType}\n');
    buffer.writeln('3. DETECTED EXTORTION / FRAUD ENTITIES');
    buffer.writeln('Authorities  : ${r.ocrEntities.detectedInstitutions.join(", ")}');
    buffer.writeln('Scam Triggers: ${r.ocrEntities.detectedScamKeywords.join(", ")}');
    buffer.writeln('Extracted UPI: ${r.ocrEntities.detectedUpiIds.join(", ")}');
    buffer.writeln('Phone Numbers: ${r.ocrEntities.detectedPhoneNumbers.join(", ")}');
    buffer.writeln('Amounts      : ${r.ocrEntities.detectedAmounts.join(", ")}\n');
    buffer.writeln('4. REVERSE ENGINE SOURCES');
    for (final q in r.engineQueries) {
      buffer.writeln('- ${q.engineName}: ${q.queryUrl}');
    }
    buffer.writeln('\n====================================================');
    buffer.writeln('Report this evidence to National Cyber Crime Portal (1930)');

    _copyToClipboard(buffer.toString(), 'Full Forensic Evidence Report');
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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : const Color(0xFF0D1117),
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Digital OSINT Suite',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 19,
                color: isDark ? Colors.white : const Color(0xFF0D1117),
                letterSpacing: -0.5,
              ),
            ),
            Text(
              _activeTab == _OsintTab.username
                  ? 'Public Handles & Profile Intel'
                  : 'Multi-Engine Visual Recon & OCR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (_activeTab == _OsintTab.reverseImage && _imageResult != null)
            IconButton(
              tooltip: 'Export Forensic Evidence Report',
              icon: const Icon(Icons.share_outlined, color: Color(0xFF00E5FF), size: 21),
              onPressed: _exportImageForensicReport,
            ),
          IconButton(
            tooltip: 'Clear & Reset',
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white60 : Colors.black54,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                if (_activeTab == _OsintTab.username) {
                  _controller.clear();
                  _state = _ScanState.idle;
                  _foundProfiles.clear();
                  _unconfirmedLinks.clear();
                } else {
                  _imageUrlController.clear();
                  _compareHashController.clear();
                  _selectedImagePath = null;
                  _activeImageUrl = null;
                  _imageResult = null;
                  _comparedSimilarity = null;
                }
              });
            },
          ),
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

              // Reverse Image Recon Tab
              if (_activeTab == _OsintTab.reverseImage) ...[
                _buildImageSearchCard(isDark),
                const SizedBox(height: 16),

                if (_isImageAnalyzing) _buildImageScanningProgress(isDark),

                if (_imageResult != null) ...[
                  _buildVisualResultsSection(_imageResult!, isDark),
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
              title: 'Reverse Image Recon',
              icon: Icons.image_search_rounded,
              isSelected: _activeTab == _OsintTab.reverseImage,
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeTab = _OsintTab.reverseImage);
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
        padding: const EdgeInsets.symmetric(vertical: 10),
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
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSearchCard(bool isDark) {
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
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.image_search_rounded,
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
                      'Visual Reverse Search & Forensics',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        color: isDark ? Colors.white : const Color(0xFF0D1117),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Detect fake warrants, scammers & web appearances',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Upload Options
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF2979FF),
                  isDark: isDark,
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFF00E5FF),
                  isDark: isDark,
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.receipt_long_rounded,
                  label: 'Sample',
                  color: const Color(0xFFA855F7),
                  isDark: isDark,
                  onTap: _loadSampleScamNotice,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Divider
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'OR SCAN REMOTE URL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // URL Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _imageUrlController,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'https://example.com/scam-notice.jpg',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    prefixIcon: const Icon(Icons.link_rounded, size: 18),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0A0F1A) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: _analyzeImageUrl,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _analyzeImageUrl(_imageUrlController.text),
              ),
            ],
          ),

          // Selected Image Preview if local or remote
          if (_selectedImagePath != null && File(_selectedImagePath!).existsSync()) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_selectedImagePath!),
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ] else if (_activeImageUrl != null && _activeImageUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _activeImageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageScanningProgress(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          const LinearProgressIndicator(
            backgroundColor: Color(0xFF0D1117),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _imageScanStep.isEmpty ? 'Processing image...' : _imageScanStep,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildVisualResultsSection(VisualOsintResult r, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Threat Assessment Header
        _buildVisualThreatHeader(r.assessment, isDark),
        const SizedBox(height: 22),

        // Search Engines
        Row(
          children: [
            Text(
              'GLOBAL REVERSE SEARCH ENGINES & FINDINGS',
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
                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${r.engineQueries.length}',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Engine Cards
        ...r.engineQueries.map((q) => _buildVisualEngineCard(q, isDark)),
        const SizedBox(height: 22),

        // OCR Extortion findings if detected
        if (r.ocrEntities.isFraudulentDocument || r.ocrEntities.rawText.isNotEmpty) ...[
          _buildOcrFindingsCard(r.ocrEntities, isDark),
          const SizedBox(height: 22),
        ],

        // Hashes Card
        _buildHashesCard(r.hashes, isDark),
        const SizedBox(height: 22),

        // Clone / Perceptual Hash Comparator Card
        _buildCloneComparatorCard(r.hashes.dHash, isDark),
      ],
    );
  }

  Widget _buildVisualThreatHeader(VisualThreatAssessment a, bool isDark) {
    final color = switch (a.threatLevel) {
      VisualThreatLevel.critical => const Color(0xFFFF1744),
      VisualThreatLevel.high => const Color(0xFFFF5252),
      VisualThreatLevel.medium => const Color(0xFFFF9100),
      VisualThreatLevel.low => const Color(0xFFFFEA00),
      VisualThreatLevel.safe => const Color(0xFF00E676),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            isDark ? const Color(0xFF131926) : Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  a.threatLevel == VisualThreatLevel.safe
                      ? Icons.verified_user_rounded
                      : Icons.security_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  a.verdictTitle,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${a.threatScore}/100',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            a.primaryThreatType,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0D1117),
            ),
          ),
          if (a.findings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...a.findings.take(3).map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _exportImageForensicReport,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Export Forensic Evidence Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildVisualEngineCard(ReverseEngineQuery q, bool isDark) {
    final (Color brandColor, IconData icon) = switch (q.engineKey) {
      'google_lens' => (const Color(0xFF4285F4), Icons.travel_explore_rounded),
      'yandex' => (const Color(0xFFFC3F1D), Icons.saved_search_rounded),
      'tineye' => (const Color(0xFF00B4D8), Icons.manage_search_rounded),
      'bing' => (const Color(0xFF008373), Icons.search_rounded),
      'baidu' => (const Color(0xFF2932E1), Icons.radar_rounded),
      _ => (const Color(0xFFE67E22), Icons.auto_awesome_rounded),
    };

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
          // Header Banner
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: brandColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: brandColor),
                    const SizedBox(width: 5),
                    Text(
                      q.engineName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: brandColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  q.specialization,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (q.isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'CORE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF00E5FF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            q.description,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),

          // Query URL snippet
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A0F1A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              q.queryUrl,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InAppBrowserScreen(url: q.queryUrl),
                      ),
                    );
                  },
                  icon: const Icon(Icons.travel_explore_rounded, size: 16),
                  label: const Text(
                    'Search Lens',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Open in Browser',
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _openUrl(q.queryUrl),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'Copy Query Link',
                icon: const Icon(Icons.copy_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _copyToClipboard(q.queryUrl, '${q.engineName} Query URL'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildOcrFindingsCard(OcrEntityExtraction ocr, bool isDark) {
    final hasThreatEntities = ocr.isFraudulentDocument ||
        ocr.detectedInstitutions.isNotEmpty ||
        ocr.detectedScamKeywords.isNotEmpty ||
        ocr.detectedUpiIds.isNotEmpty;

    final headerColor = hasThreatEntities ? const Color(0xFFFF5252) : const Color(0xFF00E5FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: headerColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: headerColor.withValues(alpha: 0.06),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: headerColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasThreatEntities ? Icons.warning_amber_rounded : Icons.document_scanner_rounded,
                  color: headerColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasThreatEntities ? 'OCR EXTORTION & FRAUD DETECTED' : 'OCR DOCUMENT FORENSICS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: headerColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      ocr.documentCategory,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (ocr.detectedInstitutions.isNotEmpty) ...[
            Text(
              'IMPERSONATED AUTHORITIES',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white38 : Colors.black45,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ocr.detectedInstitutions.map((inst) {
                return Chip(
                  backgroundColor: const Color(0xFFFF5252).withValues(alpha: 0.15),
                  side: BorderSide(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
                  label: Text(
                    inst,
                    style: const TextStyle(
                      color: Color(0xFFFF5252),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          if (ocr.detectedScamKeywords.isNotEmpty) ...[
            Text(
              'DETECTED FRAUD & EXTORTION PHRASES',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white38 : Colors.black45,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ocr.detectedScamKeywords.map((kw) {
                return Chip(
                  backgroundColor: const Color(0xFFFF9100).withValues(alpha: 0.15),
                  side: BorderSide(color: const Color(0xFFFF9100).withValues(alpha: 0.4)),
                  label: Text(
                    kw.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFFF9100),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          if (ocr.detectedUpiIds.isNotEmpty) ...[
            Text(
              'EXTRACTED PAYMENT VENDOR / UPI IDs',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white38 : Colors.black45,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            ...ocr.detectedUpiIds.map((upi) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0A0F1A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2979FF).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Color(0xFF2979FF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        upi,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF2979FF),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _copyToClipboard(upi, 'UPI ID'),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),
          ],

          if (ocr.detectedPhoneNumbers.isNotEmpty) ...[
            Text(
              'EXTRACTED CONTACT NUMBERS',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white38 : Colors.black45,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: ocr.detectedPhoneNumbers.map((phone) {
                return ActionChip(
                  avatar: const Icon(Icons.phone_rounded, size: 12, color: Colors.white70),
                  label: Text(phone, style: const TextStyle(fontSize: 11)),
                  onPressed: () => _copyToClipboard(phone, 'Phone number'),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildHashesCard(VisualHashReport h, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint_rounded, color: Color(0xFF00E5FF), size: 20),
              const SizedBox(width: 8),
              Text(
                'CRYPTOGRAPHIC & PERCEPTUAL SIGNATURES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildHashRow('64-bit dHash (Perceptual)', h.dHash, isDark, isHighlight: true),
          const SizedBox(height: 8),
          _buildHashRow('SHA-256 Checksum', h.sha256, isDark),
          const SizedBox(height: 8),
          _buildHashRow('MD5 Legacy Hash', h.md5, isDark),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetaPill('Size', '${(h.fileSizeBytes / 1024).toStringAsFixed(1)} KB', isDark),
              _buildMetaPill('Type', h.mimeType.toUpperCase(), isDark),
              if (h.width != null && h.height != null)
                _buildMetaPill('Resolution', '${h.width}x${h.height} px', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHashRow(String title, String val, bool isDark, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: isHighlight
                ? const Color(0xFF00E5FF)
                : (isDark ? Colors.white38 : Colors.black45),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: Text(
                val,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 14),
              visualDensity: VisualDensity.compact,
              onPressed: () => _copyToClipboard(val, title),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetaPill(String k, String v, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0F1A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        '$k: $v',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildCloneComparatorCard(String currentDHash, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131926) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_rounded, color: Color(0xFFA855F7), size: 20),
              const SizedBox(width: 8),
              Text(
                'CLONE & TAMPER DETECTOR (dHash Matching)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Paste another image dHash to compute Hamming distance and detect cropped or re-encoded clones.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _compareHashController,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter 16-hex char dHash...',
                    hintStyle: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0A0F1A) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final target = _compareHashController.text.trim();
                  if (target.isEmpty) return;
                  final sim = VisualOsintEngine.calculateVisualSimilarity(currentDHash, target);
                  setState(() => _comparedSimilarity = sim);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA855F7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                child: const Text('Compare', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          if (_comparedSimilarity != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _comparedSimilarity! >= 80.0
                    ? const Color(0xFFFF5252).withValues(alpha: 0.12)
                    : const Color(0xFF00E5FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _comparedSimilarity! >= 80.0
                      ? const Color(0xFFFF5252).withValues(alpha: 0.4)
                      : const Color(0xFF00E5FF).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _comparedSimilarity! >= 80.0
                        ? Icons.copy_all_rounded
                        : Icons.check_circle_outline_rounded,
                    color: _comparedSimilarity! >= 80.0
                        ? const Color(0xFFFF5252)
                        : const Color(0xFF00E5FF),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _comparedSimilarity! >= 80.0
                          ? 'HIGH MATCH (${_comparedSimilarity!.toStringAsFixed(1)}%): Visual clone or cropped derivative detected!'
                          : 'LOW MATCH (${_comparedSimilarity!.toStringAsFixed(1)}%): Distinct visual composition.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _comparedSimilarity! >= 80.0
                            ? const Color(0xFFFF5252)
                            : const Color(0xFF00E5FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
