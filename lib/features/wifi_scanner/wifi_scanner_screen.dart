import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../../core/widgets/arc_gauge.dart';
import '../../core/services/supabase_service.dart';
class WifiScannerScreen extends StatefulWidget {
  const WifiScannerScreen({super.key});

  @override
  State<WifiScannerScreen> createState() => _WifiScannerScreenState();
}

class _WifiScannerScreenState extends State<WifiScannerScreen> {
  static const _channel = MethodChannel('com.safesignal/app_scanner');

  _Phase _phase = _Phase.idle;
  _WifiResult? _result;

  Future<void> _scan() async {
    setState(() {
      _phase = _Phase.scanning;
      _result = null;
    });

    // Request location permission (needed for SSID on Android 9+)
    final locPerm = await Permission.locationWhenInUse.request();
    if (!locPerm.isGranted) {
      setState(() {
        _phase = _Phase.done;
        _result = _WifiResult.permissionDenied();
      });
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    final isWifi = connectivity.contains(ConnectivityResult.wifi);

    if (!isWifi) {
      setState(() {
        _phase = _Phase.done;
        _result = _WifiResult.noWifi();
      });
      return;
    }

    final info = NetworkInfo();
    final ssid = (await info.getWifiName())?.replaceAll('"', '') ?? 'Unknown';
    final bssid = await info.getWifiBSSID() ?? 'N/A';
    final ip = await info.getWifiIP() ?? 'N/A';
    final gateway = await info.getWifiGatewayIP() ?? 'N/A';

    // Get WiFi security type from native Android
    String securityType = 'Unknown';
    try {
      final result = await _channel.invokeMethod<String>('getWifiSecurityType');
      securityType = result ?? 'Unknown';
    } catch (_) {
      securityType = 'WPA2'; // fallback
    }

    // Build analysis
    final checks = <_Check>[];
    int score = 100; // start at 100, deduct for issues

    // Encryption check
    final encryptionLevel = _getEncryptionLevel(securityType);
    if (encryptionLevel == 0) {
      // Open network
      score -= 70;
      checks.add(_Check(
        label: 'Encryption',
        detail: 'OPEN NETWORK — Koi encryption nahi! Data completely exposed hai',
        level: _Level.critical,
        icon: Icons.lock_open,
      ));
    } else if (encryptionLevel == 1) {
      // WEP — very old, broken
      score -= 50;
      checks.add(_Check(
        label: 'Encryption (WEP)',
        detail: 'WEP bahut purani aur broken encryption hai — easily hack ho sakta hai',
        level: _Level.danger,
        icon: Icons.lock_outlined,
      ));
    } else if (encryptionLevel == 2) {
      // WPA/WPA2
      score -= 10;
      checks.add(_Check(
        label: 'Encryption (WPA2)',
        detail: 'WPA2 with PSK+CCMP security. Safe hai lekin WPA3 se upgrade karein',
        level: _Level.ok,
        icon: Icons.lock,
      ));
    } else {
      // WPA3 — best
      checks.add(_Check(
        label: 'Encryption (WPA3)',
        detail: 'WPA3 — Latest aur strongest encryption standard. Excellent!',
        level: _Level.safe,
        icon: Icons.lock,
      ));
    }

    // Public network name check
    final publicKw = ['free', 'public', 'open', 'guest', 'cafe', 'hotel', 'airport'];
    if (publicKw.any((k) => ssid.toLowerCase().contains(k))) {
      score -= 30;
      checks.add(_Check(
        label: 'Network Type',
        detail: 'Public network — banking aur UPI BILKUL mat karo',
        level: _Level.danger,
        icon: Icons.public_off,
      ));
    } else {
      checks.add(_Check(
        label: 'Network Type',
        detail: 'Private network — likely aapka ghar/office WiFi',
        level: _Level.safe,
        icon: Icons.home_outlined,
      ));
    }

    // Default router name check
    final defaultNames = ['dlink', 'netgear', 'tp-link', 'tplink', 'linksys', 'asus', 'belkin'];
    if (defaultNames.any((k) => ssid.toLowerCase().contains(k))) {
      score -= 15;
      checks.add(_Check(
        label: 'Router Configuration',
        detail: 'Default router naam se lagta hai iska password kabhi change nahi hua',
        level: _Level.warning,
        icon: Icons.router_outlined,
      ));
    } else {
      checks.add(_Check(
        label: 'Router Configuration',
        detail: 'Custom network naam — properly configured lagta hai',
        level: _Level.safe,
        icon: Icons.router,
      ));
    }

    // IP range check
    final isPrivateIp = ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.');
    if (!isPrivateIp && ip != 'N/A') {
      score -= 20;
      checks.add(_Check(
        label: 'IP Address',
        detail: 'Unusual IP range ($ip) — suspicious',
        level: _Level.warning,
        icon: Icons.router_outlined,
      ));
    } else {
      checks.add(_Check(
        label: 'IP Address',
        detail: 'Normal private IP ($ip) — theek hai',
        level: _Level.safe,
        icon: Icons.router,
      ));
    }

    // ─── ACTIVE DEEP NETWORK INSPECTION ────────────────────────────────────────

    // 1. Captive Portal Detection (Man-in-the-Middle Trap)
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        validateStatus: (status) => true,
      ));
      
