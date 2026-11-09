// SafeSignal Mobile Security Suite
// Module: Breach Intelligence & Dark Web Security Analyzer
// Author: Umar Farooque (https://github.com/UmarFarooqueJi)
// Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/hibp_service.dart';
import '../../core/services/live_osint_service.dart';
import '../../core/services/llm_orchestrator.dart';
import '../url_scanner/in_app_browser_screen.dart';

enum _Phase { idle, scanning, done, error }

class EmailBreachScreen extends StatefulWidget {
  const EmailBreachScreen({super.key});

  @override
  State<EmailBreachScreen> createState() => _EmailBreachScreenState();
}

class _EmailBreachScreenState extends State<EmailBreachScreen> {
  final TextEditingController _emailCtrl = TextEditingController();

  final HibpService _hibp = HibpService();
  final LiveOsintService _liveOsint = LiveOsintService();

  _Phase _phase = _Phase.idle;

  // Email state
  List<BreachInfo> _emailBreaches = [];
  String _emailVerdict = '';
  LiveOsintProfile? _liveOsintProfile;
  bool _showAuthenticityWhy = false;
  bool _showExposureWhy = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    final emailPattern = r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$';
    if (!RegExp(emailPattern).hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Kripya ek valid email address enter karein (e.g. name@example.com).",
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _phase = _Phase.scanning;
      _emailBreaches.clear();
      _emailVerdict = '';
    });

    try {
      final breaches = await _hibp.checkEmail(email);
      final osint = await _liveOsint.performFullLookup(email, breaches);

      String instantVerdict;
      if (breaches.isEmpty) {
        instantVerdict =
            'Great news! Your email was checked across 800+ dark web breaches and zero records were found.';
      } else {
        final hasPwd = breaches.any(
          (b) => b.dataClasses.any((d) => d.toLowerCase().contains('password')),
        );
        instantVerdict = hasPwd
            ? 'HIGH RISK: Passwords linked to this email were exposed in ${breaches.length} security breaches. Change compromised passwords and enable 2FA immediately.'
            : 'ALERT: Your email was found in ${breaches.length} public data exposures. Verify linked accounts and monitor for suspicious communications.';
      }

      if (mounted) {
        setState(() {
          _emailBreaches = breaches;
          _liveOsintProfile = osint;
          _emailVerdict = instantVerdict;
          _phase = _Phase.done;
        });
      }

      _fetchEmailVerdict(email, breaches);
    } catch (e) {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _fetchEmailVerdict(
    String email,
    List<BreachInfo> breaches,
  ) async {
    if (breaches.isEmpty) {
      if (mounted) {
        setState(
          () => _emailVerdict =
              'Great news! Your email "$email" has not been found in any public data breaches.',
        );
      }
      return;
    }

    final prompt =
        '''
    Analyze these data breaches for the email $email.
    Breaches: ${breaches.map((b) => '${b.title} (Leaked: ${b.dataClasses.join(", ")})').join(' | ')}
    
    Give a concise, authoritative security verdict in 2-3 sentences. Tell the user exactly what to do (e.g., change passwords immediately, enable 2FA). Use simple English/Hinglish. Do NOT use markdown.
    ''';

    try {
      final verdictObj = await LlmOrchestrator().analyze(
        text: prompt,
        type: 'chat',
      );
      if (mounted) {
        setState(() => _emailVerdict = verdictObj.summary);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _emailVerdict =
              'WARNING: Your email was found in ${breaches.length} data breaches. Please change your passwords for the affected services immediately and enable Two-Factor Authentication.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF06090F) : const Color(0xFFEBF3FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    double gaugeScore = 0;
    String statusText = '';
    Color statusColor = Colors.transparent;

    if (_phase == _Phase.done) {
      if (_emailBreaches.isEmpty) {
        statusText = 'Safe';
        statusColor = const Color(0xFF4CAF50);
      } else {
        int score = 0;
        for (var b in _emailBreaches) {
          if (b.dataClasses.contains('Passwords')) score += 40;
          if (b.dataClasses.contains('Email addresses')) score += 10;
          if (b.dataClasses.contains('Phone numbers')) score += 20;
          if (b.dataClasses.contains('Physical addresses')) score += 20;
        }
        score = score.clamp(0, 100);
        gaugeScore = score.toDouble();
        statusText = score >= 50 ? 'Unsafe' : 'Suspicious';
        statusColor = score >= 50
            ? const Color(0xFFFF8A65)
            : const Color(0xFFFFB300);
      }
    } else if (_phase == _Phase.scanning) {
      statusText = 'Scanning...';
      statusColor = const Color(0xFF7C4DFF);
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
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12,
                width: 1.5,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.grid_view_rounded,
                color: isDark ? Colors.white54 : Colors.black54,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Data Breach Check',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: textColor,
            fontFamily: 'serif',
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Speedometer Gauge
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: gaugeScore),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return _EmailSpeedometerGauge(score: value);
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

              const SizedBox(height: 24),

              // Email Input Field
              _buildEmailInput(isDark, textColor),

              const SizedBox(height: 18),

              // Primary Scan Button
              _buildScanButton(),

              if (_phase == _Phase.error)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'Network error. Please check your internet connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              if (_phase == _Phase.done) ...[
                const SizedBox(height: 24),
                _buildEmailAnalysisCards(isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildEmailInput(bool isDark, Color textColor) {
    return TextField(
      controller: _emailCtrl,
      enabled: _phase != _Phase.scanning,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: textColor, fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Email Address',
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.black54,
          fontSize: 13,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            icon: Icon(
              Icons.search,
              color: isDark ? Colors.white70 : Colors.black54,
              size: 24,
            ),
            onPressed: _phase == _Phase.scanning ? null : _startScan,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: isDark ? Colors.white30 : Colors.black26,
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: isDark ? Colors.white30 : Colors.black26,
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: isDark ? Colors.white70 : Colors.black87,
            width: 1.4,
          ),
        ),
      ),
      onSubmitted: (_) => _startScan(),
    );
  }

  Widget _buildScanButton() {
    return Container(
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
        onPressed: _phase == _Phase.scanning ? null : _startScan,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_phase == _Phase.scanning) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                _phase == _Phase.scanning
                    ? 'Scanning 800+ Breach Archives...'
                    : 'Scan Email Breach',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_phase != _Phase.scanning) ...[
                const SizedBox(width: 10),
                const Icon(
                  CupertinoIcons.mail,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 150.ms);
  }

  // ---------------------------------------------------------------------------
  // INTELBASE OSINT & BREACH ANALYSIS DASHBOARD (intelbase.is Feature Parity)
  // ---------------------------------------------------------------------------
  Widget _buildEmailAnalysisCards(bool isDark) {
    final osint = _liveOsintProfile;
    if (osint == null) {
      return _buildLegacyEmailCards(isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Likely Owner & Identity Header Card
        _buildIntelBaseIdentityCard(osint, isDark),
        const SizedBox(height: 16),

        // 1.5. Total Breaches & Incident Counter Hero Banner
        _buildIntelBaseBreachOverviewBanner(osint, isDark),
        const SizedBox(height: 16),

        // 2. Dual Assessment Matrix (Authenticity & Exposure Scores)
        _buildIntelBaseAssessmentCard(osint, isDark),
        const SizedBox(height: 16),

        // 2.5 Cryptographic Threat Identifiers
        _buildCryptographicHashesCard(osint.query, isDark),
        const SizedBox(height: 16),

        // 3. Infostealer Malware Logs Threat Card (if compromised)
        if (osint.stealerReport.hasStealerExposure) ...[
          _buildIntelBaseStealerCard(osint.stealerReport, isDark),
          const SizedBox(height: 16),
        ],

        // 4. Discovered Live Accounts (Gravatar, GitHub, etc.)
        if (osint.accounts.isNotEmpty) ...[
          _buildIntelBaseAccountsCard(osint.accounts, isDark),
          const SizedBox(height: 16),
        ],

        // 5. Digital Footprint Timeline
        if (osint.timeline.isNotEmpty) ...[
          _buildIntelBaseTimelineCard(osint.timeline, isDark),
          const SizedBox(height: 16),
        ],

        // 6. Data Breaches Breakdown
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'COMPROMISED BREACH ARCHIVES (${osint.breaches.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (osint.breaches.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                  : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF10B981),
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Zero Known Breaches Found',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Your email was checked across 800+ dark-web breach archives and zero compromised records were detected.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF065F46),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...osint.breaches.map((b) => _buildEmailBreachDetailCard(b, isDark)),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildIntelBaseBreachOverviewBanner(
    LiveOsintProfile osint,
    bool isDark,
  ) {
    final totalBreaches = osint.breaches.length;
    final isBreached = totalBreaches > 0;
    final passwordBreaches = osint.breaches
        .where(
          (b) => b.dataClasses.any((c) => c.toLowerCase().contains('password')),
        )
        .length;
    final stealerCount = osint.stealerReport.stealerFamilies.length;

    final primaryColor = isBreached
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);
    final bgColor = isDark
        ? (isBreached ? const Color(0xFF1E1114) : const Color(0xFF062015))
        : (isBreached ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5));
    final borderColor = primaryColor.withValues(alpha: isDark ? 0.35 : 0.25);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isBreached
                      ? Icons.gpp_bad_rounded
                      : Icons.verified_user_rounded,
                  color: primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL BREACH INCIDENTS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBreached
                          ? '$totalBreaches Known Data ${totalBreaches == 1 ? "Breach" : "Breaches"} Detected'
                          : 'Zero Breaches Detected (Safe)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalBreaches',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Colors.white10),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildBreachKpiTile(
                  label: 'Breaches',
                  value: '$totalBreaches',
                  color: primaryColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBreachKpiTile(
                  label: 'Passwords Exposed',
                  value: '$passwordBreaches',
                  color: passwordBreaches > 0
                      ? const Color(0xFFF97316)
                      : const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBreachKpiTile(
                  label: 'Stealer Logs',
                  value: '$stealerCount',
                  color: stealerCount > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreachKpiTile({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntelBaseIdentityCard(LiveOsintProfile osint, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: osint.avatarUrl != null && osint.avatarUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: osint.avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(
                              Icons.person,
                              color: Color(0xFF3B82F6),
                              size: 28,
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            (osint.likelyOwner ?? 'U')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3B82F6),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            osint.likelyOwner ?? 'Anonymous Subject',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: Color(0xFF3B82F6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      osint.query,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (osint.primaryBio != null &&
                        osint.primaryBio!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        osint.primaryBio!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 12),
          // Timeline Footprint badges
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FIRST SEEN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      osint.firstSeenYear ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAST SEEN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      osint.lastSeenYear ?? '2024',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MAIL PROVIDER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      osint.domainIntel.mailProvider,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntelBaseAssessmentCard(LiveOsintProfile osint, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'THREAT & IDENTITY ASSESSMENT',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'IntelBase Matrix',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Algorithmic scoring derived from live OSINT validators, domain reputation, and breach corpora.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),

          // Score 1: Authenticity
          _buildScoreAccordion(
            title: 'Authenticity',
            subtitle: 'How established the identifier appears',
            score: osint.authenticity.score,
            bandLabel: osint.authenticity.label,
            barColor: const Color(0xFF34D399),
            reasons: osint.authenticity.reasons,
            isOpen: _showAuthenticityWhy,
            onToggle: () =>
                setState(() => _showAuthenticityWhy = !_showAuthenticityWhy),
            isDark: isDark,
          ),

          const SizedBox(height: 12),

          // Score 2: Exposure
          _buildScoreAccordion(
            title: 'Exposure',
            subtitle: 'How severely credentials & assets are exposed',
            score: osint.exposure.score,
            bandLabel: osint.exposure.label,
            barColor: osint.exposure.score >= 70
                ? const Color(0xFFEF4444)
                : (osint.exposure.score > 25
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF34D399)),
            reasons: osint.exposure.reasons,
            isOpen: _showExposureWhy,
            onToggle: () =>
                setState(() => _showExposureWhy = !_showExposureWhy),
            isDark: isDark,
          ),

          if (osint.passwordReuseCount > 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.key_rounded,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Same Password Found Across ${osint.passwordReuseCount} Breaches',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'High risk of automated credential stuffing attack. Change passwords across all accounts.',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
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

  Widget _buildScoreAccordion({
    required String title,
    required String subtitle,
    required int score,
    required String bandLabel,
    required Color barColor,
    required List<ScoreReason> reasons,
    required bool isOpen,
    required VoidCallback onToggle,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.5)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$score',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: barColor,
                          ),
                        ),
                        TextSpan(
                          text: '/100',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: barColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      bandLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: barColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 5,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onToggle,
            child: Row(
              children: [
                Icon(
                  isOpen
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 16,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                const SizedBox(width: 4),
                Text(
                  'Why this score',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (isOpen) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: Colors.white10),
            const SizedBox(height: 8),
            ...reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (r.points >= 0
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444))
                                .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.points >= 0 ? '+${r.points}' : '${r.points}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: r.points >= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntelBaseStealerCard(
    InfostealerThreatReport report,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A0A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.gpp_bad_rounded,
                  color: Color(0xFFEF4444),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'INFOSTEALER MALWARE DETECTED',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Compromised Windows device logs indexed',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.riskSummary,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: report.exposedDataTypes.map((dt) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  dt,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFCA5A5),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIntelBaseAccountsCard(
    List<DiscoveredAccount> accounts,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌐', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'LIVE CONNECTED PLATFORMS (${accounts.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Active web profiles verified live via public identity endpoints.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          ...accounts.map(
            (acc) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: acc.avatarUrl != null
                          ? CachedNetworkImage(
                              imageUrl: acc.avatarUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  acc.icon,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                acc.icon,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          acc.displayName ?? acc.username ?? acc.formattedName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          acc.formattedName,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        if (acc.bio != null && acc.bio!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            acc.bio!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (acc.profileUrl != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      color: const Color(0xFF3B82F6),
                      onPressed: () async {
                        final uri = Uri.tryParse(acc.profileUrl!);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntelBaseTimelineCard(
    List<TimelineEvent> timeline,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⏳', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'DIGITAL FOOTPRINT TIMELINE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Chronological audit of platform creations and breach exposures.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          ...timeline
              .take(5)
              .map(
                (ev) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (ev.isBreach
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF3B82F6))
                                  .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ev.dateString,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: ev.isBreach
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ev.title,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ev.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
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

  Widget _buildLegacyEmailCards(bool isDark) {
    if (_emailBreaches.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 60,
              color: Color(0xFF4CAF50),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Breaches Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _emailVerdict.isEmpty
                  ? 'Your email is secure and has not been found in any public leaks.'
                  : _emailVerdict,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    const outlineColor = Color(0xFFFF8A65);
    final cardStyle = BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: outlineColor, width: 1.5),
    );

    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: cardStyle,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF5D1D05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Risk Analysis',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildRow(
                'Security Grade',
                _emailBreaches.length >= 3 ? 'E' : 'C',
                valueColor: outlineColor,
                isDark: isDark,
              ),
              _divider(),
              _buildRow(
                'Total Breaches',
                '${_emailBreaches.length} Databases',
                valueColor: outlineColor,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'BREACH TIMELINE & LEAK DETAILS (${_emailBreaches.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._emailBreaches.map((b) => _buildEmailBreachDetailCard(b, isDark)),
        const SizedBox(height: 30),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // DETAIL CARDS (EMAIL & PHONE)
  // ---------------------------------------------------------------------------
  Widget _buildEmailBreachDetailCard(BreachInfo b, bool isDark) {
    final hasPassword = b.dataClasses.any(
      (d) => d.toLowerCase().contains('password'),
    );
    final isPlaintext = b.passwordRisk.toLowerCase().contains('plain');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasPassword
              ? Colors.redAccent.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
          width: hasPassword ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1F2937)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  b.logoPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      b.title.isNotEmpty ? b.title[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: hasPassword
                            ? Colors.redAccent
                            : const Color(0xFF6C63FF),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            b.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (b.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: Color(0xFF38BDF8),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.domain.isNotEmpty ? b.domain : b.title.toLowerCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      (hasPassword ? Colors.redAccent : const Color(0xFF6C63FF))
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  b.breachDate,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: hasPassword
                        ? Colors.redAccent
                        : const Color(0xFF6C63FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (b.pwnCount > 0)
                _buildBadge(
                  Icons.people_outline,
                  '${_formatRecords(b.pwnCount)} victims',
                  const Color(0xFFF59E0B),
                ),
              if (b.industry.isNotEmpty && b.industry != 'General')
                _buildBadge(
                  Icons.business_outlined,
                  b.industry,
                  const Color(0xFF38BDF8),
                ),
              if (isPlaintext)
                _buildBadge(
                  Icons.lock_open,
                  'Plaintext Passwords Exposed!',
                  Colors.redAccent,
                )
              else if (hasPassword)
                _buildBadge(
                  Icons.lock_outline,
                  'Password Hash Leaked',
                  Colors.orangeAccent,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'EXPOSED DATA TYPES:',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: b.dataClasses.map((dc) => _buildDataChip(dc)).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            b.description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              height: 1.35,
            ),
          ),
          if (b.referenceUrl != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final uri = Uri.tryParse(b.referenceUrl!);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Read incident source',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF38BDF8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.open_in_new, size: 12, color: Color(0xFF38BDF8)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCryptographicHashesCard(String identifier, bool isDark) {
    final clean = identifier.trim().toLowerCase();
    final bytes = utf8.encode(clean);
    final md5Hash = md5.convert(bytes).toString();
    final sha1Hash = sha1.convert(bytes).toString();
    final sha256Hash = sha256.convert(bytes).toString();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.number_square_fill,
                color: Color(0xFF38BDF8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'CRYPTOGRAPHIC THREAT IDENTIFIERS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cryptographic digests utilized by threat intelligence platforms, dehashed indices, and COMB database correlation.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          _buildHashRow('MD5', md5Hash, isDark),
          const SizedBox(height: 10),
          _buildHashRow('SHA-1', sha1Hash, isDark),
          const SizedBox(height: 10),
          _buildHashRow('SHA-256', sha256Hash, isDark),
        ],
      ),
    );
  }

  Widget _buildHashRow(String algo, String hash, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              algo,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF38BDF8),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              hash,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFF1E293B),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            tooltip: 'Copy $algo',
            visualDensity: VisualDensity.compact,
            color: isDark ? Colors.white60 : Colors.black54,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: hash));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied $algo digest to clipboard'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataChip(String dc) {
    final lower = dc.toLowerCase();
    final isPwd = lower.contains('password');
    final isPhone = lower.contains('phone') || lower.contains('mobile');
    final isAddress = lower.contains('address') || lower.contains('location');
    final isGovt =
        lower.contains('id') ||
        lower.contains('kyc') ||
        lower.contains('father');

    final color = isPwd
        ? Colors.redAccent
        : isGovt
        ? Colors.deepOrangeAccent
        : isPhone
        ? Colors.purpleAccent
        : isAddress
        ? Colors.amber.shade700
        : const Color(0xFF6C63FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        dc,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRecords(int n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }

  Widget _buildRow(
    String label,
    String value, {
    required Color valueColor,
    required bool isDark,
    Widget? trailingWidget,
    int labelFlex = 5,
    int valueFlex = 6,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: labelFlex,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: valueFlex,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                ?trailingWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: Colors.white24, height: 1, thickness: 1),
    );
  }
}

// -----------------------------------------------------------------------------
// SPEEDOMETER GAUGE WIDGET
// -----------------------------------------------------------------------------
class _EmailSpeedometerGauge extends StatelessWidget {
  final double score; // 0 to 100
  const _EmailSpeedometerGauge({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 140,
      child: CustomPaint(painter: _EmailSpeedometerPainter(score)),
    );
  }
}

class _EmailSpeedometerPainter extends CustomPainter {
  final double score;

  _EmailSpeedometerPainter(this.score);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 20);
    final radius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: radius - 20);

    paint.color = Colors.greenAccent.shade400;
    canvas.drawArc(rect, 3.14159, 3.14159 / 3, false, paint);

    paint.color = Colors.orangeAccent.shade400;
    canvas.drawArc(rect, 3.14159 + (3.14159 / 3), 3.14159 / 3, false, paint);

    paint.color = Colors.redAccent.shade400;
    canvas.drawArc(
      rect,
      3.14159 + (2 * 3.14159 / 3),
      3.14159 / 3,
      false,
      paint,
    );

    double clampedScore = score.clamp(0.0, 100.0);
    final angle = 3.14159 + (clampedScore / 100) * 3.14159;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final needlePaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, -6);
    path.lineTo(radius - 10, 0);
    path.lineTo(0, 6);
    path.close();

    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, needlePaint);

    canvas.drawCircle(const Offset(0, 0), 16, needlePaint);
    final innerCirclePaint = Paint()..color = Colors.grey.shade400;
    canvas.drawCircle(const Offset(0, 0), 10, innerCirclePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EmailSpeedometerPainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
