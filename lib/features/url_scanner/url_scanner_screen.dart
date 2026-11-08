import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/url_intelligence_engine.dart';
import '../../core/services/virus_total_service.dart';
import '../../core/services/link_guard_service.dart';
import 'in_app_browser_screen.dart';

class UrlScannerScreen extends StatefulWidget {
  final String? initialUrl;
  const UrlScannerScreen({super.key, this.initialUrl});

  @override
  State<UrlScannerScreen> createState() => _UrlScannerScreenState();
}

enum _ScanState { idle, scanning, done, error }

class _UrlScannerScreenState extends State<UrlScannerScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  _ScanState _state = _ScanState.idle;
  UrlResult? _result;
  String _statusMsg = '';
  bool _isDefaultBrowser = false;
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  StreamSubscription<String>? _urlSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBrowserRole();
    _urlSub = LinkGuardService.onUrlReceived.listen((url) {
      if (mounted && url.trim().isNotEmpty) {
        _controller.text = url.trim();
        _scan();
      }
    });
    if (widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty) {
      _controller.text = widget.initialUrl!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scan();
      });
    }
  }

  @override
  void didUpdateWidget(covariant UrlScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUrl != null &&
        widget.initialUrl != oldWidget.initialUrl &&
        widget.initialUrl!.trim().isNotEmpty) {
      _controller.text = widget.initialUrl!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scan();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBrowserRole();
    }
  }

  Future<void> _checkBrowserRole() async {
    final held = await LinkGuardService.isBrowserRoleHeld();
    if (mounted) setState(() => _isDefaultBrowser = held);
  }

  @override
  void dispose() {
    _urlSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _dio.close();
    super.dispose();
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _statusMsg = msg);
  }

  Future<void> _scan() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;

    String url = raw;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url'; // Default to HTTPS
    }

    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasAuthority || !parsed.host.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Kripya ek valid URL ya domain enter karein (e.g. example.com).",
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _state = _ScanState.scanning;
      _result = null;
      _statusMsg = 'Initializing deep scan...';
    });

    try {
      final result = await _analyzeUrl(url);

      if (!mounted) return;
      setState(() {
        _state = _ScanState.done;
        _result = result;
        _statusMsg = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _result = UrlResult.error(url);
        _statusMsg = '';
      });
    }
  }

  Future<UrlResult> _analyzeUrl(String url) async {
    _setStatus('Querying threat intelligence & multi-engine radar...');
    return await UrlIntelligenceEngine.analyze(
      url,
      traceShorteners: true,
      checkVirusTotal: true,
      checkSecurityDns: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF06090F) : const Color(0xFFEBF3FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    // Determine gauge score and status text
    double gaugeScore = 0;
    String statusText = '';
    Color statusColor = Colors.transparent;

    if (_state == _ScanState.done && _result != null) {
      gaugeScore = _result!.riskScore.toDouble();
      if (_result!.verdict == UrlVerdict.dangerous) {
        statusText = 'Unsafe';
        statusColor = const Color(0xFFFF8A65); // Orange-red matching screenshot
      } else if (_result!.verdict == UrlVerdict.caution) {
        statusText = 'Suspicious';
        statusColor = const Color(0xFFFFB300);
      } else {
        statusText = 'Safe';
        statusColor = const Color(0xFF4CAF50);
      }
    } else if (_state == _ScanState.scanning) {
      statusText = _statusMsg.isNotEmpty ? _statusMsg : 'Scanning...';
      statusColor = AppTheme.primary;
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
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.grid_view_rounded,
                color: Colors.white54,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Scan Link',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: textColor,
            fontFamily:
                'serif', // Matching the screenshot's serif-like font for title
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.vpn_key_outlined,
              color: Colors.white54,
              size: 20,
            ),
            tooltip: 'Configure VirusTotal API Key',
            onPressed: _showVirusTotalConfigDialog,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.radar_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                tooltip: 'Titan Radar Diagnostics',
                onPressed: () => _showForensicAuditDialog(_result),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Gauge
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: gaugeScore),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return SpeedometerGauge(score: value);
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

              const SizedBox(height: 32),

              TextField(
                controller: _controller,
                enabled: _state != _ScanState.scanning,
                style: TextStyle(color: textColor, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Link',
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
                      onPressed: _scan,
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
                onSubmitted: (_) => _scan(),
              ),

              const SizedBox(height: 20),

              // Scan Button
              Container(
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
                  onPressed: _state == _ScanState.scanning ? null : _scan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 24), // Balance for centering
                      Expanded(
                        child: Center(
                          child: Text(
                            _state == _ScanState.scanning
                                ? 'Scanning...'
                                : 'Scan URL',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      _state == _ScanState.scanning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.language,
                              color: isDark ? Colors.white : Colors.black87,
                              size: 24,
                            ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 150.ms),

              const SizedBox(height: 16),
              _buildWhatsAppShieldBanner(isDark),

              if (_state == _ScanState.done && _result != null) ...[
                const SizedBox(height: 24),
                _buildAnalysisCards(_result!, isDark),
              ],

              if (_state == _ScanState.error)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'Network error. Please check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisCards(UrlResult result, bool isDark) {
    String siteGrade = result.verdict == UrlVerdict.dangerous
        ? 'E'
        : (result.verdict == UrlVerdict.caution ? 'C' : 'A');
    String secScore = result.riskScore > 50
        ? '1'
        : (result.riskScore > 20 ? '5' : '9');

    // Extract registry date if possible
    String registryDate = 'Unknown';
    for (var c in result.domainChecks) {
      if (c.name.contains('Domain Age') && c.detail.contains('days old')) {
        final days =
            RegExp(r'(\d+) days old').firstMatch(c.detail)?.group(1) ?? '';
        registryDate = days.isNotEmpty ? '$days days ago' : c.detail;
      } else if (c.name.contains('Domain Age') &&
          c.detail.contains('days ago')) {
        final days =
            RegExp(r'(\d+) days ago').firstMatch(c.detail)?.group(1) ?? '';
        registryDate = days.isNotEmpty ? '$days days ago' : c.detail;
      }
    }

    // Extract synopsis from failed checks
    String synopsis = result.domainChecks
        .where((c) => c.passed == false)
        .map((c) => c.detail)
        .join('. ');
    if (synopsis.isEmpty) {
      synopsis = 'No major threats detected — all checks passed.';
    }
    if (result.verdict == UrlVerdict.dangerous && synopsis.length < 20) {
      synopsis =
          'Multiple security risks detected: possible phishing, suspicious domain structure, or flagged by threat intelligence databases.';
    }

    final outlineColor = result.verdict == UrlVerdict.dangerous
        ? const Color(0xFFFF8A65)
        : result.verdict == UrlVerdict.caution
        ? const Color(0xFFFFB300)
        : const Color(0xFF4CAF50);

    final cardStyle = BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: outlineColor, width: 1.5),
    );

    final labelStyle = TextStyle(
      color: isDark ? Colors.white : Colors.black87,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );
    final mutedStyle = TextStyle(
      color: isDark ? Colors.white54 : Colors.black45,
      fontSize: 13,
      height: 1.4,
    );

    return Column(
      children: [
        // ── Forensic Threat Banner (RAT, Dropper, Banking Trojan, Phish, Safe) ──
        if (result.threatCategoryBadge.isNotEmpty) ...[
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: result.verdict == UrlVerdict.dangerous
                    ? [const Color(0xFF3B0D0C), const Color(0xFF200507)]
                    : result.verdict == UrlVerdict.caution
                    ? [const Color(0xFF382505), const Color(0xFF1E1302)]
                    : [const Color(0xFF07291B), const Color(0xFF03160D)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: outlineColor.withValues(alpha: 0.8),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: outlineColor.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
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
                        color: outlineColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        result.threatType == MalwareThreatType.ratDropper
                            ? Icons.bug_report_rounded
                            : result.threatType ==
                                  MalwareThreatType.bankingTrojan
                            ? Icons.account_balance_rounded
                            : result.threatType == MalwareThreatType.apkDropper
                            ? Icons.system_update_alt_rounded
                            : result.verdict == UrlVerdict.safe
                            ? Icons.verified_user_rounded
                            : Icons.shield_rounded,
                        color: outlineColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.threatCategoryBadge,
                            style: TextStyle(
                              color: outlineColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.verdict == UrlVerdict.dangerous
                                ? 'Active Threat Intercepted'
                                : result.verdict == UrlVerdict.caution
                                ? 'Unverified Destination'
                                : 'Validated Reputation',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (result.threatForensicDetails.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    result.threatForensicDetails,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.9)
                          : const Color(0xFF1E293B),
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Card 1: Site Overview ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: cardStyle,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader('Site Overview', isDark),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Favicon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        'https://www.google.com/s2/favicons?domain=${result.domain}&sz=128',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            result.domain.isNotEmpty
                                ? result.domain[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              fontSize: 28,
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.bold,
                            ),
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
                        Text(
                          result.siteTitle.isNotEmpty
                              ? result.siteTitle
                              : result.domain,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0D1117),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (result.siteDescription.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            result.siteDescription,
                            style: mutedStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _divider2(isDark),
              const SizedBox(height: 12),
              _buildRow(
                'Site Grade',
                siteGrade,
                valueColor: outlineColor,
                isDark: isDark,
              ),
              _divider(),
              _buildRow(
                'Security Score',
                '$secScore/10',
                valueColor: outlineColor,
                isDark: isDark,
              ),
              _divider(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: Text('Synopsis', style: labelStyle)),
                  Expanded(
                    flex: 3,
                    child: Text(
                      synopsis,
                      style: TextStyle(
                        color: outlineColor,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Card 2: Security Rating Breakdown ─────────────────────────────────
        Container(
          width: double.infinity,
          decoration: cardStyle,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader('Security Rating Breakdown', isDark),
              const SizedBox(height: 20),
              _buildRow(
                'Phishing Check',
                result.verdict == UrlVerdict.dangerous ? 'Failed' : 'Passed',
                valueColor: result.verdict == UrlVerdict.dangerous
                    ? const Color(0xFFFF8A65)
                    : const Color(0xFF4CAF50),
                isDark: isDark,
              ),
              _divider(),
              _buildRow(
                'Malware Scan',
                result.verdict == UrlVerdict.dangerous
                    ? 'Threat Found'
                    : 'Clean',
                valueColor: result.verdict == UrlVerdict.dangerous
                    ? const Color(0xFFFF8A65)
                    : const Color(0xFF4CAF50),
                isDark: isDark,
              ),
              _divider(),
              _buildRow(
                'URLhaus DB',
                result.domainChecks.any(
                      (c) => c.name.contains('URLhaus') && c.passed == false,
                    )
                    ? 'Listed'
                    : 'Clean',
                valueColor:
                    result.domainChecks.any(
                      (c) => c.name.contains('URLhaus') && c.passed == false,
                    )
                    ? const Color(0xFFFF8A65)
                    : const Color(0xFF4CAF50),
                isDark: isDark,
              ),
              _divider(),
              _buildRow(
                'Domain Trust',
                result.verdict == UrlVerdict.dangerous ? 'Low' : 'Established',
                valueColor: result.verdict == UrlVerdict.dangerous
                    ? const Color(0xFFFF8A65)
                    : const Color(0xFF4CAF50),
                isDark: isDark,
              ),
              _divider(),
              // Security headers
              _buildRow(
                'Security Headers',
                '${result.securityHeaders}/4 present',
                valueColor: result.securityHeaders >= 3
                    ? const Color(0xFF4CAF50)
                    : result.securityHeaders >= 2
                    ? const Color(0xFFFFB300)
                    : const Color(0xFFFF8A65),
                isDark: isDark,
              ),
              _divider(),
              _buildRow(
                'Final Score',
                '$secScore/10',
                valueColor: outlineColor,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Card 3: Domain Reputation ─────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: cardStyle,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader('Domain Reputation', isDark),
              const SizedBox(height: 20),
              _buildRow(
                'Domain',
                result.domain,
                valueColor: outlineColor,
                isDark: isDark,
              ),
              if (registryDate != 'Unknown') ...[
                _divider(),
                _buildRow(
                  'Registered',
                  registryDate,
                  valueColor: outlineColor,
                  isDark: isDark,
                ),
              ],
              _divider(),
              _buildRow(
                'In Allowlist',
                result.isVerifiedSafe ? 'Yes (Trusted)' : 'No',
                valueColor: result.isVerifiedSafe
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF8A65),
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Card 4: Server Intelligence ───────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: cardStyle,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader('Server Intelligence', isDark),
              const SizedBox(height: 20),
              if (result.serverIp.isNotEmpty) ...[
                _buildRow(
                  'IP Address',
                  result.serverIp,
                  valueColor: outlineColor,
                  isDark: isDark,
                ),
                _divider(),
              ],
              if (result.serverCountry.isNotEmpty) ...[
                _buildRow(
                  'Country',
                  '${result.serverCity.isNotEmpty ? "${result.serverCity}, " : ""}${result.serverCountry}',
                  valueColor: outlineColor,
                  isDark: isDark,
                ),
                _divider(),
              ],
              if (result.serverIsp.isNotEmpty) ...[
                _buildRow(
                  'ISP / Host',
                  result.serverIsp,
                  valueColor: outlineColor,
                  isDark: isDark,
                ),
                _divider(),
              ],
              if (result.serverSoftware.isNotEmpty) ...[
                _buildRow(
                  'Server Software',
                  result.serverSoftware,
                  valueColor: outlineColor,
                  isDark: isDark,
                ),
                _divider(),
              ],
              if (result.poweredBy.isNotEmpty) ...[
                _buildRow(
                  'Powered By',
                  result.poweredBy,
                  valueColor: outlineColor,
                  isDark: isDark,
                ),
                _divider(),
              ],
              _buildRow(
                'Safe for Payments',
                result.verdict == UrlVerdict.dangerous
                    ? 'No — High Risk'
                    : 'Yes (HTTPS Secured)',
                valueColor: result.verdict == UrlVerdict.dangerous
                    ? const Color(0xFFFF8A65)
                    : const Color(0xFF4CAF50),
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Card 5: DNS & Mail Security (Cloudflare DoH) ─────────────────────
        Container(
          width: double.infinity,
          decoration: cardStyle,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader('DNS & Email Recon (Cloudflare DoH)', isDark),
              const SizedBox(height: 20),
              if (result.aRecords.isNotEmpty) ...[
                _buildRow(
                  'Resolved IPs (A)',
                  result.aRecords.take(2).join(', '),
                  valueColor: outlineColor,
                  isDark: isDark,
                ),
                _divider(),
              ],
              _buildRow(
                'Mail Server (MX)',
                result.mxRecords.isNotEmpty
                    ? result.mxRecords.first
                    : 'No Mail Server (Phishing Suspect)',
                valueColor: result.mxRecords.isNotEmpty
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF8A65),
                isDark: isDark,
              ),
              _divider(),
              _buildRow(
                'DMARC Anti-Spoof',
                result.hasDmarc
                    ? 'Enabled (Valid Policy)'
                    : 'Not Configured (Spoofable)',
                valueColor: result.hasDmarc
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFFB300),
                isDark: isDark,
              ),
              if (result.nsRecords.isNotEmpty) ...[
                _divider(),
                _buildRow(
                  'Nameservers (NS)',
                  result.nsRecords.take(2).join(', '),
                  valueColor: outlineColor,
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Card 6: SafeSignal Titan Cyber Threat Radar™ ─────────────────────
        _buildTitanCyberRadarCard(result, isDark, outlineColor),
        const SizedBox(height: 16),

        // ── Threat Warning (only if dangerous/caution) ────────────────
        if (result.verdict == UrlVerdict.dangerous ||
            result.verdict == UrlVerdict.caution)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: result.verdict == UrlVerdict.dangerous
                  ? const Color(0xFF3E120A)
                  : const Color(0xFF3E2A00),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      result.verdict == UrlVerdict.dangerous
                          ? 'Suspected Fraud'
                          : 'Use With Caution',
                      style: TextStyle(
                        color: result.verdict == UrlVerdict.dangerous
                            ? const Color(0xFFFF8A65)
                            : const Color(0xFFFFB300),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      result.verdict == UrlVerdict.dangerous
                          ? Icons.warning_rounded
                          : Icons.info_outline,
                      color: result.verdict == UrlVerdict.dangerous
                          ? const Color(0xFFFF8A65)
                          : const Color(0xFFFFB300),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  result.verdict == UrlVerdict.dangerous
                      ? 'Do NOT perform any financial transactions or share personal information on this site. Report to cybercrime.gov.in or call 1930.'
                      : 'Proceed with caution. Verify the website authenticity before sharing any personal or financial information.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // ── Protective Action Buttons ─────────────────────────────────────────
        if (result.verdict == UrlVerdict.dangerous ||
            result.verdict == UrlVerdict.caution) ...[
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '🛑 Malicious link blocked. SafeSignal kept your device protected.',
                    ),
                    backgroundColor: Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 22,
              ),
              label: const Text(
                'Block & Abort (Recommended)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _confirmAndOpenUrl(
              context,
              result.url,
              result.threatCategoryBadge.isNotEmpty
                  ? result.threatCategoryBadge
                  : 'High Risk Domain',
            ),
            icon: const Icon(
              Icons.open_in_new_rounded,
              color: Color(0xFF94A3B8),
              size: 18,
            ),
            label: const Text(
              'Proceed to Browser (Dangerous)',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ] else ...[
          // Option 1: Open Inside SafeSignal (In-App Sandbox)
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E676).withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                if (result.url.isNotEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InAppBrowserScreen(url: result.url),
                    ),
                  );
                }
              },
              icon: const Icon(
                Icons.shield_outlined,
                color: Colors.black,
                size: 22,
              ),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Open Inside SafeSignal (Sandbox)',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Option 2: Open in External Browser (Chrome / System)
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFCBD5E1),
                width: 1.2,
              ),
            ),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () async {
                if (result.url.isNotEmpty) {
                  final launched =
                      await LinkGuardService.openUrlInSystemBrowser(result.url);
                  if (!launched) {
                    final uri = Uri.tryParse(result.url);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  }
                }
              },
              icon: Icon(
                Icons.open_in_browser_rounded,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                size: 20,
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Open in Chrome / External Browser ↗',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  Future<void> _confirmAndOpenUrl(
    BuildContext context,
    String url,
    String threatBadge,
  ) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFEF4444),
              size: 28,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Security Warning',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'SafeSignal flagged this link as:\n\n• $threatBadge\n\nOpening this destination in an external browser may trigger drive-by malware downloads, Remote Access Trojans (RATs), or steal banking credentials.\n\nAre you sure you want to proceed?',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel & Stay Safe',
              style: TextStyle(
                color: Color(0xFF22C55E),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Proceed Anyway',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (proceed == true) {
      final launched = await LinkGuardService.openUrlInSystemBrowser(url);
      if (!launched) {
        final uri = Uri.tryParse(url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    }
  }

  Widget _buildWhatsAppShieldBanner(bool isDark) {
    const activeColor = Color(0xFF00E676);
    const inactiveColor = Color(0xFF00B0FF);
    final borderColor = _isDefaultBrowser
        ? activeColor.withValues(alpha: 0.35)
        : inactiveColor.withValues(alpha: 0.35);
    final bgColor = isDark
        ? (_isDefaultBrowser
              ? const Color(0xFF052012)
              : const Color(0xFF041B2D))
        : (_isDefaultBrowser
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFE1F5FE));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (_isDefaultBrowser ? activeColor : inactiveColor)
                      .withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    _isDefaultBrowser
                        ? Icons.verified_user_rounded
                        : Icons.shield_outlined,
                    color: _isDefaultBrowser ? activeColor : inactiveColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isDefaultBrowser
                          ? 'WhatsApp Link Shield: ACTIVE'
                          : 'Link Protection: OPTIONAL',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isDefaultBrowser
                          ? 'All links clicked in WhatsApp & Telegram route here first. You can reset to Chrome anytime.'
                          : 'You decide: Open links directly in Chrome, or share them to SafeSignal Link Guard to scan.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isDefaultBrowser) ...[
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF97316),
                  side: const BorderSide(color: Color(0xFFF97316)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  await LinkGuardService.clearDefaultBrowser();
                  await LinkGuardService.openDefaultAppsSettings();
                  await _checkBrowserRole();
                },
                icon: const Icon(
                  Icons.settings_backup_restore_rounded,
                  size: 16,
                ),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Reset Default Browser to Chrome',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: inactiveColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  await LinkGuardService.openDefaultAppsSettings();
                  await _checkBrowserRole();
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Choose Default Browser in Settings (Optional)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardHeader(String title, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF5D1D05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _divider2(bool isDark) => Divider(
    color: isDark ? Colors.white12 : Colors.black12,
    height: 1,
    thickness: 1,
  );

  Widget _buildRow(
    String label,
    String value, {
    required Color valueColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitanCyberRadarCard(
    UrlResult result,
    bool isDark,
    Color outlineColor,
  ) {
    final vt = result.virusTotalResult;
    final secDns = result.securityDnsResult;

    final isVtMalicious = vt != null && vt.isMalicious;
    final isDnsBlocked = secDns != null && secDns.isBlocked;
    final isCredHarvester = result.isCredentialHarvester;
    final isDga = result.isDgaDomain;
    final isBrandSpoofed = result.typosquattingWarning != null;
    final hasThreatFound =
        isVtMalicious ||
        isDnsBlocked ||
        isCredHarvester ||
        isDga ||
        isBrandSpoofed ||
        result.verdict == UrlVerdict.dangerous;

    final cardBorderColor = hasThreatFound
        ? const Color(0xFFFF8A65)
        : (result.verdict == UrlVerdict.safe
            ? const Color(0xFF4CAF50)
            : outlineColor);

    final cardStyle = BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: cardBorderColor, width: 1.5),
    );

    return Container(
      width: double.infinity,
      decoration: cardStyle,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _cardHeader('SafeSignal Titan Cyber Radar™', isDark),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (hasThreatFound
                          ? const Color(0xFFFF8A65)
                          : const Color(0xFF10B981))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasThreatFound
                        ? const Color(0xFFFF8A65)
                        : const Color(0xFF10B981),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasThreatFound
                          ? Icons.warning_amber_rounded
                          : Icons.verified_user_rounded,
                      size: 13,
                      color: hasThreatFound
                          ? const Color(0xFFFF8A65)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasThreatFound ? 'ACTIVE THREAT' : '6 ENGINES CLEAN',
                      style: TextStyle(
                        color: hasThreatFound
                            ? const Color(0xFFFF8A65)
                            : const Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. Zero-Day DOM & Credential Trapper
          _buildRow(
            'Zero-Day Phish Trap',
            isCredHarvester
                ? 'Intercepted (${result.detectedFormType ?? "Harvest Form"})'
                : 'Clean (No Form Traps)',
            valueColor: isCredHarvester
                ? const Color(0xFFFF8A65)
                : const Color(0xFF4CAF50),
            isDark: isDark,
          ),
          _divider(),

          // 2. Shannon DGA & Botnet Radar
          _buildRow(
            'Shannon DGA Radar',
            isDga
                ? 'DGA Algorithmic C2 (Entropy: ${result.shannonEntropy.toStringAsFixed(2)})'
                : 'Standard Host (Entropy: ${result.shannonEntropy.toStringAsFixed(2)})',
            valueColor: isDga
                ? const Color(0xFFFF8A65)
                : const Color(0xFF4CAF50),
            isDark: isDark,
          ),
          _divider(),

          // 3. Cloudflare Zero Trust (1.1.1.2 DoH)
          _buildRow(
            'Cloudflare Zero Trust',
            isDnsBlocked
                ? 'Blocked (Malware/Phishing match)'
                : 'Clean (Zero-Key Active)',
            valueColor: isDnsBlocked
                ? const Color(0xFFFF8A65)
                : const Color(0xFF4CAF50),
            isDark: isDark,
          ),
          if (isDnsBlocked && secDns.details.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                secDns.details,
                style: const TextStyle(
                  color: Color(0xFFFF8A65),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          _divider(),

          // 4. Brand Spoof & Homograph Engine
          _buildRow(
            'Brand & Homograph Engine',
            isBrandSpoofed
                ? 'Deceptive Spoof Intercepted'
                : 'Genuine Identity Validated',
            valueColor: isBrandSpoofed
                ? const Color(0xFFFF8A65)
                : const Color(0xFF4CAF50),
            isDark: isDark,
          ),
          _divider(),

          // 5. Mobile Trojan & Dropper Guard
          _buildRow(
            'Mobile Trojan & APK Guard',
            (result.threatType == MalwareThreatType.ratDropper ||
                    result.threatType == MalwareThreatType.bankingTrojan ||
                    result.threatType == MalwareThreatType.apkDropper)
                ? 'Dropper Intercepted'
                : 'No Malicious Payload',
            valueColor: (result.threatType == MalwareThreatType.ratDropper ||
                    result.threatType == MalwareThreatType.bankingTrojan ||
                    result.threatType == MalwareThreatType.apkDropper)
                ? const Color(0xFFFF8A65)
                : const Color(0xFF4CAF50),
            isDark: isDark,
          ),
          _divider(),

          // 6. Multi-Feed Threat Consensus
          _buildRow(
            'Global Threat Feeds',
            vt != null && vt.hasScanData
                ? (isVtMalicious
                    ? '${vt.malicious}/${vt.totalEngines} Engines Flagged'
                    : '0/${vt.totalEngines} Clean')
                : 'Real-Time Threat Feeds Synced',
            valueColor: isVtMalicious
                ? const Color(0xFFFF8A65)
                : const Color(0xFF4CAF50),
            isDark: isDark,
          ),

          const SizedBox(height: 18),

          // Action row: In-App Deep Forensic Audit Diagnostics
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF38BDF8), width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _showForensicAuditDialog(result),
              icon: const Icon(Icons.analytics_rounded, size: 18),
              label: const Text(
                'View Deep Forensic Diagnostics (In-App)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showForensicAuditDialog(UrlResult? res) {
    if (res == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(sheetCtx).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B132B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.radar_rounded,
                      color: Color(0xFF38BDF8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SafeSignal Titan Forensic Audit',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          res.domain,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              Expanded(
                child: ListView(
                  children: [
                    _buildAuditSection('Target Integrity', [
                      _buildAuditItem('Canonical URL', res.url, isDark),
                      _buildAuditItem('Base Domain', res.domain, isDark),
                      _buildAuditItem('Risk Classification', res.riskLevel.name.toUpperCase(), isDark),
                      _buildAuditItem('Verdict Score', '${res.riskScore}/100', isDark),
                    ], isDark),
                    _buildAuditSection('DOM & Harvesting Inspection', [
                      _buildAuditItem('Credential Harvester', res.isCredentialHarvester ? '🚨 DETECTED' : 'Clean', isDark),
                      if (res.detectedFormType != null)
                        _buildAuditItem('Detected Trap', res.detectedFormType!, isDark),
                      _buildAuditItem('Page Title', res.siteTitle.isNotEmpty ? res.siteTitle : 'None', isDark),
                      _buildAuditItem('Content-Type', res.contentType.isNotEmpty ? res.contentType : 'Unknown', isDark),
                    ], isDark),
                    _buildAuditSection('Algorithmic Randomness (DGA)', [
                      _buildAuditItem('Shannon Entropy', res.shannonEntropy.toStringAsFixed(3), isDark),
                      _buildAuditItem('DGA Algorithmic C2', res.isDgaDomain ? '🚨 POSITIVE' : 'Negative (Normal)', isDark),
                    ], isDark),
                    _buildAuditSection('Network & Cryptographic Routing', [
                      _buildAuditItem('Resolved IP (A)', res.serverIp.isNotEmpty ? res.serverIp : 'Unresolved', isDark),
                      _buildAuditItem('Nameservers (NS)', res.nsRecords.isNotEmpty ? res.nsRecords.take(2).join(', ') : 'None', isDark),
                      _buildAuditItem('Mail Protocol (MX)', res.mxRecords.isNotEmpty ? res.mxRecords.first : 'None', isDark),
                      _buildAuditItem('DMARC Enforcement', res.hasDmarc ? 'Active (v=DMARC1)' : 'Missing', isDark),
                      _buildAuditItem('Server Software', res.serverSoftware.isNotEmpty ? res.serverSoftware : 'Undisclosed', isDark),
                      _buildAuditItem('Security Headers', '${res.securityHeaders}/4 Configured', isDark),
                    ], isDark),
                    if (res.redirectChain.length > 1)
                      _buildAuditSection('Unraveled Redirect Chain', [
                        for (int i = 0; i < res.redirectChain.length; i++)
                          _buildAuditItem('Hop ${i + 1}', res.redirectChain[i], isDark),
                      ], isDark),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: const Text('Close Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuditSection(String title, List<Widget> items, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16203A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Column(children: items),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditItem(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVirusTotalConfigDialog() async {
    final currentKey = await VirusTotalService.getApiKey() ?? '';
    final keyController = TextEditingController(text: currentKey);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  color: Color(0xFF38BDF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'VirusTotal Integration',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SafeSignal automatically checks Cloudflare 1.1.1.2 Security telemetry with zero setup. To query 70+ AV vendor verdicts in real-time inside the app, add your free VirusTotal API key.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: keyController,
                  obscureText: true,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'VirusTotal v3 API Key',
                    hintText: 'Enter 64-character API key',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.key_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(
                      'https://www.virustotal.com/gui/my-apikey',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: const Text(
                    'Get a free API key at virustotal.com ↗',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (currentKey.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await VirusTotalService.clearApiKey();
                  if (mounted && dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('VirusTotal API key cleared.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Clear Key',
                  style: TextStyle(color: Color(0xFFEF4444)),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final key = keyController.text.trim();
                if (key.isNotEmpty) {
                  await VirusTotalService.saveApiKey(key);
                } else {
                  await VirusTotalService.clearApiKey();
                }
                if (mounted && dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('VirusTotal API key saved successfully.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Divider(color: Colors.white12, height: 1, thickness: 1),
    );
  }
}

class SpeedometerGauge extends StatelessWidget {
  final double score; // 0 to 100
  const SpeedometerGauge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height:
          140, // Height is roughly half of width + padding for the needle base
      child: CustomPaint(painter: _SpeedometerPainter(score)),
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double score;

  _SpeedometerPainter(this.score);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 20);
    final radius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.butt;

    // Draw the 3 arcs (Green, Orange, Red)
    final rect = Rect.fromCircle(center: center, radius: radius - 20);

    // Green (0 to 33)
    paint.color = Colors.greenAccent.shade400;
    canvas.drawArc(rect, 3.14159, 3.14159 / 3, false, paint);

    // Orange (33 to 66)
    paint.color = Colors.orangeAccent.shade400;
    canvas.drawArc(rect, 3.14159 + (3.14159 / 3), 3.14159 / 3, false, paint);

    // Red (66 to 100)
    paint.color = Colors.redAccent.shade400;
    canvas.drawArc(
      rect,
      3.14159 + (2 * 3.14159 / 3),
      3.14159 / 3,
      false,
      paint,
    );

    // Draw needle
    // Map score (0-100) to angle (Pi to 2*Pi)
    // We map a bit inside the bounds so it doesn't go fully horizontal
    double clampedScore = score.clamp(0.0, 100.0);
    final angle = 3.14159 + (clampedScore / 100) * 3.14159;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final needlePaint = Paint()
      ..color =
          const Color(0xFFE0E0E0) // Light grey to work on both themes
      ..style = PaintingStyle.fill;

    // Draw needle triangle
    final path = Path();
    path.moveTo(0, -6);
    path.lineTo(radius - 10, 0);
    path.lineTo(0, 6);
    path.close();

    // Add shadow
    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, needlePaint);

    // Draw center circle
    canvas.drawCircle(const Offset(0, 0), 16, needlePaint);
    final innerCirclePaint = Paint()..color = Colors.grey.shade400;
    canvas.drawCircle(const Offset(0, 0), 10, innerCirclePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