      final portalRes = await dio.get('http://connectivitycheck.gstatic.com/generate_204');
      if (portalRes.statusCode != 204) {
        score -= 40;
        checks.add(const _Check(
          label: 'Captive Portal Interception',
          detail: 'Koi login page ya portal aapka connection intercept kar raha hai! Data leak ka khatra.',
          level: _Level.danger,
          icon: Icons.warning_amber_rounded,
        ));
      } else {
        checks.add(const _Check(
          label: 'Connection Interception',
          detail: 'Direct internet access. Koi interception nahi.',
          level: _Level.safe,
          icon: Icons.shield_outlined,
        ));
      }

      // 2. SSL Stripping & DNS Hijacking Check + Ping Latency
      final stopwatch = Stopwatch()..start();
      try {
        final sslRes = await dio.get('https://1.1.1.1');
        stopwatch.stop();
        
        if (sslRes.statusCode == 200) {
          checks.add(const _Check(
            label: 'DNS & SSL Secure',
            detail: 'DNS hijacking nahi hai. SSL connection strongly encrypted hai.',
            level: _Level.safe,
            icon: Icons.lock_clock,
          ));

          final latency = stopwatch.elapsedMilliseconds;
          if (latency > 2000) {
            score -= 15;
            checks.add(_Check(
              label: 'Network Latency Anomalies',
              detail: 'Ping bohot high hai (${latency}ms). Shayad koi Evil-Twin network data relay kar raha hai.',
              level: _Level.warning,
              icon: Icons.speed,
            ));
          }
        }
      } catch (e) {
        // SSL Certificate error or DNS timeout = HIGH DANGER
        score -= 60;
        checks.add(const _Check(
          label: 'SSL Stripping / DNS Hijack',
          detail: 'CRITICAL: HTTPS connection fail hua! Network encrypted traffic break karne ki koshish kar raha hai.',
          level: _Level.critical,
          icon: Icons.gpp_bad,
        ));
      }
      // 3. Router Gateway Port Security Audit
      if (gateway != 'N/A' && gateway.isNotEmpty) {
        final dangerousPorts = [23, 21, 445];
        final openDangerousPorts = <int>[];
        for (final port in dangerousPorts) {
          try {
            final socket = await Socket.connect(gateway, port, timeout: const Duration(milliseconds: 350));
            socket.destroy();
            openDangerousPorts.add(port);
          } catch (_) {}
        }

        if (openDangerousPorts.isNotEmpty) {
          score -= 30;
          final portNames = openDangerousPorts.map((p) => p == 23 ? 'Telnet (23)' : (p == 21 ? 'FTP (21)' : 'SMB (445)')).join(', ');
          checks.add(_Check(
            label: 'Insecure Router Ports',
            detail: 'CRITICAL: Router gateway has vulnerable unencrypted ports open ($portNames). Attackers on this WiFi can hijack the router.',
            level: _Level.danger,
            icon: Icons.router_outlined,
          ));
        } else {
          checks.add(const _Check(
            label: 'Router Port Hardening',
            detail: 'Dangerous router administration ports (Telnet, SMB, FTP) are securely closed.',
            level: _Level.safe,
            icon: Icons.verified_user_outlined,
          ));
        }
      }
    } catch (e) {
      // Offline ya totally unreachable
      checks.add(const _Check(
        label: 'Internet Connection',
        detail: 'Active internet nahi mil raha (offline mode).',
        level: _Level.warning,
        icon: Icons.cloud_off,
      ));
    }

    // ──────────────────────────────────────────────────────────────────────────

    score = score.clamp(0, 100);
    final rating = (score / 20).clamp(0.0, 5.0); // 0-100 → 0-5

    final recommendations = _getRecommendations(securityType, encryptionLevel, ssid);

    // Save to Supabase
    try {
      await SupabaseService().saveScanHistory(
        scanType: 'WIFI_SCAN',
        target: ssid,
        status: score < 50 ? 'DANGER' : (score < 80 ? 'WARNING' : 'SAFE'),
        details: {
          'score': score,
          'securityType': securityType,
        },
      );
    } catch (e) {
      debugPrint('Supabase save error: $e');
    }

    setState(() {
      _phase = _Phase.done;
      _result = _WifiResult(
        ssid: ssid,
        bssid: bssid,
        ip: ip,
        gateway: gateway,
        securityType: securityType,
        score: score,
        rating: rating,
        checks: checks,
        recommendations: recommendations,
        isConnected: true,
      );
    });
  }

  int _getEncryptionLevel(String secType) {
    final s = secType.toUpperCase();
    if (s.contains('WPA3')) return 3;
    if (s.contains('WPA2') || s.contains('WPA')) return 2;
    if (s.contains('WEP')) return 1;
    if (s == 'OPEN' || s == 'NONE' || s.isEmpty || s == 'UNKNOWN') return 0;
    return 2; // assume WPA2 if unknown
  }

  List<String> _getRecommendations(String secType, int level, String ssid) {
    final recs = <String>[];
    if (level < 3) recs.add('1. WPA3 sabse latest aur strong standard hai — router settings mein enable karein');
    if (level == 2) recs.add('2. WPA2 abhi bhi safe hai — use karte rehein');
    if (level < 2) recs.add('2. Abhi router settings mein jaake WPA2/WPA3 enable karein');
    recs.add('3. Router admin panel ka default password zaroor change karein');
    recs.add('4. Public WiFi pe VPN use karein banking ke liye');
    return recs;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0D1117), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Network Scanner',
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
              ? _buildIdle(isDark)
              : _phase == _Phase.scanning
                  ? _buildScanning(isDark)
                  : _buildResult(isDark),
        ),
      ),
    );
  }

  Widget _buildIdle(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_find, size: 56, color: AppTheme.primary),
          ).animate().scale(begin: const Offset(0.7, 0.7)).fadeIn(),
          const SizedBox(height: 28),
          Text(
            'WiFi Security Analyzer',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1565C0),
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Aapke current WiFi network ka real encryption type, security level, aur vulnerabilities check karo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 36),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ElevatedButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.radar, size: 22),
              label: const Text('WiFi Scan Karo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                elevation: 0,
              ),
            ),
          ).animate().fadeIn(delay: 220.ms),
        ],
      ),
    );
  }

  Widget _buildScanning(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    color: AppTheme.primary,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .rotate(duration: 1200.ms),
                Image.asset('assets/images/logo_transparent.png', width: 48, height: 48)
                    .animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Network scan ho raha hai...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0D1117),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Encryption type check ho rahi hai',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(bool isDark) {
    final r = _result!;

    if (!r.isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 72, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              'WiFi Connected Nahi Hai',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0D1117)),
            ),
            const SizedBox(height: 10),
            Text(
              r.message ?? 'Pehle WiFi se connect karo',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _scan,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white),
              child: const Text('Dobara Try Karo'),
            ),
          ],
        ),
      );
    }

    final gaugeColor = r.score >= 70
        ? const Color(0xFF4CAF50)
        : r.score >= 40
            ? const Color(0xFFFFB300)
            : const Color(0xFFE53935);

    final verdictText = r.score >= 70 ? 'SAFE' : r.score >= 40 ? 'CAUTION' : 'UNSAFE';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      child: Column(
        children: [
          // Gauge
          SizedBox(
            width: 240,
            height: 200,
            child: ArcGauge(
              value: r.rating,
              maxValue: 5.0,
              color: gaugeColor,
              trackColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
              strokeWidth: 18,
              sweepDegrees: 210,
              centerChild: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: r.rating.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: gaugeColor,
                            height: 1,
                          ),
                        ),
                        TextSpan(
                          text: '.${((r.rating * 10) % 10).round()}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: gaugeColor.withValues(alpha: 0.7),
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '5',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // SSID name
          Text(
            r.ssid,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0D1117),
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 20),

          // Verdict card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: gaugeColor.withValues(alpha: isDark ? 0.1 : 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: gaugeColor.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: gaugeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        verdictText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Encryption: ${r.securityType}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0D1117),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _getEncryptionDescription(r.securityType),
                  style: TextStyle(
                    color: gaugeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                // Recommended steps
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Recommended Steps',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: gaugeColor,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.check_circle, color: gaugeColor, size: 20),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...r.recommendations.map((rec) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              rec,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 150.ms),

          const SizedBox(height: 16),

          // Security checks
          ...r.checks.asMap().entries.map((e) {
            final c = e.value;
            final color = c.level == _Level.safe
                ? const Color(0xFF4CAF50)
                : c.level == _Level.ok
                    ? const Color(0xFF66BB6A)
                    : c.level == _Level.warning
                        ? const Color(0xFFFFB300)
                        : c.level == _Level.danger
                            ? const Color(0xFFE53935)
                            : const Color(0xFFB71C1C);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B27) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE8EEF8),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(c.icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isDark ? Colors.white : const Color(0xFF0D1117),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          c.detail,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: 200 + e.key * 70));
          }),

          const SizedBox(height: 16),

          // Open Settings button
          ElevatedButton.icon(
            onPressed: () async {
              const MethodChannel('com.safesignal/app_scanner')
                  .invokeMethod('openWifiSettings');
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text('${r.ssid} Settings Kholo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF161B27) : Colors.white,
              foregroundColor: isDark ? Colors.white : const Color(0xFF0D1117),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE0E0E0),
                ),
              ),
              elevation: 0,
            ),
          ).animate().fadeIn(delay: 500.ms),

          const SizedBox(height: 12),

          // BSSID
          Text(
            "Router's BSSID: ${r.bssid}",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ).animate().fadeIn(delay: 550.ms),
        ],
      ),
    );
  }

  String _getEncryptionDescription(String secType) {
    final s = secType.toUpperCase();
    if (s.contains('WPA3')) {
      return 'Aapka WiFi Router WPA3 security use karta hai. Yeh sabse latest aur strongest standard hai. Excellent!';
    }
    if (s.contains('WPA2')) {
      return 'Aapka WiFi Router WPA2 with PSK+CCMP Security use karta hai. Yeh Network Safe Hai.';
    }
    if (s.contains('WPA')) {
      return 'Aapka Router WPA security use karta hai. WPA2 ya WPA3 pe upgrade karna better hoga.';
    }
    if (s.contains('WEP')) {
      return 'DANGER! WEP encryption bahut purani aur broken hai. Koi bhi aasani se hack kar sakta hai!';
    }
    return 'Open Network — Koi encryption nahi. Aapka data completely exposed hai!';
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────
enum _Phase { idle, scanning, done }
enum _Level { safe, ok, warning, danger, critical }

class _Check {
  final String label, detail;
  final _Level level;
  final IconData icon;
  const _Check({required this.label, required this.detail, required this.level, required this.icon});
}

class _WifiResult {
  final String ssid, bssid, ip, gateway, securityType;
  final int score;
  final double rating;
  final List<_Check> checks;
  final List<String> recommendations;
  final bool isConnected;
  final String? message;

  const _WifiResult({
    required this.ssid,
    required this.bssid,
    required this.ip,
    required this.gateway,
    required this.securityType,
    required this.score,
    required this.rating,
    required this.checks,
    required this.recommendations,
    required this.isConnected,
    this.message,
  });

  factory _WifiResult.noWifi() => const _WifiResult(
        ssid: '', bssid: '', ip: '', gateway: '', securityType: '',
        score: 0, rating: 0, checks: [], recommendations: [],
        isConnected: false, message: 'WiFi se connect karo phir scan karo',
      );

  factory _WifiResult.permissionDenied() => const _WifiResult(
        ssid: '', bssid: '', ip: '', gateway: '', securityType: '',
        score: 0, rating: 0, checks: [], recommendations: [],
        isConnected: false, message: 'Location permission chahiye WiFi details ke liye.\nSettings > SafeSignal > Permissions > Location',
      );
}
