import 'dart:convert';
import 'dart:io';
import 'package:safesignal/core/forensics/threat_graph_service.dart';

void main() {
  final graph = ThreatGraphService();
  graph.clear();

  final now = DateTime.now();
  final urlNode = ThreatNode(
    id: 'node_url_1',
    type: ThreatNodeType.url,
    value: 'https://evil-phish.xyz/login.apk',
    metadata: {'verdict': 'dangerous', 'threat_score': 95},
    threatScore: 95,
    firstSeen: now,
    lastSeen: now,
  );

  final domainNode = ThreatNode(
    id: 'node_domain_1',
    type: ThreatNodeType.domain,
    value: 'evil-phish.xyz',
    metadata: {'registrar': 'NameCheap', 'risk': 'high'},
    threatScore: 85,
    firstSeen: now,
    lastSeen: now,
  );

  final ipNode = ThreatNode(
    id: 'node_ip_1',
    type: ThreatNodeType.ipAddress,
    value: '185.220.101.5',
    metadata: {'country': 'RU', 'asn': 'AS12345'},
    threatScore: 90,
    firstSeen: now,
    lastSeen: now,
  );

  final apkNode = ThreatNode(
    id: 'node_apk_1',
    type: ThreatNodeType.apkPackage,
    value: 'com.fake.sbi.banking',
    metadata: {
      'sha256':
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    },
    threatScore: 95,
    firstSeen: now,
    lastSeen: now,
  );

  final hashNode = ThreatNode(
    id: 'node_hash_1',
    type: ThreatNodeType.fileHash,
    value: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    metadata: {'algorithm': 'SHA-256'},
    threatScore: 95,
    firstSeen: now,
    lastSeen: now,
  );

  graph.addOrUpdateNode(urlNode);
  graph.addOrUpdateNode(domainNode);
  graph.addOrUpdateNode(ipNode);
  graph.addOrUpdateNode(apkNode);
  graph.addOrUpdateNode(hashNode);

  graph.addEdge(
    sourceNodeId: urlNode.id,
    targetNodeId: domainNode.id,
    relationship: 'hosted-on',
    confidence: 0.95,
    timestamp: now,
  );

  graph.addEdge(
    sourceNodeId: domainNode.id,
    targetNodeId: ipNode.id,
    relationship: 'resolves-to',
    confidence: 0.90,
    timestamp: now,
  );

  graph.addEdge(
    sourceNodeId: urlNode.id,
    targetNodeId: apkNode.id,
    relationship: 'drops-payload',
    confidence: 1.0,
    timestamp: now,
  );

  graph.recordEvidence(
    eventType: 'OBSERVABLE_EXTRACTED',
    payload: {'observable': 'evil-phish.xyz', 'source': 'sms'},
  );

  final bundle = graph.exportStixBundle();
  final jsonStr = const JsonEncoder.withIndent('  ').convert(bundle);

  final outputFile = File('test/stix_bundle_output.json');
  outputFile.writeAsStringSync(jsonStr);
  print('Successfully wrote STIX 2.1 bundle to test/stix_bundle_output.json');
}
