import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/supabase_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/hibp_service.dart';
import '../../core/services/llm_orchestrator.dart';

class EmailBreachScreen extends StatefulWidget {
  const EmailBreachScreen({super.key});

  @override
  State<EmailBreachScreen> createState() => _EmailBreachScreenState();
}

class _EmailBreachScreenState extends State<EmailBreachScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final HibpService _hibp = HibpService();
  
  _Phase _phase = _Phase.idle;
  List<BreachInfo> _breaches = [];
  String _verdict = '';

  Future<void> _startScan() async {
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
      _breaches.clear();
      _verdict = '';
    });

    try {
      final breaches = await _hibp.checkEmail(email);
      
      // Calculate risk score based on what was leaked
      int score = 0;
      for (var b in breaches) {
        if (b.dataClasses.contains('Passwords')) score += 40;
        if (b.dataClasses.contains('Email addresses')) score += 10;
        if (b.dataClasses.contains('Phone numbers')) score += 20;
        if (b.dataClasses.contains('Physical addresses')) score += 20;
      }
      score = score.clamp(0, 100);

      // Instant authoritative verdict so user never sees empty loading
      String instantVerdict;
      if (breaches.isEmpty) {
        instantVerdict = 'Great news! Your email was checked across 800+ dark web breaches and zero records were found.';
      } else {
        final hasPwd = breaches.any((b) => b.dataClasses.any((d) => d.toLowerCase().contains('password')));
        instantVerdict = hasPwd
            ? 'HIGH RISK: Passwords linked to this email were exposed in ' + breaches.length.toString() + ' security breaches. Change compromised passwords and enable 2FA immediately.'
            : 'ALERT: Your email was found in ' + breaches.length.toString() + ' public data exposures. Verify linked accounts and monitor for suspicious communications.';
      }

      setState(() {
        _breaches = breaches;
        _verdict = instantVerdict;
        _phase = _Phase.done;
      });

      // Save to Supabase
      try {
        await SupabaseService().saveScanHistory(
          scanType: 'EMAIL',
          target: email,
          status: breaches.isEmpty ? 'SAFE' : 'DANGER',
          details: {
            'breachCount': breaches.length,
            'breachNames': breaches.map((b) => b.title).toList(),
          },
        );
      } catch (e) {
        debugPrint('Supabase save error: $e');
      }

      // Fetch LLM Verdict
      _fetchVerdict(email, breaches);

    } catch (e) {
      setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _fetchVerdict(String email, List<BreachInfo> breaches) async {
    if (breaches.isEmpty) {
      setState(() => _verdict = 'Great news! Your email "$email" has not been found in any public data breaches.');
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
        setState(() => _verdict = verdictObj.summary);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _verdict = 'WARNING: Your email was found in ${breaches.length} data breaches. Please change your passwords for the affected services immediately and enable Two-Factor Authentication.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF06090F) : const Color(0xFFEBF3FA); // Keep original background colors
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    
    // Determine gauge score and status text based on breaches
    double gaugeScore = 0;
    String statusText = '';
    Color statusColor = Colors.transparent;

    if (_phase == _Phase.done) {
      if (_breaches.isEmpty) {
        statusText = 'Safe';
        statusColor = const Color(0xFF4CAF50);
      } else {
        // Calculate score
        int score = 0;
        for (var b in _breaches) {
          if (b.dataClasses.contains('Passwords')) score += 40;
          if (b.dataClasses.contains('Email addresses')) score += 10;
          if (b.dataClasses.contains('Phone numbers')) score += 20;
          if (b.dataClasses.contains('Physical addresses')) score += 20;
        }
        score = score.clamp(0, 100);
        gaugeScore = score.toDouble();
        
        if (score >= 50) {
          statusText = 'Unsafe';
          statusColor = const Color(0xFFFF8A65); // Orange-red
        } else {
          statusText = 'Suspicious';
          statusColor = const Color(0xFFFFB300);
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
          'Email Analyzer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: textColor,
            fontFamily: 'serif', 
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Gauge
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
              
              const SizedBox(height: 32),

              // TextField mimicking the screenshot
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark ? Colors.white : Colors.black54,
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    TextField(
                      controller: _emailCtrl,
                      enabled: _phase != _Phase.scanning,
                      style: TextStyle(color: textColor, fontSize: 16),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.search, color: isDark ? Colors.white : Colors.black87, size: 24),
                        ),
                      ),
                      onSubmitted: (_) => _startScan(),
                    ),
                    Positioned(
                      left: 24,
                      top: -10,
                      child: Container(
                        color: bg,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          'Email',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),

              // Scan Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF29B6F6), Color(0xFF0D47A1)],
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
                      const SizedBox(width: 24), // Balance for centering
                      Expanded(
                        child: Center(
                          child: Text(
                            _phase == _Phase.scanning ? 'Scanning...' : 'Scan Email',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                        ),
                      ),
                      _phase == _Phase.scanning 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(CupertinoIcons.mail, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 150.ms),

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
                _buildAnalysisCards(isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisCards(bool isDark) {
    if (_breaches.isEmpty) {
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
              _verdict.isEmpty ? 'Your email is secure and has not been found in any public leaks.' : _verdict,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    // Determine values for cards
    int score = 0;
    bool passwordLeaked = false;
    for (var b in _breaches) {
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
    
    // Top leaked data
    Set<String> allLeaked = {};
    for (var b in _breaches) {
      allLeaked.addAll(b.dataClasses);
    }
    String topLeaked = allLeaked.take(3).join(', ');
    if (topLeaked.isEmpty) topLeaked = 'Unknown Data';

    final outlineColor = const Color(0xFFFF8A65); // Coral/Orange outline
    final cardStyle = BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: outlineColor, width: 1.5),
    );

    return Column(
      children: [
        // Card 1: Risk Analysis
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
                  color: const Color(0xFF5D1D05), // Dark reddish brown
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
                  Expanded(flex: 3, child: Text(_verdict.isEmpty ? 'Loading AI Analysis...' : _verdict, style: TextStyle(color: outlineColor, fontSize: 13, height: 1.4))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Card 2: Breach Details
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
                  color: const Color(0xFF5D1D05), // Dark reddish brown
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Breach Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 24),
              _buildRow('Total Breaches', '${_breaches.length} Databases', valueColor: outlineColor, isDark: isDark),
              _divider(),
              _buildRow('Top Leaked Data', topLeaked, valueColor: outlineColor, isDark: isDark),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Card 3: Suspected Fraud (If Dangerous)
        if (passwordLeaked)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF3E120A), // Dark red bg
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Action Required', style: TextStyle(color: Color(0xFFFF8A65), fontSize: 16, fontWeight: FontWeight.bold)),
                    Icon(Icons.warning_rounded, color: const Color(0xFFFF8A65), size: 20),
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

        // Section: Real Individual Breaches Breakdown
        if (_breaches.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'BREACH TIMELINE & LEAK DETAILS (${_breaches.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._breaches.map((b) => _buildBreachDetailCard(b, isDark)),
        ],

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildBreachDetailCard(BreachInfo b, bool isDark) {
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
              // Company Logo
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
              // Year pill
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

          // Metric Badges (Records, Industry, Password Risk)
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

          // Leaked Data Classes Chips
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
            children: b.dataClasses.map((dc) {
              final isPwd = dc.toLowerCase().contains('password');
              final isPhone = dc.toLowerCase().contains('phone');
              final isAddress = dc.toLowerCase().contains('address');
              final isGovt = dc.toLowerCase().contains('id') || dc.toLowerCase().contains('ssn');

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
            }).toList(),
          ),

          const SizedBox(height: 10),

          // Incident Description
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

  String _formatRecords(int n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }

  Widget _buildRow(String label, String value, {required Color valueColor, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: valueColor, fontSize: 15, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: Colors.white24, height: 1, thickness: 1),
    );
  }
}

class _EmailSpeedometerGauge extends StatelessWidget {
  final double score; // 0 to 100
  const _EmailSpeedometerGauge({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 140, // Height is roughly half of width + padding for the needle base
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
    
    // Draw the 3 arcs (Green, Orange, Red)
    final rect = Rect.fromCircle(center: center, radius: radius - 20);
    
    // Green (0 to 33)
    paint.color = Colors.greenAccent.shade400;
    canvas.drawArc(rect, 3.14159, 3.14159 / 3, false, paint);
    
    // Orange (33 to 66)
    paint.color = Colors.orangeAccent.shade400;
    canvas.drawArc(rect, 3.14159 + (3.14159 / 3), 3.14159 / 3, false, paint);
    
    // Red (66 to 100)
    paint.color = Colors.redAccent.shade400;
    canvas.drawArc(rect, 3.14159 + (2 * 3.14159 / 3), 3.14159 / 3, false, paint);
    
    // Draw needle
    // Map score (0-100) to angle (Pi to 2*Pi)
    double clampedScore = score.clamp(0.0, 100.0);
    final angle = 3.14159 + (clampedScore / 100) * 3.14159;
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    
    final needlePaint = Paint()
      ..color = const Color(0xFFE0E0E0) // Light grey
      ..style = PaintingStyle.fill;
    
    // Draw needle triangle
    final path = Path();
    path.moveTo(0, -6);
    path.lineTo(radius - 10, 0);
    path.lineTo(0, 6);
    path.close();
    
    // Add shadow
    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, needlePaint);
    
    // Draw center circle
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

enum _Phase { idle, scanning, done, error }
