import 'package:flutter_dotenv/flutter_dotenv.dart';

// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: App Constants & Configuration
// Author: Umar Farooque (umarfarooque@safesignal.app)
// Copyright (c) 2026 SafeSignal Technologies. All rights reserved.
// -----------------------------------------------------------------------------

class AppConstants {
  // ─── Network ────────────────────────────────────────────────────────────────
  static const String apiBaseUrlRelease = 'https://your-backend.onrender.com';

  // ─── Supabase ────────────────────────────────────────────────────────────────
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // ─── News ────────────────────────────────────────────────────────────────────
  static String get newsDataApiKey => dotenv.env['NEWS_DATA_API_KEY'] ?? '';

  // ─── AI Providers ────────────────────────────────────────────────────────────
  static String get grokApiKey => dotenv.env['GROK_API_KEY'] ?? '';
  static String get deepSeekApiKey => dotenv.env['DEEPSEEK_API_KEY'] ?? '';
  static String get openRouterApiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String cloudflareAccountId = '5cbda16ddf6f9d6303f19b68b21da20e';
  static String get cloudflareAiToken =>
      dotenv.env['CLOUDFLARE_AI_TOKEN'] ?? '';

  // ─── Security APIs ───────────────────────────────────────────────────────────
  static String get hibpApiKey => dotenv.env['HIBP_API_KEY'] ?? '';
  static String get googleSafeBrowsingApiKey =>
      dotenv.env['SAFE_BROWSING_API_KEY'] ?? '';
  static String get virusTotalApiKey => dotenv.env['VIRUSTOTAL_API_KEY'] ?? '';

  // ─── Crowd Intel ─────────────────────────────────────────────────────────────
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
  static const int apiTimeoutSeconds = 30;
  static const int deepAnalysisTimeoutSeconds = 60;

  // ─── Pagination ──────────────────────────────────────────────────────────────
  static const int feedPageSize = 20;
  static const int historyPageSize = 50;
}
