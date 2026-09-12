import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../device_audit/device_audit_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _profileImagePath = prefs.getString('userProfileImage');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                            color: Colors.black.withOpacity(0.05),
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
                            child: _ImageCard(
                              title: 'App Spyware\nAudit',
                              subtitle: 'Malware Check',
                              imagePath: 'assets/images/ai_spyware_card.png',
                              height: 155,
                              onTap: () => context.push('/app-scanner'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 50.ms).fadeIn(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ImageCard(
                              title: 'WiFi Security\nScanner',
                              subtitle: 'Network Threat Alert',
                              imagePath: 'assets/images/ai_wifi_card.png',
                              height: 155,
                              onTap: () => context.push('/wifi-scanner'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 100.ms).fadeIn(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ImageCard(
                              title: 'Website\nAnalyzer',
                              subtitle: 'Phishing Check',
                              imagePath: 'assets/images/ai_website_card.png',
                              height: 145,
                              onTap: () => context.push('/url-scanner'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 150.ms).fadeIn(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ImageCard(
                              title: 'Call Shield\nAnalysis',
                              subtitle: 'Spam Call Protection',
                              imagePath: 'assets/images/ai_call_shield_card.png',
                              height: 145,
                              onTap: () => context.push('/call-shield'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 200.ms).fadeIn(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ImageCard(
                              title: 'SMS Guard\n& OTP Protect',
                              subtitle: 'Financial Fraud Alert',
                              imagePath: 'assets/images/ai_sms_guard_card.png',
                              height: 135,
                              onTap: () => context.push('/sms-inbox'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 250.ms).fadeIn(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ImageCard(
                              title: 'Dark Web\nBreach Scan',
                              subtitle: 'Identity Theft Check',
                              imagePath: 'assets/images/ai_darkweb_card.png',
                              height: 135,
                              onTap: () => context.push('/email-breach'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 300.ms).fadeIn(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ImageCard(
                              title: 'AI Cyber\nAssistant',
                              subtitle: 'Ask Any Threat',
                              imagePath: 'assets/images/ai_assistant_card.png',
                              height: 135,
                              onTap: () => context.push('/chat'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 350.ms).fadeIn(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ImageCard(
                              title: 'AI Scanner\nAdvanced',
                              subtitle: 'QR & Barcode',
                              imagePath: 'assets/images/ai_website_card.png',
                              height: 135,
                              onTap: () => context.push('/qr-scanner'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 400.ms).fadeIn(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ImageCard(
                              title: 'Clipboard\nGuard',
                              subtitle: 'OTP Protection',
                              imagePath: 'assets/images/ai_sms_guard_card.png',
                              height: 135,
                              onTap: () => context.push('/clipboard'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 450.ms).fadeIn(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ImageCard(
                              title: 'App Lock\nVault',
                              subtitle: 'Biometric Security',
                              imagePath: 'assets/images/ai_spyware_card.png',
                              height: 135,
                              onTap: () => context.push('/vault'),
                            ).animate().scale(begin: const Offset(0.9, 0.9), delay: 500.ms).fadeIn(),
                          ),
                        ],
                      ),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/ai_darkweb_card.png',
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
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
                        const SizedBox(height: 24),
                        
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

class _ImageCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final double height;
  final VoidCallback onTap;

  const _ImageCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.2),
                Colors.black.withOpacity(0.8),
                Colors.black,
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SolidCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final double height;
  final VoidCallback onTap;

  const _SolidCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Positioned(
              bottom: 0,
              right: 0,
              child: Icon(icon, color: iconColor, size: 28),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Color> colors;
  final double height;
  final VoidCallback onTap;

  const _GradientCard({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
