import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

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
  String _generatedComplaint = '';

  final List<Map<String, String>> _bankFreezeList = [
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
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Incident Response Kit',
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
              // Hero Golden Hour Banner
              _buildGoldenHourBanner(),
              const SizedBox(height: 20),

              // Emergency 1930 Helpline Tile
              _buildEmergencyHelplineTile(),
              const SizedBox(height: 20),

              // Bank Nodal Freeze Directory
              _buildBankFreezeSection(),
              const SizedBox(height: 20),

              // Instant FIR & Chakshu Complaint Formatter
              _buildComplaintGenerator(),
              const SizedBox(height: 20),

              // Evidence Preservation in Vault
              _buildEvidenceVaultBanner(),
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
          colors: [Color(0xFF7F1D1D), Color(0xFF991B1B), Color(0xFF450A0A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.25),
            blurRadius: 16,
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                    SizedBox(width: 4),
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
            'Indian Cyber Crime Coordination Centre (I4C) reports that 80%+ of stolen funds can be frozen in the banking pipeline if 1930 is alerted within 120 minutes of transaction debit.',
            style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.45),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildEmergencyHelplineTile() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFDC2626), size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dial 1930 (Cyber Helpline)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 2),
                Text(
                  'CFCFRS National Anti-Fraud Gateway',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _callNumber('1930'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Call 1930', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildBankFreezeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EMERGENCY BANK FREEZE DIRECTORY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Color(0xFF64748B),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _bankFreezeList.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final b = _bankFreezeList[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_rounded, size: 20, color: Color(0xFF2563EB)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b['name']!,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          b['smsFreeze']!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _callNumber(b['tollFree']!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.call, size: 14),
                    label: Text(b['tollFree']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildComplaintGenerator() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_rounded, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text(
                'Instant Cybercrime Portal FIR Generator',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Fills a legally formatted complaint statement ready to copy into cybercrime.gov.in and DoT Chakshu.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Stolen Amount (₹)',
              labelStyle: const TextStyle(fontSize: 12),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _utrCtrl,
            decoration: InputDecoration(
              labelText: 'Transaction UTR / Ref ID (12 digits)',
              labelStyle: const TextStyle(fontSize: 12),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _scammerInfoCtrl,
            decoration: InputDecoration(
              labelText: 'Scammer Phone / UPI ID / Telegram handle',
              labelStyle: const TextStyle(fontSize: 12),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bankNameCtrl,
            decoration: InputDecoration(
              labelText: 'Your Bank / Payment App (SBI, GPay, etc.)',
              labelStyle: const TextStyle(fontSize: 12),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _generateComplaintText,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('Generate Pre-formatted Complaint', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          if (_generatedComplaint.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        'FORMATTED STATEMENT',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF64748B)),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _copyToClipboard(_generatedComplaint, 'Official Complaint Statement'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 12),
                        label: const Text('Copy Statement', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _generatedComplaint,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF1E293B)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('cybercrime.gov.in', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('https://sancharsaathi.gov.in/sfc/'), mode: LaunchMode.externalApplication),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('DoT Chakshu', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvidenceVaultBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preserve Evidence in Vault',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                SizedBox(height: 2),
                Text(
                  'Lock scam screenshots & transaction receipts behind biometric encryption.',
                  style: TextStyle(fontSize: 11.5, color: Colors.white70),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.push('/vault'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Open Vault', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
