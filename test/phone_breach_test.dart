// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Test: Phone Breach & Mobile Identity OSINT Threat Intelligence Tests
// -----------------------------------------------------------------------------
import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/services/phone_breach_service.dart';
import 'package:safesignal/core/services/mcp_security_agent_service.dart';

void main() {
  group('PhoneBreachService - Telecom NNP Resolution & Leak Exposure', () {
    late PhoneBreachService service;

    setUp(() {
      service = PhoneBreachService();
    });

    test('resolves Delhi NCR Circle and Airtel for 9810 series', () async {
      final res = await service.scanPhoneNumber('9810123456');

      expect(res.isValid, isTrue);
      expect(res.circle, contains('Delhi'));
      expect(res.carrier, contains('Airtel'));
      expect(res.formattedNumber, equals('+91 98101 23456'));
      expect(res.breaches, isNotEmpty);
      expect(res.riskScore, greaterThan(0));
    });

    test('normalizes international format +91 98201 23456 to Mumbai Circle', () async {
      final res = await service.scanPhoneNumber('+91 98201 23456');

      expect(res.isValid, isTrue);
      expect(res.circle, contains('Mumbai'));
      expect(res.formattedNumber, equals('+91 98201 23456'));
      expect(res.lineType, contains('Mobile'));
    });

    test('normalizes trunk zero 09845123456 to Karnataka Circle', () async {
      final res = await service.scanPhoneNumber('09845123456');

      expect(res.isValid, isTrue);
      expect(res.circle, contains('Karnataka'));
      expect(res.formattedNumber, equals('+91 98451 23456'));
    });

    test('detects BSNL carrier for 94 series and flags BSNL 2024 database exposure', () async {
      final res = await service.scanPhoneNumber('9412012345');

      expect(res.isValid, isTrue);
      expect(res.carrier, contains('BSNL'));
      expect(res.breaches.any((b) => b.title.contains('BSNL')), isTrue);
    });

    test('identifies stacademy / MobileSearch commercial CAF scraping leak vector', () async {
      final res = await service.scanPhoneNumber('9810123456');

      final cafLeak = res.breaches.firstWhere(
        (b) => b.title.contains('CAF') || b.title.contains('Telecom KYC'),
      );
      expect(cafLeak.dataClasses, contains('Father\'s Name'));
      expect(cafLeak.dataClasses, contains('Physical Residential Address'));
      expect(res.simSwapVulnerable, isTrue);
      expect(res.actionableSteps.any((s) => s.contains('SIM Lock PIN') || s.contains('Aadhaar')), isTrue);
    });

    test('gracefully rejects invalid numbers without crashing', () async {
      final res = await service.scanPhoneNumber('12345');

      expect(res.isValid, isFalse);
      expect(res.riskScore, equals(0));
      expect(res.securityGrade, equals('A'));
      expect(res.breaches, isEmpty);
      expect(res.actionableSteps.first, contains('valid 10-digit'));
    });
  });

  group('McpSecurityAgentService - check_phone_breach_osint Integration', () {
    final mcp = McpSecurityAgentService();

    test('listTools includes check_phone_breach_osint with valid schema', () {
      final tools = mcp.listTools();
      final phoneTool = tools.firstWhere((t) => t.name == 'check_phone_breach_osint');

      expect(phoneTool.description, contains('stacademy'));
      expect(phoneTool.inputSchema['properties'], contains('phoneNumber'));
      expect(phoneTool.inputSchema['required'], contains('phoneNumber'));
    });

    test('callTool executes check_phone_breach_osint and returns structured forensic analysis', () async {
      final res = await mcp.callTool('check_phone_breach_osint', {
        'phoneNumber': '+91 98101 23456',
      });

      expect(res.isError, isFalse);
      expect(res.content.first['text'], contains('Carrier: Bharti Airtel'));
      expect(res.content.first['text'], contains('Delhi NCR Circle'));
      expect(res.structuredData?['isValid'], isTrue);
      expect(res.structuredData?['carrier'], contains('Bharti Airtel'));
      expect(res.structuredData?['circle'], contains('Delhi'));
      expect(res.structuredData?['breachCount'], greaterThan(0));
      expect(res.structuredData?['breaches'], isNotEmpty);
    });

    test('callTool returns error when phoneNumber argument is missing', () async {
      final res = await mcp.callTool('check_phone_breach_osint', {
        'phoneNumber': '   ',
      });

      expect(res.isError, isTrue);
      expect(res.content.first['text'], contains('phoneNumber argument is required'));
    });
  });
}
