import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Color Palette ────────────────────────────────────────────────────────────
const _kScaffold   = Color(0xFFDEEBF7); // light blue like reference
const _kCard       = Colors.white;
const _kBlue       = Color(0xFF0284C7);
const _kTextMain   = Color(0xFF0F172A);
const _kOrange     = Color(0xFFEA580C);
const _kSubtext    = Color(0xFFCBDDF0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  double _securityScore = 4.85;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadScore();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadScore() async {
    final prefs = await SharedPreferences.getInstance();
    final rawScore = prefs.getInt('last_device_audit_score');
    if (rawScore != null && rawScore > 0) {
      setState(() {
        _securityScore = (rawScore / 20.0).clamp(1.0, 5.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("==== SAFESIGNAL HOMESCREEN BUILT SUCCESSFULLY ====");
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF06090F) : _kScaffold;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: scaffoldBg,
      endDrawer: _buildDrawer(context),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: scaffoldBg,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: SafeArea(
          bottom: false,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header (scrolls smoothly with entire page) ──────────────
                  _buildHeader(context),

                  // ── Device Secured Banner ──────────────────────────────────
                  _buildSecuredBanner(context),

                  const SizedBox(height: 24),

                  // ── 2-col Feature Cards ────────────────────────────────────
                  _buildCardGrid(context),

                  const SizedBox(height: 24),

                  // ── Helpline ───────────────────────────────────────────────
                  _buildHelplineCard(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header — matches reference ────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF06090F) : _kScaffold;
    final textMain = isDark ? Colors.white : _kTextMain;

    return Container(
      width: double.infinity,
      color: scaffoldBg,
      padding: const EdgeInsets.fromLTRB(22, 18, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo_transparent.png',
                width: 32,
                height: 32,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.shield_rounded, color: _kBlue, size: 30),
              ),
              const SizedBox(width: 8),
              Text(
                'SAFESIGNAL',
                style: TextStyle(
                  color: textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Builder(
                builder: (ctx) => InkWell(
                  onTap: () => Scaffold.of(ctx).openEndDrawer(),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.more_vert_rounded,
                        color: textMain, size: 24),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Big tagline — inline rich text matching reference exactly
          RichText(
            text: TextSpan(
              style: TextStyle(
                color: textMain,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                height: 1.15,
                letterSpacing: -0.5,
              ),
              children: const [
                TextSpan(text: 'Protect Your Digital Life, '),
                TextSpan(
                  text: 'Get Security Alerts',
                  style: TextStyle(
                    color: _kOrange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Device Secured Banner ─────────────────────────────────────────────────
  Widget _buildSecuredBanner(BuildContext context) => const _DeviceSecuredCard();

  // ── 2-Column Feature Card Grid ────────────────────────────────────────────
  Widget _buildCardGrid(BuildContext context) {
    final cards = [
      _CardData(
        title: 'App Spyware\nAudit',
        subtitle: 'Malware Check',
        icon: Icons.android_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A2F)],
        ),
        accentColor: const Color(0xFF22C55E),
        route: '/app-scanner',
      ),
      _CardData(
        title: 'WiFi Security\nScanner',
        subtitle: 'Network Threat Alert',
        icon: Icons.wifi_password_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0A0F2A), Color(0xFF1A1060)],
        ),
        accentColor: const Color(0xFF818CF8),
        route: '/wifi-scanner',
      ),
      _CardData(
        title: 'Website\nAnalyzer',
        subtitle: 'Phishing Check',
        icon: Icons.language_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0F1A0F), Color(0xFF0A2A1A)],
        ),
        accentColor: const Color(0xFF4ADE80),
        route: '/url-scanner',
      ),
      _CardData(
        title: 'Call Shield\nAnalysis',
        subtitle: 'Spam Call Protection',
        icon: Icons.phone_in_talk_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0A1A2A), Color(0xFF0C2A4D)],
        ),
        accentColor: const Color(0xFF38BDF8),
        route: '/call-shield',
      ),
      _CardData(
        title: 'SMS Scam\nRadar',
        subtitle: 'Fake SMS & Phishing',
        icon: Icons.sms_failed_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1A0A00), Color(0xFF2D1200)],
        ),
        accentColor: const Color(0xFFFB923C),
        route: '/sms-inbox',
      ),
      _CardData(
        title: 'Hardware\nSecurity Vault',
        subtitle: 'AES-256 Secret Storage',
        icon: Icons.shield_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0B1B15), Color(0xFF0D3326)],
        ),
        accentColor: const Color(0xFF10B981),
        route: '/vault',
      ),
      _CardData(
        title: 'Data Breach\nCheck',
        subtitle: 'Email Exposure Scan',
        icon: Icons.lock_open_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1A0A0A), Color(0xFF2D0000)],
        ),
        accentColor: const Color(0xFFF87171),
        route: '/email-breach',
      ),
      _CardData(
        title: 'Digital OSINT\nFootprint',
        subtitle: 'Phone & Profile Recon',
        icon: Icons.person_search_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1A0A1A), Color(0xFF2D0040)],
        ),
        accentColor: const Color(0xFFC084FC),
        route: '/social-osint',
      ),
      _CardData(
        title: 'Scan QR & UPI\nShield',
        subtitle: 'Safe Link & Payment Scan',
        icon: Icons.qr_code_scanner_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0A1A2A), Color(0xFF0E2A4A)],
        ),
        accentColor: const Color(0xFF60A5FA),
        route: '/qr-scanner',
      ),
      _CardData(
        title: 'AI Threat\nCopilot',
        subtitle: 'Ask AI Anything',
        icon: Icons.smart_toy_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF001A10), Color(0xFF002D1A)],
        ),
        accentColor: const Color(0xFF34D399),
        route: '/chat',
      ),
      _CardData(
        title: 'Incident\nResponse',
        subtitle: 'Emergency Protocol',
        icon: Icons.bolt_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1A0000), Color(0xFF3D0000)],
        ),
        accentColor: const Color(0xFFEF4444),
        route: '/incident-response',
      ),
      _CardData(
        title: 'App Lock\nVault',
        subtitle: 'Biometric Guard',
        icon: Icons.shield_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0A0A1A), Color(0xFF1A1A3A)],
        ),
        accentColor: const Color(0xFF6366F1),
        route: '/vault',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemCount: cards.length,
        itemBuilder: (context, i) => _FeatureCard(data: cards[i]),
      ),
    );
  }

  // ── Helpline Card ─────────────────────────────────────────────────────────
  Widget _buildHelplineCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141926) : _kCard;
    final textMain = isDark ? Colors.white : _kTextMain;
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.35 : 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_in_talk_rounded,
                  color: Color(0xFFDC2626), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'National Cyber Crime 1930',
                    style: TextStyle(
                      color: textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Toll-free fraud escalation portal',
                    style: TextStyle(color: textSub, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Material(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => launchUrl(Uri.parse('tel:1930')),
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    'Call 1930',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Side Drawer ───────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0369A1), Color(0xFF2563EB)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/logo_transparent.png',
                  width: 52,
                  height: 52,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'SafeSignal',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
                const Text('AI Threat Intelligence',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _drawerItem(context, Icons.newspaper_rounded, 'Cyber News & Alerts', '/feed'),
          _drawerItem(context, Icons.history_rounded, 'Scan History', '/history'),
          _drawerItem(context, Icons.settings_rounded, 'Settings', '/settings'),
        ],
      ),
    );
  }

  Widget _drawerItem(
      BuildContext context, IconData icon, String label, String route) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _kBlue, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              color: isDark ? Colors.white : _kTextMain,
              fontWeight: FontWeight.w600,
              fontSize: 14)),
      onTap: () {
        Navigator.pop(context);
        context.push(route);
      },
    );
  }
}

