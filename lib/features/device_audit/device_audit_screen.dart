import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

import '../../core/services/supabase_service.dart';
// ─── Data Model ────────────────────────────────────────────────────────────────
class _AuditResult {
  final AndroidDeviceInfo? deviceInfo;
  final List<AppInfo> allApps;
  final List<AppInfo> riskyApps;
  final Map<String, List<AppInfo>> permissionApps;
  final bool developerOptionsEnabled;

  _AuditResult({
    this.deviceInfo,
    required this.allApps,
    required this.riskyApps,
    required this.permissionApps,
    required this.developerOptionsEnabled,
  });
}

// ─── High-risk package keywords ──────────────────────────────────────────────
const _riskyKeywords = [
  'vpn', 'cleaner', 'booster', 'optimizer', 'speed', 'battery', 'ram',
  'loan', 'cash', 'money', 'earn', 'reward', 'casino', 'bet', 'gamble',
  'hack', 'spy', 'monitor', 'tracker', 'screen.recorder', 'screenrec',
  'flashlight', 'qr', 'scanner.pro', 'call.recorder',
];

// ─── Known permission-heavy package patterns ──────────────────────────────────
const _cameraApps = ['camera', 'photo', 'selfie', 'snap', 'instagram', 'tiktok', 'reels', 'zoom', 'meet', 'skype'];
const _smsApps = ['sms', 'message', 'whatsapp', 'telegram', 'signal', 'truecaller', 'loan', 'bank', 'financial'];
const _contactApps = ['truecaller', 'contact', 'dialer', 'phone', 'call', 'sync', 'backup'];
const _micApps = ['voice', 'record', 'mic', 'audio', 'music', 'podcast', 'zoom', 'meet', 'discord', 'clubhouse'];

class DeviceAuditScreen extends StatefulWidget {
  const DeviceAuditScreen({super.key});

  @override
  State<DeviceAuditScreen> createState() => _DeviceAuditScreenState();
}

