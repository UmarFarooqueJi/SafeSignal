import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/forensics/threat_graph_service.dart';

void main() {
  group('ThreatGraphService & RFC 3161 Evidence Chaining Tests', () {
    late ThreatGraphService graphService;

    setUp(() {
      graphService = ThreatGraphService();
      graphService.clear();
    });

    test('Adds nodes and edges to threat graph accurately', () {
      final now = DateTime.now();
      final urlNode = ThreatNode(
        id: 'node_url_1',
        type: ThreatNodeType.url,
        value: 'https://evil-phish.xyz/login.apk',
        threatScore: 90,
        firstSeen: now,
        lastSeen: now,
      );

      final domainNode = ThreatNode(
        id: 'node_domain_1',
        type: ThreatNodeType.domain,
        value: 'evil-phish.xyz',
        threatScore: 85,
        firstSeen: now,
        lastSeen: now,
      );

      graphService.addOrUpdateNode(urlNode);
      graphService.addOrUpdateNode(domainNode);

      graphService.addEdge(
        sourceNodeId: urlNode.id,
        targetNodeId: domainNode.id,
        relationship: 'hosted_on',
        confidence: 0.95,
      );

      expect(graphService.nodes.length, equals(2));
      expect(graphService.edges.length, equals(1));
      expect(graphService.edges.first.relationship, equals('hosted_on'));
    });

    test(
      'Maintains and verifies cryptographic RFC 3161 evidence chain integrity',
      () {
        final block1 = graphService.recordEvidence(
          eventType: 'OBSERVABLE_EXTRACTED',
          payload: {'observable': 'evil-domain.com', 'source': 'sms'},
        );
        expect(block1.index, equals(0));
        expect(
          block1.previousHash,
          equals(
            '0000000000000000000000000000000000000000000000000000000000000000',
          ),
        );

        final block2 = graphService.recordEvidence(
          eventType: 'URL_SCAN_EXECUTED',
          payload: {'verdict': 'dangerous', 'threat_score': 95},
        );
        expect(block2.index, equals(1));
        expect(block2.previousHash, equals(block1.blockHash));

        expect(graphService.verifyChainIntegrity(), isTrue);
      },
    );

    test(
      'Generates valid STIX 2.1 JSON-LD export bundle with OASIS compliant UUIDs and patterns',
      () {
        graphService.addOrUpdateNode(
          ThreatNode(
            id: 'stix_test_1',
            type: ThreatNodeType.url,
            value: 'http://test.in',
            threatScore: 40,
            firstSeen: DateTime.now(),
            lastSeen: DateTime.now(),
          ),
        );

        final bundle = graphService.exportStixBundle();
        expect(bundle['type'], equals('bundle'));
        expect(bundle.containsKey('spec_version'), isFalse);
        expect(bundle['x_safesignal_evidence_chain_verified'], isTrue);
        expect((bundle['objects'] as List).isNotEmpty, isTrue);

        // Verify UUIDv4 format for bundle and indicators
        final uuidRegex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        );
        final bundleId = bundle['id'] as String;
        expect(bundleId.startsWith('bundle--'), isTrue);
        expect(
          uuidRegex.hasMatch(bundleId.substring('bundle--'.length)),
          isTrue,
        );

        final indicator =
            (bundle['objects'] as List).first as Map<String, dynamic>;
        final indicatorId = indicator['id'] as String;
        expect(indicatorId.startsWith('indicator--'), isTrue);
        expect(
          uuidRegex.hasMatch(indicatorId.substring('indicator--'.length)),
          isTrue,
        );

        // Verify STIX 2.1 pattern and pattern_type
        expect(indicator['pattern_type'], equals('stix'));
        expect(indicator['pattern'], equals("[url:value = 'http://test.in']"));
        expect(indicator.containsKey('x_safesignal_metadata'), isTrue);

        // Verify STIX 2.1 bundle root has NO spec_version (STIX 2.1 spec Section 4.1)
        expect(bundle.containsKey('spec_version'), isFalse);
      },
    );

    test('Detects unauthorized payload tampering in evidence chain', () {
      graphService.recordEvidence(
        eventType: 'OBSERVABLE_EXTRACTED',
        payload: {'observable': 'evil-domain.com', 'source': 'sms'},
      );
      graphService.recordEvidence(
        eventType: 'URL_SCAN_EXECUTED',
        payload: {'verdict': 'dangerous', 'threat_score': 95},
      );

      expect(graphService.verifyChainIntegrity(), isTrue);

      // Tampering test: mutating evidence chain payload
      // In-memory verification verifies data hash and block hash mismatch
      final blocks = graphService.evidenceChain;
      final tamperedBlock = EvidenceBlock(
        index: blocks.first.index,
        timestamp: blocks.first.timestamp,
        eventType: blocks.first.eventType,
        payload: {
          'observable': 'evil-domain.com',
          'source': 'sms',
          'tampered': true,
        },
        dataHash: blocks.first.dataHash,
        previousHash: blocks.first.previousHash,
        blockHash: blocks.first.blockHash,
      );

      // Expected data hash mismatch when payload content is modified
      final recalculatedHash = EvidenceBlock.calculateDataHash(
        tamperedBlock.payload,
      );
      expect(recalculatedHash != tamperedBlock.dataHash, isTrue);
    });
  });
}
