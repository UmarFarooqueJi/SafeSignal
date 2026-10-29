import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';

class NewOnboardingScreen extends StatefulWidget {
  const NewOnboardingScreen({super.key});

  @override
  State<NewOnboardingScreen> createState() => _NewOnboardingScreenState();
}

class _NewOnboardingScreenState extends State<NewOnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_Slide> _slides = const [
    _Slide(
      emoji: '🛡️',
      illustrationIcon: Icons.security_rounded,
      illustrationColor: Color(0xFF6C63FF),
      bgColor: Color(0xFFF0EEFF),
      accentColor: Color(0xFF6C63FF),
      title: 'Easily Accessible',
      subtitle: 'Aasaan aur Fast',
      desc:
          'SafeSignal ek tap mein kisi bhi suspicious message, link ya call ko check kar leta hai. No tech knowledge needed.',
    ),
    _Slide(
      emoji: '🤖',
      illustrationIcon: Icons.psychology_rounded,
      illustrationColor: Color(0xFF00C896),
      bgColor: Color(0xFFE6FBF5),
      accentColor: Color(0xFF00C896),
      title: 'Manage Anytime',
      subtitle: 'Har Waqt Surakshit',
      desc:
          'AI-powered analysis 24/7 background mein kaam karta hai. SMS, calls, URLs — sab automatically scan hote hain.',
    ),
    _Slide(
      emoji: '💰',
      illustrationIcon: Icons.account_balance_wallet_rounded,
      illustrationColor: Color(0xFFFF6B6B),
      bgColor: Color(0xFFFFF0F0),
      accentColor: Color(0xFFFF6B6B),
      title: 'Safe Transaction',
      subtitle: 'Secure Payments',
      desc:
          'UPI fraud, QR scam aur fake payment links se protected rahein. Real-time financial threat detection included.',
    ),
  ];

  void _next() async {
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      // Done — go to sign-in
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefOnboardingDone, true);
      if (mounted) context.go('/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Skip
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20, top: 8),
                  child: _currentPage < _slides.length - 1
                      ? TextButton(
                          onPressed: () async {
                            final router = GoRouter.of(context);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(
                              AppConstants.prefOnboardingDone,
                              true,
                            );
                            if (mounted) router.go('/signin');
                          },
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        )
                      : const SizedBox(height: 40),
                ),
              ),

              // PageView
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _slides.length,
                  itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                ),
              ),

              // Bottom section
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 36),
                child: Column(
                  children: [
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == i ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? slide.accentColor
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Next button
                    GestureDetector(
                      onTap: _next,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: slide.accentColor,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: slide.accentColor.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == _slides.length - 1
                                  ? 'Get Started'
                                  : 'Next',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
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
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration card
          Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              color: slide.bgColor,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: slide.illustrationColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
                // Main icon illustration
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: slide.illustrationColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: slide.illustrationColor.withValues(
                              alpha: 0.2,
                            ),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        slide.illustrationIcon,
                        color: slide.illustrationColor,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Emoji badge
                    Text(
                      slide.emoji,
                      style: const TextStyle(fontSize: 36),
                    ).animate().scale(begin: const Offset(0.5, 0.5)).fadeIn(),
                  ],
                ),
                // Decorative dots
                Positioned(
                  top: 30,
                  left: 30,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: slide.illustrationColor.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  right: 40,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: slide.illustrationColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  top: 60,
                  right: 25,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: slide.illustrationColor.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),

          const SizedBox(height: 40),

          // Title
          Text(
            slide.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A2E),
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            slide.subtitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: slide.accentColor,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms),

          const SizedBox(height: 16),

          // Description
          Text(
            slide.desc,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
        ],
      ),
    );
  }
}

class _Slide {
  final String emoji;
  final IconData illustrationIcon;
  final Color illustrationColor;
  final Color bgColor;
  final Color accentColor;
  final String title;
  final String subtitle;
  final String desc;

  const _Slide({
    required this.emoji,
    required this.illustrationIcon,
    required this.illustrationColor,
    required this.bgColor,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.desc,
  });
}
