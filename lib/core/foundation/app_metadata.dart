// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: Application Metadata & Build Registry
// Author: Umar Farooque (https://github.com/UmarFarooqueJi)
// Copyright (c) 2026 SafeSignal Technologies. All rights reserved.
// -----------------------------------------------------------------------------

import 'attribution.dart';

/// Central registry for app metadata. Single source of truth for version,
/// build, and feature flags. Eliminates magic strings across the codebase.
class AppMetadata {
  AppMetadata._();

  // ─── Version ──────────────────────────────────────────────────────────────
  static String get version => SafeSignalAttribution.kVersion;
  static int get buildNumber => SafeSignalAttribution.kBuildNumber;
  static String get versionLabel =>
      'v${SafeSignalAttribution.kVersion} (${SafeSignalAttribution.kBuildNumber})';

  // ─── Product Identity ─────────────────────────────────────────────────────
  static String get appName => SafeSignalAttribution.kAppName;
  static String get tagline => SafeSignalAttribution.kTagline;
  static String get developer => SafeSignalAttribution.kDeveloper;
  static String get organization => SafeSignalAttribution.kOrganization;
  static String get copyright => SafeSignalAttribution.copyrightLine;

  // ─── Feature Flags ────────────────────────────────────────────────────────
  static const bool featureSmsThreatEnabled = true;
  static const bool featureCallShieldEnabled = true;
  static const bool featureUrlScannerEnabled = true;
  static const bool featureSocialOsintEnabled = true;
  static const bool featureBreachMonitorEnabled = true;
  static const bool featureIncidentResponseEnabled = true;
  static const bool featureVaultEnabled = true;
  static const bool featureNewsEnabled = true;
  static const bool featureAiExpertEnabled = true;
  static const bool featureWifiScannerEnabled = true;

  // ─── AI Engine Config ─────────────────────────────────────────────────────
  static const String aiEngineVersion = 'SafeSignal-ThreatEngine/3.0';
  static const String aiPrimaryProvider = 'OpenRouter';
  static const int aiCircuitBreakerThreshold = 3;
  static const Duration aiCircuitBreakerCooldown = Duration(minutes: 2);
  static const double aiLocalConfidenceGate = 0.90;

  // ─── Platform ─────────────────────────────────────────────────────────────
  static const String minAndroidVersion = 'Android 10 (API 29)';
  static const String targetAndroidVersion = 'Android 14 (API 34)';
  static const String releaseChannel = 'production';

  // ─── Support ──────────────────────────────────────────────────────────────
  static const String supportContact =
      'https://github.com/UmarFarooqueJi/SafeSignal/issues';
  static const String privacyPolicyUrl =
      'https://github.com/UmarFarooqueJi/SafeSignal/blob/main/PRIVACY.md';
  static const String termsUrl =
      'https://github.com/UmarFarooqueJi/SafeSignal/blob/main/TERMS.md';
  static const String changelogUrl =
      'https://github.com/UmarFarooqueJi/SafeSignal/releases';
}
