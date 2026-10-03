// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: App Constants & Configuration (100% On-Device & Zero-Cloud)
// Author: Umar Farooque (https://github.com/UmarFarooqueJi)
// Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
// -----------------------------------------------------------------------------

class AppConstants {
  // ─── Zero-Cloud / Air-Gapped Status ──────────────────────────────────────────
  static const bool isAirGappedMode = true;

  // ─── Legacy compatibility stubs (100% Local / Zero-Tracking) ───────────────
  static String get newsDataApiKey => '';
  static String get grokApiKey => '';
  static String get deepSeekApiKey => '';
  static String get openRouterApiKey => '';
  static String get geminiApiKey => '';
  static const String cloudflareAccountId = '';
  static String get cloudflareAiToken => '';
  static String get hibpApiKey => '';
  static String get googleSafeBrowsingApiKey => '';
  static String get virusTotalApiKey => '';

  // ─── Crowd & Threat Intel ───────────────────────────────────────────────────
  static const int crowdReportThreshold = 5;

  // ─── AI Confidence Thresholds ────────────────────────────────────────────────
  static const double confidenceGate = 0.80;
  static const double highConfidence = 0.90;

  // ─── Verdict Codes ───────────────────────────────────────────────────────────
  static const String verdictScam = 'SCAM';
  static const String verdictSafe = 'LIKELY_SAFE';
  static const String verdictUncertain = 'UNCERTAIN';

  // ─── Hive Box Names ──────────────────────────────────────────────────────────
  static const String hiveHistoryBox = 'check_history';
  static const String hiveAlertsBox = 'daily_alerts';
  static const String hiveSettingsBox = 'settings';

  // ─── SharedPreferences Keys ──────────────────────────────────────────────────
  static const String prefLanguage = 'language_pref';
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefTextScale = 'text_scale';
  static const String prefNotifications = 'notifications_enabled';

  // ─── India Cybercrime Helpline ────────────────────────────────────────────────
  static const String cyberHelpline = '1930';

  // ─── Timeouts ────────────────────────────────────────────────────────────────
  static const int apiTimeoutSeconds = 15;
  static const int deepAnalysisTimeoutSeconds = 30;

  // ─── Pagination ──────────────────────────────────────────────────────────────
  static const int feedPageSize = 20;
  static const int historyPageSize = 50;
}
