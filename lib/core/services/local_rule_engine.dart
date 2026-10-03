// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: Tier-1 Local Threat Heuristics Engine
// Spec: SafeSignal Rule Matrix IN-TRAI-2026
// Author: Umar Farooque (https://github.com/UmarFarooqueJi)
// Copyright (c) 2026 SafeSignal Technologies. All rights reserved.
// Proprietary pattern matching: Indian telecom fraud, digital arrest scripts,
// banking impersonation, UPI payment scams, APK dropper detection.
// -----------------------------------------------------------------------------
import '../models/ai_verdict.dart';

/// Pure Dart offline rule engine — no network, always works.
/// Runs as Tier 1 before any cloud LLM call.
class LocalRuleEngine {
  // ─── Scam keyword banks ────────────────────────────────────────────────────
  static const _urgencyKeywords = [
    'kyc block',
    'kyc update',
    'kyc expired',
    'kyc verify',
    'kyc pending',
    'account suspend',
    'account blocked',
    'account closed',
    'account deactivated',
    'aadhaar link',
    'pan link',
    'pan update',
    'aadhaar verify',
    'otp share',
    'otp bata',
    'otp send',
    'otp forward',
    'share pin',
    'arrest',
    'police',
    'cbi',
    'cybercrime',
    'digital arrest',
    'court order',
    'lottery',
    'won prize',
    'congratulation',
    'lucky winner',
    'kbc winner',
    'free recharge',
    'free gift',
    'click here',
    'claim now',
    'claim reward',
    'urgent',
    'immediately',
    'last chance',
    'expire today',
    'action required',
    'emi pending',
    'loan approve',
    'job offer',
    'work from home',
    '100% return',
    'double your',
    'invest now',
    'guaranteed profit',
    'anydesk',
    'teamviewer',
    'screen share',
    'remote access',
    'rustdesk',
    'quicksupport',
  ];

  static const _safeKeywords = [
    'otp is',
    'your otp',
    'transaction otp',
    'login otp',
    'one time password',
    'hdfc bank',
    'sbi bank',
    'icici bank',
    'axis bank',
    'kotak bank',
    'neft',
    'imps',
    'upi payment',
    'paytm',
    'phonepe',
    'gpay',
  ];

  static const _suspiciousDomainPatterns = [
    'bit.ly',
    'tinyurl',
    'goo.gl',
    't.co',
    'ow.ly',
    'shorturl',
    'is.gd',
    'cutt.ly',
    '-secure',
    '-verify',
    '-update',
    '-login',
    '-bank',
    '-kyc',
    '-support',
    'sbi-',
    'hdfc-',
    'icici-',
    'paytm-',
    'phonepe-',
    'axis-',
  ];

  // International number pattern
  static final _intlSenderPattern = RegExp(r'^\+[^9][0-9]');
  // Standard Indian 10-digit mobile number pattern
  static final _indianMobilePattern = RegExp(r'^(\+91|91)?[6-9]\d{9}$');
  // TRAI DLT 6-character header pattern (e.g. VM-HDFCBK, AD-SBIINB, BZ-PAYTM)
  static final _traiHeaderPattern = RegExp(r'^[A-Za-z]{2}-?[A-Za-z0-9]{6}$');

