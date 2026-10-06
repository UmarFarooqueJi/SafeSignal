import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/alert_model.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<AlertModel> _alerts = [];
  bool _loading = true;
  String _selectedCategory = 'all';
  String? _errorMessage;

  // Category definitions: (id, display label, emoji)
  static const _categoryDefs = [
    ('all',            'All Alerts',       '🔔'),
    ('new',            'Latest',           '⚡'),
    ('digital_arrest', 'Digital Arrest',   '⚖️'),
    ('investment',     'Investment Fraud', '📈'),
    ('otp',            'OTP & SIM Swap',   '📱'),
    ('lottery',        'Lottery Scams',    '🎁'),
    ('phishing',       'Phishing Links',   '🎣'),
    ('general',        'Cyber Intel',      '🛡️'),
  ];

  @override
  void initState() {
    super.initState()
    ;
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 12),
      ));

      final allItems = <dynamic>[];

      // Open-source Keyless Public Aggregator: Fetch live Indian Cyber Fraud & Hacker News RSS feeds
      final inQuery = Uri.encodeComponent('https://news.google.com/rss/search?q=cyber+scam+OR+fraud+OR+"digital+arrest"+india&hl=en-IN&gl=IN&ceid=IN:en');
        final thnQuery = Uri.encodeComponent('https://feeds.feedburner.com/TheHackersNews');

        final rssResults = await Future.wait([
          dio.get('https://api.rss2json.com/v1/api.json?rss_url=$inQuery'),
          dio.get('https://api.rss2json.com/v1/api.json?rss_url=$thnQuery'),
        ]);

        for (final r in rssResults) {
          if (r.statusCode == 200 && r.data != null && r.data['status'] == 'ok') {
            final items = r.data['items'] as List? ?? [];
            allItems.addAll(items);
          }
        }

      if (allItems.isNotEmpty) {
        final parsed = _NewsDataParser.parse(allItems);
        parsed.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        setState(() {
          _alerts = parsed;
          _loading = false;
        });
      } else {
        throw Exception('No articles returned from online feeds');
      }
    } catch (e) {
      debugPrint('News fetch error: $e');
      setState(() {
        _alerts = AlertModel.mockAlerts();
        _loading = false;
        _errorMessage = 'Online news unavailable. Showing offline alerts.';
      });
    }
  }

  List<AlertModel> get _filtered {
    if (_selectedCategory == 'all') return _alerts;
    if (_selectedCategory == 'new') {
      return _alerts.where((a) => a.isNew).toList();
    }
    return _alerts.where((a) => a.category == _selectedCategory).toList();
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF06090F) : Colors.white;
    final textThemeColor = isDark ? Colors.white : const Color(0xFF0D1117);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo_transparent.png',
              width: 38,
              height: 38,
            ),
            const SizedBox(width: 12),
            Text(
              'Scam Alerts',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: textThemeColor,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _fetchNews,
            icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : Colors.black87),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _categoryDefs.length,
              itemBuilder: (context, i) {
                final cat = _categoryDefs[i];
                final isSelected = _selectedCategory == cat.$1;
                // Count items for this category
                int count = 0;
                if (!_loading) {
                  if (cat.$1 == 'all') {
                    count = _alerts.length;
                  } else if (cat.$1 == 'new') {
                    count = _alerts.where((a) => a.isNew).length;
                  } else {
                    count = _alerts.where((a) => a.category == cat.$1).length;
                  }
                }
                return GestureDetector(
                  onTap: () {
                    if (_selectedCategory != cat.$1) {
                      setState(() => _selectedCategory = cat.$1);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            )
                          : null,
                      color: isSelected
                          ? null
                          : (isDark ? const Color(0xFF131D32) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF3B82F6)
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat.$3, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 5),
                        Text(
                          cat.$2,
                          style: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF334155)),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        if (!_loading && count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withValues(alpha: 0.22) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade900.withValues(alpha: 0.2),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF2563EB)),
                        const SizedBox(height: 16),
                        Text(
                          'Aggregating real-time cyber threat feeds...',
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: const Color(0xFF2563EB),
                    onRefresh: _fetchNews,
                    child: _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.newspaper_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                                const SizedBox(height: 16),
                                Text(
                                  'No threat advisories found in this category',
                                  style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) => _AlertCard(
                              alert: _filtered[i],
                              index: i,
                              isDark: isDark,
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Alert Card ───────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final AlertModel alert;
  final int index;
  final bool isDark;

  const _AlertCard({required this.alert, required this.index, required this.isDark});

  Color get _categoryColor {
    switch (alert.category) {
      case 'digital_arrest':
        return const Color(0xFFD32F2F);
      case 'investment':
        return const Color(0xFFE65100);
      case 'otp':
        return const Color(0xFF1565C0);
      case 'lottery':
        return const Color(0xFF6A1B9A);
      default:
        return const Color(0xFF455A64);
    }
  }

  IconData get _categoryIcon {
    switch (alert.category) {
      case 'digital_arrest':
        return Icons.local_police_rounded;
      case 'investment':
        return Icons.monetization_on_rounded;
      case 'otp':
        return Icons.password_rounded;
      case 'loan':
        return Icons.account_balance_rounded;
      case 'job':
        return Icons.work_rounded;
      case 'phishing':
        return Icons.phishing_rounded;
      default:
        return Icons.warning_rounded;
    }
  }

  String get _categoryLabel {
    switch (alert.category) {
      case 'digital_arrest':
        return 'Arrest Scam';
      case 'investment':
        return 'Investment Fraud';
      case 'otp':
        return 'OTP Fraud';
      case 'lottery':
        return 'Lottery Scam';
      default:
        return 'Safety Update';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) return 'Abhi abhi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minute pehle';
    if (diff.inHours < 24) return '${diff.inHours} ghante pehle';
    return '${diff.inDays} din pehle';
  }

  Future<void> _openNews(BuildContext context) async {
    if (alert.sourceUrl == null) return;
    try {
      final uri = Uri.parse(alert.sourceUrl!);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _shareNews(BuildContext context) {
    final shareText = '🚨 ${alert.headline}\n\n${alert.summary.substring(0, alert.summary.length.clamp(0, 80))}...\n\n🔗 ${alert.sourceUrl ?? 'SafeSignal App'}\n\nStay safe with SafeSignal!';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('News link clipboard mein copy ho gaya!', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B27) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE8EEF8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(_categoryIcon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  _categoryLabel.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                if (alert.isNew)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
          ),

          ClipRRect(
            child: alert.imageUrl != null 
              ? Image.network(
                  alert.imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Image.asset(
                    'assets/images/news_fallback.png',
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  'assets/images/news_fallback.png',
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.headline,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.35,
                    color: isDark ? Colors.white : const Color(0xFF0D1117),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  alert.summary,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: isDark ? Colors.white30 : Colors.black38),
                    const SizedBox(width: 4),
                    Text(
                      _timeAgo(alert.publishedAt),
                      style: TextStyle(
                        color: isDark ? Colors.white30 : Colors.black38,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Share button
                    InkWell(
                      onTap: () => _shareNews(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.share_outlined, size: 14, color: isDark ? Colors.white38 : Colors.black38),
                            const SizedBox(width: 3),
                            Text(
                              'Share',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Read More action link
                    InkWell(
                      onTap: () => _openNews(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Poori Padhein',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.open_in_new, size: 13, color: color),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 40)).slideY(begin: 0.1);
  }
}

// ─── JSON NewsData & RSS Feed Parser ─────────────────────────────────────────
class _NewsDataParser {
  static String _cleanText(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<AlertModel> parse(List results) {
    final list = <AlertModel>[];
    final seenIds = <String>{};
    int count = 0;
    final now = DateTime.now();

    for (final item in results) {
      if (item is! Map) continue;

      final id = item['guid']?.toString() ??
          item['article_id']?.toString() ??
          item['link']?.toString() ??
          'news_${count++}';
      if (seenIds.contains(id)) continue;
      seenIds.add(id);

      final rawTitle = item['title']?.toString() ?? 'Scam Alert';
      final title = _cleanText(rawTitle);

      final rawDesc = item['description']?.toString() ?? item['content']?.toString() ?? '';
      final description = _cleanText(rawDesc);

      final link = item['link']?.toString();
      final pubDateStr = item['pubDate']?.toString();

      String? imageUrl;
      if (item['image_url'] != null && item['image_url'].toString().isNotEmpty) {
        imageUrl = item['image_url'].toString();
      } else if (item['enclosure'] is Map && item['enclosure']['link'] != null) {
        imageUrl = item['enclosure']['link'].toString();
      } else if (item['thumbnail'] != null && item['thumbnail'].toString().isNotEmpty) {
        imageUrl = item['thumbnail'].toString();
      }

      String source = item['source_id']?.toString() ?? '';
      if (source.isEmpty && item['author'] != null) {
        source = item['author'].toString();
      }
      if (source.isEmpty && link != null) {
        try {
          source = Uri.parse(link).host.replaceAll('www.', '');
        } catch (_) {}
      }
      if (source.isEmpty) source = 'Cyber News';

      DateTime publishedAt;
      try {
        publishedAt = DateTime.parse(pubDateStr ?? '');
      } catch (_) {
        publishedAt = now.subtract(Duration(hours: count * 2));
      }

      // isNew: published within last 24 hours
      final isNew = now.difference(publishedAt).inHours < 24;

      // Category detection — check both title and description
      final lowerText = '${title.toLowerCase()} ${description.toLowerCase()}';
      String category = 'general';
      if (lowerText.contains('arrest') || lowerText.contains('digital arrest') || lowerText.contains('cbi') || lowerText.contains('police call')) {
        category = 'digital_arrest';
      } else if (lowerText.contains('phishing') || lowerText.contains('fake website') || lowerText.contains('fake bank') || lowerText.contains('clone site')) {
        category = 'phishing';
      } else if (lowerText.contains('otp') || lowerText.contains('sim swap') || lowerText.contains('sms scam') || lowerText.contains('sim cloning') || lowerText.contains('aadhaar link')) {
        category = 'otp';
      } else if (lowerText.contains('invest') || lowerText.contains('trading') || lowerText.contains('earn') || lowerText.contains('profit') || lowerText.contains('crypto') || lowerText.contains('return')) {
        category = 'investment';
      } else if (lowerText.contains('lottery') || lowerText.contains('won') || lowerText.contains('prize') || lowerText.contains('kbc') || lowerText.contains('lucky winner')) {
        category = 'lottery';
      }

      list.add(
        AlertModel(
          id: id,
          headline: title,
          summary: description.isNotEmpty
              ? description
              : 'Cybercrime alert from $source. Read the full news article below.',
          sourceUrl: link,
          imageUrl: imageUrl,
          isTrending: count <= 3,
          publishedAt: publishedAt,
          category: category,
          isNew: isNew,
        ),
      );

      count++;
    }
    return list;
  }
}
