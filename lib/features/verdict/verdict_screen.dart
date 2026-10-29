import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/verdict_model.dart';

class VerdictScreen extends StatelessWidget {
  final VerdictModel verdict;
  const VerdictScreen({super.key, required this.verdict});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = AppTheme.verdictColor(verdict.verdict);
    final isScam = verdict.verdict == 'SCAM';
    final isSafe = verdict.verdict == 'LIKELY_SAFE';

    String verdictTitle;
    if (verdict.language == 'hi') {
      verdictTitle = isScam
          ? 'SCAM HAI! 🛑'
          : isSafe
          ? 'SAFE HAI ✅'
          : 'SAVDHAN RAHO ⚠️';
    } else {
      verdictTitle = isScam
          ? 'IT\'S A SCAM! 🛑'
          : isSafe
          ? 'LOOKS SAFE ✅'
          : 'BE CAREFUL ⚠️';
    }

    final bg = isDark ? const Color(0xFF060A12) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: color,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          AppTheme.verdictEmoji(verdict.verdict),
                          style: const TextStyle(fontSize: 52),
                        ),
                      ).animate().scale(
                        duration: 500.ms,
                        curve: Curves.elasticOut,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        verdictTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ).animate().fadeIn(delay: 150.ms),
                      const SizedBox(height: 12),
                      // Confidence indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${(verdict.confidence * 100).toStringAsFixed(0)}% Confidence Score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ).animate().fadeIn(delay: 250.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Badge(
                        label: verdict.scamType.toUpperCase(),
                        color: color,
                        isDark: isDark,
                      ),
                      if (verdict.escalated)
                        _Badge(
                          label: verdict.language == 'hi'
                              ? '🔍 ADVANCED AI ANALYSIS'
                              : '🔍 ADVANCED AI ANALYSIS',
                          color: const Color(0xFF7C4DFF),
                          icon: Icons.auto_awesome,
                          isDark: isDark,
                        ),
                    ],
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 24),

                  // Trend note
                  if (verdict.trendNote != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF241C10)
                            : const Color(0xFFFFFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('📈', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  verdict.language == 'hi'
                                      ? 'SECURITY ALERT'
                                      : 'SECURITY ALERT',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    color: Color(0xFFFF8F00),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  verdict.trendNote!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.87)
                                        : Colors.black.withValues(alpha: 0.87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 350.ms),
                    const SizedBox(height: 20),
                  ],

                  // WHY section
                  _SectionCard(
                    title: verdict.language == 'hi' ? 'KYUN? / WHY?' : 'WHY?',
                    icon: Icons.help_outline_rounded,
                    color: color,
                    isDark: isDark,
                    child: Column(
                      children: verdict.why
                          .map(
                            (w) => _BulletItem(
                              text: w,
                              color: color,
                              isDark: isDark,
                            ),
                          )
                          .toList(),
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05),

                  const SizedBox(height: 16),

                  // WHAT TO DO section
                  _SectionCard(
                    title: verdict.language == 'hi'
                        ? 'AB KYA KARO? / WHAT TO DO?'
                        : 'ACTION STEPS',
                    icon: Icons.checklist_rounded,
                    color: color,
                    isDark: isDark,
                    child: Column(
                      children: verdict.whatToDo
                          .map(
                            (w) => _BulletItem(
                              text: w,
                              color: color,
                              isTick: true,
                              isDark: isDark,
                            ),
                          )
                          .toList(),
                    ),
                  ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.05),

                  const SizedBox(height: 24),

                  // Feedback section
                  Text(
                    verdict.language == 'hi'
                        ? 'Kya yeh verdict sahi tha?'
                        : 'Was this verdict helpful?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 500.ms),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _sendFeedback(context, true),
                          icon: const Icon(
                            Icons.thumb_up_alt_outlined,
                            size: 18,
                          ),
                          label: Text(
                            verdict.language == 'hi' ? 'Sahi Tha' : 'Helpful',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.safeGreen,
                            side: const BorderSide(
                              color: AppTheme.safeGreen,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _sendFeedback(context, false),
                          icon: const Icon(
                            Icons.thumb_down_alt_outlined,
                            size: 18,
                          ),
                          label: Text(
                            verdict.language == 'hi'
                                ? 'Galat Tha'
                                : 'Incorrect',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.scamRed,
                            side: const BorderSide(
                              color: AppTheme.scamRed,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 550.ms),

                  const SizedBox(height: 16),

                  // Share button
                  GestureDetector(
                    onTap: () => _shareVerdict(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGrad,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.25),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.share_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            verdict.language == 'hi'
                                ? 'Parivaar ke saath share karein'
                                : 'Share with Family & Friends',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms),

                  const SizedBox(height: 24),

                  // Disclaimer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F1724)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF202A3C)
                            : const Color(0xFFEDF2F7),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '⚠️ ${verdict.disclaimer}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.phone_in_talk,
                              color: Color(0xFFEF5350),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              verdict.language == 'hi'
                                  ? 'Cyber Helpline: Call 1930'
                                  : 'Cyber Helpline: Call 1930',
                              style: const TextStyle(
                                color: Color(0xFFEF5350),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 650.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendFeedback(BuildContext context, bool correct) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          verdict.language == 'hi'
              ? (correct
                    ? 'Shukriya! Feedback mila ✓'
                    : 'Shukriya! Hum sudhar karenge.')
              : (correct
                    ? 'Thank you for your feedback! ✓'
                    : 'Thank you! We will improve.'),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareVerdict(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          verdict.language == 'hi'
              ? 'Share feature aane wali hai!'
              : 'Sharing feature coming soon!',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final bool isDark;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1724) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF202A3C) : const Color(0xFFEDF2F7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: color,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black12),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  final Color color;
  final bool isTick;
  final bool isDark;

  const _BulletItem({
    required this.text,
    required this.color,
    this.isTick = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isTick ? Icons.check_circle : Icons.error_outline_rounded,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool isDark;

  const _Badge({
    required this.label,
    required this.color,
    this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
