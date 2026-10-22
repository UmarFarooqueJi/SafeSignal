/*
 * SafeSignal Mobile Security Suite & Research Platform
 * Module: Typed Tool Registry & Safety Governor
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
 * Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
 *
 * Implements policy-constrained typed tools for agentic investigations.
 * Read-only analytical tools execute deterministically; state-modifying actions
 * are strictly gated behind human-in-the-loop confirmation.
 */

import '../services/url_intelligence_engine.dart';
import '../services/local_rule_engine.dart';

/// Result of an agent tool execution
class ToolResult {
  final bool success;
  final Map<String, dynamic> data;
  final String? error;

  const ToolResult.success(this.data)
      : success = true,
        error = null;

  const ToolResult.failure(this.error)
      : success = false,
        data = const {};

  Map<String, dynamic> toJson() => {
        'success': success,
        'data': data,
        if (error != null) 'error': error,
      };
}

/// Abstract contract for an agentic tool
abstract class AgentTool {
  String get name;
  String get description;
  Map<String, dynamic> get parameterSchema;
  bool get requiresConfirmation;

  Future<ToolResult> execute(Map<String, dynamic> args);
}

/// Tool 1: Deep Phishing & Malicious URL Scanner
class ScanUrlTool extends AgentTool {
  @override
  String get name => 'scan_url';

  @override
  String get description => 'Perform deep on-device forensic analysis on a suspicious URL or domain.';

  @override
  Map<String, dynamic> get parameterSchema => {
        'type': 'object',
        'properties': {
          'url': {'type': 'string', 'description': 'The URL or hostname to inspect'}
        },
        'required': ['url']
      };

  @override
  bool get requiresConfirmation => false; // Read-only

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final url = args['url']?.toString();
    if (url == null || url.trim().isEmpty) {
      return const ToolResult.failure('URL parameter cannot be empty');
    }

    try {
      final analysis = await UrlIntelligenceEngine.analyze(url);
      return ToolResult.success({
        'url': analysis.url,
        'domain': analysis.domain,
        'verdict': analysis.verdict.name,
        'threat_score': analysis.riskScore,
        'warnings': analysis.warnings,
        'is_verified_safe': analysis.isVerifiedSafe,
        'typosquatting_warning': analysis.typosquattingWarning,
      });
    } catch (e) {
      return ToolResult.failure('URL scan failed: $e');
    }
  }
}

/// Tool 2: SMS Smishing & Fraud Text Heuristic Analyzer
class AnalyzeSmsTool extends AgentTool {
  @override
  String get name => 'analyze_sms';

  @override
  String get description =>
      'Analyze SMS text for digital arrest, KYC fraud, OTP theft, and TRAI sender spoofing.';

  @override
  Map<String, dynamic> get parameterSchema => {
        'type': 'object',
        'properties': {
          'text': {'type': 'string', 'description': 'Message body content'},
          'sender': {'type': 'string', 'description': 'Originating phone number or sender ID'}
        },
        'required': ['text']
      };

  @override
  bool get requiresConfirmation => false; // Read-only

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final text = args['text']?.toString() ?? '';
    final sender = args['sender']?.toString();

    if (text.trim().isEmpty) {
      return const ToolResult.failure('Text body cannot be empty');
    }

    try {
      final engine = LocalRuleEngine();
      final verdict = engine.analyze(text, sender: sender);
      return ToolResult.success({
        'verdict': verdict.verdict,
        'risk_score': verdict.riskScore,
        'reasons': verdict.reasons,
        'summary': verdict.summary,
        'what_to_do': verdict.whatToDo,
      });
    } catch (e) {
      return ToolResult.failure('SMS analysis failed: $e');
    }
  }
}

/// Tool 3: UPI VPA & QR Fraud Analyzer
class VerifyUpiTool extends AgentTool {
  @override
  String get name => 'verify_upi';

  @override
  String get description => 'Audit a UPI ID (VPA) or payment handle against known cyber fraud patterns.';

  @override
  Map<String, dynamic> get parameterSchema => {
        'type': 'object',
        'properties': {
          'vpa': {'type': 'string', 'description': 'The UPI Virtual Payment Address (e.g. name@oksbi)'}
        },
        'required': ['vpa']
      };

