// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: Pre-PIN UPI Intent & Fraud Shield Engine
// Standard: NPCI UPI Intent Specification & TRAI Anti-Phishing Framework
// License: SafeSignal Source-Available (Zero Cloud Egress, 100% On-Device)
// -----------------------------------------------------------------------------

enum UpiRiskSeverity { safe, caution, dangerous, critical }

class UpiRiskAnalysis {
  final bool isFraud;
  final UpiRiskSeverity severity;
  final String payeeAddress;
  final String payeeName;
  final String? amount;
  final String? transactionNote;
  final String? merchantCode;
  final bool isRecurringMandate;
  final List<String> warnings;
  final String forensicDetail;
  final String actionGuidance;

  const UpiRiskAnalysis({
    required this.isFraud,
    required this.severity,
    required this.payeeAddress,
    required this.payeeName,
    this.amount,
    this.transactionNote,
    this.merchantCode,
    this.isRecurringMandate = false,
    this.warnings = const [],
    this.forensicDetail = '',
    this.actionGuidance = '',
  });

  static const clean = UpiRiskAnalysis(
    isFraud: false,
    severity: UpiRiskSeverity.safe,
    payeeAddress: '',
    payeeName: '',
    warnings: [],
    forensicDetail: 'Verified standard UPI Intent with no anomalous fraud indicators.',
    actionGuidance: 'Confirm payee name and amount in your UPI app before entering UPI PIN.',
  );
}

class UpiIntentGuardService {
  // ─── Known Impersonation / Social Engineering VPA Keywords ─────────────────
  static const Set<String> _impersonationVpaKeywords = {
    'customercare',
    'customerhelp',
    'helpdesk',
    'support',
    'refund',
    'cashback',
    'kycverify',
    'kycupdate',
    'banksupport',
    'helpline',
    'paytmcare',
    'phonepecare',
    'gpaycare',
    'sbicare',
    'hdfccare',
    'icicicare',
    'axiscare',
    'olxrefund',
    'olxpay',
    'armyhelp',
    'armypost',
  };

