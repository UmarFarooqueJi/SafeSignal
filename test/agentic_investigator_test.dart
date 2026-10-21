import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/agent/agentic_investigator.dart';
import 'package:safesignal/core/agent/tool_registry.dart';

void main() {
  group('Policy-Constrained Agentic Cyber Investigator Tests', () {
    late AgenticInvestigator investigator;

    setUp(() {
      investigator = AgenticInvestigator();
    });

    test('ToolRegistry exports standard analytical schemas', () {
      final registry = ToolRegistry();
      final schemas = registry.exportToolSchemas();
      expect(schemas.length, greaterThanOrEqualTo(3));

      final toolNames = schemas.map((s) => s['name']).toList();
      expect(toolNames, contains('scan_url'));
      expect(toolNames, contains('analyze_sms'));
      expect(toolNames, contains('verify_upi'));
    });

    test('Investigates phishing SMS with URL and flags critical fraud trajectory', () async {
      final report = await investigator.investigate(
        rawInput: 'Electricity bill unpaid! Power will be disconnected tonight. Update APK at http://bit.ly/power-bill.apk',
        sender: '+919876543210',
      );

      expect(report.verdict, equals('CRITICAL'));
      expect(report.confidence, greaterThanOrEqualTo(90));
      expect(report.auditTrace.isNotEmpty, isTrue);
      expect(report.evidenceChainVerified, isTrue);

      final hasUrlStep = report.auditTrace.any((s) => s.toolName == 'scan_url');
      expect(hasUrlStep, isTrue);
    });

    test('Verifies clean legitimate communication with zero false positives', () async {
      final report = await investigator.investigate(
        rawInput: 'Dear Customer, your transaction at Amazon was successful. Thank you for banking with us.',
      );

      expect(report.verdict, equals('SAFE'));
      expect(report.evidenceChainVerified, isTrue);
    });
  });
}
