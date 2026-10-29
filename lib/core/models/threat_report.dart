import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Crowd-sourced threat report. Raw values are NEVER stored — only SHA-256 hash.
class ThreatReport {
  final String id;
  final String type; // 'sms', 'url', 'upi', 'call'
  final String valueHash; // SHA-256 of the raw value
  final String verdict; // 'SCAM', 'SUSPICIOUS', 'SAFE'
  final int reporterCount;
  final double confidence;
  final String status; // 'pending', 'verified', 'rejected'
  final DateTime createdAt;

  const ThreatReport({
    required this.id,
    required this.type,
    required this.valueHash,
    required this.verdict,
    required this.reporterCount,
    required this.confidence,
    required this.status,
    required this.createdAt,
  });

  factory ThreatReport.fromJson(Map<String, dynamic> json) {
    return ThreatReport(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown',
      valueHash: json['value_hash'] as String? ?? '',
      verdict: json['verdict'] as String? ?? 'SUSPICIOUS',
      reporterCount: json['reporter_count'] as int? ?? 1,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      status: json['status'] as String? ?? 'pending',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'value_hash': valueHash,
    'verdict': verdict,
    'reporter_count': reporterCount,
    'confidence': confidence,
    'status': status,
  };

  /// Hash any raw value (phone, URL, UPI VPA) before sending to server
  static String hashValue(String rawValue) {
    final bytes = utf8.encode(rawValue.trim().toLowerCase());
    return sha256.convert(bytes).toString();
  }
}
