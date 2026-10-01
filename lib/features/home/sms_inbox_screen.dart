import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/services/crowd_intel_service.dart';
import '../../core/services/local_rule_engine.dart';

class SmsInboxScreen extends StatefulWidget {
  const SmsInboxScreen({super.key});

  @override
  State<SmsInboxScreen> createState() => _SmsInboxScreenState();
}

class _SmsInboxScreenState extends State<SmsInboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SmsRecord> _allSms = [];
  bool _loading = true;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
    _loadSms();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSms() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('sms_inbox');
    List<dynamic> jsonList = [];
    if (jsonString != null) {
      try {
        jsonList = json.decode(jsonString) as List<dynamic>;
      } catch (_) {}
    }
    
    final records = jsonList.map((m) {
      try {
        return SmsRecord.fromJson(m as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<SmsRecord>().toList();

    // Sort newest first
    records.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

    setState(() {
      _allSms = records;
      _loading = false;
    });
  }

  List<SmsRecord> get _filtered {
    switch (_tabIndex) {
      case 1:
        return _allSms.where((s) => s.verdict == 'SCAM' || s.verdict == 'CAUTION').toList();
      case 2:
        return _allSms.where((s) => s.verdict == 'SAFE').toList();
      default:
        return _allSms;
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sab Delete Karo?'),
        content: const Text('Saari saved SMS delete ho jaayengi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sms_inbox');
      setState(() => _allSms = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0D1117), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'SMS Inbox',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: Color(0xFF0D1117),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.phonelink_lock_rounded, color: Color(0xFF0D1117)),
            onPressed: () => context.push('/otp-guard'),
            tooltip: 'SIM Hijack & USSD Tools',
          ),
          if (_allSms.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFF0D1117)),
              onPressed: _clearAll,
              tooltip: 'Clear All',
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0D1117),
          unselectedLabelColor: const Color(0xFF0D1117).withValues(alpha: 0.5),
          indicatorColor: const Color(0xFF0D1117),
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          tabs: [
            Tab(
              icon: const Icon(Icons.all_inbox_outlined, size: 18),
              text: 'All (${_allSms.length})',
            ),
            Tab(
              icon: const Icon(Icons.warning_amber_outlined, size: 18),
              text: 'Scam (${_allSms.where((s) => s.verdict == 'SCAM' || s.verdict == 'CAUTION').length})',
            ),
            Tab(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              text: 'Safe (${_allSms.where((s) => s.verdict == 'SAFE').length})',
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB), Color(0xFF90CAF9)],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? Center(
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(
                          width: 80, height: 80,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            color: Color(0xFF2979FF),
                          ),
                        ),
                        Image.asset('assets/images/logo_transparent.png', width: 40, height: 40)
                            .animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1)),
                      ],
                    ),
                  ),
                )
              : _filtered.isEmpty
                  ? _buildEmpty(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) => _SmsCard(
                        sms: _filtered[i],
                        isDark: isDark,
                        index: i,
                      ),
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showManualScanSheet(context),
        backgroundColor: const Color(0xFF2979FF),
        icon: const Icon(Icons.add_comment_outlined, color: Colors.white),
        label: const Text('SMS Scan Karo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _showManualScanSheet(BuildContext context) {
    final ctrl = TextEditingController();
    final senderCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('SMS Paste Karo — Scan Karein', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0D1117))),
              const SizedBox(height: 6),
              const Text('Koi bhi suspicious SMS yahan paste karo aur SafeSignal turant batayega.', style: TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: senderCtrl,
                decoration: InputDecoration(
                  labelText: 'Sender (optional, e.g. +91-9999999999)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.person_outline),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'SMS text yahan paste karo...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 64),
                    child: Icon(Icons.sms_outlined),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final text = ctrl.text.trim();
                    final sender = senderCtrl.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(ctx);
                    await _analyzeAndSave(text, sender.isEmpty ? 'Manual Scan' : sender);
                  },
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Scan Karo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2979FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _analyzeAndSave(String body, String sender) async {
    // Run upgraded enterprise offline rule engine with TRAI DLT and APK dropper logic
    final engineVerdict = LocalRuleEngine().analyze(body, sender: sender);

    final record = SmsRecord(
      sender: sender,
      body: body,
      verdict: engineVerdict.verdict,
      confidence: engineVerdict.riskScore,
      reason: engineVerdict.reasons.join('; '),
      receivedAt: DateTime.now(),
    );
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('sms_inbox');
    List<dynamic> list = [];
    if (existing != null) {
      try { list = json.decode(existing) as List; } catch (_) {}
    }
    list.insert(0, record.toJson());
    if (list.length > 200) list = list.sublist(0, 200); // cap at 200
    await prefs.setString('sms_inbox', json.encode(list));

    // Show classic warning dialog
    if (mounted) {
      _showVerdictDialog(record);
      _loadSms(); // Refresh list
    }
  }

  void _showVerdictDialog(SmsRecord record) {
    final isScam = record.verdict == 'SCAM';
    final isCaution = record.verdict == 'CAUTION';

    showDialog(
      context: context,
      barrierDismissible: !isScam,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isScam
                ? const Color(0xFF1A0000)
                : isCaution
                    ? const Color(0xFF1A1200)
                    : const Color(0xFF001A08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isScam
                  ? const Color(0xFFEF5350)
                  : isCaution
                      ? const Color(0xFFFFB300)
                      : const Color(0xFF4CAF50),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Big verdict icon
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: (isScam ? const Color(0xFFEF5350) : isCaution ? const Color(0xFFFFB300) : const Color(0xFF4CAF50)).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isScam ? Icons.dangerous_rounded : isCaution ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                  size: 44,
                  color: isScam ? const Color(0xFFEF5350) : isCaution ? const Color(0xFFFFB300) : const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isScam ? '🚨 SCAM DETECTED!' : isCaution ? '⚠️ SUSPICIOUS SMS' : '✅ SMS SAFE Hai',
                style: TextStyle(
                  color: isScam ? const Color(0xFFEF5350) : isCaution ? const Color(0xFFFFB300) : const Color(0xFF4CAF50),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isScam
                    ? 'Ye SMS ek confirmed scam pattern hai. Kisi link pe click mat karo, koi OTP share mat karo!'
                    : isCaution
                        ? 'Ye SMS suspicious lagta hai. Sender ki identity verify karo pehle.'
                        : 'Koi major red flag nahi mila. SMS safe lagta hai.',
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Risk Score bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Risk Score', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('${record.confidence}/100', style: TextStyle(
                        color: isScam ? const Color(0xFFEF5350) : isCaution ? const Color(0xFFFFB300) : const Color(0xFF4CAF50),
                        fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: record.confidence / 100,
                      backgroundColor: Colors.white12,
                      color: isScam ? const Color(0xFFEF5350) : isCaution ? const Color(0xFFFFB300) : const Color(0xFF4CAF50),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
              if (record.reason.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: record.reason.split(';').where((r) => r.trim().isNotEmpty).map((r) =>
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isScam ? '🔴 ' : isCaution ? '⚠️ ' : '✅ ', style: const TextStyle(fontSize: 11)),
                            Expanded(child: Text(r.trim(), style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4))),
                          ],
                        ),
                      ),
                    ).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (isScam) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('Samajh Gaya — Block Karunga', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF5350),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white38, fontSize: 13)),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCaution ? const Color(0xFFFFB300) : const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Theek Hai', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
            ],
          ),
        ),
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
              child: const Icon(Icons.inbox_outlined,
                  size: 42, color: Color(0xFF2979FF)),
            ).animate().scale(begin: const Offset(0.7, 0.7)).fadeIn(),
            const SizedBox(height: 24),
            Text(
              _tabIndex == 0
                  ? 'Abhi Koi SMS Nahi'
                  : _tabIndex == 1
                      ? 'Koi Scam SMS Nahi Mila'
                      : 'Koi Safe SMS Nahi Mila',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0D1117),
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 12),
            Text(
              _tabIndex == 0
                  ? 'Jab bhi koi SMS aayega, SafeSignal automatically analyze karega aur yahan section-wise store karega.'
                  : _tabIndex == 1
                      ? 'Abhi tak koi suspicious ya scam SMS detect nahi hua. Aapka inbox safe hai! ✅'
                      : 'Safe SMS abhi yahan nahi hain.',
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

// ─── SMS Card ─────────────────────────────────────────────────────────────────
class _SmsCard extends StatefulWidget {
  final SmsRecord sms;
  final bool isDark;
  final int index;
  const _SmsCard({required this.sms, required this.isDark, required this.index});

  @override
  State<_SmsCard> createState() => _SmsCardState();
}

class _SmsCardState extends State<_SmsCard> {
  bool _expanded = false;

  Color get _verdictColor {
    switch (widget.sms.verdict) {
      case 'SCAM':
        return const Color(0xFFEF5350);
      case 'CAUTION':
        return const Color(0xFFFFB300);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  String get _verdictEmoji {
    switch (widget.sms.verdict) {
      case 'SCAM':
        return '🔴';
      case 'CAUTION':
        return '⚠️';
      default:
        return '🟢';
    }
  }

  String get _verdictLabel {
    switch (widget.sms.verdict) {
      case 'SCAM':
        return 'SCAM';
      case 'CAUTION':
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
    final sms = widget.sms;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF0F1724) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _expanded
                ? vc.withValues(alpha: 0.5)
                : (widget.isDark
                    ? const Color(0xFF2A3347)
                    : const Color(0xFFE8EEF8)),
            width: _expanded ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _expanded
                  ? vc.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.04),
              blurRadius: _expanded ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Verdict badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: vc.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(_verdictEmoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                sms.sender,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: widget.isDark
                                      ? Colors.white
                                      : const Color(0xFF0D1117),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: vc.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: vc.withValues(alpha: 0.3),
                                    width: 0.8),
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
                        const SizedBox(height: 4),
                        Text(
                          sms.body,
                          maxLines: _expanded ? 6 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: widget.isDark
                                ? Colors.white60
                                : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time_outlined,
                                size: 11,
                                color: widget.isDark
                                    ? Colors.white30
                                    : Colors.black26),
                            const SizedBox(width: 4),
                            Text(
                              _timeAgo(sms.receivedAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.isDark
                                    ? Colors.white30
                                    : Colors.black26,
                              ),
                            ),
                            if (sms.confidence > 0) ...[
                              const SizedBox(width: 10),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: widget.isDark
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : Colors.black12,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${sms.confidence}% confidence',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: vc.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

      // Expanded: Risk score + Reason card + Report button
            if (_expanded) ...[  
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                decoration: BoxDecoration(
                  color: vc.withValues(alpha: 0.05),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(18)),
                  border: Border(
                    top: BorderSide(color: vc.withValues(alpha: 0.15)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Risk Score bar
                    Row(
                      children: [
                        Text(
                          'Risk Score',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: vc,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${sms.confidence}/100',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: vc,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: sms.confidence / 100,
                        backgroundColor: vc.withValues(alpha: 0.15),
                        color: vc,
                        minHeight: 5,
                      ),
                    ),

                    // Reason card
                    if (sms.reason.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Why this verdict?',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: widget.isDark ? Colors.white54 : Colors.black45,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Split reasons by newline or semicolon
                      ...sms.reason.split(RegExp(r'[;\n]+')).where((r) => r.trim().isNotEmpty).map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('🔴 ', style: const TextStyle(fontSize: 12)),
                              Expanded(
                                child: Text(
                                  r.trim(),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.45,
                                    color: widget.isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Report as Scam button
                    if (sms.verdict == 'SCAM' || sms.verdict == 'CAUTION') ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          await CrowdIntelService().reportThreat(
                            rawValue: '${sms.sender}::${sms.body.substring(0, sms.body.length.clamp(0, 50))}',
                            type: 'sms',
                            verdict: 'SCAM',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Reported! This will protect other SafeSignal users.'),
                                backgroundColor: Color(0xFF4CAF50),
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.flag_outlined, color: Color(0xFFE53935), size: 15),
                              SizedBox(width: 6),
                              Text(
                                'Report as Scam',
                                style: TextStyle(
                                  color: Color(0xFFE53935),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: widget.index * 40)),
    );
  }
}

// ─── Data Model ───────────────────────────────────────────────────────────────
class SmsRecord {
  final String sender;
  final String body;
  final String verdict; // SAFE | SCAM | CAUTION
  final int confidence;
  final String reason;
  final DateTime receivedAt;

  const SmsRecord({
    required this.sender,
    required this.body,
    required this.verdict,
    required this.confidence,
    required this.reason,
    required this.receivedAt,
  });

  factory SmsRecord.fromJson(Map<String, dynamic> m) => SmsRecord(
        sender: m['sender'] as String? ?? 'Unknown',
        body: m['body'] as String? ?? '',
        verdict: m['verdict'] as String? ?? 'SAFE',
        confidence: m['confidence'] as int? ?? 0,
        reason: m['reason'] as String? ?? '',
        receivedAt: DateTime.tryParse(m['receivedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'sender': sender,
        'body': body,
        'verdict': verdict,
        'confidence': confidence,
        'reason': reason,
        'receivedAt': receivedAt.toIso8601String(),
      };
}