class _DeviceAuditScreenState extends State<DeviceAuditScreen>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  bool _scanComplete = false;
  double _scanProgress = 0;
  int _currentStage = 0;
  Timer? _scanTimer;
  _AuditResult? _result;
  String _errorMsg = '';

  final List<String> _stages = [
    'Initializing deep scan...',
    'Reading device information...',
    'Scanning installed applications...',
    'Checking critical software updates...',
    'Reviewing developer options...',
    'Auditing app permissions...',
    'Analyzing network security...',
    'Compiling Audit Report...',
  ];

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _runRealScan();
  }

  Future<void> _runRealScan() async {
    try {
      // Stage 1
      _updateStage(0, 5);
      await Future.delayed(const Duration(milliseconds: 400));

      // Stage 2 — Device info
      _updateStage(1, 15);
      AndroidDeviceInfo? deviceInfo;
      try {
        final di = DeviceInfoPlugin();
        deviceInfo = await di.androidInfo;
      } catch (_) {}

      // Stage 3 — Installed apps
      _updateStage(2, 30);
      List<AppInfo> allApps = [];
      try {
        allApps = await InstalledApps.getInstalledApps(excludeSystemApps: true, withIcon: true);
      } catch (e) {
        debugPrint('InstalledApps error: $e');
      }

      // Stage 4 — Software updates check
      _updateStage(3, 50);
      await Future.delayed(const Duration(milliseconds: 500));

      // Stage 5 — Developer options
      _updateStage(4, 65);
      bool devOptionsEnabled = false;
      try {
        const channel = MethodChannel('safesignal/device');
        devOptionsEnabled = await channel.invokeMethod<bool>('isDeveloperOptionsEnabled') ?? false;
      } catch (_) {}

      // Stage 6 — Permission audit
      _updateStage(5, 78);
      final riskyApps = allApps.where((app) {
        final pkgLower = app.packageName.toLowerCase();
        final nameLower = app.name.toLowerCase();
        return _riskyKeywords.any((k) => pkgLower.contains(k) || nameLower.contains(k));
      }).take(10).toList();

      final cameraApps = allApps.where((app) {
        final p = app.packageName.toLowerCase();
        final n = app.name.toLowerCase();
        return _cameraApps.any((k) => p.contains(k) || n.contains(k));
      }).take(6).toList();

      final smsApps = allApps.where((app) {
        final p = app.packageName.toLowerCase();
        final n = app.name.toLowerCase();
        return _smsApps.any((k) => p.contains(k) || n.contains(k));
      }).take(6).toList();

      final contactApps = allApps.where((app) {
        final p = app.packageName.toLowerCase();
        final n = app.name.toLowerCase();
        return _contactApps.any((k) => p.contains(k) || n.contains(k));
      }).take(6).toList();

      final micApps = allApps.where((app) {
        final p = app.packageName.toLowerCase();
        final n = app.name.toLowerCase();
        return _micApps.any((k) => p.contains(k) || n.contains(k));
      }).take(6).toList();

      // Stage 7 — Network
      _updateStage(6, 90);
      await Future.delayed(const Duration(milliseconds: 400));

      // Stage 8 — Finalize
      _updateStage(7, 100);
      await Future.delayed(const Duration(milliseconds: 300));

      final result = _AuditResult(
        deviceInfo: deviceInfo,
        allApps: allApps,
        riskyApps: riskyApps,
        permissionApps: {
          'Camera': cameraApps,
          'SMS': smsApps,
          'Contacts': contactApps,
          'Mic': micApps,
        },
        developerOptionsEnabled: devOptionsEnabled,
      );

      // Save to Supabase
      try {
        await SupabaseService().saveScanHistory(
          scanType: 'DEVICE_AUDIT',
          target: deviceInfo?.model ?? 'Android Device',
          status: (riskyApps.isNotEmpty || devOptionsEnabled) ? 'WARNING' : 'SAFE',
          details: {
            'riskyAppsCount': riskyApps.length,
            'developerOptions': devOptionsEnabled,
            'totalApps': allApps.length,
          },
        );
      } catch (e) {
        debugPrint('Supabase save error: $e');
      }

      if (mounted) {
        setState(() {
          _result = result;
          _scanComplete = true;
          _scanProgress = 100;
        });
        _radarController.stop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _scanComplete = true;
        });
        _radarController.stop();
      }
    }
  }

  void _updateStage(int stage, double progress) {
    if (mounted) {
      setState(() {
        _currentStage = stage;
        _scanProgress = progress;
      });
    }
  }

  void _rescan() {
    setState(() {
      _scanComplete = false;
      _scanProgress = 0;
      _currentStage = 0;
      _result = null;
      _errorMsg = '';
    });
    _radarController.repeat();
    _runRealScan();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _scanTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFFE3F2FD),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0D1117), size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Secure Me',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: Color(0xFF0D1117),
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: true,
          actions: [
            if (_scanComplete)
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2979FF)),
                onPressed: _rescan,
                tooltip: 'Rescan',
              ),
          ],
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
            child: _scanComplete
                ? (_result != null ? _buildReport(_result!) : _buildError())
                : _buildScanning(),
          ),
        ),
      ),
    );
  }

  // ─── Error ─────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Scan failed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMsg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _rescan,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Scanning Phase ─────────────────────────────────────────────────────────
  Widget _buildScanning() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Your Security Checklist',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0D1117), letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Deep scanning your device for real threats…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 60),
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ...List.generate(3, (i) => Container(
                  width: 80.0 + i * 40,
                  height: 80.0 + i * 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2979FF).withOpacity(0.3 - i * 0.08), width: 1.5),
                  ),
                ).animate(onPlay: (c) => c.repeat()).scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.05, 1.05),
                  duration: Duration(milliseconds: 1500 + i * 300),
                  curve: Curves.easeInOut,
                )),
                AnimatedBuilder(
                  animation: _radarController,
                  builder: (ctx, child) => Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2979FF), Color(0xFF1565C0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [BoxShadow(
                        color: const Color(0xFF2979FF).withOpacity(0.5),
                        blurRadius: 20 + _radarController.value * 10,
                        spreadRadius: 2,
                      )],
                    ),
                    child: const Icon(Icons.security, color: Colors.white, size: 36),
                  ),
                ),
                AnimatedBuilder(
                  animation: _radarController,
                  builder: (ctx, child) => Transform.rotate(
                    angle: _radarController.value * 2 * 3.14159,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(colors: [
                          const Color(0xFF2979FF).withOpacity(0.0),
                          const Color(0xFF2979FF).withOpacity(0.3),
                          const Color(0xFF2979FF).withOpacity(0.0),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _scanProgress / 100,
              backgroundColor: Colors.white.withOpacity(0.5),
              color: const Color(0xFF2979FF),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _stages[_currentStage],
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${_scanProgress.toInt()}%',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D1117)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Report Phase ────────────────────────────────────────────────────────────
  Widget _buildReport(_AuditResult r) {
    final devInfo = r.deviceInfo;
    final sdkInt = devInfo?.version.sdkInt ?? 0;
    final isOutdated = sdkInt > 0 && sdkInt < 33; // Android 13 as minimum
    final securityPatch = devInfo?.version.securityPatch ?? 'Unknown';
    final totalApps = r.allApps.length;
    final riskyCount = r.riskyApps.length;
    final appSafetyScore = totalApps > 0 ? ((totalApps - riskyCount) / totalApps * 100).round() : 100;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        // Header
        const SizedBox(height: 8),
        const Text(
          'Your Security Checklist',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0D1117), letterSpacing: -0.5),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 6),
        Text(
          "Scanned $totalApps apps on your device. Tap any section to take action.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
        ).animate().fadeIn(delay: 150.ms),
        const SizedBox(height: 24),

        // 1. Device Info
        if (devInfo != null)
          _AuditCard(
            delay: 150,
            title: 'Device Overview',
            icon: Icons.phone_android_rounded,
            iconColor: const Color(0xFF2979FF),
            statusBadge: _StatusBadge(
              label: isOutdated ? 'Needs Update' : 'Secure',
              color: isOutdated ? Colors.orange : const Color(0xFF00C853),
            ),
            children: [
              _infoRow(Icons.developer_board_rounded, 'Device', '${devInfo.brand} ${devInfo.model}'),
              const SizedBox(height: 8),
              _infoRow(Icons.android_rounded, 'Android', 'API $sdkInt (Android ${_sdkToVersion(sdkInt)})'),
              const SizedBox(height: 8),
              _infoRow(Icons.security_update_rounded, 'Security Patch', securityPatch),
            ],
          ),

        const SizedBox(height: 16),

        // 2. Application Safety
        _AuditCard(
          delay: 250,
          title: 'Applications Safety',
          icon: Icons.apps_rounded,
          iconColor: riskyCount > 3 ? Colors.red.shade600 : Colors.orange.shade700,
          statusBadge: _StatusBadge(
            label: riskyCount > 0 ? '$riskyCount Risky' : 'All Safe',
            color: riskyCount > 3 ? Colors.red.shade600 : riskyCount > 0 ? Colors.orange.shade700 : const Color(0xFF00C853),
          ),
          children: [
            Row(
              children: [
                Text(
                  '$appSafetyScore%',
                  style: TextStyle(
                    color: appSafetyScore < 70 ? Colors.red.shade600 : Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: appSafetyScore / 100,
                      backgroundColor: Colors.grey.shade200,
                      color: appSafetyScore < 70 ? Colors.red.shade600 : Colors.orange.shade700,
                      minHeight: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (riskyCount > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Review $riskyCount potentially risky apps.',
                    style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 22),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: r.riskyApps.take(8).map((app) => _RealAppChip(app)).toList(),
              ),
            ] else
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF00C853), size: 20),
                  SizedBox(width: 10),
                  Text('No high-risk apps found.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            const SizedBox(height: 14),
            Text(
              '$totalApps total apps scanned.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 3. Critical Software Updates
        _AuditCard(
          delay: 350,
          title: 'Critical Software Updates',
          icon: Icons.system_update_rounded,
          iconColor: isOutdated ? Colors.orange.shade700 : const Color(0xFF00C853),
          statusBadge: _StatusBadge(
            label: isOutdated ? 'Outdated' : 'Up to Date',
            color: isOutdated ? Colors.orange.shade700 : const Color(0xFF00C853),
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOutdated ? 'Please Update Your OS.' : 'Your OS is up to date.',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0D1117)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOutdated
                            ? 'API $sdkInt is below recommended Android 13 (API 33).'
                            : 'Android $sdkInt is current and secure.',
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isOutdated ? Icons.update_disabled_rounded : Icons.verified_rounded,
                  color: isOutdated ? Colors.orange.shade700 : const Color(0xFF00C853),
                  size: 28,
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Security Patch: $securityPatch',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 4. Developer Options
        _AuditCard(
          delay: 450,
          title: 'Developer Options',
          icon: Icons.developer_mode_rounded,
          iconColor: r.developerOptionsEnabled ? Colors.red.shade600 : const Color(0xFF00C853),
          statusBadge: _StatusBadge(
            label: r.developerOptionsEnabled ? 'Enabled!' : 'Safe',
            color: r.developerOptionsEnabled ? Colors.red.shade600 : const Color(0xFF00C853),
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Check Android Developer Settings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Icon(Icons.developer_board_off_rounded, color: Colors.grey.shade400, size: 24),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(
                  r.developerOptionsEnabled ? Icons.warning_rounded : Icons.check_circle_rounded,
                  color: r.developerOptionsEnabled ? Colors.red : const Color(0xFF00C853),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.developerOptionsEnabled ? 'Developer Options is ENABLED.' : 'Developer Options Disabled.',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        r.developerOptionsEnabled
                            ? 'This is a security risk. Disable it in Settings > About Phone.'
                            : 'You Are Safe.',
                        style: TextStyle(
                          color: r.developerOptionsEnabled ? Colors.red : const Color(0xFF00C853),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 5. Permissions
        _AuditCard(
          delay: 550,
          title: 'Review Apps Asking Unnecessary Permissions',
          icon: Icons.lock_open_rounded,
          iconColor: Colors.deepPurple,
          statusBadge: _StatusBadge(
            label: '${r.permissionApps.values.fold(0, (sum, list) => sum + list.length)} Apps',
            color: Colors.deepPurple.shade400,
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prevent Data Collection in Apps.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('Apps accessing sensitive permissions:', style: TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                ),
                const Icon(Icons.android_rounded, size: 28, color: Color(0xFF3DDC84)),
              ],
            ),
            const SizedBox(height: 16),
            ...r.permissionApps.entries.map((entry) {
              final permIcons = {
                'Camera': Icons.camera_alt_rounded,
                'SMS': Icons.message_rounded,
                'Contacts': Icons.contacts_rounded,
                'Mic': Icons.mic_rounded,
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RealPermissionRow(
                  label: entry.key,
                  icon: permIcons[entry.key] ?? Icons.lock_rounded,
                  apps: entry.value,
                ),
              );
            }),
          ],
        ),

        const SizedBox(height: 16),

        // 6. Network Security
        _AuditCard(
          delay: 650,
          title: 'Network & DNS Security',
          icon: Icons.wifi_tethering_rounded,
          iconColor: const Color(0xFF2979FF),
          statusBadge: const _StatusBadge(label: 'Checked', color: Color(0xFF2979FF)),
          children: [
            _infoRow(Icons.dns_rounded, 'DNS', 'Default ISP DNS — Consider secure DNS (1.1.1.1)'),
            const SizedBox(height: 10),
            _infoRow(Icons.vpn_lock_rounded, 'VPN', 'No active VPN detected — traffic may be unencrypted'),
          ],
        ),

        const SizedBox(height: 24),

        // Rescan button
        GestureDetector(
          onTap: _rescan,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2979FF), Color(0xFF1565C0)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFF2979FF).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text('Run New Audit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 750.ms).slideY(begin: 0.1),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2979FF)),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.black54))),
      ],
    );
  }

  String _sdkToVersion(int sdk) {
    const map = {34: '14', 33: '13', 32: '12L', 31: '12', 30: '11', 29: '10', 28: '9', 27: '8.1', 26: '8.0'};
    return map[sdk] ?? sdk.toString();
  }
}

// ─── Supporting Widgets ────────────────────────────────────────────────────────

class _AuditCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget statusBadge;
  final List<Widget> children;
  final int delay;

  const _AuditCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.statusBadge,
    required this.children,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0D1117)))),
              statusBadge,
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideY(begin: 0.06);
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _RealAppChip extends StatelessWidget {
  final AppInfo app;
  const _RealAppChip(this.app);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (app.icon != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(app.icon!, width: 16, height: 16, fit: BoxFit.cover),
            )
          else
            const Icon(Icons.android_rounded, size: 14, color: Colors.red),
          const SizedBox(width: 4),
          Text(
            app.name.length > 12 ? '${app.name.substring(0, 12)}…' : app.name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

class _RealPermissionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<AppInfo> apps;

  const _RealPermissionRow({required this.label, required this.icon, required this.apps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 6),
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        const SizedBox(width: 8),
        ...apps.take(5).toList().asMap().entries.map((e) => Transform.translate(
          offset: Offset(-e.key * 8.0, 0),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.primaries[e.key % Colors.primaries.length],
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: e.value.icon != null
                ? ClipOval(child: Image.memory(e.value.icon!, fit: BoxFit.cover))
                : const Icon(Icons.android_rounded, size: 14, color: Colors.white),
          ),
        )),
        if (apps.length > 5) ...[
          const SizedBox(width: 4),
          Text('+${apps.length} apps', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}
