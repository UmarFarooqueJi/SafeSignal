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
      expect(res.circle, equals('Delhi NCR Circle'));
      expect(res.carrier, equals('Bharti Airtel'));
      expect(res.carrier.contains('/'), isFalse);
      expect(res.formattedNumber, equals('+91 98101 23456'));
      expect(res.breaches, isNotEmpty);
      expect(res.riskScore, greaterThan(0));
      expect(res.leakedDossier, isNotNull);
      expect(res.leakedDossier!.subscriberName, isNotEmpty);
      expect(res.leakedDossier!.fatherName, contains('Digital Arrest'));
      expect(res.leakedDossier!.rawCafAddress, contains('!'));
      expect(res.leakedDossier!.formattedAddress, isNotEmpty);
      expect(res.leakedDossier!.rawDumpSyntax, contains('"mobile": "9810123456"'));
    });

    test('normalizes international format +91 98201 23456 to Mumbai Circle', () async {
      final res = await service.scanPhoneNumber('+91 98201 23456');

      expect(res.isValid, isTrue);
      expect(res.circle, equals('Mumbai Metro Circle'));
      expect(res.carrier, equals('Vodafone Idea (Vi)'));
      expect(res.carrier.contains('/'), isFalse);
      expect(res.formattedNumber, equals('+91 98201 23456'));
      expect(res.lineType, contains('Mobile'));
    });

    test('normalizes trunk zero 09845123456 to Karnataka Circle', () async {
      final res = await service.scanPhoneNumber('09845123456');

      expect(res.isValid, isTrue);
      expect(res.circle, equals('Karnataka Circle'));
      expect(res.carrier, equals('Bharti Airtel'));
      expect(res.carrier.contains('/'), isFalse);
      expect(res.formattedNumber, equals('+91 98451 23456'));
    });

    test('detects BSNL carrier for 94 series and flags BSNL 2024 database exposure', () async {
      final res = await service.scanPhoneNumber('9412012345');

      expect(res.isValid, isTrue);
      expect(res.carrier, equals('BSNL Mobile (Bharat Sanchar Nigam Ltd)'));
      expect(res.carrier.contains('/'), isFalse);
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

      expect(res.exposedProfile, isNotEmpty);
      final fatherField = res.exposedProfile.firstWhere((p) => p.fieldName.contains("Father"));
      expect(fatherField.isCompromised, isTrue);
      expect(fatherField.severity, equals('Critical'));

      final addressField = res.exposedProfile.firstWhere((p) => p.fieldName.contains("Address"));
      expect(addressField.isCompromised, isTrue);
      expect(addressField.severity, equals('Critical'));
    });

    test('detects Reliance Jio Infocomm for 70, 79, 83, and 92 series', () async {
      final res70 = await service.scanPhoneNumber('7003123456');
      expect(res70.carrier, equals('Reliance Jio Infocomm'));
      expect(res70.circle, equals('Kolkata Circle'));

      final res79 = await service.scanPhoneNumber('7970123456');
      expect(res79.carrier, equals('Reliance Jio Infocomm'));
      expect(res79.circle, equals('Bihar & Jharkhand Circle'));

      final res83 = await service.scanPhoneNumber('8303123456');
      expect(res83.carrier, equals('Reliance Jio Infocomm'));

      final res92 = await service.scanPhoneNumber('9210123456');
      expect(res92.carrier, equals('Reliance Jio Infocomm'));
      expect(res92.circle, equals('Delhi NCR Circle'));
    });

    test('supports MNP carrier switching and updates dossier and defense telemetry live', () async {
      final initial = await service.scanPhoneNumber('9810123456');
      expect(initial.carrier, equals('Bharti Airtel'));
      expect(initial.isPorted, isFalse);

      final ported = service.updateCarrierWithMnp(initial, 'Reliance Jio Infocomm');
      expect(ported.carrier, equals('Reliance Jio Infocomm'));
      expect(ported.isPorted, isTrue);
      expect(ported.leakedDossier?.primaryCarrier, equals('Reliance Jio Infocomm'));
      expect(ported.leakedDossier?.rawDumpSyntax, contains('RELIANCE JIO INFOCOMM'));
      expect(ported.actionableSteps.any((s) => s.contains('Reliance Jio Infocomm')), isTrue);
      final carrierField = ported.exposedProfile.firstWhere((p) => p.fieldName.contains('Carrier'));
      expect(carrierField.exposureStatus, contains('Reliance Jio Infocomm - MNP Active'));
    });

    test('confirms clean record with 0 risk score for modern uncompromised series', () async {
      final res = await service.scanPhoneNumber('6201234567');

      expect(res.isValid, isTrue);
      expect(res.carrier, equals('Reliance Jio Infocomm'));
      expect(res.breaches, isEmpty);
      expect(res.riskScore, equals(0));
      expect(res.securityGrade, equals('A'));
      expect(res.simSwapVulnerable, isFalse);
      expect(res.leakedDossier, isNotNull);
      expect(res.leakedDossier!.subscriberName, contains('Clean'));
      expect(res.actionableSteps.first, contains('No active dark-web breach exposures'));
    });

    test('gracefully rejects invalid numbers without crashing', () async {
      final res = await service.scanPhoneNumber('12345');

      expect(res.isValid, isFalse);
      expect(res.riskScore, equals(0));
      expect(res.securityGrade, equals('A'));
      expect(res.breaches, isEmpty);
      expect(res.leakedDossier, isNull);
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
      expect(res.structuredData?['carrier'], equals('Bharti Airtel'));
      expect(res.structuredData?['circle'], equals('Delhi NCR Circle'));
      expect(res.structuredData?['breachCount'], greaterThan(0));
      expect(res.structuredData?['breaches'], isNotEmpty);
      expect(res.structuredData?['exposedProfile'], isNotEmpty);
      expect(res.structuredData?['leakedDossier'], isNotNull);
      expect(res.structuredData?['leakedDossier']['subscriberName'], isNotEmpty);
      expect(res.structuredData?['leakedDossier']['rawCafAddress'], contains('!'));
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
