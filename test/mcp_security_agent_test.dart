// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Test: Model Context Protocol (MCP) Security Agent Service Tests
// -----------------------------------------------------------------------------
import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/services/mcp_security_agent_service.dart';

void main() {
  group('McpSecurityAgentService - Protocol Specification & Tool Execution', () {
    final mcp = McpSecurityAgentService();

    test(
      'listTools exposes standardized MCP tool catalog with input schemas',
      () {
        final tools = mcp.listTools();
        expect(tools.length, greaterThanOrEqualTo(5));

        final toolNames = tools.map((t) => t.name).toList();
        expect(toolNames, contains('inspect_app_ioc'));
        expect(toolNames, contains('analyze_url_c2'));
        expect(toolNames, contains('verify_upi_intent'));
        expect(toolNames, contains('verify_sms_trai_header'));
        expect(toolNames, contains('check_phone_breach_osint'));

        for (final t in tools) {
          expect(t.inputSchema['type'], equals('object'));
          expect(t.inputSchema['properties'], isNotEmpty);
        }
      },
    );

    test(
      'callTool executes inspect_app_ioc tool and returns structured MCP response',
      () async {
        final res = await mcp.callTool('inspect_app_ioc', {
          'package': 'com.mspy.android.tracker',
          'name': 'Device Service',
          'permissions': ['android.permission.RECORD_AUDIO'],
        });

        expect(res.isError, isFalse);
        expect(res.content.first['text'], contains('CRITICAL MATCH'));
        expect(res.structuredData?['isMatch'], isTrue);
        expect(res.structuredData?['threatFamily'], contains('mSpy'));
      },
    );

    test(
      'callTool executes analyze_url_c2 tool and flags C2 infrastructure',
      () async {
        final res = await mcp.callTool('analyze_url_c2', {
          'url': 'https://anatsa-c2.top/login',
        });

        expect(res.isError, isFalse);
        expect(res.content.first['text'], contains('C2'));
        expect(res.content.first['text'], contains('INFRASTRUCTURE'));
        expect(res.structuredData?['verdict'], equals('dangerous'));
        expect(res.structuredData?['riskScore'], greaterThanOrEqualTo(90));
      },
    );

    test(
      'callTool executes verify_upi_intent tool and detects reverse payment fraud',
      () async {
        final res = await mcp.callTool('verify_upi_intent', {
          'upiUri':
              'upi://pay?pa=refundscam@oksbi&pn=SBI+Refund&am=1000&tn=Tax+Refund',
        });

        expect(res.isError, isFalse);
        expect(res.structuredData?['isFraud'], isTrue);
        expect(res.content.first['text'], contains('REVERSE PAYMENT FRAUD'));
      },
    );

    test(
      'callTool executes verify_sms_trai_header and checks sender spoofing',
      () async {
        final res = await mcp.callTool('verify_sms_trai_header', {
          'messageText':
              'Dear customer, your SBI account is blocked. Call +919876543210 immediately.',
          'senderId': '+919876543210',
        });

        expect(res.isError, isFalse);
        expect(res.structuredData?['verdict'], isIn(['SCAM', 'SUSPICIOUS']));
        expect(res.structuredData?['reasons'], isNotEmpty);
      },
    );

    test('callTool returns error on unknown tool name', () async {
      final res = await mcp.callTool('unknown_tool_xyz', {});
      expect(res.isError, isTrue);
      expect(res.content.first['text'], contains('Unknown tool'));
    });
  });
}