  // ─── Main analyze function ─────────────────────────────────────────────────
  AiVerdict analyze(String text, {String? sender, String? type}) {
    final lower = text.toLowerCase();
    final reasons = <String>[];
    var riskScore = 0;

    // 1. Urgency / scare keywords
    final foundUrgency = _urgencyKeywords
        .where((kw) => lower.contains(kw))
        .toList();
    if (foundUrgency.isNotEmpty) {
      riskScore += foundUrgency.length * 12;
      reasons.add(
        'Urgent/threatening language detected: "${foundUrgency.first}"',
      );
    }

    // 2. Shortened / suspicious URLs
    final foundDomains = _suspiciousDomainPatterns
        .where((p) => lower.contains(p))
        .toList();
    if (foundDomains.isNotEmpty) {
      riskScore += 25;
      reasons.add(
        'Suspicious URL shortener or deceptive link: "${foundDomains.first}" — common phishing trap',
      );
    }

    // 3. Malicious APK Dropper Detection
    final isApkLink = RegExp(
      r'(\.apk(\?|$|\s)|mediafire\.com|drive\.google\.com\/file|download.*app|install.*apk)',
    ).hasMatch(lower);
    if (isApkLink) {
      riskScore += 50;
      reasons.insert(
        0,
        '🚨 CRITICAL MALWARE DROPPER: Contains APK download link designed to install trojan spyware on your device!',
      );
    }

    // 4. URL present at all
    final hasUrl = RegExp(
      r'https?://|www\.|\.(com|in|net|org|xyz|top|live|online)',
    ).hasMatch(lower);
    if (hasUrl && foundDomains.isEmpty && !isApkLink) {
      riskScore += 8;
      reasons.add('Contains a web link — verify before clicking');
    }

    // 5. OTP request pattern (distinguishing legitimate OTP delivery vs theft)
    final otpRequest = RegExp(
      r'(share|bata|send|de do|forward|enter|tell).{0,25}(otp|code|pin|password)',
    ).hasMatch(lower);
    if (otpRequest) {
      riskScore += 40;
      reasons.insert(
        0,
        '🚨 OTP THEFT PATTERN: Asking you to SHARE your OTP/PIN. Real banks never ask for OTPs over message or call!',
      );
    }

    // 6. Electricity / Utility bill cutoff scam
    final isElectricityScam = RegExp(
      r'(electricity|bijli|power\s+bill).*(disconnect|tonight|light\s+cut|suspend|update\s+bill)',
    ).hasMatch(lower);
    if (isElectricityScam) {
      riskScore += 45;
      reasons.insert(
        0,
        '⚠️ ELECTRICITY BILL FRAUD: Threatens power disconnection to panic you into calling a fraudster number.',
      );
    }

    // 7. Part-time Job / Telegram Task scam
    final isJobScam = RegExp(
      r'(part-?time job|youtube like|telegram task|daily earn|wfh earn|rating task|per day 3000|per day 5000)',
    ).hasMatch(lower);
    if (isJobScam) {
      riskScore += 35;
      reasons.add(
        'Task/Investment Fraud: Offers unrealistically high income for simple online tasks or Telegram groups.',
      );
    }

    // 8. Money/prize promises
    final moneyPromise = RegExp(
      r'(₹|rs\.?|inr|lakh|crore|prize|lottery|won|reward|kbc)',
    ).hasMatch(lower);
    if (moneyPromise && !isJobScam) {
      riskScore += 15;
      reasons.add(
        'Mentions lottery/cash prize — classic phishing bait to induce financial greed',
      );
    }

    // 9. Call forwarding attack (*21*, *401*, ##002#)
    if (lower.contains('*21*') ||
        lower.contains('*401*') ||
        lower.contains('**21') ||
        lower.contains('divert') ||
        lower.contains('##002#')) {
      riskScore += 55;
      reasons.insert(
        0,
        '🚨 CALL FORWARDING HIJACK (*21* / *401*): Dialing this code will silently divert your calls & OTPs to a scammer!',
      );
    }

    // 10. Remote access tools (AnyDesk, TeamViewer, RustDesk)
    if (lower.contains('anydesk') ||
        lower.contains('teamviewer') ||
        lower.contains('quick support') ||
        lower.contains('rustdesk')) {
      riskScore += 50;
      reasons.insert(
        0,
        '🚨 REMOTE ACCESS ATTACK: Mentions screen-sharing app (AnyDesk/TeamViewer). Scammer wants full control of your phone!',
      );
    }

    // 11. TRAI DLT Sender ID vs Bank Impersonation check
    if (sender != null && sender.trim().isNotEmpty && sender != 'Manual Scan') {
      final s = sender.trim();
      final claimsBank = RegExp(
        r'(sbi|hdfc|icici|axis|kotak|pnb|bob|bank|paytm|phonepe)',
      ).hasMatch(lower);

      if (_intlSenderPattern.hasMatch(s)) {
        riskScore += 30;
        reasons.add(
          'Sent from an international number ($s) — Indian financial institutions only use official TRAI DLT 6-character sender IDs.',
        );
      } else if (_indianMobilePattern.hasMatch(s) && claimsBank) {
        riskScore += 45;
        reasons.insert(
          0,
          '🚨 SENDER SPOOFING: Bank alert sent from a personal mobile number ($s). Genuine banks never send transactional or security alerts from 10-digit mobile numbers.',
        );
      } else if (_traiHeaderPattern.hasMatch(s)) {
        // Genuine TRAI DLT format
        if (riskScore < 20) {
          riskScore = (riskScore * 0.5).round();
        }
      }
    }

    // 12. Safe signal — legitimate OTP delivery
    final foundSafe = _safeKeywords.where((kw) => lower.contains(kw)).toList();
    if (foundSafe.isNotEmpty && riskScore < 25 && !otpRequest && !isApkLink) {
      riskScore = (riskScore * 0.2).round();
      reasons.add(
        'Pattern matches standard legitimate OTP/transaction notification',
      );
    }

    // Cap score at 100
    riskScore = riskScore.clamp(0, 100);

    // Determine verdict
    String verdict;
    if (riskScore >= 55) {
      verdict = 'SCAM';
    } else if (riskScore >= 25) {
      verdict = 'SUSPICIOUS';
    } else {
      verdict = 'SAFE';
    }

    if (reasons.isEmpty) {
      reasons.add(
        verdict == 'SAFE'
            ? 'No suspicious patterns detected'
            : 'Low-confidence suspicious signal detected',
      );
    }

    final whatToDo = _buildWhatToDo(verdict, riskScore);

    return AiVerdict(
      verdict: verdict,
      riskScore: riskScore,
      reasons: reasons,
      whatToDo: whatToDo,
      summary: _buildSummary(verdict, riskScore),
      confidence: riskScore > 55 ? 0.90 : (riskScore > 25 ? 0.70 : 0.85),
      provider: 'local_rule_engine',
      isOffline: true,
    );
  }

  List<String> _buildWhatToDo(String verdict, int score) {
    if (verdict == 'SCAM') {
      return [
        'Do NOT click any links, install APKs, or share any OTP',
        'Block and report this sender number immediately',
        'Call National Cyber Helpline 1930 if you shared OTP or money',
        'Forward this message to 7726 (DoT Spam Reporting)',
      ];
    } else if (verdict == 'SUSPICIOUS') {
      return [
        'Be cautious — verify sender identity through official bank apps/websites',
        'Never share OTP, password, UPI PIN, or Aadhaar number',
        'Contact the official helpline of your bank to confirm the alert',
      ];
    }
    return [
      'This message looks legitimate, but never share OTPs with anyone on call.',
    ];
  }

  String _buildSummary(String verdict, int score) {
    if (verdict == 'SCAM') {
      return 'High risk — this message scored $score/100 with multiple high-confidence scam markers. Do NOT respond, click links, or share OTPs.';
    } else if (verdict == 'SUSPICIOUS') {
      return 'Caution advised — scored $score/100. This message contains patterns frequently observed in social engineering fraud.';
    }
    return 'Clean — scored $score/100. No typical fraud or phishing patterns identified.';
  }
}
