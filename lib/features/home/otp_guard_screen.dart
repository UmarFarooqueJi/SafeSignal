import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class OtpGuardScreen extends StatefulWidget {
  const OtpGuardScreen({super.key});

  @override
  State<OtpGuardScreen> createState() => _OtpGuardScreenState();
}

class _OtpGuardScreenState extends State<OtpGuardScreen> {
  bool _isSmsPermissionGranted = false;
  bool _isPhonePermissionGranted = false;
  String _selectedTab = 'USSD Tools';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final smsStatus = await Permission.sms.status;
    final phoneStatus = await Permission.phone.status;
    if (mounted) {
      setState(() {
        _isSmsPermissionGranted = smsStatus.isGranted;
        _isPhonePermissionGranted = phoneStatus.isGranted;
      });
    }
  }

  Future<void> _requestSmsPermission() async {
    final status = await Permission.sms.request();
    if (mounted) {
      setState(() {
        _isSmsPermissionGranted = status.isGranted;
      });
    }
  }

  Future<void> _requestPhonePermission() async {
    final status = await Permission.phone.request();
    if (mounted) {
      setState(() {
        _isPhonePermissionGranted = status.isGranted;
      });
    }
  }

  Future<void> _launchUssd(String rawCode) async {
    HapticFeedback.mediumImpact();
    // USSD hash (#) must be URL-encoded as %23 for tel: scheme
    final encoded = rawCode.replaceAll('#', '%23');
    final uri = Uri.parse('tel:$encoded');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _copyToClipboard(rawCode, 'USSD Code');
      }
    } catch (e) {
      _copyToClipboard(rawCode, 'USSD Code');
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label "$text" copied to clipboard! Paste in your dialer.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'SIM & OTP Forwarding Shield',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Banner
              _buildHeroBanner(isDark),
              const SizedBox(height: 20),

              // Emergency Master Purge Card (##002#)
              _buildMasterPurgeCard(),
              const SizedBox(height: 20),

              // Segmented Tab Selector
              _buildSegmentedTabs(),
              const SizedBox(height: 16),

              if (_selectedTab == 'USSD Tools') ...[
                _buildUssdToolsSection(),
              ] else if (_selectedTab == 'Scam Vectors') ...[
                _buildScamVectorsSection(),
              ] else ...[
                _buildSecurityChecklistSection(isDark),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F2B48)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, size: 12, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text(
                      'CARRIER USSD DEFENSE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.phonelink_lock_rounded, color: Colors.white70, size: 28),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Stop Stealth Call & OTP Forwarding',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cybercriminals trick victims into dialing *401* or *21* codes to forward all calls and voice OTPs directly to their burners. Verify and cleanse your SIM routing below.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.45,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildMasterPurgeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Universal Forwarding Purge',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    Text(
                      'GSM Standard Code: ##002#',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Dialing ##002# instantly cancels and de-registers ALL unconditional, busy, and unanswered call/SMS forwards across Jio, Airtel, Vi, and BSNL.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF7F1D1D), height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _launchUssd('##002#'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.phone_forwarded_rounded, size: 18),
                  label: const Text(
                    'Dial ##002# (Purge All)',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _copyToClipboard('##002#', 'Universal Purge Code'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF991B1B),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildSegmentedTabs() {
    final tabs = ['USSD Tools', 'Scam Vectors', 'SIM Checklist'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = tab);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUssdToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'ACTIVE FORWARDING STATUS CHECKERS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
        ),
        _buildUssdActionCard(
          code: '*#21#',
          title: 'Unconditional Forwarding Interrogation',
          desc: 'Checks if ALL calls/SMS are being stealthily diverted to a third-party scam number 24/7 without your phone ringing.',
          threatLevel: 'CRITICAL THREAT',
          threatColor: const Color(0xFFEF4444),
          icon: Icons.ring_volume_rounded,
        ),
        const SizedBox(height: 12),
        _buildUssdActionCard(
          code: '*#62#',
          title: 'Unreachable / Switched Off Forwarding',
          desc: 'Checks where calls/SMS are directed when your phone is unreachable, switched off, or when you are in airplane mode.',
          threatLevel: 'HIGH EXPOSURE',
          threatColor: const Color(0xFFF97316),
          icon: Icons.phonelink_erase_rounded,
        ),
        const SizedBox(height: 12),
        _buildUssdActionCard(
          code: '*#67#',
          title: 'Busy Call Forwarding Interrogation',
          desc: 'Checks where calls are routed when you reject or are actively speaking on another call.',
          threatLevel: 'EAVESDROPPING RISK',
          threatColor: const Color(0xFFEAB308),
          icon: Icons.phone_paused_rounded,
        ),
        const SizedBox(height: 12),
        _buildUssdActionCard(
          code: '*#004#',
          title: 'All Conditional Forwards Query',
          desc: 'Comprehensive carrier probe checking unreachable, busy, and unanswered forwarding status in a single sweep.',
          threatLevel: 'RECOMMENDED AUDIT',
          threatColor: const Color(0xFF3B82F6),
          icon: Icons.checklist_rtl_rounded,
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildUssdActionCard({
    required String code,
    required String title,
    required String desc,
    required String threatLevel,
    required Color threatColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: threatColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: threatColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          code,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: threatColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            threatLevel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: threatColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _launchUssd(code),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: Text('Dial $code', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _copyToClipboard(code, 'USSD Code'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Icon(Icons.copy_rounded, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScamVectorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'REAL-WORLD SIM HIJACK SCAM PATTERNS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
        ),
        _buildVectorCard(
          title: 'The *401* Jio & Airtel Stealth Forwarding Trap',
          badge: 'ACTIVE HIGH RISK',
          badgeColor: const Color(0xFFEF4444),
          body: 'A scammer impersonating an Airtel/Jio executive, courier partner, or police officer calls you: "Your SIM will be blocked in 2 hours due to KYC failure. Dial *401*98xxxxxxxx immediately to verify."\n\n'
              '⚠️ REALITY: *401* is the unconditional call forwarding prefix. Dialing this instantly routes all your incoming calls and voice OTPs to the scammer’s device, allowing them to reset your WhatsApp, NetBanking, and UPI.',
          remedy: 'Never dial *401* under any circumstances. If dialed, dial ##002# immediately.',
        ),
        const SizedBox(height: 14),
        _buildVectorCard(
          title: 'eSIM QR Code Hijack / SIM Swap',
          badge: 'FINANCIAL ATTACK',
          badgeColor: const Color(0xFFF97316),
          body: 'Victims receive a phishing email or SMS asking to upgrade to 5G or eSIM. The scammer sends a malicious eSIM QR code.\n\n'
              '⚠️ REALITY: Once scanned, your physical SIM is permanently deactivated by the carrier, and the scammer gains full cellular control over your mobile number.',
          remedy: 'Only scan eSIM QR codes issued inside official carrier stores. Check your physical SIM signal regularly.',
        ),
        const SizedBox(height: 14),
        _buildVectorCard(
          title: 'Voice Call OTP Bypass',
          badge: 'BANKING RISK',
          badgeColor: const Color(0xFF8B5CF6),
          body: 'When SMS OTP is delayed or blocked, banks offer "Verify via Phone Call". If the scammer has forwarded your calls, they trigger this button and receive the spoken OTP code directly on their burner phone.',
          remedy: 'Run the *#21# check once every week to confirm no forwarding numbers exist.',
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildVectorCard({
    required String title,
    required String badge,
    required Color badgeColor,
    required String body,
    required String remedy,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.45)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.security_rounded, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    remedy,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityChecklistSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'DEVICE & CELLULAR HYGIENE AUDIT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
        ),
        _buildChecklistTile(
          title: 'SMS Scam Monitoring Permission',
          subtitle: _isSmsPermissionGranted ? 'Active: Watching incoming OTP fraud patterns' : 'Permission missing: Cannot alert on OTP scams',
          isGranted: _isSmsPermissionGranted,
          onAction: _requestSmsPermission,
          actionLabel: 'Grant SMS Access',
        ),
        const SizedBox(height: 10),
        _buildChecklistTile(
          title: 'Telephony & Call State Permission',
          subtitle: _isPhonePermissionGranted ? 'Active: Monitoring unknown caller traps' : 'Missing: Cannot verify carrier call states',
          isGranted: _isPhonePermissionGranted,
          onAction: _requestPhonePermission,
          actionLabel: 'Grant Phone Access',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.sim_card_rounded, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'DoT Sanchar Saathi (TAFCOP)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Department of Telecommunications official portal to check how many active mobile connections are registered under your Aadhaar card.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse('https://tafcop.sancharsaathi.gov.in/'), mode: LaunchMode.externalApplication),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open TAFCOP Portal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.support_agent_rounded, color: Color(0xFFDC2626), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'National Cyber Crime Helpline: 1930',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'If your money has been siphoned off through SIM forwarding or unauthorized UPI debit, dial 1930 within the Golden Hour to freeze bank accounts.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:1930')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.phone_rounded, size: 16),
                label: const Text('Call 1930 Cyber Helpline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildChecklistTile({
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onAction,
    required String actionLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: isGranted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          if (!isGranted)
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(actionLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
