import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';

class DisclaimerScreen extends StatefulWidget {
  const DisclaimerScreen({super.key});

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  bool _agreed = false;

  Future<void> _proceed() async {
    if (!_agreed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefOnboardingDone, true);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF060A12) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Text(
                  '⚠️',
                  style: TextStyle(fontSize: 64),
                  textAlign: TextAlign.center,
                ).animate().scale(duration: 500.ms),
                const SizedBox(height: 20),
                Text(
                  'Zaroori Baat',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 4),
                Text(
                  'Important Disclaimer',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E150B)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF3F2F1B)
                          : const Color(0xFFFEF3C7),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'SafeSignal shak wale messages pehchanne mein madad karta hai, lekin ye ek AI tool hai — insan nahi.\n\n'
                        'SafeSignal helps identify suspicious messages, but it is an AI tool — not a human expert.\n\n'
                        '🚨 Asli fraud ke liye:\nFor real fraud, always call:\n\n'
                        '📞 1930\n(National Cybercrime Helpline)\n\n'
                        'SafeSignal ki raay final nahi hai. Apna vivek bhi istamaal karein.\n'
                        "SafeSignal's verdict is not final. Use your own judgment too.",
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.orange.shade100
                              : Colors.amber.shade900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () => setState(() => _agreed = !_agreed),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _agreed
                          ? (isDark
                                ? AppTheme.primary.withValues(alpha: 0.1)
                                : const Color(0xFFEFF5FF))
                          : (isDark
                                ? const Color(0xFF0F1724)
                                : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _agreed
                            ? AppTheme.primary
                            : (isDark
                                  ? const Color(0xFF202A3C)
                                  : const Color(0xFFE2E8F0)),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreed,
                          onChanged: (v) =>
                              setState(() => _agreed = v ?? false),
                          activeColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Mujhe samajh aa gaya, main sahamat hoon\nI understand and agree',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _agreed ? _proceed : null,
                  child: AnimatedContainer(
                    duration: 250.ms,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: _agreed ? AppTheme.primaryGrad : null,
                      color: _agreed
                          ? null
                          : (isDark ? Colors.white10 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _agreed
                          ? [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        'Shuru Karein / Get Started',
                        style: TextStyle(
                          color: _agreed ? Colors.white : Colors.grey.shade500,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
