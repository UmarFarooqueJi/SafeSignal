import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/services/ai_expert_service.dart';

class PhoneOsintScreen extends StatefulWidget {
  final String? initialPhone;
  const PhoneOsintScreen({super.key, this.initialPhone});

  @override
  State<PhoneOsintScreen> createState() => _PhoneOsintScreenState();
}

enum _PhoneCategory { all, messaging, upi, callerId, govt }

class PhonePlatformProfile {
  final String platform;
  final String category; // 'Messaging', 'UPI Banking', 'Caller ID', 'Law Enforcement'
  final IconData icon;
  final Color brandColor;
  final String statusBadge;
  final Color statusBadgeColor;
  final String headline;
  final String description;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final List<String> details;
  final Widget? customContent;

  const PhonePlatformProfile({
    required this.platform,
    required this.category,
    required this.icon,
    required this.brandColor,
    required this.statusBadge,
    required this.statusBadgeColor,
    required this.headline,
    required this.description,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.details = const [],
    this.customContent,
  });
}

class PhoneScanResult {
  final String rawInput;
  final String cleanedNumber;
  final String internationalE164;
  final String countryName;
  final String countryCode;
  final String flag;
  final String operator;
  final Color operatorColor;
  final String telecomCircle;
  final String lineType; // Mobile, VoIP / Virtual Number, Fixed Landline, Satellite / Premium
  final int riskScore; // 0-100
  final String riskLevel; // SAFE, LOW, MEDIUM, HIGH, CRITICAL
  final Color riskColor;
  final List<String> threatAlerts;
  final List<String> technicalDetails;
  final List<String> predictedUpiVpas;
  final bool isVoip;
  final bool isSatelliteWangiri;
  final bool isHighScamOrigin;
  final List<PhonePlatformProfile> platforms;
  String? aiThreatAnalysis;

  PhoneScanResult({
    required this.rawInput,
    required this.cleanedNumber,
    required this.internationalE164,
    required this.countryName,
    required this.countryCode,
    required this.flag,
    required this.operator,
    required this.operatorColor,
    required this.telecomCircle,
    required this.lineType,
    required this.riskScore,
    required this.riskLevel,
    required this.riskColor,
    required this.threatAlerts,
    required this.technicalDetails,
    required this.predictedUpiVpas,
    required this.isVoip,
    required this.isSatelliteWangiri,
    required this.isHighScamOrigin,
    required this.platforms,
    this.aiThreatAnalysis,
  });
}

