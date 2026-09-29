import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../device_audit/device_audit_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      endDrawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFE3F2FD)),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/logo_transparent.png', width: 60, height: 60),
                    const SizedBox(height: 12),
                    const Text('SAFESIGNAL', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0D1117))),
                    const Text('AI-Powered Security', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.newspaper_rounded, color: Color(0xFF0D1117)),
              title: const Text('Cyber News & Alerts', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1117))),
              onTap: () {
                Navigator.pop(context);
                context.push('/feed');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_rounded, color: Color(0xFF0D1117)),
              title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1117))),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F2FD), // Light blue
              Color(0xFFBBDEFB), // Medium light blue
              Color(0xFF90CAF9), // Deeper light blue at bottom
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo and Text
                      Row(
                        children: [
                          Image.asset('assets/images/logo_transparent.png', width: 28, height: 28, fit: BoxFit.contain),
                          const SizedBox(width: 8),
                          const Text(
                            'SAFESIGNAL',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Color(0xFF0D1117),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      // 3-dot menu icon that opens drawer
                      Builder(
                        builder: (context) => IconButton(
                          icon: const Icon(Icons.more_vert, color: Color(0xFF0D1117), size: 28),
                          onPressed: () {
                            Scaffold.of(context).openEndDrawer();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Hero Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        height: 1.1,
                        letterSpacing: -1,
                      ),
                      children: [
                        TextSpan(text: 'Protect Your Digital\nLife, '),
                        TextSpan(
                          text: 'Get Security\nAlerts',
                          style: TextStyle(
                            color: Color(0xFFFF5722), 
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Device Secured Pill
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DeviceAuditScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFCA28),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.security, size: 20, color: Colors.black87),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Device Secured',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Tap to run security audit',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF2979FF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2979FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Audit',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Grid of Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _CyberCard(
                              title: 'App Spyware\nAudit',
                              subtitle: 'Malware & Trojan Check',
                              icon: Icons.radar_rounded,
                              accentColor: const Color(0xFF2563EB),
                              badgeText: 'ON-DEVICE',
                              onTap: () => context.push('/app-scanner'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 50.ms).fadeIn(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CyberCard(
                              title: 'WiFi Security\nScanner',
                              subtitle: 'DNS & Rogue AP Audit',
                              icon: Icons.wifi_find_rounded,
                              accentColor: const Color(0xFF06B6D4),
                              badgeText: 'LIVE AUDIT',
                              onTap: () => context.push('/wifi-scanner'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 100.ms).fadeIn(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _CyberCard(
                              title: 'Website\nAnalyzer',
                              subtitle: 'Domain Typosquatting',
                              icon: Icons.travel_explore_rounded,
                              accentColor: const Color(0xFF8B5CF6),
                              badgeText: 'ANTI-PHISH',
                              onTap: () => context.push('/url-scanner'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 150.ms).fadeIn(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CyberCard(
                              title: 'Social OSINT\nFootprint',
                              subtitle: 'Handle & Identity Recon',
                              icon: Icons.person_search_rounded,
                              accentColor: const Color(0xFFEC4899),
                              badgeText: 'RECON',
                              onTap: () => context.push('/social-osint'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 200.ms).fadeIn(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _CyberCard(
                              title: 'Phone Fraud\n& OSINT',
                              subtitle: 'VPA & Legal Name Unmask',
                              icon: Icons.contact_phone_rounded,
                              accentColor: const Color(0xFF10B981),
                              badgeText: 'NPCI / DOT',
                              onTap: () => context.push('/phone-osint'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 220.ms).fadeIn(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CyberCard(
                              title: 'SIM & OTP\nHijack Shield',
                              subtitle: '##002# Call Divert Flush',
                              icon: Icons.phonelink_lock_rounded,
                              accentColor: const Color(0xFFEF4444),
                              badgeText: 'USSD PURGE',
                              onTap: () => context.push('/otp-guard'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 250.ms).fadeIn(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _CyberCard(
                              title: 'SMS Phishing\nRadar',
                              subtitle: 'Financial Fraud Alert',
                              icon: Icons.mark_chat_unread_rounded,
                              accentColor: const Color(0xFFF59E0B),
                              badgeText: 'SMS FILTER',
                              onTap: () => context.push('/sms-inbox'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 270.ms).fadeIn(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CyberCard(
                              title: 'Dark Web\nBreach Scan',
                              subtitle: 'Identity Theft Check',
                              icon: Icons.key_off_rounded,
                              accentColor: const Color(0xFF6366F1),
                              badgeText: 'LEAK MONITOR',
                              onTap: () => context.push('/email-breach'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 290.ms).fadeIn(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _CyberCard(
                              title: 'AI Cyber\nAssistant',
                              subtitle: 'Threat Advisory AI',
                              icon: Icons.smart_toy_rounded,
                              accentColor: const Color(0xFF2563EB),
                              badgeText: 'LLAMA 3.1',
                              onTap: () => context.push('/chat'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 320.ms).fadeIn(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CyberCard(
                              title: 'UPI Payment\nShield',
                              subtitle: 'QR & Collect Scam Intel',
                              icon: Icons.currency_rupee_rounded,
                              accentColor: const Color(0xFF059669),
                              badgeText: 'VPA SHIELD',
                              onTap: () => context.push('/upi-scanner'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 350.ms).fadeIn(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _CyberCard(
                              title: 'Deep QR & UPI\nInspector',
                              subtitle: 'Gallery & Intent Decoder',
                              icon: Icons.qr_code_scanner_rounded,
                              accentColor: const Color(0xFF0284C7),
                              badgeText: 'DEEP SCAN',
                              onTap: () => context.push('/qr-scanner'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 380.ms).fadeIn(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CyberCard(
                              title: 'Call Shield\nSentinel',
                              subtitle: 'Spam & Robocall Defense',
                              icon: Icons.phone_paused_rounded,
                              accentColor: const Color(0xFFD97706),
                              badgeText: 'CARRIER',
                              onTap: () => context.push('/call-shield'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 410.ms).fadeIn(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _VaultCyberCard(
                        onTap: () => context.push('/vault'),
                      ).animate().scale(begin: const Offset(0.95, 0.95), delay: 440.ms).fadeIn(),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Emergency Cyber Helpline Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.shield_rounded, color: Color(0xFF60A5FA), size: 28),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'National Cyber Command',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Immediate 1930 & Bank Nodal Escalation',
                                      style: TextStyle(
                                        color: Color(0xFF93C5FD),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Emergency Helplines',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0), // Premium dark blue
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Immediate assistance for cyber fraud and emergencies. Call instantly to freeze accounts.',
                          style: TextStyle(
                            color: Colors.black54,
                            height: 1.5,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => context.push('/incident-response'),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF991B1B), Color(0xFFDC2626)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cyber Fraud Emergency Kit',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Golden Hour: 1-tap Bank Freeze & FIR Gen',
                                        style: TextStyle(fontSize: 12, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // 1930 Cyber Crime
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD), // Theme light blue
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.security_rounded, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('1930 - Cyber Crime', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                    SizedBox(height: 4),
                                    Text('Report financial fraud immediately.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
                                icon: const Icon(Icons.call, color: Colors.white),
                                onPressed: () {
                                  launchUrl(Uri.parse('tel:1930'));
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 112 National Emergency
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD), // Theme light blue
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.local_police_rounded, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('112 - National Emergency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                    SizedBox(height: 4),
                                    Text('Police, ambulance, & fire.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
                                icon: const Icon(Icons.call, color: Colors.white),
                                onPressed: () {
                                  launchUrl(Uri.parse('tel:112'));
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CyberCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String badgeText;
  final VoidCallback onTap;
  final double? height;

  const _CyberCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.badgeText,
    required this.onTap,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: accentColor.withValues(alpha: 0.1),
        highlightColor: accentColor.withValues(alpha: 0.05),
        child: Ink(
          height: height ?? 142,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: accentColor,
                      size: 22,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultCyberCard extends StatelessWidget {
  final VoidCallback onTap;

  const _VaultCyberCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: Color(0xFF38BDF8),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SafeSignal Vault Lock',
                          style: TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'AES-256',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Biometric Encrypted Evidence & Secret Vault',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
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
