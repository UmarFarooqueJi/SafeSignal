import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/ai_expert_service.dart';

/// Reusable "Ask AI Expert" bottom sheet widget.
/// Used across URL Scanner, WiFi, App Audit, Device Audit, Breach Scanner, UPI Scanner.
class AiExpertPanel extends StatefulWidget {
  final String domain;       // 'url' | 'wifi' | 'app' | 'device' | 'breach' | 'upi' | 'sms'
  final String context;      // The data/report string to analyze
  final bool isDark;
  final Color accentColor;
  final String expertName;   // Shown in the UI (e.g. "WebGuard AI")
  final String expertIcon;   // Emoji icon for the expert

  const AiExpertPanel({
    super.key,
    required this.domain,
    required this.context,
    required this.isDark,
    required this.accentColor,
    required this.expertName,
    required this.expertIcon,
  });

  @override
  State<AiExpertPanel> createState() => _AiExpertPanelState();
}

class _AiExpertPanelState extends State<AiExpertPanel> {
  String? _explanation;
  bool _loading = false;
  bool _hasError = false;
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    _fetchExplanation();
  }

  Future<void> _fetchExplanation() async {
    setState(() {
      _loading = true;
      _hasError = false;
      _explanation = null;
    });
    try {
      final result = await AiExpertService().explainWithExpert(
        domain: widget.domain,
        context: widget.context,
        language: _language,
      );
      if (mounted) {
        setState(() {
          _explanation = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    }
  }

  void _toggleLanguage() {
    setState(() {
      _language = _language == 'en' ? 'hi' : 'en';
    });
    _fetchExplanation();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF0F1724) : Colors.white;
    final textColor = widget.isDark ? Colors.white : const Color(0xFF0D1117);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      widget.expertIcon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.expertName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'AI Domain Expert',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Language Toggle
                GestureDetector(
                  onTap: _toggleLanguage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _language == 'en' ? '🇮🇳 हिंदी' : '🇬🇧 English',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Container(
              height: 1,
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: _buildContent(textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color textColor) {
    if (_loading) {
      return Column(
        children: [
          const SizedBox(height: 20),
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: widget.accentColor,
              strokeWidth: 3,
            ),
          ).animate().scale().fadeIn(),
          const SizedBox(height: 16),
          Text(
            _language == 'en'
                ? 'Analyzing with ${widget.expertName}...'
                : 'AI expert analyze kar raha hai...',
            style: TextStyle(
              fontSize: 14,
              color: widget.isDark ? Colors.white54 : Colors.black45,
              fontWeight: FontWeight.w600,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          // Shimmer lines
          ...List.generate(
            4,
            (i) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 14,
              decoration: BoxDecoration(
                color: (widget.isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(7),
              ),
            ).animate(delay: Duration(milliseconds: 100 * i)).shimmer(
                  color: widget.accentColor.withValues(alpha: 0.1),
                ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    if (_hasError || _explanation == null) {
      return Column(
        children: [
          const SizedBox(height: 20),
          Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            _language == 'en'
                ? 'Could not connect to AI expert.\nCheck your internet connection.'
                : 'AI expert se connect nahi hua.\nInternet check karein.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: widget.isDark ? Colors.white54 : Colors.black45,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchExplanation,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_language == 'en' ? 'Try Again' : 'Dobara Koshish'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    // Parse bullet points
    final lines = _explanation!
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...lines.asMap().entries.map((entry) {
          final i = entry.key;
          final line = entry.value.trim();
          final isBullet = line.startsWith('•') ||
              line.startsWith('-') ||
              line.startsWith('*');
          final cleanLine = isBullet ? line.substring(1).trim() : line;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isBullet) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    cleanLine,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.55,
                      color: textColor.withValues(alpha: 0.85),
                      fontWeight:
                          isBullet ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ).animate(delay: Duration(milliseconds: 80 * i)).fadeIn().slideX(begin: -0.05);
        }),
        const SizedBox(height: 8),
        // Powered by badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.accentColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded, color: widget.accentColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Umar Farooque',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: widget.accentColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Show the AI Expert bottom sheet from any screen
Future<void> showAiExpertSheet(
  BuildContext context, {
  required String domain,
  required String context_,
  required bool isDark,
  required Color accentColor,
  required String expertName,
  required String expertIcon,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AiExpertPanel(
      domain: domain,
      context: context_,
      isDark: isDark,
      accentColor: accentColor,
      expertName: expertName,
      expertIcon: expertIcon,
    ),
  );
}