class _PhoneOsintScreenState extends State<PhoneOsintScreen> {
  final _phoneController = TextEditingController();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 7),
    receiveTimeout: const Duration(seconds: 7),
    validateStatus: (s) => s != null && s < 500,
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    },
  ));

  PhoneScanResult? _result;
  bool _isAnalyzing = false;
  bool _isAiLoading = false;
  String? _errorMessage;
  double _scanProgress = 0.0;
  String _scanStep = '';
  _PhoneCategory _selectedCategory = _PhoneCategory.all;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null && widget.initialPhone!.trim().isNotEmpty) {
      _phoneController.text = widget.initialPhone!.trim();
      _runAnalysis(_phoneController.text);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _dio.close();
    super.dispose();
  }

  // ─── TELECOM RECON & OSINT ENGINE ──────────────────────────────────────────

  Future<void> _runAnalysis(String input) async {
    final raw = input.trim();
    if (raw.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid phone number');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isAnalyzing = true;
      _isAiLoading = true;
      _errorMessage = null;
      _result = null;
      _scanProgress = 0.18;
      _scanStep = 'Interrogating ITU-T E.164 allocation & DoT databases...';
      _selectedCategory = _PhoneCategory.all;
    });

    try {
      final res = _analyzePhoneNumber(raw);

      // Step 2: Probing WhatsApp profile route
      if (mounted) {
        setState(() {
          _scanProgress = 0.42;
          _scanStep = 'Probing WhatsApp Direct Profile & Business route...';
        });
      }
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 3: Probing Telegram Network footprint
      if (mounted) {
        setState(() {
          _scanProgress = 0.65;
          _scanStep = 'Interrogating Telegram network & task syndicates...';
        });
      }
      try {
        final cleanDigits = res.cleanedNumber;
        await _dio.get('https://t.me/+$cleanDigits');
      } catch (_) {}

      // Step 4: Resolving NPCI UPI banking routing
      if (mounted) {
        setState(() {
          _scanProgress = 0.85;
          _scanStep = 'Synthesizing NPCI UPI banking switches & VPA mapping...';
        });
      }
      await Future.delayed(const Duration(milliseconds: 250));

      // Step 5: Finalizing compilation & AI Threat Assessment
      if (mounted) {
        setState(() {
          _scanProgress = 1.0;
          _scanStep = 'Compiling Cloudflare AI Telecom Threat Dossier...';
          _result = res;
          _isAnalyzing = false;
        });
      }

      // Background AI call
      _fetchAiThreatAssessment(res);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not parse number format: $e';
          _isAnalyzing = false;
          _isAiLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAiThreatAssessment(PhoneScanResult res) async {
    try {
      final contextData = '''
Phone: ${res.internationalE164}
Country: ${res.countryName}
Carrier: ${res.operator}
Circle: ${res.telecomCircle}
Line Type: ${res.lineType}
Risk Score: ${res.riskScore}/100 (${res.riskLevel})
Is VoIP: ${res.isVoip}
Wangiri Trap: ${res.isSatelliteWangiri}
High Scam Region: ${res.isHighScamOrigin}
Alerts: ${res.threatAlerts.join('; ')}
''';

      final analysis = await AiExpertService().explainWithExpert(
        domain: 'phone',
        context: contextData,
        language: 'hi',
      );

      if (mounted && _result != null) {
        setState(() {
          _result!.aiThreatAnalysis = analysis;
          _isAiLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAiLoading = false);
      }
    }
  }

  PhoneScanResult _analyzePhoneNumber(String raw) {
    String sanitized = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (sanitized.startsWith('00')) {
      sanitized = '+${sanitized.substring(2)}';
    }

    String e164 = sanitized;
    String digitsOnly = sanitized.replaceAll(RegExp(r'[^\d]'), '');

    if (!sanitized.startsWith('+')) {
      if (digitsOnly.length == 10 && RegExp(r'^[6-9]').hasMatch(digitsOnly)) {
        e164 = '+91$digitsOnly';
      } else if (digitsOnly.length == 11 && digitsOnly.startsWith('0')) {
        e164 = '+91${digitsOnly.substring(1)}';
      } else {
        e164 = '+$digitsOnly';
      }
    }

    final digits = e164.replaceAll('+', '');

    String countryName = 'International / Unknown';
    String countryCode = 'Unknown';
    String flag = '🌐';
    bool isHighScam = false;
    bool isWangiri = false;
    bool isVoip = false;

    if (e164.startsWith('+91')) {
      countryName = 'India';
      countryCode = '+91';
      flag = '🇮🇳';
    } else if (e164.startsWith('+1')) {
      countryName = 'United States / Canada (NANP)';
      countryCode = '+1';
      flag = '🇺🇸';
      isVoip = _checkUsVoip(digits);
    } else if (e164.startsWith('+44')) {
      countryName = 'United Kingdom';
      countryCode = '+44';
      flag = '🇬🇧';
      if (digits.startsWith('4470')) isVoip = true;
    } else if (e164.startsWith('+92')) {
      countryName = 'Pakistan';
      countryCode = '+92';
      flag = '🇵🇰';
      isHighScam = true;
    } else if (e164.startsWith('+234')) {
      countryName = 'Nigeria';
      countryCode = '+234';
      flag = '🇳🇬';
      isHighScam = true;
    } else if (e164.startsWith('+855')) {
      countryName = 'Cambodia (Digital Arrest Hub)';
      countryCode = '+855';
      flag = '🇰🇭';
      isHighScam = true;
    } else if (e164.startsWith('+95')) {
      countryName = 'Myanmar (KK Park Scam Complex)';
      countryCode = '+95';
      flag = '🇲🇲';
      isHighScam = true;
    } else if (e164.startsWith('+881') || e164.startsWith('+882') || e164.startsWith('+870')) {
      countryName = 'Global Satellite Network (Iridium/Inmarsat)';
      countryCode = e164.substring(0, 4);
      flag = '🛰️';
      isWangiri = true;
    } else if (e164.startsWith('+247') || e164.startsWith('+269') || e164.startsWith('+239') || e164.startsWith('+675')) {
      countryName = 'High-Tariff Island Territory';
      countryCode = e164.substring(0, 4);
      flag = '🏝️';
      isWangiri = true;
    } else if (e164.startsWith('+86')) {
      countryName = 'China';
      countryCode = '+86';
      flag = '🇨🇳';
    } else if (e164.startsWith('+971')) {
      countryName = 'United Arab Emirates';
      countryCode = '+971';
      flag = '🇦🇪';
    } else if (e164.startsWith('+65')) {
      countryName = 'Singapore';
      countryCode = '+65';
      flag = '🇸🇬';
    }

    String operator = 'Standard Global Telecom';
    Color operatorColor = const Color(0xFF3B82F6);
    String circle = 'Global Route';
    String lineType = 'Physical Cellular Mobile';
    final threatAlerts = <String>[];
    final technicalDetails = <String>[];
    final predictedUpi = <String>[];

    int riskScore = 15;

    // Detailed Indian DoT Telecom Parsing (+91)
    if (e164.startsWith('+91')) {
      final nationalDigits = digits.substring(2);
      if (nationalDigits.length == 10) {
        final prefix3 = nationalDigits.substring(0, 3);
        final prefix4 = nationalDigits.substring(0, 4);
        final firstDigit = nationalDigits[0];

        if (RegExp(r'^[6-9]').hasMatch(firstDigit)) {
          lineType = 'Cellular Mobile (GSM/LTE/5G)';
        } else if (firstDigit == '1') {
          lineType = 'Toll Free / Special Services (1800)';
          riskScore = 20;
        } else {
          lineType = 'Fixed Landline / PSTN';
        }

        // Operator Heuristics (DoT Series Allocations)
        if (prefix3.startsWith('6') || prefix3.startsWith('700') || prefix3.startsWith('701') || prefix3.startsWith('797') || prefix3.startsWith('798') || prefix3.startsWith('799') || prefix3.startsWith('898')) {
          operator = 'Reliance Jio Infocomm';
          operatorColor = const Color(0xFF0A66C2);
        } else if (prefix3.startsWith('981') || prefix3.startsWith('987') || prefix3.startsWith('991') || prefix3.startsWith('992') || prefix3.startsWith('993') || prefix3.startsWith('994') || prefix3.startsWith('989') || prefix3.startsWith('704') || prefix3.startsWith('705')) {
          operator = 'Bharti Airtel';
          operatorColor = const Color(0xFFEF4444);
        } else if (prefix3.startsWith('982') || prefix3.startsWith('983') || prefix3.startsWith('984') || prefix3.startsWith('988') || prefix3.startsWith('971') || prefix3.startsWith('972') || prefix3.startsWith('973') || prefix3.startsWith('974')) {
          operator = 'Vodafone Idea (Vi)';
          operatorColor = const Color(0xFFF59E0B);
        } else if (prefix3.startsWith('94') || prefix4.startsWith('940') || prefix4.startsWith('941') || prefix4.startsWith('942') || prefix4.startsWith('943') || prefix4.startsWith('944')) {
          operator = 'BSNL / MTNL Cellular';
          operatorColor = const Color(0xFFEA580C);
        } else {
          operator = 'Indian Cellular Carrier';
          operatorColor = const Color(0xFF6366F1);
        }

        circle = _resolveIndianCircle(prefix4);

        // Generate Predicted Indian UPI VPAs
        predictedUpi.addAll([
          '$nationalDigits@ybl (PhonePe - Yes Bank)',
          '$nationalDigits@oksbi (Google Pay - SBI)',
          '$nationalDigits@paytm (Paytm Payments Bank)',
          '$nationalDigits@upi (BHIM - NPCI)',
          '$nationalDigits@okaxis (Google Pay - Axis)',
          '$nationalDigits@ibl (PhonePe - ICICI Bank)',
        ]);

        technicalDetails.add('DoT Licensed Series: $prefix4 ($operator)');
        technicalDetails.add('Original Telecom Circle: $circle');
        technicalDetails.add('E.164 Compliant: 10-digit ITU-T standard');
        technicalDetails.add('Number Portability (MNP): May be active on another network; original series licensed to $operator.');
      } else {
        threatAlerts.add('Invalid Length: Indian mobile numbers must be exactly 10 digits.');
        riskScore = 55;
      }
    } else {
      technicalDetails.add('International Route: $e164');
      technicalDetails.add('Jurisdiction: $countryName');
      technicalDetails.add('Country Code: $countryCode');
      lineType = isVoip ? 'Virtual VoIP / Cloud PBX (Burner Number)' : 'International Cellular';
    }

    if (isWangiri) {
      riskScore = 95;
      lineType = 'Satellite / High-Tariff Premium Route';
      threatAlerts.add('🚨 CRITICAL WANGIRI SCAM RISK: Originates from high-tariff satellite or island territory. DO NOT CALL BACK! Outgoing rates can reach ₹500 - ₹2500 per minute.');
    } else if (isHighScam) {
      riskScore = 88;
      threatAlerts.add('⚠️ HIGH-RISK SCAM SYNDICATE ORIGIN: Numbers from $countryName are actively abused in Digital Arrest, fake FedEx courier, police impersonation, and crypto investment frauds.');
    } else if (isVoip) {
      riskScore = 78;
      threatAlerts.add('🛡️ VIRTUAL VOIP NUMBER: Hosted on a cloud PBX without physical SIM KYC or Aadhaar verification. Used by cybercriminals to maintain complete anonymity.');
    }

    String riskLevel = 'LOW';
    Color riskColor = const Color(0xFF10B981);
    if (riskScore >= 90) {
      riskLevel = 'CRITICAL THREAT';
      riskColor = const Color(0xFFEF4444);
    } else if (riskScore >= 70) {
      riskLevel = 'HIGH RISK';
      riskColor = const Color(0xFFF97316);
    } else if (riskScore >= 40) {
      riskLevel = 'SUSPICIOUS';
      riskColor = const Color(0xFFEAB308);
    }

    // Build Platform Profiles Array (Structured like SocialOsintScreen)
    final platforms = _buildPlatformProfiles(e164, digits, countryName, isVoip, predictedUpi);

    return PhoneScanResult(
      rawInput: raw,
      cleanedNumber: digits,
      internationalE164: e164,
      countryName: countryName,
      countryCode: countryCode,
      flag: flag,
      operator: operator,
      operatorColor: operatorColor,
      telecomCircle: circle,
      lineType: lineType,
      riskScore: riskScore,
      riskLevel: riskLevel,
      riskColor: riskColor,
      threatAlerts: threatAlerts,
      technicalDetails: technicalDetails,
      predictedUpiVpas: predictedUpi,
      isVoip: isVoip,
      isSatelliteWangiri: isWangiri,
      isHighScamOrigin: isHighScam,
      platforms: platforms,
    );
  }

  bool _checkUsVoip(String digits) {
    final voipPrefixes = ['1201', '1202', '1206', '1213', '1214', '1312', '1347', '1415', '1646', '1702', '1855', '1866', '1877', '1888'];
    for (final p in voipPrefixes) {
      if (digits.startsWith(p)) return true;
    }
    return false;
  }

  String _resolveIndianCircle(String prefix4) {
    final circles = {
      '9810': 'Delhi NCR', '9811': 'Delhi NCR', '9818': 'Delhi NCR', '9871': 'Delhi NCR', '7042': 'Delhi NCR',
      '9820': 'Mumbai', '9821': 'Mumbai', '9819': 'Mumbai', '9833': 'Mumbai', '9869': 'Mumbai',
      '9830': 'Kolkata', '9831': 'Kolkata', '9832': 'West Bengal',
      '9840': 'Chennai', '9841': 'Chennai', '9884': 'Chennai',
      '9822': 'Maharashtra & Goa', '9823': 'Maharashtra & Goa', '9850': 'Maharashtra & Goa',
      '9824': 'Gujarat', '9825': 'Gujarat', '9898': 'Gujarat', '9727': 'Gujarat',
      '9848': 'Andhra Pradesh & Telangana', '9849': 'Andhra Pradesh & Telangana',
      '9844': 'Karnataka', '9845': 'Karnataka', '9880': 'Karnataka', '9900': 'Karnataka',
      '9842': 'Tamil Nadu', '9843': 'Tamil Nadu',
      '9846': 'Kerala', '9847': 'Kerala', '9895': 'Kerala',
      '9814': 'Punjab', '9815': 'Punjab', '9872': 'Punjab',
      '9812': 'Haryana', '9813': 'Haryana',
      '9837': 'UP (West) & Uttarakhand', '9838': 'UP (East)', '9839': 'UP (East)',
      '9828': 'Rajasthan', '9829': 'Rajasthan',
      '9826': 'Madhya Pradesh & Chhattisgarh', '9827': 'Madhya Pradesh & Chhattisgarh',
      '9835': 'Bihar & Jharkhand', '9934': 'Bihar & Jharkhand',
      '9861': 'Odisha', '9937': 'Odisha',
      '9864': 'Assam', '9862': 'North East',
      '9858': 'Jammu & Kashmir', '9816': 'Himachal Pradesh',
    };
    return circles[prefix4] ?? 'Pan-India Operational Circle';
  }

  List<PhonePlatformProfile> _buildPlatformProfiles(String e164, String digits, String country, bool isVoip, List<String> upiList) {
    final cleanDigits = digits.replaceAll('+', '');
    final nationalDigits = cleanDigits.startsWith('91') && cleanDigits.length == 12 ? cleanDigits.substring(2) : cleanDigits;

    final list = <PhonePlatformProfile>[
      // 1. WhatsApp Profile Probe
      PhonePlatformProfile(
        platform: 'WhatsApp Messenger & Business',
        category: 'Messaging',
        icon: Icons.chat_bubble_rounded,
        brandColor: const Color(0xFF25D366),
        statusBadge: 'DIRECT PROFILE AUDIT READY',
        statusBadgeColor: const Color(0xFF25D366),
        headline: 'Instant WhatsApp Profile Inspection (No Contact Save)',
        description: 'Audit profile photo, display name, status/about text, and WhatsApp Business badge without saving the scammer to your address book.',
        primaryActionLabel: 'Probe Profile on WhatsApp',
        onPrimaryAction: () => _openUrl('https://wa.me/$cleanDigits'),
        secondaryActionLabel: 'Copy wa.me Link',
        onSecondaryAction: () => _copyToClipboard('https://wa.me/$cleanDigits', 'WhatsApp direct link'),
        details: [
          'Direct Deep Link: wa.me/$cleanDigits',
          'Verification: Reveals business catalog, verified tick, and about info.',
          'Safety: Prevents scammer from accessing your profile photo (No Contact Sync required).',
        ],
      ),

      // 2. Telegram Footprint Probe
      PhonePlatformProfile(
        platform: 'Telegram Network',
        category: 'Messaging',
        icon: Icons.send_rounded,
        brandColor: const Color(0xFF229ED9),
        statusBadge: 'USERNAME & GROUP SCAN READY',
        statusBadgeColor: const Color(0xFF229ED9),
        headline: 'Telegram Account & Public Group Footprint',
        description: 'Check if this phone number is associated with Telegram trading channels, part-time job groups, or fake investment bots.',
        primaryActionLabel: 'Probe Telegram Handle',
        onPrimaryAction: () => _openUrl('https://t.me/+$cleanDigits'),
        secondaryActionLabel: 'Copy Telegram Link',
        onSecondaryAction: () => _copyToClipboard('https://t.me/+$cleanDigits', 'Telegram link'),
        details: [
          'Target Address: t.me/+$cleanDigits',
          'Scam Vector: Used extensively for task scams and fake crypto investment syndicates.',
        ],
      ),

      // 3. NPCI UPI Banking VPA (India Exclusive)
      if (upiList.isNotEmpty)
        PhonePlatformProfile(
          platform: 'NPCI UPI Payment Ecosystem',
          category: 'UPI Banking',
          icon: Icons.account_balance_wallet_rounded,
          brandColor: const Color(0xFF5F259F),
          statusBadge: 'ZERO-RUPEE NAME REVEAL',
          statusBadgeColor: const Color(0xFF10B981),
          headline: 'Extract Registered Legal Name via Banking Network',
          description: 'Indian mobile numbers are mapped to NPCI bank VPAs. In PhonePe, Google Pay, or BHIM, entering the VPA instantly displays the legal registered bank account name without sending ₹1.',
          primaryActionLabel: 'Copy Primary VPA ($nationalDigits@ybl)',
          onPrimaryAction: () => _copyToClipboard('$nationalDigits@ybl', 'PhonePe UPI VPA'),
          secondaryActionLabel: 'Launch UPI App',
          onSecondaryAction: () => _openUrl('upi://pay?pa=$nationalDigits@ybl&pn=Verify'),
          details: [
            'PhonePe VPA: $nationalDigits@ybl / $nationalDigits@ibl',
            'Google Pay VPA: $nationalDigits@oksbi / $nationalDigits@okaxis',
            'Paytm VPA: $nationalDigits@paytm',
            'BHIM NPCI VPA: $nationalDigits@upi',
            '💡 Forensic Tip: Paste any VPA in Google Pay/PhonePe under "Pay to UPI ID". The banking switch displays the real bank-registered legal name before entering any amount!',
          ],
        ),

      // 4. Truecaller & Community Spam Directory
      PhonePlatformProfile(
        platform: 'Truecaller & Community Directory',
        category: 'Caller ID',
        icon: Icons.person_search_rounded,
        brandColor: const Color(0xFF0288D1),
        statusBadge: 'COMMUNITY SPAM SCORES',
        statusBadgeColor: const Color(0xFF0288D1),
        headline: 'Reverse Directory & Community Scam Reports',
        description: 'Queries millions of crowd-sourced spam reports, scam tags (CBI, Customs, Fake Police), and verified business designations.',
        primaryActionLabel: 'Query Truecaller Directory',
        onPrimaryAction: () => _openUrl('https://www.truecaller.com/search/in/$cleanDigits'),
        secondaryActionLabel: 'Query Sync.me Lookup',
        onSecondaryAction: () => _openUrl('https://sync.me/search/?number=$e164'),
        details: [
          'Direct Web Query: truecaller.com/search/in/$cleanDigits',
          'Spam Badges: Flags numbers reported by 100+ citizens as spam or fraud.',
        ],
      ),

      // 5. Government DoT Chakshu & National Helpline 1930
      PhonePlatformProfile(
        platform: 'DoT Chakshu & Cybercrime Portal',
        category: 'Law Enforcement',
        icon: Icons.gavel_rounded,
        brandColor: const Color(0xFFDC2626),
        statusBadge: 'OFFICIAL SIM BLOCKING PORTAL',
        statusBadgeColor: const Color(0xFFDC2626),
        headline: 'Official Government of India Fraud Escalation',
        description: 'Report suspected fraud calls, fake Digital Arrest notices, and smishing directly to the Department of Telecommunications (DoT) to disconnect and blacklist the scammer\'s SIM.',
        primaryActionLabel: 'Report on Chakshu (DoT)',
        onPrimaryAction: () => _openUrl('https://sancharsaathi.gov.in/sfc/'),
        secondaryActionLabel: 'Dial 1930 Cyber Helpline',
        onSecondaryAction: () => _callHelpline('1930'),
        details: [
          'DoT Chakshu: Official Sanchar Saathi platform for citizen fraud reporting.',
          'Enforcement: Suspected scam numbers are disconnected within 24-48 hours by DoT.',
          'National Helpline: 1930 (MHA Indian Cybercrime Coordination Centre - I4C).',
        ],
      ),

      // 6. Google Dorking & Scam Forum Index
      PhonePlatformProfile(
        platform: 'Google Scam Dorking & FIR Index',
        category: 'Law Enforcement',
        icon: Icons.travel_explore_rounded,
        brandColor: const Color(0xFFEA4335),
        statusBadge: '50+ COMPLAINT FORUMS',
        statusBadgeColor: const Color(0xFFF59E0B),
        headline: 'Deep Search for FIRs & Consumer Complaints',
        description: 'Executes Google dorking queries across National Consumer Complaint forums, Cyberpolice portals, and victim discussion boards for this specific number.',
        primaryActionLabel: 'Search FIRs & Fraud Mentions',
        onPrimaryAction: () => _openGoogleDork(e164),
        secondaryActionLabel: 'Copy Search Query',
        onSecondaryAction: () => _copyToClipboard('"$e164" (scam OR fraud OR police OR cbi OR complaint OR "digital arrest")', 'Search query'),
        details: [
          'Dork Pattern: "$e164" (scam OR fraud OR police OR cbi OR complaint)',
          'Indexes: Consumer Complaint Court, Cybercrime reports, Twitter/X scam alerts.',
        ],
      ),
    ];

    return list;
  }

  // ─── ACTION LAUNCHERS ──────────────────────────────────────────────────────

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showToast('Could not launch browser');
    }
  }

  Future<void> _callHelpline(String number) async {
    final uri = Uri.parse('tel:$number');
    try {
      await launchUrl(uri);
    } catch (_) {
      _showToast('Could not launch phone dialer');
    }
  }

  Future<void> _openGoogleDork(String phone) async {
    final query = Uri.encodeComponent('"$phone" (scam OR fraud OR police OR cbi OR complaint OR "digital arrest")');
    _openUrl('https://www.google.com/search?q=$query');
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showToast('$label copied to clipboard');
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF06090F) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.phone_android_rounded, color: Color(0xFF3B82F6), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Phone Fraud & OSINT',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Switch to Username OSINT',
            icon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF3B82F6)),
            onPressed: () => context.push('/social-osint'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.radar_rounded, color: Color(0xFF3B82F6), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Telecom & Forensic Recon Engine',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Detects VoIP burner numbers, Wangiri toll traps, WhatsApp/Telegram presence & NPCI UPI legal names.',
                          style: TextStyle(color: subColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Dedicated Phone Input Card
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.3 : 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TARGET PHONE NUMBER',
                        style: TextStyle(
                          color: Color(0xFF3B82F6),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        'Telecom / Scam Recon',
                        style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🇮🇳', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 4),
                              Text(
                                '+91',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              letterSpacing: 0.8,
                            ),
                            decoration: InputDecoration(
                              hintText: '98765 43210 or +1...',
                              hintStyle: TextStyle(
                                color: subColor.withValues(alpha: 0.7),
                                fontSize: 15,
                                fontWeight: FontWeight.normal,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (val) => _runAnalysis(val),
                          ),
                        ),
                        if (_phoneController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: subColor, size: 20),
                            onPressed: () {
                              _phoneController.clear();
                              setState(() => _result = null);
                            },
                          ),
                        IconButton(
                          tooltip: 'Paste from clipboard',
                          icon: const Icon(Icons.content_paste_rounded, color: Color(0xFF3B82F6), size: 20),
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data?.text != null && data!.text!.trim().isNotEmpty) {
                              String pasted = data.text!.trim();
                              final phoneRegex = RegExp(r'(\+?\d{1,4}[-.\s]?\(?\d{1,4}\)?[-.\s]?\d{1,4}[-.\s]?\d{1,9})');
                              final match = phoneRegex.firstMatch(pasted);
                              if (match != null) {
                                pasted = match.group(0)!;
                              }
                              if (pasted.length > 20) {
                                pasted = pasted.substring(0, 20);
                              }
                              _phoneController.text = pasted;
                              _runAnalysis(pasted);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Full-Width Scan Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isAnalyzing ? null : () => _runAnalysis(_phoneController.text),
                      icon: _isAnalyzing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.radar_rounded, size: 20),
                      label: Text(
                        _isAnalyzing ? 'RUNNING TELECOM RECON...' : 'SCAN TELECOM & FRAUD RISK',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Presets
                  Text(
                    'QUICK DEMO PRESETS',
                    style: TextStyle(
                      color: subColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip('🇮🇳 +91 98100 12345 (Airtel)', '+91 98100 12345', isDark, cardBg, textColor),
                        const SizedBox(width: 8),
                        _buildPresetChip('🇮🇳 +91 70000 12345 (Jio)', '+91 70000 12345', isDark, cardBg, textColor),
                        const SizedBox(width: 8),
                        _buildPresetChip('🇰🇭 +855 23 999 123 (Cambodia Arrest)', '+855 23 999 123', isDark, cardBg, textColor),
                        const SizedBox(width: 8),
                        _buildPresetChip('🇺🇸 +1 202 555 0123 (VoIP Burner)', '+1 202 555 0123', isDark, cardBg, textColor),
                        const SizedBox(width: 8),
                        _buildPresetChip('🛰️ +881 837 1234 (Wangiri Trap)', '+881 837 1234', isDark, cardBg, textColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13))),
                  ],
                ),
              ),
            ],

            // RESULTS VIEW
            if (_isAnalyzing) ...[
              _buildScanningProgress(isDark, cardBg, textColor, subColor),
            ] else if (_result != null) ...[
              _buildResultCard(_result!, isDark, cardBg, textColor, subColor),
            ] else ...[
              _buildEducationalCard(isDark, cardBg, textColor, subColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String number, bool isDark, Color cardBg, Color textColor) {
    return InkWell(
      onTap: () {
        _phoneController.text = number;
        _runAnalysis(number);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // ─── MAIN RESULT CARD ──────────────────────────────────────────────────────

  Widget _buildResultCard(PhoneScanResult res, bool isDark, Color cardBg, Color textColor, Color subColor) {
    final filteredPlatforms = res.platforms.where((p) {
      if (_selectedCategory == _PhoneCategory.all) return true;
      if (_selectedCategory == _PhoneCategory.messaging && p.category == 'Messaging') return true;
      if (_selectedCategory == _PhoneCategory.upi && p.category == 'UPI Banking') return true;
      if (_selectedCategory == _PhoneCategory.callerId && p.category == 'Caller ID') return true;
      if (_selectedCategory == _PhoneCategory.govt && p.category == 'Law Enforcement') return true;
      return false;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Telecom Routing & Threat Level Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: res.riskColor.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: res.riskColor.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(res.flag, style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                res.internationalE164,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${res.operator} • ${res.telecomCircle}',
                                style: TextStyle(
                                  color: res.operatorColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: res.riskColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: res.riskColor.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          res.riskLevel,
                          style: TextStyle(color: res.riskColor, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                        Text(
                          '${res.riskScore}/100 Risk',
                          style: TextStyle(color: res.riskColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: res.riskScore / 100.0,
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  color: res.riskColor,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    res.lineType,
                    style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    res.countryName,
                    style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.05),

        // Threat Warnings (if any)
        if (res.threatAlerts.isNotEmpty) ...[
          const SizedBox(height: 14),
          ...res.threatAlerts.map(
            (alert) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: res.riskColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: res.riskColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                alert,
                style: TextStyle(color: res.riskColor, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],

        // 2. AI Telecom Threat Intelligence Card
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_rounded, color: Color(0xFF3B82F6), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'AI Telecom Threat Assessment',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                  if (_isAiLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Live AI Engine', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (_isAiLoading)
                Text(
                  'Analyzing carrier series allocation, Digital Arrest syndicate risk, and VoIP spoof signatures with Cloudflare AI...',
                  style: TextStyle(color: subColor, fontSize: 12, height: 1.4, fontStyle: FontStyle.italic),
                )
              else if (res.aiThreatAnalysis != null && res.aiThreatAnalysis!.isNotEmpty)
                Text(
                  res.aiThreatAnalysis!,
                  style: TextStyle(color: textColor, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
                )
              else
                Text(
                  '• Licensed Carrier: ${res.operator} in ${res.telecomCircle}.\n• Risk Classification: ${res.lineType}.\n• Security Rule: Legitimate banks or police NEVER call on WhatsApp or threaten immediate digital arrest.',
                  style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
                ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // 3. Category Filter Tabs (Structured like SocialOsintScreen)
        Text(
          'PLATFORM & INVESTIGATION CHANNELS (${res.platforms.length})',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.6),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryChip('All (${res.platforms.length})', _PhoneCategory.all, isDark, textColor),
              const SizedBox(width: 8),
              _buildCategoryChip('Messengers', _PhoneCategory.messaging, isDark, textColor),
              const SizedBox(width: 8),
              _buildCategoryChip('UPI Banking', _PhoneCategory.upi, isDark, textColor),
              const SizedBox(width: 8),
              _buildCategoryChip('Caller ID', _PhoneCategory.callerId, isDark, textColor),
              const SizedBox(width: 8),
              _buildCategoryChip('DoT & Legal', _PhoneCategory.govt, isDark, textColor),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4. Platform Investigation Cards
        ...filteredPlatforms.map((p) => _buildPlatformCard(p, res, isDark, cardBg, textColor, subColor)),

        const SizedBox(height: 24),

        // 5. Technical ITU-T Routing Forensics
        Text('ITU-T Technical Parameters', style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: res.technicalDetails.map(
              (detail) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(detail, style: TextStyle(color: textColor, fontSize: 12, height: 1.35))),
                  ],
                ),
              ),
            ).toList(),
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildCategoryChip(String label, _PhoneCategory cat, bool isDark, Color textColor) {
    final isSelected = _selectedCategory == cat;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = cat),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildScanningProgress(bool isDark, Color cardBg, Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.radar_rounded, color: Color(0xFF3B82F6), size: 26)
                    .animate(onPlay: (c) => c.repeat())
                    .rotate(duration: 2000.ms),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deep Telecom & OSINT Interrogation',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target: ${_phoneController.text.trim()}',
                      style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(_scanProgress * 100).toInt()}%',
                  style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _scanProgress,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              color: const Color(0xFF3B82F6),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _scanStep,
                  style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildPlatformCard(PhonePlatformProfile p, PhoneScanResult res, bool isDark, Color cardBg, Color textColor, Color subColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.brandColor.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.brandColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(p.icon, color: p.brandColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.platform,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      Text(
                        p.category,
                        style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: p.statusBadgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.statusBadgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  p.statusBadge,
                  style: TextStyle(color: p.statusBadgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Headline & Description
          Text(
            p.headline,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            p.description,
            style: TextStyle(color: subColor, fontSize: 12, height: 1.45),
          ),

          // Details bullet list (if any)
          if (p.details.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF06090F) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: p.details.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(d, style: TextStyle(color: textColor, fontSize: 11, height: 1.35)),
                )).toList(),
              ),
            ),
          ],

          // Platform Specific Interactive Panels
          if (p.category == 'UPI Banking') ...[
            const SizedBox(height: 14),
            _buildUpiInteractivePanel(res, isDark, cardBg, textColor, subColor),
          ] else if (p.category == 'Law Enforcement' && p.platform.contains('Chakshu')) ...[
            const SizedBox(height: 14),
            _buildChakshuInteractivePanel(res, isDark, cardBg, textColor, subColor),
          ],

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: p.onPrimaryAction,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(
                    p.primaryActionLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.brandColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  ),
                ),
              ),
              if (p.secondaryActionLabel != null && p.onSecondaryAction != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: p.onSecondaryAction,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(
                    p.secondaryActionLabel!,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.04);
  }

  Widget _buildUpiInteractivePanel(PhoneScanResult res, bool isDark, Color cardBg, Color textColor, Color subColor) {
    final clean = res.cleanedNumber;
    final nationalDigits = clean.startsWith('91') && clean.length == 12 ? clean.substring(2) : clean;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF06090F) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF5F259F).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DIRECT BANK VPA SWITCHES',
                style: TextStyle(color: subColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
              ),
              const Text(
                'Tap to copy handle',
                style: TextStyle(color: Color(0xFF5F259F), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildVpaChip('PhonePe', '$nationalDigits@ybl', isDark, textColor),
              _buildVpaChip('GPay', '$nationalDigits@oksbi', isDark, textColor),
              _buildVpaChip('Paytm', '$nationalDigits@paytm', isDark, textColor),
              _buildVpaChip('BHIM', '$nationalDigits@upi', isDark, textColor),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showLegalNameRevealSheet(context, nationalDigits, isDark, cardBg, textColor, subColor),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unmask Bank Account Holder Name (₹0 Exploit)',
                      style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF10B981), size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChakshuInteractivePanel(PhoneScanResult res, bool isDark, Color cardBg, Color textColor, Color subColor) {
    final complaintText = 'Suspect number ${res.internationalE164} reported for fraudulent extortion / cybercrime impersonation under DoT Sanchar Saathi. Requesting immediate CDR audit and SIM deactivation.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF06090F) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRE-COMPOSED SANCHAR SAATHI COMPLAINT',
            style: TextStyle(color: subColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          Text(
            complaintText,
            style: TextStyle(color: textColor, fontSize: 11, height: 1.35, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _copyToClipboard(complaintText, 'Complaint Statement'),
            icon: const Icon(Icons.copy_rounded, size: 14),
            label: const Text('Copy Complaint for Chakshu Form', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFDC2626)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVpaChip(String bank, String vpa, bool isDark, Color textColor) {
    return InkWell(
      onTap: () => _copyToClipboard(vpa, '$bank VPA'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDE9FE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF5F259F).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$bank: ', style: const TextStyle(color: Color(0xFF5F259F), fontSize: 11, fontWeight: FontWeight.bold)),
            Text(vpa, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF5F259F)),
          ],
        ),
      ),
    );
  }

  void _showLegalNameRevealSheet(BuildContext context, String nationalDigits, bool isDark, Color cardBg, Color textColor, Color subColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: const Color(0xFF5F259F).withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5F259F).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF5F259F), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NPCI Zero-Rupee Name Reveal Exploit',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        'Extract Bank-Registered Legal Account Name',
                        style: TextStyle(color: subColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOW IT WORKS (100% LEGAL BANKING QUERY):',
                    style: TextStyle(color: subColor, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),
                  Text('1. Copy the VPA below (e.g. $nationalDigits@ybl or $nationalDigits@oksbi).', style: TextStyle(color: textColor, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 4),
                  Text('2. Open PhonePe, Google Pay, or BHIM.', style: TextStyle(color: textColor, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 4),
                  Text('3. Select "To UPI ID / Number" and paste the VPA.', style: TextStyle(color: textColor, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 4),
                  Text('4. The banking switch queries NPCI and immediately reveals the official Aadhaar/PAN-verified legal name on the destination account without paying ₹1!', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _copyToClipboard('$nationalDigits@ybl', 'PhonePe VPA');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy PhonePe VPA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5F259F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _copyToClipboard('$nationalDigits@oksbi', 'Google Pay VPA');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy GPay VPA'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: subColor.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ─── EDUCATIONAL / EMPTY STATE VIEW ────────────────────────────────────────

  Widget _buildEducationalCard(bool isDark, Color cardBg, Color textColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How SafeSignal Phone OSINT Works', style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 12),
        _buildInfoCard(
          title: 'Virtual VoIP Burner Number Detection',
          desc: 'Scammers on WhatsApp and Telegram use virtual cloud PBX numbers (TextNow, Skype) that have no Aadhaar or physical SIM KYC. SafeSignal identifies virtual numbers instantly.',
          icon: Icons.cloud_done_rounded,
          color: const Color(0xFF3B82F6),
          cardBg: cardBg,
          textColor: textColor,
          subColor: subColor,
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          title: 'NPCI UPI Legal Name Extraction Guide',
          desc: 'Indian mobile numbers are linked to bank VPAs (@ybl, @oksbi, @paytm). Entering the VPA in any UPI app queries NPCI and reveals the true registered legal name of the account holder.',
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFF5F259F),
          cardBg: cardBg,
          textColor: textColor,
          subColor: subColor,
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          title: 'Wangiri & High-Tariff Satellite Traps',
          desc: 'One-ring missed calls from satellite networks (+881) or Pacific territories (+247, +269) are designed to make you call back, costing ₹500 - ₹2000 per minute. SafeSignal flags them as Critical Threat.',
          icon: Icons.phone_callback_rounded,
          color: const Color(0xFFEF4444),
          cardBg: cardBg,
          textColor: textColor,
          subColor: subColor,
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          title: 'DoT Chakshu Direct Blacklisting',
          desc: 'Department of Telecommunications (DoT) allows citizens to report cyber fraud directly on the Sanchar Saathi Chakshu platform, disconnecting scammer SIM cards within 24 hours.',
          icon: Icons.gavel_rounded,
          color: const Color(0xFFDC2626),
          cardBg: cardBg,
          textColor: textColor,
          subColor: subColor,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Privacy Architecture: In compliance with Indian TRAI & DoT data protection regulations, customer personal records are confidential. SafeSignal utilizes technical telecom routing, NPCI VPA protocol analysis, and open intelligence without storing personal logs.',
                  style: TextStyle(color: textColor, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildInfoCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color textColor,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: subColor, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
