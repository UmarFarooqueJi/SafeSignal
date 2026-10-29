import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLang = 'hi';

  Future<void> _selectLanguage(String lang) async {
    setState(() => _selectedLang = lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefLanguage, lang);
    if (mounted) context.go('/disclaimer');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF060A12) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '🌐',
                style: TextStyle(fontSize: 64),
                textAlign: TextAlign.center,
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 24),
              Text(
                'Apni Bhasha Chunein',
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
                'Choose Your Language',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 48),
              _LangCard(
                flag: '🇮🇳',
                lang: 'हिंदी',
                subtitle: 'Hindi',
                selected: _selectedLang == 'hi',
                onTap: () => _selectLanguage('hi'),
                isDark: isDark,
              ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
              const SizedBox(height: 16),
              _LangCard(
                flag: '🇬🇧',
                lang: 'English',
                subtitle: 'English',
                selected: _selectedLang == 'en',
                onTap: () => _selectLanguage('en'),
                isDark: isDark,
              ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  final String flag;
  final String lang;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _LangCard({
    required this.flag,
    required this.lang,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.primary;
    final cardBg = selected
        ? (isDark
              ? activeColor.withValues(alpha: 0.15)
              : const Color(0xFFEFF5FF))
        : (isDark ? const Color(0xFF0F1724) : const Color(0xFFF8FAFC));

    final borderColor = selected
        ? activeColor
        : (isDark ? const Color(0xFF202A3C) : const Color(0xFFE2E8F0));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 250.ms,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: selected ? 2 : 1.2),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(flag, style: const TextStyle(fontSize: 32)),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? activeColor
                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (selected)
              Icon(Icons.check_circle, color: activeColor, size: 28)
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