  @override
  bool get requiresConfirmation => false; // Read-only

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final vpa = args['vpa']?.toString().trim().toLowerCase() ?? '';
    if (vpa.isEmpty || !vpa.contains('@')) {
      return const ToolResult.failure('Invalid UPI VPA format. Must contain "@" separator.');
    }

    final suspiciousPrefixes = ['refund', 'cashback', 'reward', 'kbc', 'winner', 'support', 'lottery'];
    final isImpersonator = suspiciousPrefixes.any((p) => vpa.startsWith(p));

    return ToolResult.success({
      'vpa': vpa,
      'is_suspicious': isImpersonator,
      'fraud_pattern': isImpersonator ? 'Deceptive reward/refund keyword impersonation' : 'Standard VPA structure',
      'warning': isImpersonator
          ? 'CRITICAL: Scammers use VPAs containing words like "refund" or "reward" to trick victims into paying.'
          : 'Normal payment address format. Remember: Entering UPI PIN always debits funds.',
    });
  }
}

/// Tool 4: Android App Package Permission & Sideloading Auditor
class InspectAppPermissionsTool extends AgentTool {
  @override
  String get name => 'inspect_app_permissions';

  @override
  String get description =>
      'Audit Android application permissions for accessibility abuse, screen overlay, SMS interception, and banking trojan risks.';

  @override
  Map<String, dynamic> get parameterSchema => {
        'type': 'object',
        'properties': {
          'package_name': {'type': 'string', 'description': 'Android package name'},
          'permissions': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of requested Android permissions'
          }
        },
        'required': ['permissions']
      };

  @override
  bool get requiresConfirmation => false; // Read-only

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final permissions = (args['permissions'] as List?)?.map((p) => p.toString()).toList() ?? [];
    final packageName = args['package_name']?.toString() ?? 'unknown.package';

    final dangerousFlags = <String>[];
    int threatScore = 0;

    for (final perm in permissions) {
      if (perm.contains('BIND_ACCESSIBILITY_SERVICE')) {
        dangerousFlags.add('Accessibility Service Abuse: Can steal keystrokes and bypass 2FA');
        threatScore += 50;
      }
      if (perm.contains('SYSTEM_ALERT_WINDOW')) {
        dangerousFlags.add('Screen Overlay: Can draw fake phishing login screens over banking apps');
        threatScore += 30;
      }
      if (perm.contains('RECEIVE_SMS') || perm.contains('READ_SMS')) {
        dangerousFlags.add('SMS Interception: Capable of intercepting bank OTPs');
        threatScore += 30;
      }
      if (perm.contains('REQUEST_INSTALL_PACKAGES')) {
        dangerousFlags.add('Secondary Dropper: Can silently download and prompt secondary APK installation');
        threatScore += 25;
      }
    }

    final isTrojanCandidate = threatScore >= 60;

    return ToolResult.success({
      'package_name': packageName,
      'threat_score': threatScore.clamp(0, 100),
      'is_suspicious': dangerousFlags.isNotEmpty,
      'is_trojan_candidate': isTrojanCandidate,
      'dangerous_flags': dangerousFlags,
      'verdict': isTrojanCandidate ? 'DANGEROUS' : (dangerousFlags.isNotEmpty ? 'SUSPICIOUS' : 'SAFE'),
    });
  }
}

/// Tool Registry maintaining all policy-approved tools
class ToolRegistry {
  final Map<String, AgentTool> _tools = {};

  ToolRegistry() {
    registerTool(ScanUrlTool());
    registerTool(AnalyzeSmsTool());
    registerTool(VerifyUpiTool());
    registerTool(InspectAppPermissionsTool());
  }

  void registerTool(AgentTool tool) {
    _tools[tool.name] = tool;
  }

  List<AgentTool> get availableTools => _tools.values.toList();

  AgentTool? getTool(String name) => _tools[name];

  List<Map<String, dynamic>> exportToolSchemas() {
    return _tools.values.map((t) => {
          'name': t.name,
          'description': t.description,
          'parameters': t.parameterSchema,
          'requires_confirmation': t.requiresConfirmation,
        }).toList();
  }
}
