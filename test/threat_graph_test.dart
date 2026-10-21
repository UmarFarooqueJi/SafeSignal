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

    test('Maintains and verifies cryptographic RFC 3161 evidence chain integrity', () {
      final block1 = graphService.recordEvidence(
        eventType: 'OBSERVABLE_EXTRACTED',
        payload: {'observable': 'evil-domain.com', 'source': 'sms'},
      );
      expect(block1.index, equals(0));
      expect(block1.previousHash, equals('0000000000000000000000000000000000000000000000000000000000000000'));

      final block2 = graphService.recordEvidence(
        eventType: 'URL_SCAN_EXECUTED',
        payload: {'verdict': 'dangerous', 'threat_score': 95},
      );
      expect(block2.index, equals(1));
      expect(block2.previousHash, equals(block1.blockHash));

      expect(graphService.verifyChainIntegrity(), isTrue);
    });

    test('Generates valid STIX 2.1 JSON-LD export bundle', () {
      graphService.addOrUpdateNode(ThreatNode(
        id: 'stix_test_1',
        type: ThreatNodeType.url,
        value: 'http://test.in',
        threatScore: 40,
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
      ));

      final bundle = graphService.exportStixBundle();
      expect(bundle['type'], equals('bundle'));
      expect(bundle['spec_version'], equals('2.1'));
      expect(bundle['evidence_chain_verified'], isTrue);
      expect((bundle['objects'] as List).isNotEmpty, isTrue);
    });
  });
}
