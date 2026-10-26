// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: Model Context Protocol (MCP) Forensic Security Tool Registry
// Spec: Model Context Protocol (MCP) Standard (2024-11-05 Specification)
// License: SafeSignal Source-Available (Zero Cloud Egress, 100% On-Device)
// -----------------------------------------------------------------------------

import 'dart:convert';
import 'stalkerware_ioc_service.dart';
import 'url_intelligence_engine.dart';
import 'upi_intent_guard_service.dart';
import 'local_rule_engine.dart';

/// Standard Model Context Protocol (MCP) Tool definition
class McpToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const McpToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

/// Standard MCP Call Response
class McpToolResult {
  final List<Map<String, dynamic>> content;
  final bool isError;
  final Map<String, dynamic>? structuredData;

  const McpToolResult({
    required this.content,
    this.isError = false,
    this.structuredData,
  });

  static McpToolResult text(String text, {Map<String, dynamic>? data}) => McpToolResult(
        content: [
          {'type': 'text', 'text': text}
        ],
        structuredData: data,
      );

  static McpToolResult error(String errorMsg) => McpToolResult(
        content: [
          {'type': 'text', 'text': 'ERROR: $errorMsg'}
        ],
        isError: true,
      );

  Map<String, dynamic> toJson() => {
        'content': content,
        'isError': isError,
        if (structuredData != null) 'data': structuredData,
      };

  @override
  String toString() => jsonEncode(toJson());
}

/// On-Device Agentic Security Tool Registry exposing forensic capabilities
/// to LLM Copilot and autonomous investigation routines via MCP standard.
class McpSecurityAgentService {
  static final McpSecurityAgentService _instance = McpSecurityAgentService._internal();
  factory McpSecurityAgentService() => _instance;
  McpSecurityAgentService._internal();

