import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/onboarding/new_onboarding_screen.dart';
import '../../features/onboarding/signin_screen.dart';
import '../../features/onboarding/profile_setup_screen.dart';
import '../../features/onboarding/language_screen.dart';
import '../../features/onboarding/disclaimer_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/verdict/verdict_screen.dart';
import '../../features/feed/feed_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/url_scanner/url_scanner_screen.dart';
import '../../features/wifi_scanner/wifi_scanner_screen.dart';
import '../../features/app_scanner/app_scanner_screen.dart';
import '../../features/home/otp_guard_screen.dart';
import '../../features/home/call_shield_screen.dart';
import '../../features/home/sms_inbox_screen.dart';
import '../../features/device_audit/device_audit_screen.dart';
import '../../features/email_breach/email_breach_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/qr_scanner/qr_scanner_screen.dart';
import '../../features/vault/vault_screen.dart';
import '../../features/vault/vault_lock_screen.dart';
import '../../features/osint/social_osint_screen.dart';
import '../../features/osint/phone_osint_screen.dart';
import '../../features/incident_response/incident_response_screen.dart';
import '../../features/history/history_screen.dart';
import '../../data/models/verdict_model.dart';


final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashRedirectScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const NewOnboardingScreen(),
      ),
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/language',
        builder: (context, state) => const LanguageScreen(),
      ),
      GoRoute(
        path: '/disclaimer',
        builder: (context, state) => const DisclaimerScreen(),
      ),

      // Full-screen tools (with proper back navigation)
      GoRoute(
        path: '/url-scanner',
        builder: (context, state) => const UrlScannerScreen(),
      ),
      GoRoute(
        path: '/wifi-scanner',
        builder: (context, state) => const WifiScannerScreen(),
      ),
      GoRoute(
        path: '/app-scanner',
        builder: (context, state) => const AppScannerScreen(),
      ),
      GoRoute(
        path: '/otp-guard',
        builder: (context, state) => const OtpGuardScreen(),
      ),
      GoRoute(
        path: '/call-shield',
        builder: (context, state) => const CallShieldScreen(),
      ),
      GoRoute(
        path: '/sms-inbox',
        builder: (context, state) => const SmsInboxScreen(),
      ),
      GoRoute(
        path: '/device-audit',
        builder: (context, state) => const DeviceAuditScreen(),
      ),
      GoRoute(
        path: '/email-breach',
        builder: (context, state) => const EmailBreachScreen(),
      ),
      GoRoute(
        path: '/qr-scanner',
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: '/social-osint',
        builder: (context, state) => const SocialOsintScreen(),
      ),
      GoRoute(
        path: '/phone-osint',
        builder: (context, state) {
          final phone = state.extra as String?;
          return PhoneOsintScreen(initialPhone: phone);
        },
      ),
      GoRoute(
        path: '/vault',
        builder: (context, state) => const VaultScreen(),
      ),
      GoRoute(
        path: '/vault-lock',
        builder: (context, state) => const VaultLockScreen(),
      ),
      GoRoute(
        path: '/verdict',
        builder: (context, state) {
          final verdict = state.extra as VerdictModel;
          return VerdictScreen(verdict: verdict);
        },
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: '/incident-response',
        builder: (context, state) => const IncidentResponseScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),

      // Top-level routes for main sections
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/feed',
        builder: (context, state) => const FeedScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

// ─── Splash Screen ─────────────────────────────────────────────────────────────
class SplashRedirectScreen extends StatefulWidget {
  const SplashRedirectScreen({super.key});

  @override
  State<SplashRedirectScreen> createState() => _SplashRedirectScreenState();
}

class _SplashRedirectScreenState extends State<SplashRedirectScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)
        .drive(Tween(begin: 0.7, end: 1.0));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn)
        .drive(Tween(begin: 0.0, end: 1.0));
    _controller.forward();
    _redirect();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    
    final isVaultEnabled = prefs.getBool('isVaultEnabled') ?? false;
    if (isVaultEnabled) {
      context.go('/vault-lock');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDEEBF7),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final fullText = "SafeSignal";
            // Calculate how many characters to show based on animation progress (0.0 to 1.0)
            final charCount = (_controller.value * fullText.length).round().clamp(0, fullText.length);
            final currentText = fullText.substring(0, charCount);

            return FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Premium logo — white squircle with drop shadow like before
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/logo_transparent.png',
                          width: 64,
                          height: 64,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.shield_rounded,
                            color: Color(0xFF0284C7),
                            size: 50,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    // App name typing animation
                    Text(
                      currentText,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AI-Powered Scam Protection',
                      style: TextStyle(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.60),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 44),
                    // Sleek loading bar
                    SizedBox(
                      width: 90,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: const LinearProgressIndicator(
                          color: Color(0xFF0284C7),
                          backgroundColor: Color(0xFFCBD5E1),
                          minHeight: 3.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
