import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'local_rule_engine.dart';
import 'dart:async';

/// Clipboard Guard - Automatically detects risky content copied to clipboard
/// UPI IDs, suspicious URLs, OTPs that shouldn't be shared
class ClipboardGuardService {
  static final ClipboardGuardService _instance = ClipboardGuardService._internal();
  factory ClipboardGuardService() => _instance;
  ClipboardGuardService._internal();

  Timer? _timer;
  String _lastClipboard = '';
  final _ruleEngine = LocalRuleEngine();
  
  // Callback when risky content detected
  Function(ClipboardRiskResult)? onRiskDetected;

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  /// Start monitoring clipboard every 2 seconds (battery friendly)
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _checkClipboard());
    debugPrint('[ClipboardGuard] Started monitoring');
  }

  void stopMonitoring() {
    _timer?.cancel();
    _isMonitoring = false;
    debugPrint('[ClipboardGuard] Stopped monitoring');
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      
      if (text.isEmpty || text == _lastClipboard) return;
      if (text.length < 6 || text.length > 500) return; // Too short/long
      
      _lastClipboard = text;
      
      // Check if it's risky
      final risk = _analyzeClipboard(text);
      if (risk.isRisky) {
        debugPrint('[ClipboardGuard] Risky content detected: ${risk.type} - $text');
        onRiskDetected?.call(risk);
      }
    } catch (e) {
      debugPrint('[ClipboardGuard] Error: $e');
    }
  }

  ClipboardRiskResult _analyzeClipboard(String text) {
    final lower = text.toLowerCase();
    
    // UPI ID detection
    final upiPattern = RegExp(r'[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}');
    if (upiPattern.hasMatch(text)) {
      // Check if it's a suspicious UPI (random numbers, etc)
      if (text.contains(RegExp(r'[0-9]{8,}@')) || lower.contains('sbi') && !lower.endsWith('@sbi') && !lower.endsWith('@ybl')) {
        return ClipboardRiskResult(
          isRisky: true,
          type: ClipboardRiskType.suspiciousUpi,
          content: text,
          message: 'Ye UPI ID suspicious lag rahi hai! Verify karo pehle.',
          riskScore: 75,
        );
      }
      return ClipboardRiskResult(
        isRisky: false,
        type: ClipboardRiskType.upi,
        content: text,
        message: 'UPI ID detected - Verify receiver name before paying',
        riskScore: 10,
      );
    }

    // URL detection
    if (lower.contains('http') || lower.contains('www.') || lower.contains('.com') || lower.contains('.in')) {
      final verdict = _ruleEngine.analyze(text);
      if (verdict.riskScore >= 30) {
        return ClipboardRiskResult(
          isRisky: true,
          type: ClipboardRiskType.suspiciousUrl,
          content: text,
          message: verdict.summary,
          riskScore: verdict.riskScore,
        );
      }
    }

    // OTP detection - user copied OTP, warn not to share
    final otpPattern = RegExp(r'\b\d{4,8}\b');
    if (otpPattern.hasMatch(text) && (lower.contains('otp') || text.length <= 8)) {
      return ClipboardRiskResult(
        isRisky: true,
        type: ClipboardRiskType.otp,
        content: text,
        message: 'OTP copy kiya hai! Kisi ke saath share mat karo, chahe bank ka naam leke mange.',
        riskScore: 90,
      );
    }

    // Bank account / IFSC
    if (lower.contains('ifsc') || RegExp(r'\b\d{9,18}\b').hasMatch(text) && lower.contains('account')) {
      return ClipboardRiskResult(
        isRisky: true,
        type: ClipboardRiskType.bankDetails,
        content: text,
        message: 'Bank details clipboard me hain - secure jagah pe paste karo',
        riskScore: 40,
      );
    }

    return ClipboardRiskResult(
      isRisky: false,
      type: ClipboardRiskType.safe,
      content: text,
      message: 'Safe',
      riskScore: 0,
    );
  }

  Future<ClipboardRiskResult> analyzeNow(String text) async {
    return _analyzeClipboard(text);
  }
}

enum ClipboardRiskType { safe, upi, suspiciousUpi, suspiciousUrl, otp, bankDetails }

class ClipboardRiskResult {
  final bool isRisky;
  final ClipboardRiskType type;
  final String content;
  final String message;
  final int riskScore;

  ClipboardRiskResult({
    required this.isRisky,
    required this.type,
    required this.content,
    required this.message,
    required this.riskScore,
  });
}
