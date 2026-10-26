// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: Advanced On-Device Application Risk Engine
// Description: Multi-factor risk assessment for installed Android packages
//              with signature verification, dangerous permission combinations,
//              and zero package-name prefix immunity.
import 'stalkerware_ioc_service.dart';
export 'stalkerware_ioc_service.dart';

enum RiskLevel { safe, low, medium, high, critical }

class AppInfo {
  final String name;
  final String package;
  final String version;
  final String installer;
  final int targetSdk;
  final List<String> permissions;
  final bool isSystem;
  final bool hasLauncher;
  final bool hasAccessibility;
  final bool hasDeviceAdmin;
  final int riskScore; // 0-100 (100 = bad)
  final RiskLevel riskLevel;
  final List<String> riskReasons;
  final String? signingCertificateSha256;
  final bool isSideloaded;
  final StalkerwareIoCResult? stalkerwareIoC;

  const AppInfo({
    required this.name,
    required this.package,
    required this.version,
    required this.installer,
    required this.targetSdk,
    required this.permissions,
    required this.isSystem,
    required this.hasLauncher,
    required this.hasAccessibility,
    required this.hasDeviceAdmin,
    required this.riskScore,
    required this.riskLevel,
    required this.riskReasons,
    this.signingCertificateSha256,
    this.isSideloaded = false,
    this.stalkerwareIoC,
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

class AppRiskEngine {
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

  static const _dangerPerms = {
    'android.permission.RECORD_AUDIO': ('Microphone', 4, 'Can record audio in background.'),
    'android.permission.CAMERA': ('Camera', 4, 'Can access camera.'),
    'android.permission.READ_CONTACTS': ('Contacts', 4, 'Can read contacts.'),
    'android.permission.READ_SMS': ('Read SMS', 8, 'Can read OTPs and private messages.'),
    'android.permission.SEND_SMS': ('Send SMS', 8, 'Can send premium SMS messages.'),
    'android.permission.RECEIVE_SMS': ('Receive SMS', 8, 'Can intercept incoming OTPs.'),
    'android.permission.ACCESS_FINE_LOCATION': ('Precise Location', 4, 'Can track exact GPS location.'),
    'android.permission.ACCESS_BACKGROUND_LOCATION': ('24/7 Location', 8, 'Can track location even when closed.'),
    'android.permission.READ_CALL_LOG': ('Call History', 6, 'Can see who you called.'),
    'android.permission.PROCESS_OUTGOING_CALLS': ('Intercept Calls', 8, 'Can monitor or block outgoing calls.'),
    'android.permission.SYSTEM_ALERT_WINDOW': ('Screen Overlay', 10, 'Can draw over other apps.'),
    'android.permission.BIND_ACCESSIBILITY_SERVICE': ('Accessibility', 14, 'Full control of device. Very dangerous if misused.'),
    'android.permission.REQUEST_INSTALL_PACKAGES': ('Install Apps', 8, 'Can install other apps.'),
  };

  // ─── Citizen Lab & Amnesty International Stalkerware Signature Database ────
  static const _knownSpywareSignatures = {
    'com.mspy': 'mSpy Commercial Stalkerware',
    'com.flexispy': 'FlexiSPY Surveillance Tool',
    'com.cerberus': 'Cerberus Spyware Suite',
    'com.spyic': 'Spyic Covert Phone Tracker',
    'com.hoverwatch': 'Hoverwatch Stealth Keylogger',
    'com.trackview': 'TrackView Hidden Spy Camera',
    'com.spymaster': 'SpyMaster Pro Stalkerware',
    'net.kidsguard': 'KidsGuard Stealth Monitor',
    'com.thetruthspy': 'TheTruthSpy Stalkerware',
    'com.cocospy': 'Cocospy Surveillance Tool',
    'org.coplug': 'Copy9 / TruthSpy Stalkerware',
    'com.ikeymonitor': 'iKeyMonitor Keylogger & Spyware',
    'com.appmia': 'Appmia Mobile Surveillance',
    'com.mobistealth': 'MobiStealth Stealth Tracker',
    'com.spybubble': 'SpyBubble Surveillance Suite',
    'com.xnspy': 'XnSpy Surveillance Software',
    'com.onespy': 'OneSpy Stalkerware System',
    'com.spyzie': 'Spyzie Stealth Monitor',
  };

  /// Analyzes an installed application map with zero prefix-based immunity.
  /// Sideload status is determined strictly by verified installer provenance, not package strings.
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
    final certSha256 = raw['signingCertificateSha256'] as String?;

    int score = 0;
    final reasons = <String>[];
    String? foundSpyware;
    bool hasTrojanPattern = false;
    StalkerwareIoCResult iocResult = StalkerwareIoCResult.clean;

    // A package is known store installed if installer matches verified distribution stores.
    // Package name strings (e.g. com.google.*, com.sbi.*) NEVER grant immunity!
    final isKnownStore = storeNames.containsKey(installer);
    final isSideloaded = !isSystem && !isKnownStore;

    if (isSystem) {
      score = 0;
    } else {
      // 1. FORENSIC STALKERWARE & SPYWARE IOC ENGINE (Immediate Critical)
      iocResult = StalkerwareIoCService.evaluate(
        package: pkg,
        name: name,
        certSha256: certSha256,
        permissions: perms,
        isSystem: isSystem,
        installer: installer,
        hasLauncher: hasLauncher,
        hasAccessibility: hasAccessibility,
        hasDeviceAdmin: hasDeviceAdmin,
      );

      if (iocResult.isMatch) {
        foundSpyware = iocResult.threatFamily;
        score += 95;
        reasons.insert(
          0,
          '🚨 CRITICAL STALKERWARE [${iocResult.threatType}]: ${iocResult.matchedIndicator}. Known to covertly exfiltrate calls, chats, photos, and live location.',
        );
        for (final detail in iocResult.technicalDetails) {
          reasons.add('Forensic Detail: $detail');
        }
        reasons.add('Remediation: ${iocResult.remediation}');
      } else {
        // Legacy fallback check
        final pkgLower = pkg.toLowerCase();
        for (final entry in _knownSpywareSignatures.entries) {
          if (pkgLower.contains(entry.key)) {
            foundSpyware = entry.value;
            break;
          }
        }
        if (foundSpyware != null) {
          score += 90;
          reasons.insert(
            0,
            '🚨 CRITICAL STALKERWARE: Matches signature for $foundSpyware. Known to covertly exfiltrate calls, chats, photos, and live location.',
          );
        }
      }

      // 2. Dangerous Trojan Combinations
      final hasInternet = perms.contains('android.permission.INTERNET');
      final hasSMS = perms.contains('android.permission.RECEIVE_SMS') ||
          perms.contains('android.permission.READ_SMS');
      final hasOverlay = perms.contains('android.permission.SYSTEM_ALERT_WINDOW');
      final hasAccessibilityService =
          perms.contains('android.permission.BIND_ACCESSIBILITY_SERVICE') || hasAccessibility;

      if (hasSMS && hasOverlay) {
        hasTrojanPattern = true;
        score += isSideloaded ? 55 : 35;
        reasons.insert(
          0,
          isSideloaded
              ? 'CRITICAL: Requests SMS + Screen Overlay (Classic Banking Trojan Pattern).'
              : 'HIGH RISK: Requests SMS + Screen Overlay (Potential Banking Trojan Overlay Pattern).',
        );
      }

      if (hasInternet && hasAccessibilityService) {
        hasTrojanPattern = true;
        score += isSideloaded ? 50 : 30;
        reasons.insert(
          0,
          isSideloaded
              ? 'CRITICAL: Untrusted app with Accessibility + Internet (Screen Scraping Risk).'
              : 'ELEVATED RISK: Active Accessibility Service with Internet Access.',
        );
      }

      if (!hasLauncher &&
          (perms.contains('android.permission.RECORD_AUDIO') ||
              perms.contains('android.permission.CAMERA'))) {
        hasTrojanPattern = true;
        score += 45;
        reasons.insert(
          0,
          'HIGH RISK: Stealth package hiding launcher icon while accessing microphone/camera.',
        );
      }

      if (hasDeviceAdmin) {
        if (isSideloaded) {
          score += 30;
          reasons.insert(0, 'HIGH RISK: Untrusted app requested Device Admin privileges.');
        } else {
          score += 15;
          reasons.add('Device Admin: Holds system administration privileges.');
        }
      }

      if (isSideloaded) {
        // Untrusted APK from outside verified stores
        score += 20;
        final instLabel = installer.isEmpty || installer == 'unknown' ? 'Direct APK' : installer;
        reasons.add('Sideloaded App: Installed via unverified source ($instLabel).');

        if (targetSdk < 28) {
          score += 15;
          reasons.add('Outdated SDK (Target: $targetSdk): Bypasses modern runtime protections.');
        }
      }

      // Collect permission hygiene reasons
      for (final perm in perms) {
        final info = _dangerPerms[perm];
        if (info != null) {
          if (isSideloaded) {
            score += info.$2;
            reasons.add('${info.$1}: ${info.$3}');
          } else {
            // For store apps, permissions contribute minor points, capped so they never falsely become high risk
            score += (info.$2 * 0.25).round();
            if (info.$2 >= 8) {
              reasons.add('${info.$1}: ${info.$3}');
            }
          }
        }
      }
    }

    // Clamping: Store apps without trojan patterns or stalkerware stay capped at low/medium risk.
    if (!isSideloaded && !isSystem) {
      if (foundSpyware != null) {
        score = score.clamp(90, 100);
      } else if (hasTrojanPattern) {
        score = score.clamp(0, 85);
      } else {
        score = score.clamp(0, 38);
      }
    } else {
      score = score.clamp(0, 100);
    }

    final level = score >= 75
        ? RiskLevel.critical
        : score >= 50
            ? RiskLevel.high
            : score >= 25
                ? RiskLevel.medium
                : score >= 12
                    ? RiskLevel.low
                    : RiskLevel.safe;

    return AppInfo(
      name: name,
      package: pkg,
      version: version,
      installer: installer,
      targetSdk: targetSdk,
      permissions: perms,
      isSystem: isSystem,
      hasLauncher: hasLauncher,
      hasAccessibility: hasAccessibility,
      hasDeviceAdmin: hasDeviceAdmin,
      riskScore: score,
      riskLevel: level,
      riskReasons: reasons,
      signingCertificateSha256: certSha256,
      isSideloaded: isSideloaded,
      stalkerwareIoC: iocResult.isMatch ? iocResult : null,
    );
  }
}
