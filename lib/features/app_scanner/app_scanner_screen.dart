import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/arc_gauge.dart';
import '../../core/services/supabase_service.dart';
import 'package:dio/dio.dart';
import '../../core/constants.dart';
class AppScannerScreen extends StatefulWidget {
  const AppScannerScreen({super.key});

  @override
  State<AppScannerScreen> createState() => _AppScannerScreenState();
}

class _AppScannerScreenState extends State<AppScannerScreen>
    with TickerProviderStateMixin {
  static const _channel = MethodChannel('com.safesignal/app_scanner');

  _Phase _phase = _Phase.idle;
  List<AppInfo> _allApps = [];
  List<AppInfo> _displayed = [];
  int _tabIndex = 0; // 0=all, 1=thirdParty, 2=highRisk
  String _search = '';
  int _scanned = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _tabIndex = _tabController.index;
          _applyFilters();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _phase = _Phase.scanning;
      _scanned = 0;
      _allApps = [];
    });

    try {
      final rawList = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      final list = rawList ?? [];
      final analyzed = <AppInfo>[];

      for (int i = 0; i < list.length; i++) {
        final raw = Map<String, dynamic>.from(list[i] as Map);
        analyzed.add(RiskEngine.analyze(raw));
        if (i % 5 == 0) {
          setState(() => _scanned = i + 1);
          await Future.delayed(const Duration(milliseconds: 5));
        }
      }

      analyzed.sort((a, b) => b.riskScore.compareTo(a.riskScore));

      // Save to Supabase
      try {
        final riskyCount = analyzed.where((a) => a.riskLevel == RiskLevel.high || a.riskLevel == RiskLevel.critical).length;
        await SupabaseService().saveScanHistory(
          scanType: 'APP_SCAN',
          target: '${analyzed.length} Apps',
          status: riskyCount > 0 ? 'WARNING' : 'SAFE',
          details: {
            'totalApps': analyzed.length,
            'riskyApps': riskyCount,
          },
        );
      } catch (e) {
        debugPrint('Supabase save error: $e');
      }

      setState(() {
        _allApps = analyzed;
        _phase = _Phase.done;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _phase = _Phase.error);
    }
  }

  void _applyFilters() {
    List<AppInfo> list = _allApps;

    // Search
    if (_search.isNotEmpty) {
      list = list.where((a) =>
          a.name.toLowerCase().contains(_search.toLowerCase()) ||
          a.package.toLowerCase().contains(_search.toLowerCase())).toList();
    }

    // Tab filter
    if (_tabIndex == 1) {
      list = list.where((a) => !a.isSystem).toList();
    } else if (_tabIndex == 2) {
      list = list.where((a) => a.riskLevel == RiskLevel.high || a.riskLevel == RiskLevel.critical).toList();
    }

    setState(() => _displayed = list);
  }

  double get _avgRating {
    if (_allApps.isEmpty) return 0;
    final avgScore = _allApps.fold(0, (sum, a) => sum + a.riskScore) / _allApps.length;
    // Invert: high score = risky = low rating
    return ((100 - avgScore) / 20).clamp(0.0, 5.0);
  }

  Color get _gaugeColor {
    final r = _avgRating;
    if (r >= 4.0) return const Color(0xFF10B981);
    if (r >= 2.5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {

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
          'App Audit',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: Color(0xFF0D1117),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
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
          child: _phase == _Phase.idle
              ? _buildIdle()
              : _phase == _Phase.scanning
                  ? _buildScanning()
                  : _phase == _Phase.error
                      ? _buildError()
                      : _buildResults(),
        ),
      ),
    );
  }

  Widget _buildIdle() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.android_rounded,
              size: 56,
              color: AppTheme.primary,
            ).animate().scale(begin: const Offset(0.7, 0.7)).fadeIn(),
            const SizedBox(height: 28),
            const Text(
              'App Security Scanner',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1565C0),
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 10),
            const Text(
              'Analyze installed apps for hidden permissions, sideloading risks, and SDK vulnerabilities.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFF64748B),
              ),
            ).animate().fadeIn(delay: 160.ms),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.radar, size: 22),
              label: const Text('Start Full Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                elevation: 0,
              ),
            ).animate().fadeIn(delay: 220.ms),
            const SizedBox(height: 14),
            const Text(
              '🔒 100% on-device analysis',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanning() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: ArcGauge(
              value: _scanned.toDouble(),
              maxValue: 200, // Estimate for scaling
              color: const Color(0xFF2979FF),
              trackColor: const Color(0xFFE2E8F0),
              strokeWidth: 16,
              sweepDegrees: 210,
              centerChild: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    '$_scanned',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2979FF),
                      height: 1,
                    ),
                  ),
                  const Text(
                    'apps',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Analyzing Environment...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scanning for sideloaded apps and risky permissions',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Scan Failed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Could not access package manager. Are you running on an emulator without permissions?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _startScan,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final rating = _avgRating;
    final gc = _gaugeColor;
    final critical = _allApps.where((a) => a.riskLevel == RiskLevel.critical).length;
    final high = _allApps.where((a) => a.riskLevel == RiskLevel.high).length;
    final thirdParty = _allApps.where((a) => !a.isSystem).length;

    return Column(
      children: [
        // Top gauge + rating
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
          child: Column(
            children: [
              SizedBox(
                width: 200,
                height: 160,
                child: ArcGauge(
                  value: rating,
                  maxValue: 5.0,
                  color: gc,
                  trackColor: const Color(0xFFE2E8F0),
                  strokeWidth: 20,
                  sweepDegrees: 210,
                  centerChild: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: rating.toStringAsFixed(1).split('.')[0],
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: gc,
                                height: 1,
                              ),
                            ),
                            TextSpan(
                              text: '.${rating.toStringAsFixed(1).split('.')[1]}',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: gc.withValues(alpha: 0.7),
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        '/ 5',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Text(
                "Device Security Rating",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              // Summary stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatPill(label: '${_allApps.length}', sub: 'Total', color: const Color(0xFF2979FF)),
                  const SizedBox(width: 8),
                  _StatPill(label: '$thirdParty', sub: 'Third-Party', color: const Color(0xFF7C4DFF)),
                  const SizedBox(width: 8),
                  _StatPill(label: '${critical + high}', sub: 'High Risk', color: const Color(0xFFEF4444)),
                ],
              ),
            ],
          ),
        ),

        // Tabs
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF2979FF),
            unselectedLabelColor: const Color(0xFF94A3B8),
            indicatorColor: const Color(0xFF2979FF),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            tabs: [
              Tab(text: 'All (${_allApps.length})'),
              Tab(text: '3rd-Party ($thirdParty)'),
              Tab(text: 'High Risk (${critical + high})'),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) {
              _search = v;
              _applyFilters();
            },
            style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search by name or package...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        // App list
        Expanded(
          child: _displayed.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _tabIndex == 2 ? Icons.verified_user_rounded : Icons.search_off_rounded,
                          size: 52,
                          color: const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _tabIndex == 2
                              ? 'No high risk apps found! ✅'
                              : 'No apps found.',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _displayed.length,
                  itemBuilder: (context, i) => _AppCard(
                    app: _displayed[i],
                    index: i,
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── App Card ─────────────────────────────────────────────────────────────────
class _AppCard extends StatefulWidget {
  final AppInfo app;
  final int index;
  const _AppCard({required this.app, required this.index});

  @override
  State<_AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<_AppCard> {
  bool _expanded = false;
  Uint8List? _iconBytes;
  bool _iconLoaded = false;
  bool _vtScanning = false;
  String? _vtResult;

  @override
  void initState() {
    super.initState();
    _loadIcon();
  }

  Future<void> _loadIcon() async {
    try {
      final bytes = await const MethodChannel('com.safesignal/app_scanner')
          .invokeMethod<Uint8List>('getAppIcon', {'package': widget.app.package});
      if (mounted) {
        setState(() {
          _iconBytes = bytes;
          _iconLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _iconLoaded = true;
        });
      }
    }
  }

  Future<void> _verifyWithVirusTotal() async {
    if (AppConstants.virusTotalApiKey.isEmpty) {
      setState(() => _vtResult = 'VirusTotal API key missing!');
      return;
    }
    setState(() {
      _vtScanning = true;
      _vtResult = null;
    });

    try {
      final hash = await const MethodChannel('com.safesignal/app_scanner')
          .invokeMethod<String>('getAppHash', {'package': widget.app.package});
      
      if (hash == null || hash.isEmpty) {
        setState(() {
          _vtScanning = false;
          _vtResult = 'Could not compute APK hash.';
        });
        return;
      }

      final response = await Dio().get(
        'https://www.virustotal.com/api/v3/files/$hash',
        options: Options(
          headers: {'x-apikey': AppConstants.virusTotalApiKey},
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final stats = response.data['data']['attributes']['last_analysis_stats'];
        final malicious = stats['malicious'] as int? ?? 0;
        final suspicious = stats['suspicious'] as int? ?? 0;
        
        setState(() {
          _vtScanning = false;
          if (malicious > 0) {
            _vtResult = 'DANGER: $malicious engines detected malware!';
          } else if (suspicious > 0) {
            _vtResult = 'Warning: $suspicious engines flagged as suspicious.';
          } else {
            _vtResult = 'Safe: 0 engines detected threats.';
          }
        });
      } else {
        setState(() {
          _vtScanning = false;
          _vtResult = 'App not found in VirusTotal database.';
        });
      }
    } on DioException catch (e) {
      setState(() {
        _vtScanning = false;
        if (e.response?.statusCode == 404) {
          _vtResult = 'App not found in VirusTotal database (likely safe).';
        } else {
          _vtResult = 'API Error: Rate limited or unavailable.';
        }
      });
    } catch (e) {
      setState(() {
        _vtScanning = false;
        _vtResult = 'Error verifying with VirusTotal.';
      });
    }
  }

  Color get _ratingColor {
    final r = widget.app.starRating;
    if (r >= 4.0) return const Color(0xFF10B981); // Emerald
    if (r >= 2.5) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final rc = _ratingColor;
    
    // Determine install source nicely
    String source;
    final storeName = RiskEngine.getStoreName(app.installer);
    if (app.isSystem) {
      source = 'System App';
    } else if (storeName != null) {
      source = storeName;
    } else if (RiskEngine.isVerifiedEcosystem(app.package)) {
      source = 'Verified Ecosystem';
    } else {
      source = app.installer.isEmpty || app.installer == 'unknown'
          ? 'Direct APK / Sideload'
          : 'Sideloaded (${app.installer})';
    }

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _expanded ? rc.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
            width: _expanded ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // App icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _iconLoaded && _iconBytes != null
                        ? Image.memory(_iconBytes!, fit: BoxFit.cover)
                        : const Center(child: Icon(Icons.android, color: Color(0xFF94A3B8))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          app.package,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Source: $source',
                          style: TextStyle(
                            fontSize: 11,
                            color: (source.startsWith('Sideloaded') || source.startsWith('Direct APK'))
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF059669),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Risk Score',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${app.riskScore}/100',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: rc,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        app.riskLabel.split(' ').last, // just emoji
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: rc,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // View details row
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Text(
                      _expanded ? 'Hide Details' : 'View Details',
                      style: TextStyle(
                        color: rc,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_right,
                      color: rc,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded details
            if (_expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: rc.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                  border: Border(
                    top: BorderSide(color: rc.withValues(alpha: 0.15)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security Issues (${app.riskReasons.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: rc,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (app.riskReasons.isEmpty)
                      const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'No major security issues found ✅',
                            style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    else
                      ...app.riskReasons.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber_rounded, color: rc, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    r,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: Color(0xFF334155),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Target SDK: ${app.targetSdk}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Total perms: ${app.permissions.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (app.riskLevel != RiskLevel.safe || app.installer != 'com.android.vending')
                      InkWell(
                        onTap: _vtScanning ? null : _verifyWithVirusTotal,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: rc.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.security_rounded, color: rc, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _vtScanning 
                                      ? 'Scanning with VirusTotal...' 
                                      : (_vtResult ?? 'Verify with VirusTotal API'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: rc,
                                  ),
                                ),
                              ),
                              if (_vtScanning)
                                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: rc)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: widget.index * 25));
  }
}

// ─── Risk Engine ──────────────────────────────────────────────────────────────
enum RiskLevel { safe, low, medium, high, critical }

class AppInfo {
  final String name, package, version, installer;
  final int targetSdk;
  final List<String> permissions;
  final bool isSystem;
  final bool hasLauncher;
  final bool hasAccessibility;
  final bool hasDeviceAdmin;
  final int riskScore; // 0-100 (100 = bad)
  final RiskLevel riskLevel;
  final List<String> riskReasons;

  const AppInfo({
    required this.name, required this.package, required this.version,
    required this.installer, required this.targetSdk,
    required this.permissions, required this.isSystem,
    required this.hasLauncher, required this.hasAccessibility, required this.hasDeviceAdmin,
    required this.riskScore, required this.riskLevel, required this.riskReasons,
  });

  /// Maps 0-100 risk score to 1.0-5.0 stars for the top gauge
  double get starRating => (5.0 - (riskScore * 4.0 / 100.0)).clamp(1.0, 5.0);

  String get riskLabel {
    final r = starRating;
    if (r >= 4.5) return 'Safe ✅';
    if (r >= 3.5) return 'Low Risk 🟡';
    if (r >= 2.5) return 'Moderate 🟠';
    if (r >= 1.5) return 'High Risk 🔴';
    return 'Critical ⛔';
  }
}

class RiskEngine {
  static final Map<String, String> storeNames = {
    'com.android.vending': 'Google Play Store',
    'com.google.android.feedback': 'Google Play Services',
    'com.google.android.packageinstaller': 'System Package Installer',
    'com.android.packageinstaller': 'System Package Installer',
    'com.sec.android.app.samsungapps': 'Samsung Galaxy Store',
    'com.xiaomi.mipicks': 'Xiaomi GetApps',
    'com.oppo.market': 'Oppo App Market',
    'com.heytap.market': 'HeyTap App Market',
    'com.vivo.appstore': 'Vivo V-Appstore',
    'com.bbk.appstore': 'Vivo App Store',
    'com.huawei.appmarket': 'Huawei AppGallery',
    'com.amazon.venezia': 'Amazon Appstore',
    'org.fdroid.fdroid': 'F-Droid',
    'org.fdroid.basic': 'F-Droid',
    'com.aurora.store': 'Aurora Store',
  };

  static String? getStoreName(String installer) => storeNames[installer];

  static bool isVerifiedEcosystem(String pkg) {
    const verifiedPrefixes = [
      'com.google.',
      'com.android.',
      'com.sec.android.',
      'com.samsung.',
      'com.whatsapp',
      'org.telegram.',
      'org.thoughtcrime.securesms',
      'com.instagram.',
      'com.facebook.',
      'com.microsoft.',
      'com.truecaller',
      'com.phonepe.',
      'net.one97.paytm',
      'in.org.npci.',
      'com.spotify.',
      'com.netflix.',
      'com.ubercab',
      'in.swiggy.',
      'com.application.zomato',
      'com.safesignal.',
      'com.twitter.',
      'com.linkedin.',
      'com.amazon.',
      'com.flipkart.',
    ];
    return verifiedPrefixes.any((prefix) => pkg.startsWith(prefix));
  }

  static const _dangerPerms = {
    'android.permission.RECORD_AUDIO':              ('Microphone',        6, 'Can record audio in background.'),
    'android.permission.CAMERA':                    ('Camera',            6, 'Can access camera.'),
    'android.permission.READ_CONTACTS':             ('Contacts',          8, 'Can read contacts.'),
    'android.permission.READ_SMS':                  ('Read SMS',          18, 'Can read OTPs and private messages.'),
    'android.permission.SEND_SMS':                  ('Send SMS',          15, 'Can send premium SMS messages.'),
    'android.permission.RECEIVE_SMS':               ('Receive SMS',       15, 'Can intercept incoming OTPs.'),
    'android.permission.ACCESS_FINE_LOCATION':      ('Precise Location',  6, 'Can track exact GPS location.'),
    'android.permission.ACCESS_BACKGROUND_LOCATION':('24/7 Location',     14, 'Can track location even when closed.'),
    'android.permission.READ_CALL_LOG':             ('Call History',      10, 'Can see who you called.'),
    'android.permission.PROCESS_OUTGOING_CALLS':    ('Intercept Calls',   16, 'Can monitor or block outgoing calls.'),
    'android.permission.SYSTEM_ALERT_WINDOW':       ('Screen Overlay',    22, 'Can draw over other apps.'),
    'android.permission.BIND_ACCESSIBILITY_SERVICE':('Accessibility',     35, 'Full control of device. Very dangerous if misused.'),
    'android.permission.REQUEST_INSTALL_PACKAGES':  ('Install Apps',      18, 'Can install other apps.'),
  };

  static AppInfo analyze(Map<String, dynamic> raw) {
    final perms = (raw['permissions'] as List<dynamic>?)?.cast<String>() ?? [];
    final name = raw['name'] as String? ?? 'Unknown';
    final pkg = raw['package'] as String? ?? '';
    final isSystem = raw['isSystem'] as bool? ?? false;
    final version = raw['versionName'] as String? ?? '';
    final installer = raw['installer'] as String? ?? '';
    final targetSdk = raw['targetSdk'] as int? ?? 33;
    final hasLauncher = raw['hasLauncher'] as bool? ?? true;
    final hasAccessibility = raw['hasAccessibility'] as bool? ?? false;
    final hasDeviceAdmin = raw['hasDeviceAdmin'] as bool? ?? false;

    int score = 0;
    final reasons = <String>[];

    final isKnownStore = storeNames.containsKey(installer);
    final isVerified = isVerifiedEcosystem(pkg);
    final isSideloaded = !isSystem && !isKnownStore && !isVerified;

    if (isSystem) {
      score = 0;
    } else {
      if (isSideloaded) {
        score += 15;
        final instLabel = installer.isEmpty || installer == 'unknown' ? 'Direct APK' : installer;
        reasons.add('Sideloaded App: Installed via unverified source ($instLabel).');
      }

      if (targetSdk < 28) {
        score += 15;
        reasons.add('Outdated SDK (Target: $targetSdk): Bypasses modern Android security protections.');
      }

      if (!hasLauncher) {
        score += 40;
        reasons.insert(0, 'CRITICAL (Hidden Spyware): App is hiding its launcher icon.');
      }

      if (hasAccessibility) {
        score += 35;
        reasons.insert(0, 'CRITICAL (Control): Has Accessibility Service enabled.');
      }

      if (hasDeviceAdmin) {
        score += 35;
        reasons.insert(0, 'CRITICAL (Admin): Requests Device Admin rights.');
      }

      for (final perm in perms) {
        final info = _dangerPerms[perm];
        if (info != null) {
          int weight = info.$2;
          if (isVerified) {
            weight = (weight * 0.15).round(); // Verified ecosystem apps have expected permissions
          } else if (isKnownStore && targetSdk >= 30) {
            weight = (weight * 0.35).round(); // Legitimate store apps vetted by platform
          }

          if (weight > 0) {
            score += weight;
            if (info.$2 >= 18 || isSideloaded) {
              reasons.add('${info.$1}: ${info.$3}');
            }
          }
        }
      }

      // Flag truly dangerous malware combinations
      final hasInternet = perms.contains('android.permission.INTERNET');

      if (perms.contains('android.permission.RECEIVE_SMS') && perms.contains('android.permission.SYSTEM_ALERT_WINDOW')) {
        score += 35;
        reasons.insert(0, 'CRITICAL: Requests SMS + Screen Overlay (Classic Banking Trojan Pattern).');
      }

      if (hasInternet && perms.contains('android.permission.BIND_ACCESSIBILITY_SERVICE')) {
        score += 40;
        reasons.insert(0, 'CRITICAL: Accessibility + Internet (High Risk of Screen Scraping / Data Theft).');
      }

      // Only penalize unverified / sideloaded apps for generic mic/camera combos
      if (isSideloaded && hasInternet && perms.contains('android.permission.RECORD_AUDIO')) {
        score += 10;
        reasons.add('Potential Risk: Unverified app requesting Mic + Internet.');
      }

      if (isSideloaded && hasInternet && perms.contains('android.permission.CAMERA')) {
        score += 10;
        reasons.add('Potential Risk: Unverified app requesting Camera + Internet.');
      }

      if (isSideloaded && hasInternet && perms.contains('android.permission.READ_CONTACTS')) {
        score += 12;
        reasons.add('Data Privacy Risk: Unverified app requesting Contacts + Internet.');
      }
    }

    score = score.clamp(0, 100);

    final level = score >= 75
        ? RiskLevel.critical
        : score >= 50
            ? RiskLevel.high
            : score >= 30
                ? RiskLevel.medium
                : score >= 15
                    ? RiskLevel.low
                    : RiskLevel.safe;

    return AppInfo(
      name: name, package: pkg, version: version, 
      installer: installer, targetSdk: targetSdk,
      permissions: perms, isSystem: isSystem, 
      hasLauncher: hasLauncher, hasAccessibility: hasAccessibility, hasDeviceAdmin: hasDeviceAdmin,
      riskScore: score, riskLevel: level,
      riskReasons: reasons,
    );
  }
}

enum _Phase { idle, scanning, done, error }

// ─── Stat Pill ────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label, sub;
  final Color color;
  const _StatPill({
    required this.label,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