  /// Returns the catalog of all available MCP tools
  List<McpToolDefinition> listTools() {
    return const [
      McpToolDefinition(
        name: 'inspect_app_ioc',
        description:
            'Queries forensic IoC database (Amnesty MVT, AssoEchap, Citizen Lab) to audit an Android package for known stalkerware, state-grade spyware (Pegasus/Chrysaor/Predator), banking trojans, and cryptographic signing certificate matches.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'package': {'type': 'string', 'description': 'Android package identifier (e.g. com.mspy.android)'},
            'name': {'type': 'string', 'description': 'Display application name'},
            'certSha256': {'type': 'string', 'description': 'SHA-256 fingerprint of APK signing certificate (optional)'},
            'permissions': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'List of requested Android permissions'
            },
            'installer': {'type': 'string', 'description': 'Package installer source (e.g. com.android.vending or unknown)'},
            'hasLauncher': {'type': 'boolean', 'description': 'Whether the app has a visible launcher icon'},
            'hasAccessibility': {'type': 'boolean', 'description': 'Whether the app binds accessibility services'},
            'hasDeviceAdmin': {'type': 'boolean', 'description': 'Whether the app holds device administration privileges'}
          },
          'required': ['package']
        },
      ),
      McpToolDefinition(
        name: 'analyze_url_c2',
        description:
            'Performs multi-factor URL analysis against Command & Control (C2) threat feeds (Maltrail, URLhaus), banking trojan droppers, Punycode/Cyrillic homographs, and unmasks URL shortener redirect hops safely.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'url': {'type': 'string', 'description': 'The target web link or suspicious domain to inspect'},
            'traceShorteners': {'type': 'boolean', 'description': 'Whether to trace redirect hops (default false)'}
          },
          'required': ['url']
        },
      ),
      McpToolDefinition(
        name: 'verify_upi_intent',
        description:
            'Inspects UPI payment URIs (upi://pay or upi://mandate) for reverse payment fraud, auto-debit mandate hijacking, and impersonated customer care/refund VPA handles.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'upiUri': {'type': 'string', 'description': 'Raw UPI URI string (e.g. upi://pay?pa=...)'}
          },
          'required': ['upiUri']
        },
      ),
      McpToolDefinition(
        name: 'verify_sms_trai_header',
        description:
            'Analyzes Indian telecom SMS messages against TRAI DLT header registry, checking for bank impersonation, 10-digit mobile number sender spoofing, digital arrest scripts, and call forwarding traps.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'messageText': {'type': 'string', 'description': 'The full text of the SMS or WhatsApp message'},
            'senderId': {'type': 'string', 'description': 'Sender string or phone number (e.g. VM-HDFCBK or +919876543210)'}
          },
          'required': ['messageText']
        },
      ),
    ];
  }

  /// Dispatches tool calls according to MCP standard
  Future<McpToolResult> callTool(String name, Map<String, dynamic> arguments) async {
    try {
      switch (name) {
        case 'inspect_app_ioc':
          return _handleInspectAppIoc(arguments);

        case 'analyze_url_c2':
          return await _handleAnalyzeUrlC2(arguments);

        case 'verify_upi_intent':
          return _handleVerifyUpiIntent(arguments);

        case 'verify_sms_trai_header':
          return _handleVerifySmsTraiHeader(arguments);

        default:
          return McpToolResult.error('Unknown tool: $name');
      }
    } catch (e) {
      return McpToolResult.error('Tool execution failed: $e');
    }
  }

  // ─── Tool Handlers ──────────────────────────────────────────────────────────

  McpToolResult _handleInspectAppIoc(Map<String, dynamic> args) {
    final package = args['package'] as String? ?? '';
    final name = args['name'] as String? ?? 'Unknown';
    final certSha256 = args['certSha256'] as String?;
    final permissions = (args['permissions'] as List<dynamic>?)?.cast<String>() ?? [];
    final installer = args['installer'] as String? ?? 'unknown';
    final hasLauncher = args['hasLauncher'] as bool? ?? true;
    final hasAccessibility = args['hasAccessibility'] as bool? ?? false;
    final hasDeviceAdmin = args['hasDeviceAdmin'] as bool? ?? false;

    final result = StalkerwareIoCService.evaluate(
      package: package,
      name: name,
      certSha256: certSha256,
      permissions: permissions,
      isSystem: false,
      installer: installer,
      hasLauncher: hasLauncher,
      hasAccessibility: hasAccessibility,
      hasDeviceAdmin: hasDeviceAdmin,
    );

    final summary = result.isMatch
        ? '🚨 CRITICAL MATCH: ${result.threatFamily} (${result.threatType}). Indicator: ${result.matchedIndicator}. Remediation: ${result.remediation}'
        : 'CLEAN: No known stalkerware or surveillance signatures matched.';

    return McpToolResult.text(summary, data: {
      'isMatch': result.isMatch,
      'threatFamily': result.threatFamily,
      'threatType': result.threatType,
      'matchedIndicator': result.matchedIndicator,
      'confidence': result.confidence,
      'remediation': result.remediation,
    });
  }

  Future<McpToolResult> _handleAnalyzeUrlC2(Map<String, dynamic> args) async {
    final url = args['url'] as String? ?? '';
    final traceShorteners = args['traceShorteners'] as bool? ?? false;

    final result = await UrlIntelligenceEngine.analyze(url, traceShorteners: traceShorteners);

    final summary = 'URL: ${result.url}\n'
        'Verdict: ${result.verdict.name.toUpperCase()} (Risk Score: ${result.riskScore}/100)\n'
        'Classification: ${result.threatCategoryBadge}\n'
        'Forensics: ${result.threatForensicDetails}\n'
        'Verified Safe: ${result.isVerifiedSafe}';

    return McpToolResult.text(summary, data: {
      'url': result.url,
      'domain': result.domain,
      'riskScore': result.riskScore,
      'verdict': result.verdict.name,
      'riskLevel': result.riskLevel.name,
      'threatCategoryBadge': result.threatCategoryBadge,
      'threatForensicDetails': result.threatForensicDetails,
      'isVerifiedSafe': result.isVerifiedSafe,
      'redirectChain': result.redirectChain,
    });
  }

  McpToolResult _handleVerifyUpiIntent(Map<String, dynamic> args) {
    final upiUri = args['upiUri'] as String? ?? '';
    final result = UpiIntentGuardService.analyze(upiUri);

    final summary = 'UPI Payee: ${result.payeeName} (${result.payeeAddress})\n'
        'Severity: ${result.severity.name.toUpperCase()}\n'
        'Is Fraud: ${result.isFraud}\n'
        'Amount: ${result.amount != null ? "₹${result.amount}" : "None"}\n'
        'Warnings: ${result.warnings.join(" | ")}\n'
        'Action: ${result.actionGuidance}';

    return McpToolResult.text(summary, data: {
      'isFraud': result.isFraud,
      'severity': result.severity.name,
      'payeeAddress': result.payeeAddress,
      'payeeName': result.payeeName,
      'amount': result.amount,
      'isRecurringMandate': result.isRecurringMandate,
      'warnings': result.warnings,
      'actionGuidance': result.actionGuidance,
    });
  }

  McpToolResult _handleVerifySmsTraiHeader(Map<String, dynamic> args) {
    final text = args['messageText'] as String? ?? '';
    final sender = args['senderId'] as String?;

    final engine = LocalRuleEngine();
    final verdict = engine.analyze(text, sender: sender);

    final summary = 'SMS Verdict: ${verdict.verdict} (Risk: ${verdict.riskScore}/100)\n'
        'Primary Reason: ${verdict.reasons.isNotEmpty ? verdict.reasons.first : "None"}\n'
        'Action Guidance: ${verdict.whatToDo}';

    return McpToolResult.text(summary, data: {
      'verdict': verdict.verdict,
      'riskScore': verdict.riskScore,
      'reasons': verdict.reasons,
      'whatToDo': verdict.whatToDo,
    });
  }
}
