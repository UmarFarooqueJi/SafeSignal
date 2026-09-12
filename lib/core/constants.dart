import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // API
  static String get apiBaseUrl {
    final env = dotenv.env['ENV'] ?? 'development';
    if (env == 'production') {
      return dotenv.env['API_BASE_URL'] ?? 'https://your-backend.onrender.com';
    }
    return dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000'; // Android emulator → localhost
  }
  static const String apiBaseUrlRelease = 'https://your-backend.onrender.com';
  static String get meshApiKey => dotenv.env['MESH_API_KEY'] ?? '';
  static String get newsDataApiKey => dotenv.env['NEWS_DATA_API_KEY'] ?? '';

  // Supabase
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // AI APIs
  static String get grokApiKey => dotenv.env['GROK_API_KEY'] ?? '';
  static String get deepSeekApiKey => dotenv.env['DEEPSEEK_API_KEY'] ?? '';
  static String get openRouterApiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';

  // Google Sign In - SECURE: now from env
  static String get googleWebClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

  // Have I Been Pwned (Phase 3)
  static String get hibpApiKey => dotenv.env['HIBP_API_KEY'] ?? '';
  static String get googleSafeBrowsingApiKey => dotenv.env['SAFE_BROWSING_API_KEY'] ?? '';
  static String get virusTotalApiKey => dotenv.env['VIRUSTOTAL_API_KEY'] ?? '';

  // Crowd Intel Settings
  static const int crowdReportThreshold = 5; // 5+ reports → verified blocklist

  // AI Confidence Thresholds
  static const double confidenceGate = 0.80; // below this → escalate to Tier-2
  static const double highConfidence = 0.90;

  // Verdicts
  static const String verdictScam = 'SCAM';
  static const String verdictSafe = 'LIKELY_SAFE';
  static const String verdictUncertain = 'UNCERTAIN';

  // Hive Box Names
  static const String hiveHistoryBox = 'check_history';
  static const String hiveAlertsBox = 'daily_alerts';
  static const String hiveSettingsBox = 'settings';

  // SharedPreferences Keys
  static const String prefLanguage = 'language_pref';
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefTextScale = 'text_scale';
  static const String prefNotifications = 'notifications_enabled';

  // Cybercrime Helpline
  static const String cyberHelpline = '1930';

  // Timeouts
  static const int apiTimeoutSeconds = 30;
  static const int deepAnalysisTimeoutSeconds = 60;

  // Feed
  static const int feedPageSize = 20;
  static const int historyPageSize = 50;
}
