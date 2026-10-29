import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/hibp_service.dart';
import '../../core/services/phone_breach_service.dart';
import '../../core/services/llm_orchestrator.dart';

enum _ScanMode { email, phone }
enum _Phase { idle, scanning, done, error }

/// Auto-formats Indian mobile numbers, gracefully cleaning pasted international prefixes (+91/0)
class _IndianPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class EmailBreachScreen extends StatefulWidget {
  final bool initialPhoneMode;
  const EmailBreachScreen({super.key, this.initialPhoneMode = false});

  @override
  State<EmailBreachScreen> createState() => _EmailBreachScreenState();
}

class _EmailBreachScreenState extends State<EmailBreachScreen> {
  late _ScanMode _mode;
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  final HibpService _hibp = HibpService();
  final PhoneBreachService _phoneService = PhoneBreachService();

  _Phase _phase = _Phase.idle;
  
  // Email state
  List<BreachInfo> _emailBreaches = [];
  String _emailVerdict = '';

  // Phone state
  PhoneIntelligenceResult? _phoneResult;
  String _phoneVerdict = '';
  bool _unmaskLeakedData = false;
  bool _showRawJsonPayload = false;
  Map<String, dynamic>? _deviceSimInfo;
  String? _selectedActiveCarrier;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialPhoneMode ? _ScanMode.phone : _ScanMode.email;
    _detectDeviceSim();
  }

  Future<void> _detectDeviceSim() async {
    final sim = await PhoneBreachService.getDeviceActiveSim();
    if (mounted && sim.isNotEmpty) {
      setState(() {
        _deviceSimInfo = sim;
        if (_selectedActiveCarrier == null && sim['normalizedCarrier'] != null && (sim['normalizedCarrier'] as String).isNotEmpty) {
          _selectedActiveCarrier = sim['normalizedCarrier'] as String;
        }
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_ScanMode newMode) {
    if (_mode == newMode || _phase == _Phase.scanning) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = newMode;
      _phase = _Phase.idle;
    });
  }

  Future<void> _startScan() async {
    if (_mode == _ScanMode.email) {
      await _startEmailScan();
    } else {
      await _startPhoneScan();
    }
  }

  // ---------------------------------------------------------------------------
  // EMAIL SCAN WORKFLOW (100% Original Logic Preserved)
  // ---------------------------------------------------------------------------
  Future<void> _startEmailScan() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    final emailPattern = r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$';
    if (!RegExp(emailPattern).hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Kripya ek valid email address enter karein (e.g. name@example.com)."),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _phase = _Phase.scanning;
      _emailBreaches.clear();
      _emailVerdict = '';
    });

    try {
      final breaches = await _hibp.checkEmail(email);

      String instantVerdict;
      if (breaches.isEmpty) {
        instantVerdict = 'Great news! Your email was checked across 800+ dark web breaches and zero records were found.';
      } else {
        final hasPwd = breaches.any((b) => b.dataClasses.any((d) => d.toLowerCase().contains('password')));
        instantVerdict = hasPwd
            ? 'HIGH RISK: Passwords linked to this email were exposed in ${breaches.length} security breaches. Change compromised passwords and enable 2FA immediately.'
            : 'ALERT: Your email was found in ${breaches.length} public data exposures. Verify linked accounts and monitor for suspicious communications.';
      }

      setState(() {
        _emailBreaches = breaches;
        _emailVerdict = instantVerdict;
        _phase = _Phase.done;
      });

      _fetchEmailVerdict(email, breaches);
    } catch (e) {
      setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _fetchEmailVerdict(String email, List<BreachInfo> breaches) async {
    if (breaches.isEmpty) {
      if (mounted) {
        setState(() => _emailVerdict = 'Great news! Your email "$email" has not been found in any public data breaches.');
      }
      return;
    }

    final prompt = '''
    Analyze these data breaches for the email $email.
    Breaches: ${breaches.map((b) => '${b.title} (Leaked: ${b.dataClasses.join(", ")})').join(' | ')}
    
    Give a concise, authoritative security verdict in 2-3 sentences. Tell the user exactly what to do (e.g., change passwords immediately, enable 2FA). Use simple English/Hinglish. Do NOT use markdown.
    ''';

    try {
      final verdictObj = await LlmOrchestrator().analyze(text: prompt, type: 'chat');
      if (mounted) {
        setState(() => _emailVerdict = verdictObj.summary);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _emailVerdict = 'WARNING: Your email was found in ${breaches.length} data breaches. Please change your passwords for the affected services immediately and enable Two-Factor Authentication.');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PHONE SCAN WORKFLOW (Advance Mobile Threat & Telecom Intelligence)
  // ---------------------------------------------------------------------------
  Future<void> _startPhoneScan() async {
    final rawPhone = _phoneCtrl.text.trim();
    if (rawPhone.isEmpty) return;

    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Kripya ek valid 10-digit mobile number enter karein."),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _phase = _Phase.scanning;
      _phoneResult = null;
      _phoneVerdict = '';
    });

    try {
      final result = await _phoneService.scanPhoneNumber(
        rawPhone,
        overrideCarrier: _selectedActiveCarrier,
      );

      String instantVerdict;
      if (result.breaches.isEmpty) {
        instantVerdict = 'CLEAN RECORD: No dark-web breach exposures or leaked CAF forms found for ${result.formattedNumber}.';
      } else if (result.simSwapVulnerable) {
        instantVerdict = 'CRITICAL SIM-SWAP RISK: Father\'s name, residential address, or KYC forms for ${result.formattedNumber} were identified in leaked telecom databases. Lock your SIM PIN immediately.';
      } else {
        instantVerdict = 'ALERT: Mobile number exposed across ${result.breaches.length} indexed leaks. Monitor linked accounts for unauthorized OTP requests.';
      }

      setState(() {
        _phoneResult = result;
        _phoneVerdict = instantVerdict;
        _phase = _Phase.done;
      });

      _fetchPhoneVerdict(result);
    } catch (e) {
      setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _fetchPhoneVerdict(PhoneIntelligenceResult result) async {
    if (result.breaches.isEmpty) return;

    final prompt = '''
    Analyze the mobile intelligence breach scan for phone number: ${result.formattedNumber} on carrier ${result.carrier} (${result.circle}).
    Exposed Breaches: ${result.breaches.map((b) => '${b.title} (Exposed: ${b.dataClasses.join(", ")})').join(' | ')}
    SIM Swap Risk: ${result.simSwapVulnerable ? "High" : "Low"}.
    
    Give a concise, authoritative mobile cyber defense verdict in 2-3 sentences. Tell the user exactly how to defend their phone number (e.g. SIM PIN lock, switch to Authenticator app instead of SMS OTP, activate DND). Use simple English/Hinglish. Do NOT use markdown.
    ''';

    try {
      final verdictObj = await LlmOrchestrator().analyze(text: prompt, type: 'chat');
      if (mounted) {
        setState(() => _phoneVerdict = verdictObj.summary);
      }
    } catch (_) {
      // Keep instant verdict on error
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD SCREEN UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF06090F) : const Color(0xFFEBF3FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    // Calculate dynamic score and status based on current active mode
    double gaugeScore = 0;
    String statusText = '';
    Color statusColor = Colors.transparent;

    if (_phase == _Phase.done) {
      if (_mode == _ScanMode.email) {
        if (_emailBreaches.isEmpty) {
          statusText = 'Safe';
          statusColor = const Color(0xFF4CAF50);
        } else {
          int score = 0;
          for (var b in _emailBreaches) {
            if (b.dataClasses.contains('Passwords')) score += 40;
            if (b.dataClasses.contains('Email addresses')) score += 10;
            if (b.dataClasses.contains('Phone numbers')) score += 20;
            if (b.dataClasses.contains('Physical addresses')) score += 20;
          }
          score = score.clamp(0, 100);
          gaugeScore = score.toDouble();
          statusText = score >= 50 ? 'Unsafe' : 'Suspicious';
          statusColor = score >= 50 ? const Color(0xFFFF8A65) : const Color(0xFFFFB300);
        }
      } else {
        if (_phoneResult != null) {
          gaugeScore = _phoneResult!.riskScore.toDouble();
          if (gaugeScore == 0) {
            statusText = 'Safe';
            statusColor = const Color(0xFF4CAF50);
          } else if (gaugeScore >= 50) {
            statusText = 'High Risk';
            statusColor = const Color(0xFFFF8A65);
          } else {
            statusText = 'Suspicious';
            statusColor = const Color(0xFFFFB300);
          }
        }
      }
    } else if (_phase == _Phase.scanning) {
      statusText = 'Scanning...';
      statusColor = const Color(0xFF7C4DFF);
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1.5),
            ),
            child: IconButton(
              icon: Icon(Icons.grid_view_rounded, color: isDark ? Colors.white54 : Colors.black54, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          _mode == _ScanMode.email ? 'Email Analyzer' : 'Phone Intelligence',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: textColor,
            fontFamily: 'serif',
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Dual-Mode Selector (Email | Phone Number)
              _buildModeSelector(isDark),
              const SizedBox(height: 16),

              // Speedometer Gauge
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: gaugeScore),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return _EmailSpeedometerGauge(score: value);
                },
              ),
              const SizedBox(height: 12),

              // Status Text
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'serif',
                ),
              ).animate(target: statusText.isNotEmpty ? 1 : 0).fadeIn(),

              const SizedBox(height: 24),

              // Input Field based on Mode
              if (_mode == _ScanMode.email)
                _buildEmailInput(isDark, textColor)
              else ...[
                if (_deviceSimInfo != null &&
                    _deviceSimInfo!['normalizedCarrier'] != null &&
                    (_deviceSimInfo!['normalizedCarrier'] as String).isNotEmpty)
                  _buildDeviceSimBadge(isDark),
                _buildPhoneInput(isDark, textColor),
              ],

              const SizedBox(height: 18),

              // Primary Scan Button
              _buildScanButton(),

              if (_phase == _Phase.error)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'Network error. Please check your internet connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

              if (_phase == _Phase.done) ...[
                const SizedBox(height: 24),
                if (_mode == _ScanMode.email)
                  _buildEmailAnalysisCards(isDark)
                else
                  _buildPhoneAnalysisCards(isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI WIDGETS: MODE SELECTOR & INPUTS
  // ---------------------------------------------------------------------------
  Widget _buildModeSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton(
            title: 'Email Breach',
            icon: CupertinoIcons.mail,
            isActive: _mode == _ScanMode.email,
            onTap: () => _switchMode(_ScanMode.email),
            isDark: isDark,
          ),
          _buildTabButton(
            title: 'Phone OSINT Leak',
            icon: CupertinoIcons.phone,
            isActive: _mode == _ScanMode.phone,
            onTap: () => _switchMode(_ScanMode.phone),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF2563EB) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? (isDark ? Colors.white : const Color(0xFF1E293B))
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive
                    ? (isDark ? Colors.white : const Color(0xFF1E293B))
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailInput(bool isDark, Color textColor) {
    return TextField(
      controller: _emailCtrl,
      enabled: _phase != _Phase.scanning,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: textColor, fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Email Address',
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.black54,
          fontSize: 13,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            icon: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.black54, size: 24),
            onPressed: _phase == _Phase.scanning ? null : _startScan,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: isDark ? Colors.white30 : Colors.black26,
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: isDark ? Colors.white30 : Colors.black26,
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: isDark ? Colors.white70 : Colors.black87,
            width: 1.4,
          ),
        ),
      ),
      onSubmitted: (_) => _startScan(),
    );
  }

  Widget _buildDeviceSimBadge(bool isDark) {
    final carrier = _deviceSimInfo?['normalizedCarrier'] ?? 'Active SIM';
    final rawName = _deviceSimInfo?['simOperatorName'] ?? '';
    final isSelected = _selectedActiveCarrier == carrier;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C1929) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0284C7).withValues(alpha: isSelected ? 0.8 : 0.3),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.sim_card_rounded, color: Color(0xFF38BDF8), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'DETECTED HARDWARE SIM',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$carrier ${rawName.isNotEmpty && rawName != carrier ? "($rawName)" : ""}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _selectedActiveCarrier = carrier;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Active hardware SIM linked: $carrier'),
                  backgroundColor: const Color(0xFF0284C7),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isSelected ? Icons.check_rounded : Icons.bolt_rounded, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    isSelected ? 'Linked' : 'Link SIM',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInput(bool isDark, Color textColor) {
    return TextField(
      controller: _phoneCtrl,
      enabled: _phase != _Phase.scanning,
      keyboardType: TextInputType.phone,
      inputFormatters: [_IndianPhoneInputFormatter()],
      style: TextStyle(color: textColor, fontSize: 16, letterSpacing: 1.2),
      decoration: InputDecoration(
        labelText: 'Mobile Number',
        prefixIcon: Container(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🇮🇳 +91',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 20, color: isDark ? Colors.white24 : Colors.black26),
            ],
          ),
        ),
        hintText: '98765 43210',
        hintStyle: TextStyle(
          color: isDark ? Colors.white30 : Colors.black38,
          fontSize: 15,
        ),
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.black54,
          fontSize: 13,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            icon: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.black54, size: 24),
            onPressed: _phase == _Phase.scanning ? null : _startScan,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: isDark ? Colors.white30 : Colors.black26,
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: isDark ? Colors.white30 : Colors.black26,
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: isDark ? Colors.white70 : Colors.black87,
            width: 1.4,
          ),
        ),
      ),
      onSubmitted: (_) => _startScan(),
    );
  }

  Widget _buildScanButton() {
    final isPhone = _mode == _ScanMode.phone;
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: isPhone
              ? const [Color(0xFF8B5CF6), Color(0xFF6D28D9)]
              : const [Color(0xFF29B6F6), Color(0xFF0D47A1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: ElevatedButton(
        onPressed: _phase == _Phase.scanning ? null : _startScan,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 24),
            Expanded(
              child: Center(
                child: Text(
                  _phase == _Phase.scanning
                      ? (isPhone ? 'Scanning Dark Web & Telecom...' : 'Scanning Breaches...')
                      : (isPhone ? 'Scan Mobile Intelligence' : 'Scan Email'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
            _phase == _Phase.scanning
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(isPhone ? CupertinoIcons.phone_fill : CupertinoIcons.mail, color: Colors.white, size: 24),
            const SizedBox(width: 8),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 150.ms);
  }

  // ---------------------------------------------------------------------------
  // EMAIL ANALYSIS CARDS (Original UI)
  // ---------------------------------------------------------------------------
  Widget _buildEmailAnalysisCards(bool isDark) {
    if (_emailBreaches.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded, size: 60, color: Color(0xFF4CAF50)),
            const SizedBox(height: 16),
            const Text(
              'No Breaches Found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4CAF50)),
            ),
            const SizedBox(height: 8),
            Text(
              _emailVerdict.isEmpty ? 'Your email is secure and has not been found in any public leaks.' : _emailVerdict,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    int score = 0;
    bool passwordLeaked = false;
    for (var b in _emailBreaches) {
      if (b.dataClasses.contains('Passwords')) {
        score += 40;
        passwordLeaked = true;
      }
      if (b.dataClasses.contains('Email addresses')) score += 10;
      if (b.dataClasses.contains('Phone numbers')) score += 20;
      if (b.dataClasses.contains('Physical addresses')) score += 20;
    }
    score = score.clamp(0, 100);

    String siteGrade = score >= 50 ? 'E' : (score >= 20 ? 'C' : 'B');
    String secScore = score > 50 ? '1' : (score > 20 ? '5' : '8');

    Set<String> allLeaked = {};
    for (var b in _emailBreaches) {
      allLeaked.addAll(b.dataClasses);
    }
    String topLeaked = allLeaked.take(3).join(', ');
    if (topLeaked.isEmpty) topLeaked = 'Unknown Data';

    const outlineColor = Color(0xFFFF8A65);
    final cardStyle = BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: outlineColor, width: 1.5),
    );

    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: cardStyle,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF5D1D05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Risk Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.warning_amber_rounded, color: Color(0xFF6C63FF), size: 36),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildRow('Security Grade', siteGrade, valueColor: outlineColor, isDark: isDark),
              _divider(),
              _buildRow('Security Score', secScore, valueColor: outlineColor, isDark: isDark),
              _divider(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: Text('Synopsis', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text(_emailVerdict.isEmpty ? 'Loading AI Analysis...' : _emailVerdict, style: const TextStyle(color: outlineColor, fontSize: 13, height: 1.4))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: cardStyle,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF5D1D05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Breach Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 24),
              _buildRow('Total Breaches', '${_emailBreaches.length} Databases', valueColor: outlineColor, isDark: isDark),
              _divider(),
              _buildRow('Top Leaked Data', topLeaked, valueColor: outlineColor, isDark: isDark),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (passwordLeaked)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF3E120A),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Action Required', style: TextStyle(color: Color(0xFFFF8A65), fontSize: 16, fontWeight: FontWeight.bold)),
                    Icon(Icons.warning_rounded, color: Color(0xFFFF8A65), size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Passwords were found in these breaches. Change your passwords immediately and enable Two-Factor Authentication.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'BREACH TIMELINE & LEAK DETAILS (${_emailBreaches.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._emailBreaches.map((b) => _buildEmailBreachDetailCard(b, isDark)),
        const SizedBox(height: 30),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PHONE ANALYSIS CARDS (Advance Mobile Threat & Telecom Intelligence)
  // ---------------------------------------------------------------------------
  Widget _buildPhoneAnalysisCards(bool isDark) {
    final result = _phoneResult;
    if (result == null) return const SizedBox.shrink();

    final outlineColor = result.riskScore >= 50
        ? const Color(0xFFFF8A65)
        : (result.riskScore > 0 ? const Color(0xFFFFB300) : const Color(0xFF4CAF50));

    return Column(
      children: [
        // Card 1: Risk Analysis & AI Synopsis
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: outlineColor, width: 1.5),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: result.riskScore >= 50 ? const Color(0xFF5D1D05) : const Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Mobile Threat Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      result.riskScore >= 50 ? Icons.sim_card_alert_rounded : Icons.verified_user_rounded,
                      color: outlineColor,
                      size: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildRow('Security Grade', result.securityGrade, valueColor: outlineColor, isDark: isDark),
              _divider(),
              _buildRow('Threat Score', '${result.riskScore} / 100', valueColor: outlineColor, isDark: isDark),
              _divider(),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: outlineColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: outlineColor.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: outlineColor),
                        const SizedBox(width: 6),
                        Text(
                          'AI CYBER DEFENSE VERDICT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: outlineColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _phoneVerdict.isEmpty ? 'Analyzing threat intelligence...' : _phoneVerdict,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Card 2: Telecom & Network Telemetry Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.antenna_radiowaves_left_right, color: Color(0xFF38BDF8), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'TELECOM & CARRIER TELEMETRY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTelecomTile(
                label: 'MOBILE NUMBER',
                value: result.formattedNumber,
                icon: CupertinoIcons.phone_fill,
                isDark: isDark,
                valueColor: const Color(0xFF38BDF8),
              ),
              _buildTelecomTile(
                label: 'ACTIVE SIM NETWORK',
                value: result.carrier,
                icon: CupertinoIcons.antenna_radiowaves_left_right,
                isDark: isDark,
                valueColor: isDark ? Colors.white : const Color(0xFF0F172A),
                trailingWidget: InkWell(
                  onTap: () => _showMnpCarrierSelector(result, isDark),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (result.isPorted ? const Color(0xFF10B981) : const Color(0xFF38BDF8)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (result.isPorted ? const Color(0xFF10B981) : const Color(0xFF38BDF8)).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          result.isPorted ? Icons.check_circle_rounded : Icons.swap_horiz_rounded,
                          size: 11,
                          color: result.isPorted ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          result.isPorted ? 'MNP Active' : 'Switch MNP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: result.isPorted ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildTelecomTile(
                label: 'ALLOCATED SERIES (DoT)',
                value: result.allocatedCarrier ?? result.carrier,
                icon: CupertinoIcons.shield_fill,
                isDark: isDark,
                valueColor: isDark ? Colors.white70 : const Color(0xFF475569),
                subtitle: 'Original MSC allocation series issued by DoT',
              ),
              _buildTelecomTile(
                label: 'TELECOM CIRCLE (LSA)',
                value: result.circle,
                icon: CupertinoIcons.map_pin_ellipse,
                isDark: isDark,
              ),
              _buildTelecomTile(
                label: 'CONNECTION LINE TYPE',
                value: result.lineType,
                icon: CupertinoIcons.waveform_path,
                isDark: isDark,
                valueColor: Colors.greenAccent.shade400,
              ),
              const SizedBox(height: 10),
              // Quick 1-tap carrier switcher chips
              Text(
                'PORTED VIA MNP? SELECT YOUR CURRENT ACTIVE SIM:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildCarrierChip(
                      name: 'Reliance Jio Infocomm',
                      shortName: '⚡ Jio 5G',
                      brandColor: const Color(0xFF0284C7),
                      isActive: result.carrier.contains('Jio'),
                      isDark: isDark,
                      onTap: () {
                        setState(() {
                          _selectedActiveCarrier = 'Reliance Jio Infocomm';
                          _phoneResult = _phoneService.updateCarrierWithMnp(result, 'Reliance Jio Infocomm');
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildCarrierChip(
                      name: 'Bharti Airtel',
                      shortName: '📶 Airtel',
                      brandColor: const Color(0xFFEF4444),
                      isActive: result.carrier.contains('Airtel'),
                      isDark: isDark,
                      onTap: () {
                        setState(() {
                          _selectedActiveCarrier = 'Bharti Airtel';
                          _phoneResult = _phoneService.updateCarrierWithMnp(result, 'Bharti Airtel');
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildCarrierChip(
                      name: 'Vodafone Idea (Vi)',
                      shortName: '🟣 Vi',
                      brandColor: const Color(0xFFF59E0B),
                      isActive: result.carrier.contains('Vodafone') || result.carrier.contains('Vi'),
                      isDark: isDark,
                      onTap: () {
                        setState(() {
                          _selectedActiveCarrier = 'Vodafone Idea (Vi)';
                          _phoneResult = _phoneService.updateCarrierWithMnp(result, 'Vodafone Idea (Vi)');
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildCarrierChip(
                      name: 'BSNL Mobile (Bharat Sanchar Nigam Ltd)',
                      shortName: '🏛️ BSNL',
                      brandColor: const Color(0xFF22C55E),
                      isActive: result.carrier.contains('BSNL'),
                      isDark: isDark,
                      onTap: () {
                        setState(() {
                          _selectedActiveCarrier = 'BSNL Mobile (Bharat Sanchar Nigam Ltd)';
                          _phoneResult = _phoneService.updateCarrierWithMnp(result, 'BSNL Mobile (Bharat Sanchar Nigam Ltd)');
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'TRAI DoT originally allocated this range to ${result.allocatedCarrier ?? result.carrier}. If you ported via MNP, tap your active network above.',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : Colors.black45,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),

        if (result.leakedDossier != null) ...[
          const SizedBox(height: 16),
          _buildRawLeakedDossierCard(result.leakedDossier!, isDark),
        ],

        const SizedBox(height: 16),

        // Card 3: Exposed Identity Profile (Attacker's Dossier View)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: result.simSwapVulnerable
                  ? Colors.redAccent.withValues(alpha: 0.5)
                  : (isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
              width: result.simSwapVulnerable ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🔍', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'EXPOSED IDENTITY DOSSIER (OSINT LEAK PROFILE)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'This is the personal identity data that dark-web aggregators & commercial search portals (e.g. stacademy.in) sell for ₹10 per search:',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              ...result.exposedProfile.map((field) => _buildDossierFieldTile(field, isDark)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4338CA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ℹ️', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Commercial lookup sites charge ₹10 via UPI to query scraped telecom activation forms (CAF). SafeSignal is 100% on-device and never exposes or uploads your data.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.indigo.shade200,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Card 4: SIM Swap Risk Alert
        if (result.simSwapVulnerable)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF3E120A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Expanded(
                      child: Text('⚠️ SIM-Swap Risk Warning', style: TextStyle(color: Color(0xFFFF8A65), fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFFF8A65), size: 22),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Physical addresses and KYC Customer Acquisition (CAF) records linked to this number were detected in compromised retailer dumps. Attackers can leverage this data to socially engineer carrier store staff for unauthorized SIM replacement.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Card 4: Actionable Cyber Defense Steps
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFF22C55E), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'RECOMMENDED DEFENSE ACTIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...result.actionableSteps.map((step) => Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Color(0xFF22C55E)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            step,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Section: Real Individual Breaches Breakdown
        if (result.breaches.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'COMPROMISED EXPOSURES & LEAKS (${result.breaches.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...result.breaches.map((b) => _buildPhoneBreachCard(b, isDark)),
        ],

        const SizedBox(height: 30),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // DETAIL CARDS (EMAIL & PHONE)
  // ---------------------------------------------------------------------------
  Widget _buildEmailBreachDetailCard(BreachInfo b, bool isDark) {
    final hasPassword = b.dataClasses.any((d) => d.toLowerCase().contains('password'));
    final isPlaintext = b.passwordRisk.toLowerCase().contains('plain');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasPassword
              ? Colors.redAccent.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
          width: hasPassword ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  b.logoPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      b.title.isNotEmpty ? b.title[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: hasPassword ? Colors.redAccent : const Color(0xFF6C63FF),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            b.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (b.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, size: 16, color: Color(0xFF38BDF8)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.domain.isNotEmpty ? b.domain : b.title.toLowerCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (hasPassword ? Colors.redAccent : const Color(0xFF6C63FF)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  b.breachDate,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: hasPassword ? Colors.redAccent : const Color(0xFF6C63FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (b.pwnCount > 0)
                _buildBadge(
                  Icons.people_outline,
                  '${_formatRecords(b.pwnCount)} victims',
                  const Color(0xFFF59E0B),
                ),
              if (b.industry.isNotEmpty && b.industry != 'General')
                _buildBadge(
                  Icons.business_outlined,
                  b.industry,
                  const Color(0xFF38BDF8),
                ),
              if (isPlaintext)
                _buildBadge(
                  Icons.lock_open,
                  'Plaintext Passwords Exposed!',
                  Colors.redAccent,
                )
              else if (hasPassword)
                _buildBadge(
                  Icons.lock_outline,
                  'Password Hash Leaked',
                  Colors.orangeAccent,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'EXPOSED DATA TYPES:',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: b.dataClasses.map((dc) => _buildDataChip(dc)).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            b.description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              height: 1.35,
            ),
          ),
          if (b.referenceUrl != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final uri = Uri.tryParse(b.referenceUrl!);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Read incident source',
                    style: TextStyle(fontSize: 12, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.open_in_new, size: 12, color: Color(0xFF38BDF8)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhoneBreachCard(PhoneBreachInfo b, bool isDark) {
    final isCritical = b.severity == 'Critical';
    final isHigh = b.severity == 'High';
    final badgeColor = isCritical ? Colors.redAccent : (isHigh ? Colors.orangeAccent : const Color(0xFF38BDF8));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCritical
              ? Colors.redAccent.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
          width: isCritical ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    isCritical ? Icons.security_update_warning_rounded : Icons.cell_tower_rounded,
                    color: badgeColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.domain,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  b.breachDate,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'EXPOSED DATA CLASSES:',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: b.dataClasses.map((dc) => _buildDataChip(dc)).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            b.description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawLeakedDossierCard(LeakedIdentityDossier dossier, bool isDark) {
    const borderColor = Color(0xFFDC2626);
    final cardBg = isDark ? const Color(0xFF180A0A) : const Color(0xFFFEF2F2);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor.withValues(alpha: 0.7), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.security_rounded, color: Color(0xFFEF4444), size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DARK-WEB CAF THREAT SURFACE (stacademy.in Vector)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: borderColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Forensic audit of stolen Customer Acquisition Forms (CAF) traded on illicit search sites (e.g. stacademy.in) for ₹10:',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Privacy Integrity Guarantee Callout Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF818CF8), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Zero-Knowledge Defense: SafeSignal never fabricates fake identities or purchases illegal citizen databases. Below is the structural threat analysis of how cybercriminals exploit leaked telecom records.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.indigo.shade200 : const Color(0xFF3730A3),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Action Toolbar: Copy Schema Button & Unmask Toggle
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: dossier.rawDumpSyntax));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Forensic CAF threat schema copied to clipboard!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                  label: const Text(
                    'Copy API Threat Schema',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _unmaskLeakedData = !_unmaskLeakedData;
                    });
                  },
                  icon: Icon(
                    _unmaskLeakedData ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 14,
                    color: const Color(0xFFEF4444),
                  ),
                  label: Text(
                    _unmaskLeakedData ? 'Mask PII' : 'Unmask PII',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Field 1: Subscriber Registration Exposure
          _buildDossierValueBox(
            label: '👤 SUBSCRIBER REGISTRATION EXPOSURE',
            value: _unmaskLeakedData ? dossier.subscriberName : _maskString(dossier.subscriberName),
            highlightColor: const Color(0xFFF97316),
            isDark: isDark,
            subtitle: 'DoT KYC record status across historical retailer dumps',
          ),

          const SizedBox(height: 10),

          // Field 2: Father's / Guardian Name (Critical vector in Digital Arrest)
          _buildDossierValueBox(
            label: "👨 FATHER'S / GUARDIAN NAME EXPLOITATION",
            value: _unmaskLeakedData ? dossier.fatherName : _maskString(dossier.fatherName),
            highlightColor: const Color(0xFFEF4444),
            isDark: isDark,
            isCriticalAlert: true,
            badgeText: 'CRITICAL THREAT VECTOR',
            subtitle: 'Primary vector cited by fraudsters in Police/CBI Digital Arrest scams',
          ),

          const SizedBox(height: 10),

          // Field 3: Residential Address
          _buildDossierAddressBox(
            dossier: dossier,
            isDark: isDark,
            unmask: _unmaskLeakedData,
          ),

          const SizedBox(height: 10),

          // Field 4: Alternate Contact Number
          _buildDossierValueBox(
            label: '📱 ALTERNATE EMERGENCY CONTACT STATUS',
            value: _unmaskLeakedData ? dossier.alternateNumber : _maskPhone(dossier.alternateNumber),
            highlightColor: const Color(0xFF38BDF8),
            isDark: isDark,
            subtitle: 'Secondary contact numbers recorded during SIM purchase',
          ),

          const SizedBox(height: 10),

          // Field 5: National ID / Aadhaar Reference
          _buildDossierValueBox(
            label: '🆔 NATIONAL ID / AADHAAR RECORD SECURITY',
            value: dossier.idProofToken,
            highlightColor: const Color(0xFFA855F7),
            isDark: isDark,
            subtitle: 'Masked identity proof tokens',
          ),

          const SizedBox(height: 10),

          // Field 6: DoT Carrier & Telecom Circle
          _buildDossierValueBox(
            label: '📡 OPERATOR & TELECOM CIRCLE',
            value: '${dossier.primaryCarrier} — ${dossier.telecomCircle}',
            highlightColor: const Color(0xFF10B981),
            isDark: isDark,
            subtitle: 'Original DoT MSC allocation series',
          ),

          const SizedBox(height: 12),

          // Expandable: Raw JSON dump matching stacademy.in API
          GestureDetector(
            onTap: () {
              setState(() {
                _showRawJsonPayload = !_showRawJsonPayload;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.code_rounded, size: 16, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 8),
                      Text(
                        _showRawJsonPayload
                            ? 'Hide stacademy.in Threat Payload Schema'
                            : 'View stacademy.in Threat Payload Schema (JSON)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _showRawJsonPayload ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: isDark ? Colors.white54 : Colors.black54,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          if (_showRawJsonPayload) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: SelectableText(
                dossier.rawDumpSyntax,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFF4ADE80),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDossierValueBox({
    required String label,
    required String value,
    required Color highlightColor,
    required bool isDark,
    required String subtitle,
    bool isCriticalAlert = false,
    String? badgeText,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCriticalAlert
              ? const Color(0xFFDC2626)
              : (isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
          width: isCriticalAlert ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDossierAddressBox({
    required LeakedIdentityDossier dossier,
    required bool isDark,
    required bool unmask,
  }) {
    final rawDisplay =
        unmask ? dossier.rawCafAddress : _maskAddress(dossier.rawCafAddress);
    final cleanDisplay =
        unmask ? dossier.formattedAddress : _maskAddress(dossier.formattedAddress);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '📍 RESIDENTIAL ADDRESS (CAF POS FORMAT)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "'!' DELIMITER SIGNATURE",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Clean readable address
          SelectableText(
            cleanDisplay,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          // Raw unparsed CAF string with '!'
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              'Raw CAF: $rawDisplay',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _maskString(String s) {
    if (s.length <= 4) return s;
    final words = s.split(' ');
    return words.map((w) {
      if (w.length <= 2) return w;
      return '${w[0]}${'*' * (w.length - 2)}${w[w.length - 1]}';
    }).join(' ');
  }

  String _maskAddress(String addr) {
    final parts = addr.split('!');
    if (parts.length < 3) return addr;
    return '${parts.first}!***!***!${parts[parts.length - 2]}!${parts.last}';
  }

  String _maskPhone(String p) {
    if (p.length < 8) return p;
    return '${p.substring(0, 7)} XXXX ${p.substring(p.length - 2)}';
  }

  Widget _buildDossierFieldTile(ExposedDossierField field, bool isDark) {
    Color badgeColor;
    Color badgeBg;
    if (field.severity == 'Critical') {
      badgeColor = const Color(0xFFEF4444);
      badgeBg = const Color(0xFFEF4444).withValues(alpha: 0.12);
    } else if (field.severity == 'High') {
      badgeColor = const Color(0xFFF97316);
      badgeBg = const Color(0xFFF97316).withValues(alpha: 0.12);
    } else if (field.severity == 'Medium') {
      badgeColor = const Color(0xFF38BDF8);
      badgeBg = const Color(0xFF38BDF8).withValues(alpha: 0.12);
    } else {
      badgeColor = const Color(0xFF22C55E);
      badgeBg = const Color(0xFF22C55E).withValues(alpha: 0.12);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(field.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.fieldName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      field.category,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  field.isCompromised ? 'LEAKED' : 'SECURE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              field.exposureStatus,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: badgeColor,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            field.threatDescription,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataChip(String dc) {
    final lower = dc.toLowerCase();
    final isPwd = lower.contains('password');
    final isPhone = lower.contains('phone') || lower.contains('mobile');
    final isAddress = lower.contains('address') || lower.contains('location');
    final isGovt = lower.contains('id') || lower.contains('kyc') || lower.contains('father');

    final color = isPwd
        ? Colors.redAccent
        : isGovt
            ? Colors.deepOrangeAccent
            : isPhone
                ? Colors.purpleAccent
                : isAddress
                    ? Colors.amber.shade700
                    : const Color(0xFF6C63FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        dc,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCarrierChip({
    required String name,
    required String shortName,
    required Color brandColor,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? brandColor.withValues(alpha: 0.2)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? brandColor : (isDark ? Colors.white12 : Colors.black12),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) ...[
              Icon(Icons.check_circle_rounded, size: 12, color: brandColor),
              const SizedBox(width: 4),
            ],
            Text(
              shortName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive
                    ? (isDark ? Colors.white : brandColor)
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRecords(int n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }

  Widget _buildTelecomTile({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    Color? valueColor,
    Widget? trailingWidget,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (valueColor ?? const Color(0xFF38BDF8)).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: valueColor ?? const Color(0xFF38BDF8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailingWidget != null) ...[
            const SizedBox(width: 8),
            trailingWidget,
          ],
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    required Color valueColor,
    required bool isDark,
    Widget? trailingWidget,
    int labelFlex = 5,
    int valueFlex = 6,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: labelFlex,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: valueFlex,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                ?trailingWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMnpCarrierSelector(PhoneIntelligenceResult currentResult, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final carriers = [
          {
            'name': 'Reliance Jio Infocomm',
            'desc': 'Jio True 5G / 4G VoLTE (Pan-India)',
            'color': const Color(0xFF0284C7),
            'icon': Icons.bolt_rounded,
          },
          {
            'name': 'Bharti Airtel',
            'desc': 'Airtel 5G Plus / 4G LTE',
            'color': const Color(0xFFEF4444),
            'icon': Icons.cell_tower_rounded,
          },
          {
            'name': 'Vodafone Idea (Vi)',
            'desc': 'Vi GIGAnet 4G LTE',
            'color': const Color(0xFFF59E0B),
            'icon': Icons.signal_cellular_alt_rounded,
          },
          {
            'name': 'BSNL Mobile (Bharat Sanchar Nigam Ltd)',
            'desc': 'BSNL 3G / 4G National Network',
            'color': const Color(0xFF22C55E),
            'icon': Icons.public_rounded,
          },
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.swap_calls_rounded, color: Color(0xFF38BDF8), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select Active SIM Carrier (MNP)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'If you ported your SIM from another operator, select your current network to update your security & leak dossier:',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                ...carriers.map((c) {
                  final carrierName = c['name'] as String;
                  final carrierDesc = c['desc'] as String;
                  final carrierColor = c['color'] as Color;
                  final carrierIcon = c['icon'] as IconData;
                  final isSelected = currentResult.carrier == carrierName;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        final updated =
                            _phoneService.updateCarrierWithMnp(currentResult, carrierName);
                        setState(() {
                          _phoneResult = updated;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Carrier updated to $carrierName (MNP Active)'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? carrierColor.withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? carrierColor
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: isSelected ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: carrierColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(carrierIcon, color: carrierColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    carrierName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    carrierDesc,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded, color: carrierColor, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: Colors.white24, height: 1, thickness: 1),
    );
  }
}

// -----------------------------------------------------------------------------
// SPEEDOMETER GAUGE WIDGET
// -----------------------------------------------------------------------------
class _EmailSpeedometerGauge extends StatelessWidget {
  final double score; // 0 to 100
  const _EmailSpeedometerGauge({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 140,
      child: CustomPaint(
        painter: _EmailSpeedometerPainter(score),
      ),
    );
  }
}

class _EmailSpeedometerPainter extends CustomPainter {
  final double score;

  _EmailSpeedometerPainter(this.score);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 20);
    final radius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: radius - 20);

    paint.color = Colors.greenAccent.shade400;
    canvas.drawArc(rect, 3.14159, 3.14159 / 3, false, paint);

    paint.color = Colors.orangeAccent.shade400;
    canvas.drawArc(rect, 3.14159 + (3.14159 / 3), 3.14159 / 3, false, paint);

    paint.color = Colors.redAccent.shade400;
    canvas.drawArc(rect, 3.14159 + (2 * 3.14159 / 3), 3.14159 / 3, false, paint);

    double clampedScore = score.clamp(0.0, 100.0);
    final angle = 3.14159 + (clampedScore / 100) * 3.14159;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final needlePaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, -6);
    path.lineTo(radius - 10, 0);
    path.lineTo(0, 6);
    path.close();

    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, needlePaint);

    canvas.drawCircle(const Offset(0, 0), 16, needlePaint);
    final innerCirclePaint = Paint()..color = Colors.grey.shade400;
    canvas.drawCircle(const Offset(0, 0), 10, innerCirclePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EmailSpeedometerPainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