  /// Evaluates a raw UPI URI string (upi://pay?... or upi://mandate?...)
  static UpiRiskAnalysis analyze(String rawUri) {
    if (!rawUri.trim().toLowerCase().startsWith('upi://')) {
      return const UpiRiskAnalysis(
        isFraud: false,
        severity: UpiRiskSeverity.caution,
        payeeAddress: '',
        payeeName: '',
        warnings: ['Payload is not a standard UPI URI scheme.'],
        forensicDetail: 'Non-UPI string passed to UPI Intent Guard.',
        actionGuidance: 'Do not open in banking applications.',
      );
    }

    final uri = Uri.tryParse(rawUri);
    if (uri == null) {
      return const UpiRiskAnalysis(
        isFraud: true,
        severity: UpiRiskSeverity.dangerous,
        payeeAddress: '',
        payeeName: '',
        warnings: ['Malformed UPI Intent URI structure.'],
        forensicDetail: 'URI failed standard RFC parsing.',
        actionGuidance: 'Abort transaction immediately.',
      );
    }

    final isMandate = uri.host.toLowerCase() == 'mandate' || rawUri.toLowerCase().contains('mandate');
    final params = uri.queryParameters;

    final pa = params['pa']?.trim() ?? ''; // Payee Address (VPA)
    final pn = params['pn']?.trim() ?? ''; // Payee Name
    final am = params['am']?.trim(); // Amount
    final tn = params['tn']?.trim(); // Transaction Note
    final mc = params['mc']?.trim(); // Merchant Code

    final warnings = <String>[];
    int score = 0; // Higher = more dangerous

    // 1. RECURRING MANDATE / AUTO-DEBIT TRAP
    if (isMandate) {
      score += 80;
      warnings.add(
        '🚨 RECURRING MANDATE / AUTO-DEBIT: This intent authorizes ongoing automatic withdrawals from your bank account!',
      );
    }

    final lowerPa = pa.toLowerCase();
    final lowerPn = pn.toLowerCase();
    final lowerTn = (tn ?? '').toLowerCase();
    final compactPa = lowerPa.replaceAll(RegExp(r'[\s\.\-_+]'), '');
    final compactPn = lowerPn.replaceAll(RegExp(r'[\s\.\-_+]'), '');

    // 2. SOCIAL ENGINEERING VPA IMPERSONATION
    for (final kw in _impersonationVpaKeywords) {
      if (lowerPa.contains(kw) || lowerPn.contains(kw) || compactPa.contains(kw) || compactPn.contains(kw)) {
        score += 70;
        warnings.add(
          '🚨 IMPERSONATED CUSTOMER CARE / REFUND VPA: "$pa" uses deceptive authority keyword "$kw". Legitimate customer care teams NEVER request incoming UPI payments!',
        );
        break;
      }
    }

    // 3. REVERSE PAYMENT FRAUD (Cashback / Refund Lure with DEBIT Amount)
    final hasLureKeyword = lowerTn.contains('refund') ||
        lowerTn.contains('cashback') ||
        lowerTn.contains('won') ||
        lowerTn.contains('prize') ||
        lowerTn.contains('claim') ||
        lowerTn.contains('receive') ||
        lowerPn.contains('refund') ||
        lowerPn.contains('cashback');

    if (hasLureKeyword && am != null && (double.tryParse(am) ?? 0) > 0) {
      score += 90;
      warnings.insert(
        0,
        '🚨 REVERSE PAYMENT FRAUD DETECTED: Note/Name promises "$tn", but this intent executes a DEBIT of ₹$am from YOUR account! In UPI, you NEVER enter your PIN to receive money.',
      );
    }

    // 4. SUSPICIOUS P2P DISGUISED AS MERCHANT
    if (mc != null && mc.isNotEmpty && mc != '0000') {
      // Claims merchant MCC, but uses standard consumer VPA handle
      final isPersonalHandle = lowerPa.endsWith('@oksbi') ||
          lowerPa.endsWith('@okaxis') ||
          lowerPa.endsWith('@okhdfcbank') ||
          lowerPa.endsWith('@okicici') ||
          lowerPa.endsWith('@ybl');

      if (isPersonalHandle && !lowerPa.contains('merchant')) {
        score += 30;
        warnings.add(
          'Mismatched Merchant Descriptor: Claiming commercial MCC ($mc) on personal consumer handle ($pa).',
        );
      }
    }

    // Determine final severity
    final UpiRiskSeverity severity;
    final bool isFraud;
    if (score >= 70) {
      severity = UpiRiskSeverity.critical;
      isFraud = true;
    } else if (score >= 40) {
      severity = UpiRiskSeverity.dangerous;
      isFraud = true;
    } else if (score >= 20 || warnings.isNotEmpty) {
      severity = UpiRiskSeverity.caution;
      isFraud = false;
    } else {
      severity = UpiRiskSeverity.safe;
      isFraud = false;
    }

    final forensicDetail = warnings.isNotEmpty
        ? warnings.join(' ')
        : 'UPI Intent directed to $pn ($pa)${am != null ? " for ₹$am" : ""}. Standard peer-to-peer or verified merchant format.';

    final actionGuidance = isFraud
        ? 'DO NOT PROCEED: Cancel immediately. Do NOT enter your UPI PIN. Entering your UPI PIN always authorizes money LEAVING your account.'
        : 'Verify payee "$pn" matches the intended recipient before authorizing in your banking app.';

    return UpiRiskAnalysis(
      isFraud: isFraud,
      severity: severity,
      payeeAddress: pa,
      payeeName: pn,
      amount: am,
      transactionNote: tn,
      merchantCode: mc,
      isRecurringMandate: isMandate,
      warnings: warnings,
      forensicDetail: forensicDetail,
      actionGuidance: actionGuidance,
    );
  }
}
