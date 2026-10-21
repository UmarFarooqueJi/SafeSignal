import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<_HistoryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();

    // Load from AI chat analysis history
    final chatHistory = prefs.getStringList('chat_analysis_history') ?? [];

    // Load from SMS inbox (reads 'sms_inbox' with backward-compatibility for legacy key)
    final smsJson = prefs.getString('sms_inbox') ?? prefs.getString('flutter.sms_inbox') ?? '[]';
    List<dynamic> smsList = [];
    try {
      smsList = json.decode(smsJson) as List<dynamic>;
    } catch (_) {}

    final List<_HistoryItem> items = [];

    // Parse chat analysis items
    for (final raw in chatHistory) {
      try {
        final m = json.decode(raw) as Map<String, dynamic>;
        items.add(_HistoryItem(
          text: m['text'] as String? ?? '',
          verdict: m['verdict'] as String? ?? 'UNCERTAIN',
          confidence: (m['confidence'] as num?)?.toDouble() ?? 0.5,
          time: DateTime.tryParse(m['time'] as String? ?? '') ?? DateTime.now(),
          source: 'AI Chat',
        ));
      } catch (_) {}
    }

    // Parse SMS inbox items
    for (final raw in smsList.take(50)) {
      try {
        final m = raw as Map<String, dynamic>;
        final verdict = m['verdict'] as String? ?? 'SAFE';
        final confidence = ((m['confidence'] as num?)?.toInt() ?? 50) / 100.0;
        items.add(_HistoryItem(
          text: '${m['sender'] ?? 'SMS'}: ${m['body'] ?? ''}',
          verdict: verdict == 'SCAM'
              ? 'SCAM'
              : verdict == 'CAUTION'
                  ? 'UNCERTAIN'
                  : 'LIKELY_SAFE',
          confidence: confidence,
          time: DateTime.tryParse(m['receivedAt'] as String? ?? '') ?? DateTime.now(),
          source: 'SMS',
        ));
      } catch (_) {}
    }

    // Sort newest first
    items.sort((a, b) => b.time.compareTo(a.time));

    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('History Clear Karo?'),
        content: const Text('AI chat analysis history delete ho jaayegi. SMS Inbox data safe rahega.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('chat_analysis_history');
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF060A12) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Analysis History',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: isDark ? Colors.white : const Color(0xFF0D1117),
          ),
        ),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined,
                  color: isDark ? Colors.white54 : Colors.black38),
              onPressed: _clearHistory,
              tooltip: 'Clear chat history',
            ),
          IconButton(
            icon: Icon(Icons.refresh_outlined,
                color: isDark ? Colors.white54 : Colors.black38),
            onPressed: _loadHistory,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmpty(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: _items.length,
                  itemBuilder: (context, i) =>
                      _HistoryCard(item: _items[i], isDark: isDark, index: i),
                ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF2979FF).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_outlined,
                  size: 42, color: Color(0xFF2979FF)),
            ).animate().scale(begin: const Offset(0.7, 0.7)).fadeIn(),
            const SizedBox(height: 24),
            Text(
              'Koi Analysis Nahi Abhi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0D1117),
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 12),
            Text(
              'AI Chat mein koi message check karo ya koi SMS aane do — sab yahan dikh jaayega.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ).animate().fadeIn(delay: 180.ms),
          ],
        ),
      ),
    );
  }
}

// ─── History Card ─────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final _HistoryItem item;
  final bool isDark;
  final int index;
  const _HistoryCard(
      {required this.item, required this.isDark, required this.index});

  Color get _verdictColor {
    switch (item.verdict) {
      case 'SCAM':
        return const Color(0xFFEF5350);
      case 'UNCERTAIN':
        return const Color(0xFFFFB300);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  String get _verdictEmoji {
    switch (item.verdict) {
      case 'SCAM':
        return '🔴';
      case 'UNCERTAIN':
        return '⚠️';
      default:
        return '🟢';
    }
  }

  String get _verdictLabel {
    switch (item.verdict) {
      case 'SCAM':
        return 'SCAM';
      case 'UNCERTAIN':
        return 'SUSPICIOUS';
      default:
        return 'SAFE';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Abhi abhi';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m pehle';
    if (diff.inHours < 24) return '${diff.inHours}h pehle';
    if (diff.inDays < 7) return '${diff.inDays}d pehle';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final vc = _verdictColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1724) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3347) : const Color(0xFFE8EEF8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Verdict badge
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: vc.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child:
                  Text(_verdictEmoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Source badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2979FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.source,
                        style: const TextStyle(
                          color: Color(0xFF2979FF),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Verdict chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: vc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: vc.withValues(alpha: 0.3), width: 0.8),
                      ),
                      child: Text(
                        _verdictLabel,
                        style: TextStyle(
                          color: vc,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_outlined,
                        size: 11,
                        color:
                            isDark ? Colors.white30 : Colors.black26),
                    const SizedBox(width: 4),
                    Text(
                      _timeAgo(item.time),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Confidence bar
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: item.confidence,
                          backgroundColor: isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(vc),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${(item.confidence * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: vc,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 35)).slideX(begin: 0.03);
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────
class _HistoryItem {
  final String text;
  final String verdict;
  final double confidence;
  final DateTime time;
  final String source;

  const _HistoryItem({
    required this.text,
    required this.verdict,
    required this.confidence,
    required this.time,
    required this.source,
  });
}