// ─── Card Data Model ──────────────────────────────────────────────────────────
class _CardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final Color accentColor;
  final String route;

  const _CardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.accentColor,
    required this.route,
  });
}

// ─── Feature Card Widget ──────────────────────────────────────────────────────
class _FeatureCard extends StatefulWidget {
  final _CardData data;
  const _FeatureCard({required this.data});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            setState(() => _pressed = false);
            context.push(widget.data.route);
          },
          child: AnimatedScale(
            scale: _pressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF131D32).withValues(alpha: 0.88),
                              const Color(0xFF0C1322).withValues(alpha: 0.78),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.62),
                              Colors.white.withValues(alpha: 0.38),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155).withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.75),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.data.accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.3 : 0.5),
                        blurRadius: 1,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Icon directly rendered without any square box — centered with accent glow
                        Icon(
                          widget.data.icon,
                          size: 38,
                          color: widget.data.accentColor,
                          shadows: [
                            Shadow(
                              color: widget.data.accentColor.withValues(alpha: 0.38),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Title
                        Text(
                          widget.data.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            letterSpacing: -0.2,
                          ),
                        ),

                        const SizedBox(height: 3),

                        // Subtitle
                        Text(
                          widget.data.subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Device Secured Premium Animated Card ──────────────────────────────────────
class _DeviceSecuredCard extends StatefulWidget {
  const _DeviceSecuredCard();

  @override
  State<_DeviceSecuredCard> createState() => _DeviceSecuredCardState();
}

class _DeviceSecuredCardState extends State<_DeviceSecuredCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  int _statusIndex = 0;
  Timer? _statusTimer;

  static const List<String> _statusMessages = [
    'Active Protection',
    'Integrity 100%',
    '0 Threats Found',
    'All Shields Armed',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _statusTimer = Timer.periodic(const Duration(milliseconds: 3200), (timer) {
      if (mounted) {
        setState(() {
          _statusIndex = (_statusIndex + 1) % _statusMessages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => context.push('/device-audit'),
          borderRadius: BorderRadius.circular(24),
          splashColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
          highlightColor: const Color(0xFF2563EB).withValues(alpha: 0.05),
          child: Container(
            constraints: const BoxConstraints(minHeight: 124),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF151D30),
                        const Color(0xFF0F172A),
                        const Color(0xFF0A0F1D),
                      ]
                    : [
                        Colors.white,
                        const Color(0xFFF8FAFC),
                        const Color(0xFFEFF6FF),
                      ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: isDark ? 0.35 : 0.28),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Layer 1: Futuristic cyber grid texture & radar watermark
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CyberCardTexturePainter(
                        isDark: isDark,
                        pulseValue: _pulseAnim.value,
                      ),
                    ),
                  ),

                  // Layer 2: Glossy specular reflection highlight on top edge
                  Positioned(
                    top: 0,
                    left: 20,
                    right: 20,
                    height: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: isDark ? 0.2 : 0.8),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Layer 3: Main interactive content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Shield icon DIRECTLY on card (NO square container box) with pulsing holographic glow
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, child) {
                            final scale = 0.95 + (_pulseAnim.value * 0.09);
                            return Transform.scale(
                              scale: scale,
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child: ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: isDark
                                          ? [
                                              const Color(0xFF00FF66),
                                              const Color(0xFF00E5FF),
                                              const Color(0xFF38BDF8),
                                            ]
                                          : [
                                              const Color(0xFF10B981),
                                              const Color(0xFF059669),
                                              const Color(0xFF0284C7),
                                            ],
                                    ).createShader(bounds),
                                    child: Icon(
                                      Icons.shield_rounded,
                                      size: 46,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: (isDark
                                                  ? const Color(0xFF00FF66)
                                                  : const Color(0xFF10B981))
                                              .withValues(
                                                  alpha: 0.55 + (_pulseAnim.value * 0.4)),
                                          blurRadius: 18 + (_pulseAnim.value * 8),
                                          offset: Offset.zero,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(width: 14),

                        // Center: Header and smooth animated telemetry ticker
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Title with verified badge
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Device Secured',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : _kTextMain,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFF10B981),
                                    size: 16,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 5),

                              // Smooth animated status ticker with pulsing live beacon
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Live animated pulse beacon dot
                                  AnimatedBuilder(
                                    animation: _pulseAnim,
                                    builder: (context, _) {
                                      return Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF10B981),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF10B981).withValues(
                                                  alpha: 0.4 + (_pulseAnim.value * 0.5)),
                                              blurRadius: 4 + (_pulseAnim.value * 4),
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(width: 7),

                                  // Smooth animated switcher for live security telemetry
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 240),
                                      switchInCurve: Curves.easeIn,
                                      switchOutCurve: Curves.easeOut,
                                      layoutBuilder: (currentChild, previousChildren) {
                                        return Stack(
                                          alignment: Alignment.centerLeft,
                                          children: [
                                            ...previousChildren,
                                            if (currentChild != null) currentChild,
                                          ],
                                        );
                                      },
                                      transitionBuilder: (child, animation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0.0, 0.25),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        _statusMessages[_statusIndex],
                                        key: ValueKey<int>(_statusIndex),
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF475569),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.1,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Right: Sleek high-tech "Audit" button
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF2563EB),
                                Color(0xFF1D4ED8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined, color: Colors.white, size: 13),
                              SizedBox(width: 4),
                              Text(
                                'Audit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

// ── Hacker / Cyber Texture & Circuit Background Painter ────────────────────────
class _CyberCardTexturePainter extends CustomPainter {
  final bool isDark;
  final double pulseValue;

  _CyberCardTexturePainter({required this.isDark, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. Tactical CRT / HUD Scanlines ──────────────────────────────────────
    final scanlinePaint = Paint()
      ..color = (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
          .withValues(alpha: isDark ? 0.045 : 0.02)
      ..strokeWidth = 1.0;
    for (double y = 4; y < size.height; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }

    // ── 2. Hacker Cyber Grid: Crosshair Reticle Markers (+) ───────────────────
    final reticlePaint = Paint()
      ..color = (isDark ? const Color(0xFF00FF66) : const Color(0xFF0284C7))
          .withValues(alpha: isDark ? 0.12 : 0.065)
      ..strokeWidth = 1.0;
    const double spacing = 22.0;
    for (double x = 14; x < size.width; x += spacing) {
      for (double y = 14; y < size.height; y += spacing) {
        // Draw tiny tactical crosshair '+' at each grid node
        canvas.drawLine(Offset(x - 2.2, y), Offset(x + 2.2, y), reticlePaint);
        canvas.drawLine(Offset(x, y - 2.2), Offset(x, y + 2.2), reticlePaint);
      }
    }

    // ── 3. PCB Circuit Bus Traces with Solder Vias (Hacker Motherboard) ───────
    final tracePaint = Paint()
      ..color = (isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB))
          .withValues(alpha: isDark ? (0.16 + (pulseValue * 0.08)) : (0.08 + (pulseValue * 0.04)))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final viaPaint = Paint()
      ..color = (isDark ? const Color(0xFF00FF66) : const Color(0xFF10B981))
          .withValues(alpha: isDark ? (0.32 + (pulseValue * 0.15)) : 0.22)
      ..style = PaintingStyle.fill;

    // Upper circuit bus with 45° dogleg
    final pathTop = Path()
      ..moveTo(size.width * 0.28, 16)
      ..lineTo(size.width * 0.62, 16)
      ..lineTo(size.width * 0.70, 32)
      ..lineTo(size.width * 0.96, 32);
    canvas.drawPath(pathTop, tracePaint);

    // Lower circuit bus with 45° dogleg
    final pathBottom = Path()
      ..moveTo(size.width * 0.40, size.height - 16)
      ..lineTo(size.width * 0.68, size.height - 16)
      ..lineTo(size.width * 0.76, size.height - 32)
      ..lineTo(size.width * 0.94, size.height - 32);
    canvas.drawPath(pathBottom, tracePaint);

    // Micro solder via rings at trace junction points
    final viaPoints = [
      Offset(size.width * 0.28, 16),
      Offset(size.width * 0.62, 16),
      Offset(size.width * 0.70, 32),
      Offset(size.width * 0.96, 32),
      Offset(size.width * 0.40, size.height - 16),
      Offset(size.width * 0.68, size.height - 16),
      Offset(size.width * 0.76, size.height - 32),
    ];
    for (final pt in viaPoints) {
      canvas.drawCircle(pt, 2.0, viaPaint);
      canvas.drawCircle(pt, 3.8, tracePaint..strokeWidth = 0.8);
    }

    // ── 4. Tactical HUD Corner Brackets (Cyber Target Frame) ──────────────────
    final bracketPaint = Paint()
      ..color = (isDark ? const Color(0xFF00FF66) : const Color(0xFF2563EB))
          .withValues(alpha: isDark ? 0.40 : 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Top-left bracket ┌
    canvas.drawLine(const Offset(8, 16), const Offset(8, 8), bracketPaint);
    canvas.drawLine(const Offset(8, 8), const Offset(20, 8), bracketPaint);

    // Bottom-right bracket ┘
    canvas.drawLine(Offset(size.width - 20, size.height - 8), Offset(size.width - 8, size.height - 8), bracketPaint);
    canvas.drawLine(Offset(size.width - 8, size.height - 8), Offset(size.width - 8, size.height - 16), bracketPaint);

    // ── 5. Concentric Radar Scanner Sweep ────────────────────────────────────
    final radarCenter = Offset(size.width * 0.88, size.height * 0.5);
    final arcPaint = Paint()
      ..color = (isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB))
          .withValues(alpha: isDark ? (0.09 + (pulseValue * 0.05)) : (0.05 + (pulseValue * 0.03)))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(radarCenter, 38 + (pulseValue * 6), arcPaint);
    canvas.drawCircle(radarCenter, 66 + (pulseValue * 8), arcPaint);
    canvas.drawCircle(radarCenter, 96 + (pulseValue * 10), arcPaint);

    // Radar crosshair ticks on radar center
    canvas.drawLine(Offset(radarCenter.dx - 10, radarCenter.dy), Offset(radarCenter.dx + 10, radarCenter.dy), arcPaint);
    canvas.drawLine(Offset(radarCenter.dx, radarCenter.dy - 10), Offset(radarCenter.dx, radarCenter.dy + 10), arcPaint);

    // ── 6. Ethereal Holographic Bloom directly behind Shield Icon ────────────
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(40, size.height * 0.5),
        56,
        [
          (isDark ? const Color(0xFF00FF66) : const Color(0xFF10B981))
              .withValues(alpha: isDark ? (0.30 + pulseValue * 0.12) : 0.18),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(Offset(40, size.height * 0.5), 56, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _CyberCardTexturePainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue || oldDelegate.isDark != isDark;
  }
}
