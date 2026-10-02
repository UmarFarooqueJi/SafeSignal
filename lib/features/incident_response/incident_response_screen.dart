import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

// ─── Theme Colors ────────────────────────────────────────────────────────────
const _kScaffoldLight = Color(0xFFDEEBF7);
const _kCardLight     = Colors.white;
const _kTextMainLight = Color(0xFF0F172A);
const _kBorderLight   = Color(0xFFCBDDF0);
const _kBlue          = Color(0xFF0284C7);
const _kRed           = Color(0xFFDC2626);

class IncidentResponseScreen extends StatefulWidget {
  const IncidentResponseScreen({super.key});

  @override
  State<IncidentResponseScreen> createState() => _IncidentResponseScreenState();
}

class _IncidentResponseScreenState extends State<IncidentResponseScreen> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _utrCtrl = TextEditingController();
  final TextEditingController _scammerInfoCtrl = TextEditingController();
  final TextEditingController _bankNameCtrl = TextEditingController();
  final TextEditingController _bankSearchCtrl = TextEditingController();

  String _generatedComplaint = '';
  String _bankQuery = '';

  final List<Map<String, String>> _allBanks = [
    {
      'name': 'State Bank of India (SBI)',
      'tollFree': '18001234',
      'altTollFree': '18002100',
      'smsFreeze': 'BLOCK <Account No> to 567676',
    },
    {
      'name': 'HDFC Bank',
      'tollFree': '18002026161',
      'altTollFree': '18001600',
      'smsFreeze': 'Call 18002026161 or NetBanking emergency block',
    },
    {
      'name': 'ICICI Bank',
      'tollFree': '18001080',
      'altTollFree': '18601207777',
      'smsFreeze': 'BLOCK <Last 4 Digits> to 9215676766',
    },
    {
      'name': 'Axis Bank',
      'tollFree': '18604195555',
      'altTollFree': '18605005555',
      'smsFreeze': 'BLOCK <Last 4 Digits> to 56161600',
    },
    {
      'name': 'Punjab National Bank (PNB)',
      'tollFree': '18001802222',
      'altTollFree': '18001032222',
      'smsFreeze': 'BLOCK <Account No> to 5607040',
    },
    {
      'name': 'Bank of Baroda (BoB)',
      'tollFree': '18005700',
      'altTollFree': '18002584455',
      'smsFreeze': 'BLOCK <Last 4 Digits> to 8422009988',
    },
    {
      'name': 'Kotak Mahindra Bank',
      'tollFree': '18602662666',
      'altTollFree': '18002090000',
      'smsFreeze': 'Emergency debit card block via app',
    },
    {
      'name': 'PhonePe Fraud Support',
      'tollFree': '08068727374',
      'altTollFree': '02268727374',
      'smsFreeze': 'In-app Help > Report Fraudulent Activity',
    },
    {
      'name': 'Google Pay Grievance',
      'tollFree': '18004190157',
      'altTollFree': '18002582555',
      'smsFreeze': 'Settings > Help & Feedback > Raise Dispute',
    },
    {
      'name': 'Paytm Payments Bank',
      'tollFree': '01204456456',
      'altTollFree': '01204888444',
      'smsFreeze': '24x7 Helpdesk to lock Paytm wallet/account',
    },
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _utrCtrl.dispose();
    _scammerInfoCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankSearchCtrl.dispose();
    super.dispose();
  }

  void _generateComplaintText() {
    final amount = _amountCtrl.text.trim();
    final utr = _utrCtrl.text.trim();
    final scammer = _scammerInfoCtrl.text.trim();
    final bank = _bankNameCtrl.text.trim();
    final date = DateTime.now().toLocal().toString().split('.')[0];

    setState(() {
      _generatedComplaint = '''
COMPLAINT UNDER SECTION 66D OF THE INFORMATION TECHNOLOGY ACT, 2000 (CYBER FRAUD & CHEATING BY PERSONATION)

To,
The National Cyber Crime Reporting Portal / Station House Officer
Date & Time: $date

Respected Officer,
I am filing an urgent complaint regarding financial cyber fraud perpetrated against me within the Golden Hour.

INCIDENT DETAILS:
- Approximate Loss Amount: ₹${amount.isNotEmpty ? amount : '[AMOUNT]'}
- Transaction UTR / Ref Number: ${utr.isNotEmpty ? utr : '[UTR_NUMBER]'}
- My Bank / Payment App: ${bank.isNotEmpty ? bank : '[BANK_NAME]'}
- Suspect Identifier (Phone / UPI / Telegram): ${scammer.isNotEmpty ? scammer : '[SUSPECT_NUMBER_OR_UPI]'}

BRIEF MODUS OPERANDI:
The suspect initiated communication under false pretenses (digital arrest / fake courier / APK phishing / fraudulent UPI collect request). I was coerced/deceived into authorizing the transaction resulting in unauthorized debits from my account.

PRAYER:
1. Direct the intermediary banks and payment aggregators to immediately freeze the beneficiary account linked to the suspect UPI/Account under the CFCFRS protocol.
2. Register an official FIR under Section 66D IT Act and relevant provisions of the Bharatiya Nyaya Sanhita (BNS).
3. Facilitate reversal and restitution of the stolen funds.

Submitted by: [YOUR FULL NAME]
Mobile: [YOUR REGISTERED PHONE NUMBER]
Aadhaar/ID: [LAST 4 DIGITS]
''';
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _callNumber(String num) async {
    HapticFeedback.mediumImpact();
    final uri = Uri.parse('tel:$num');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF06090F) : _kScaffoldLight;
    final textMain = isDark ? Colors.white : _kTextMainLight;

    final filteredBanks = _allBanks.where((b) {
      if (_bankQuery.isEmpty) return true;
      final q = _bankQuery.toLowerCase();
      return b['name']!.toLowerCase().contains(q) ||
          b['tollFree']!.contains(q) ||
          b['smsFreeze']!.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Incident Response Kit',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: textMain,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textMain, size: 20),
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
              // Hero Golden Hour Banner
              _buildGoldenHourBanner(),
              const SizedBox(height: 16),

              // Emergency 1930 Helpline Tile
              _buildEmergencyHelplineTile(isDark),
              const SizedBox(height: 20),

              // Bank Nodal Freeze Directory
              _buildBankFreezeSection(filteredBanks, isDark),
              const SizedBox(height: 20),

              // Instant FIR & Chakshu Complaint Formatter
              _buildComplaintGenerator(isDark),
              const SizedBox(height: 20),

              // Evidence Preservation in Vault
              _buildEvidenceVaultBanner(isDark),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoldenHourBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF991B1B), Color(0xFFDC2626), Color(0xFF7F1D1D)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.35),
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
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'GOLDEN HOUR PROTOCOL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.emergency_rounded, color: Colors.white, size: 28),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Act Within the First 2 Hours',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Indian Cyber Crime Coordination Centre (I4C) data confirms that 80%+ of stolen funds can be frozen in the banking pipeline if 1930 is alerted within 120 minutes of unauthorized transaction debit.',
            style: TextStyle(fontSize: 12.5, color: Colors.white, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyHelplineTile(bool isDark) {
    final cardBg = isDark ? const Color(0xFF131926) : _kCardLight;
    final textMain = isDark ? Colors.white : _kTextMainLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kRed.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_in_talk_rounded, color: _kRed, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Dial 1930 (Cyber Helpline)',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: textMain),
                ),
                const SizedBox(height: 2),
                Text(
                  'CFCFRS National Anti-Fraud Gateway',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: _kRed,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _callNumber('1930'),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Call 1930',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankFreezeSection(List<Map<String, String>> banks, bool isDark) {
    final textMain = isDark ? Colors.white : _kTextMainLight;
    final cardBg = isDark ? const Color(0xFF131926) : _kCardLight;
    final borderColor = isDark ? Colors.white12 : _kBorderLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'EMERGENCY BANK FREEZE DIRECTORY',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            Text(
              '${banks.length} Entities',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _kBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Search Bar for Banks
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: TextField(
            controller: _bankSearchCtrl,
            onChanged: (val) => setState(() => _bankQuery = val),
            style: TextStyle(fontSize: 13, color: textMain),
            decoration: InputDecoration(
              hintText: 'Search Bank or Payment App (SBI, HDFC, PhonePe)...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // List of Banks
        if (banks.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: Text(
              'No bank found matching "$_bankQuery"',
              style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 13),
            ),
          )
        else
          ...banks.map((b) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_rounded, size: 19, color: _kBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          b['name']!,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: textMain),
                        ),
                        const SizedBox(height: 3),
                        InkWell(
                          onTap: () => _copyToClipboard(b['smsFreeze']!, 'SMS Protocol'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded, size: 11, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  b['smsFreeze']!,
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => _callNumber(b['tollFree']!),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.call, size: 12, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              b['tollFree']!,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildComplaintGenerator(bool isDark) {
    final textMain = isDark ? Colors.white : _kTextMainLight;
    final cardBg = isDark ? const Color(0xFF131926) : _kCardLight;
    final borderColor = isDark ? Colors.white12 : _kBorderLight;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
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
                  color: _kBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_rounded, color: _kBlue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cybercrime FIR & Chakshu Generator',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: textMain),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Automatically formats a legally grounded complaint statement ready to submit on cybercrime.gov.in and DoT Chakshu.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          _buildTextField(_amountCtrl, 'Stolen Amount (₹)', 'e.g. 25000', TextInputType.number, isDark),
          const SizedBox(height: 10),
          _buildTextField(_utrCtrl, 'Transaction UTR / Ref ID (12 digits)', 'e.g. 429381928472', TextInputType.text, isDark),
          const SizedBox(height: 10),
          _buildTextField(_scammerInfoCtrl, 'Scammer Phone / UPI ID / Handle', 'e.g. 9876543210 or scammer@upi', TextInputType.text, isDark),
          const SizedBox(height: 10),
          _buildTextField(_bankNameCtrl, 'Your Bank / Payment App', 'e.g. SBI, HDFC, PhonePe', TextInputType.text, isDark),
          const SizedBox(height: 16),
          Material(
            color: _kBlue,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _generateComplaintText,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Generate Legal Complaint Draft',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_generatedComplaint.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'LEGAL STATEMENT FORMATTED',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                      ),
                      const Spacer(),
                      Material(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => _copyToClipboard(_generatedComplaint, 'Official Complaint Statement'),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy_rounded, size: 12, color: Colors.white),
                                SizedBox(width: 5),
                                Text('Copy Draft', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    _generatedComplaint,
                    style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: isDark ? Colors.white : const Color(0xFF1E293B), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('https://cybercrime.gov.in/'), mode: LaunchMode.externalApplication),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: borderColor),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14, color: _kBlue),
                    label: const Text('cybercrime.gov.in', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kBlue)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('https://sancharsaathi.gov.in/sfc/'), mode: LaunchMode.externalApplication),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: borderColor),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14, color: _kBlue),
                    label: const Text('DoT Chakshu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kBlue)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, String hint, TextInputType type, bool isDark) {
    final borderColor = isDark ? Colors.white12 : _kBorderLight;
    final textMain = isDark ? Colors.white : _kTextMainLight;

    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: TextStyle(fontSize: 13, color: textMain),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white24 : Colors.black26),
        isDense: true,
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildEvidenceVaultBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFF0B1B15),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hardware Security Vault',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                SizedBox(height: 2),
                Text(
                  'Lock scam evidence & UTR receipts behind AES-256 hardware biometric encryption.',
                  style: TextStyle(fontSize: 11.5, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => context.push('/vault'),
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'Open Vault',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
