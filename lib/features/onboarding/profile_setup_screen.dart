import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  bool _isLoading = false;
  late final String _nodeId;

  @override
  void initState() {
    super.initState();
    final randomHex = (DateTime.now().millisecondsSinceEpoch % 65535)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(4, '0');
    _nodeId = 'NODE-SS-$randomHex';
  }

  Future<void> _activateNode() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', _nodeId);
      await prefs.setBool('isProfileSetupDone', true);
      await prefs.setBool(AppConstants.prefOnboardingDone, true);
      await prefs.setBool('isLoggedIn', true);

      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Initialization error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF06090F) : const Color(0xFFF1F5F9),
        body: Stack(
          children: [
            // Breathing background glow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF06090F), const Color(0xFF0F172A), const Color(0xFF0A192F)]
                        : [const Color(0xFFE2E8F0), const Color(0xFFEDF2F7), const Color(0xFFF8FAFC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo icon
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF00E676).withValues(alpha: 0.12),
                            border: Border.all(
                              color: const Color(0xFF00E676).withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                          child: Image.asset(
                            'assets/images/logo_transparent.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

                      const SizedBox(height: 24),

                      Text(
                        'Air-Gapped Node Initializer',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

                      const SizedBox(height: 8),

                      Text(
                        '100% Open-Source & Private — Zero Personal Data Required',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF00E676) : const Color(0xFF059669),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),

                      const SizedBox(height: 32),

                      // Card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.shield_outlined, color: Color(0xFF00E676), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Assigned Cryptographic Node',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0B132B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFF00E676).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _nodeId,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF00E676),
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00E676).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'ANONYMOUS',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF00E676),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Privacy guarantees list
                                _buildBulletPoint(
                                  icon: Icons.check_circle_outline,
                                  title: 'Zero Name or Identity Tracking',
                                  subtitle: 'SafeSignal never asks for or stores your real name, username, or phone number.',
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 12),
                                _buildBulletPoint(
                                  icon: Icons.lock_outline,
                                  title: '100% On-Device Threat Intelligence',
                                  subtitle: 'All scans, forensic audits, and vault encryptions run locally on this hardware.',
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 12),
                                _buildBulletPoint(
                                  icon: Icons.cloud_off_outlined,
                                  title: 'Zero Cloud Telemetry',
                                  subtitle: 'No analytics, no behavioral trackers, and no external log servers.',
                                  isDark: isDark,
                                ),

                                const SizedBox(height: 28),

                                // Activate Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _activateNode,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00E676),
                                      foregroundColor: const Color(0xFF06090F),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: _isLoading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.black,
                                            ),
                                          )
                                        : const Icon(Icons.bolt, size: 20, color: Colors.black),
                                    label: Text(
                                      _isLoading ? 'Initializing...' : 'Launch Defense Suite',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF00E676), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
