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
import '../../features/upi_scanner/upi_scanner_screen.dart';
import '../../features/device_audit/device_audit_screen.dart';
import '../../features/email_breach/email_breach_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/qr_scanner/qr_scanner_screen.dart';
import '../../features/clipboard/clipboard_guard_screen.dart';
import '../../features/vault/vault_screen.dart';
import '../../features/vault/vault_lock_screen.dart';
import '../../data/models/verdict_model.dart';


final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
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
        path: '/upi-scanner',
        builder: (context, state) => const UpiScannerScreen(),
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
        path: '/clipboard',
        builder: (context, state) => const ClipboardGuardScreen(),
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
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)
        .drive(Tween(begin: 0.5, end: 1.0));
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
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final isProfileSetupDone = prefs.getBool('isProfileSetupDone') ?? false;
    final isVaultEnabled = prefs.getBool('isVaultEnabled') ?? false;
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    
    if (!mounted) return;
    
    // Use GoRouter to navigate safely
    if (!onboardingDone) {
      context.go('/onboarding');
      return;
    }
    
    if (isLoggedIn) {
      if (isProfileSetupDone) {
        if (isVaultEnabled) {
          context.go('/vault-lock');
        } else {
          context.go('/home');
        }
      } else {
        context.go('/profile-setup');
      }
    } else {
      context.go('/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C63FF),
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
                    // Premium logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Image.asset(
                          'assets/images/logo_transparent.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    // App name typing animation
                    Text(
                      currentText,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'AI-Powered Scam Protection',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 80),
                    // Loading bar
                    SizedBox(
                      width: 100,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          color: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          minHeight: 3,
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
