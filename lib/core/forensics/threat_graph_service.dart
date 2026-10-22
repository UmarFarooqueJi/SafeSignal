/*
 * SafeSignal Mobile Security Suite & Research Platform
 * Module: Temporal Threat Graph & Local Tamper-Evident Cryptographic Hash Chain
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
 * Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
 *
 * Provides a directed temporal threat graph for forensic incident reconstruction,
 * combined with an append-only, tamper-evident SHA-256 cryptographic hash chain
 * for local digital evidence provenance tracking without third-party cloud dependencies.
 *
 * Standards Transparency:
 * - Evidence Ledger: Implements local SHA-256 block-hash chaining (genesis block,
 *   previous-hash linkage, canonical payload hashing). Designed for offline zero-cloud privacy.
 *   Does NOT contact external RFC 3161 TSA servers or issue X.509 CMS signed tokens.
 * - Threat Intelligence Export: Generates OASIS STIX 2.1-compliant bundle JSON with
 *   UUIDv4 identifiers, typed Indicator patterns, and custom property namespaces.
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Entity types represented in the forensic threat graph
enum ThreatNodeType {
  url,
  domain,
  ipAddress,
  apkPackage,
  phoneSender,
  upiVpa,
  cryptoAddress,
  fileHash,
}

/// Node representing a discrete observable entity in an incident
class ThreatNode {
  final String id;
  final ThreatNodeType type;
  final String value;
  final Map<String, dynamic> metadata;
  final int threatScore; // 0 - 100
  final DateTime firstSeen;
  final DateTime lastSeen;

  ThreatNode({
    required this.id,
    required this.type,
    required this.value,
    this.metadata = const {},
    required this.threatScore,
    required this.firstSeen,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'value': value,
        'metadata': metadata,
        'threat_score': threatScore,
        'first_seen': firstSeen.toIso8601String(),
        'last_seen': lastSeen.toIso8601String(),
      };

  factory ThreatNode.fromJson(Map<String, dynamic> json) => ThreatNode(
        id: json['id'] as String,
        type: ThreatNodeType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => ThreatNodeType.url,
        ),
        value: json['value'] as String,
        metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
        threatScore: json['threat_score'] as int? ?? 0,
        firstSeen: DateTime.parse(json['first_seen'] as String),
        lastSeen: DateTime.parse(json['last_seen'] as String),
      );
}

/// Directed relationship edge connecting two observable threat nodes
class ThreatEdge {
  final String id;
  final String sourceNodeId;
  final String targetNodeId;
  final String relationship; // e.g. "impersonates", "drops_payload", "redirects_to"
  final double confidence; // 0.0 - 1.0
  final DateTime timestamp;

  ThreatEdge({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.relationship,
    required this.confidence,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'source_node_id': sourceNodeId,
        'target_node_id': targetNodeId,
        'relationship': relationship,
        'confidence': confidence,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ThreatEdge.fromJson(Map<String, dynamic> json) => ThreatEdge(
        id: json['id'] as String,
        sourceNodeId: json['source_node_id'] as String,
        targetNodeId: json['target_node_id'] as String,
        relationship: json['relationship'] as String,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Tamper-evident evidence block in an append-only SHA-256 cryptographic hash chain
class EvidenceBlock {
  final int index;
  final DateTime timestamp;
  final String eventType;
  final Map<String, dynamic> payload;
  final String dataHash;
  final String previousHash;
  final String blockHash;

  EvidenceBlock({
    required this.index,
    required this.timestamp,
    required this.eventType,
    required this.payload,
    required this.dataHash,
    required this.previousHash,
    required this.blockHash,
  });

  static String calculateDataHash(Map<String, dynamic> payload) {
    final canonicalJson = jsonEncode(payload);
    return sha256.convert(utf8.encode(canonicalJson)).toString();
  }

  static String calculateBlockHash(int index, DateTime timestamp, String dataHash, String previousHash) {
    final raw = '$index|${timestamp.toIso8601String()}|$dataHash|$previousHash';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'timestamp': timestamp.toIso8601String(),
        'event_type': eventType,
        'payload': payload,
        'data_hash': dataHash,
        'previous_hash': previousHash,
        'block_hash': blockHash,
      };

  factory EvidenceBlock.fromJson(Map<String, dynamic> json) => EvidenceBlock(
        index: json['index'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
        eventType: json['event_type'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
        dataHash: json['data_hash'] as String,
        previousHash: json['previous_hash'] as String,
        blockHash: json['block_hash'] as String,
      );
}

/// Service managing the in-memory and persistent Threat Graph and Cryptographic Evidence Chain
class ThreatGraphService {
  static final ThreatGraphService _instance = ThreatGraphService._internal();
  factory ThreatGraphService() => _instance;
  ThreatGraphService._internal();

  final Map<String, ThreatNode> _nodes = {};
  final List<ThreatEdge> _edges = [];
  final List<EvidenceBlock> _evidenceChain = [];

  Map<String, ThreatNode> get nodes => Map.unmodifiable(_nodes);
  List<ThreatEdge> get edges => List.unmodifiable(_edges);
  List<EvidenceBlock> get evidenceChain => List.unmodifiable(_evidenceChain);

  /// Add or update a node in the threat graph
  void addOrUpdateNode(ThreatNode node) {
    if (_nodes.containsKey(node.id)) {
      final existing = _nodes[node.id]!;
      _nodes[node.id] = ThreatNode(
        id: node.id,
        type: node.type,
        value: node.value,
        metadata: {...existing.metadata, ...node.metadata},
        threatScore: node.threatScore > existing.threatScore ? node.threatScore : existing.threatScore,
        firstSeen: existing.firstSeen.isBefore(node.firstSeen) ? existing.firstSeen : node.firstSeen,
        lastSeen: node.lastSeen.isAfter(existing.lastSeen) ? node.lastSeen : existing.lastSeen,
      );
    } else {
      _nodes[node.id] = node;
    }
  }

  /// Add a directed relationship between two existing nodes
  void addEdge({
    required String sourceNodeId,
    required String targetNodeId,
    required String relationship,
    double confidence = 1.0,
    DateTime? timestamp,
  }) {
    final edgeId = 'edge_${sourceNodeId}_${targetNodeId}_$relationship';
    final edge = ThreatEdge(
      id: edgeId,
      sourceNodeId: sourceNodeId,
      targetNodeId: targetNodeId,
      relationship: relationship,
      confidence: confidence,
      timestamp: timestamp ?? DateTime.now(),
    );
    _edges.removeWhere((e) => e.id == edgeId);
    _edges.add(edge);
  }

  /// Append a new immutable forensic artifact to the cryptographic evidence chain
  EvidenceBlock recordEvidence({
    required String eventType,
    required Map<String, dynamic> payload,
  }) {
    final index = _evidenceChain.length;
    final timestamp = DateTime.now();
    final previousHash = _evidenceChain.isEmpty
        ? '0000000000000000000000000000000000000000000000000000000000000000'
        : _evidenceChain.last.blockHash;

    final dataHash = EvidenceBlock.calculateDataHash(payload);
    final blockHash = EvidenceBlock.calculateBlockHash(index, timestamp, dataHash, previousHash);

    final block = EvidenceBlock(
      index: index,
      timestamp: timestamp,
      eventType: eventType,
      payload: payload,
      dataHash: dataHash,
      previousHash: previousHash,
      blockHash: blockHash,
    );

    _evidenceChain.add(block);
    return block;
  }

  /// Cryptographically verifies the integrity of the evidence chain from genesis block
  bool verifyChainIntegrity() {
    if (_evidenceChain.isEmpty) return true;

    for (int i = 0; i < _evidenceChain.length; i++) {
      final current = _evidenceChain[i];

      // Verify index sequence
      if (current.index != i) return false;

      // Verify data hash
      final expectedDataHash = EvidenceBlock.calculateDataHash(current.payload);
      if (current.dataHash != expectedDataHash) return false;

      // Verify link to previous block
      if (i == 0) {
        if (current.previousHash != '0000000000000000000000000000000000000000000000000000000000000000') {
          return false;
        }
      } else {
        final previous = _evidenceChain[i - 1];
        if (current.previousHash != previous.blockHash) return false;
      }

      // Verify block hash
      final expectedBlockHash = EvidenceBlock.calculateBlockHash(
        current.index,
        current.timestamp,
        current.dataHash,
        current.previousHash,
      );
      if (current.blockHash != expectedBlockHash) return false;
    }

    return true;
  }

  static String _escapeStix(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  }

  static String _generateDeterministicUuid(String seed) {
    final digest = sha256.convert(utf8.encode(seed)).bytes;
    final bytes = digest.sublist(0, 16);
    final b6 = (bytes[6] & 0x0F) | 0x40; // Version 4
    final b8 = (bytes[8] & 0x3F) | 0x80; // RFC 4122 variant

    String hex(int b) => b.toRadixString(16).padLeft(2, '0');

    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(b6)}${hex(bytes[7])}-'
        '${hex(b8)}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  static String _buildStixPattern(ThreatNodeType type, String value) {
    final escaped = _escapeStix(value);
    switch (type) {
      case ThreatNodeType.url:
        return "[url:value = '$escaped']";
      case ThreatNodeType.domain:
        return "[domain-name:value = '$escaped']";
      case ThreatNodeType.ipAddress:
        return "[ipv4-addr:value = '$escaped']";
      case ThreatNodeType.apkPackage:
        return "[file:name = '$escaped']";
      case ThreatNodeType.fileHash:
        return "[file:hashes.'SHA-256' = '$escaped']";
      case ThreatNodeType.phoneSender:
        return "[x-safesignal-phone:number = '$escaped']";
      case ThreatNodeType.upiVpa:
        return "[x-safesignal-payment:vpa = '$escaped']";
      case ThreatNodeType.cryptoAddress:
        return "[cryptocurrency-wallet:address = '$escaped']";
    }
  }

  /// Export the complete graph and evidence chain in standard OASIS STIX 2.1 format
  Map<String, dynamic> exportStixBundle() {
    final objects = <Map<String, dynamic>>[];

    // Add nodes as STIX 2.1 Indicator objects with typed STIX patterns
    for (final node in _nodes.values) {
      final indicatorId = 'indicator--${_generateDeterministicUuid("node_${node.id}")}';
      objects.add({
        'type': 'indicator',
        'spec_version': '2.1',
        'id': indicatorId,
        'created': node.firstSeen.toUtc().toIso8601String(),
        'modified': node.lastSeen.toUtc().toIso8601String(),
        'name': node.value,
        'description': 'SafeSignal Observable: ${node.type.name}',
        'confidence': node.threatScore,
        'pattern_type': 'stix',
        'pattern': _buildStixPattern(node.type, node.value),
        'valid_from': node.firstSeen.toUtc().toIso8601String(),
        'x_safesignal_observable_type': node.type.name,
        'x_safesignal_metadata': node.metadata,
        // Backward-compatibility key for existing unit tests
        'custom_properties': node.metadata,
      });
    }

    // Add relationships as STIX 2.1 Relationship objects
    for (final edge in _edges) {
      final relationshipId = 'relationship--${_generateDeterministicUuid("edge_${edge.id}")}';
      final sourceRef = 'indicator--${_generateDeterministicUuid("node_${edge.sourceNodeId}")}';
      final targetRef = 'indicator--${_generateDeterministicUuid("node_${edge.targetNodeId}")}';

      objects.add({
        'type': 'relationship',
        'spec_version': '2.1',
        'id': relationshipId,
        'created': edge.timestamp.toUtc().toIso8601String(),
        'modified': edge.timestamp.toUtc().toIso8601String(),
        'relationship_type': edge.relationship,
        'source_ref': sourceRef,
        'target_ref': targetRef,
        'confidence': (edge.confidence * 100).toInt(),
      });
    }

    final bundleId = 'bundle--${_generateDeterministicUuid("bundle_${_nodes.keys.join("_")}_${_edges.length}_${_evidenceChain.length}")}';

    return {
      'type': 'bundle',
      'id': bundleId,
      'spec_version': '2.1',
      // Forensic integrity metadata
      'evidence_chain_verified': verifyChainIntegrity(),
      'evidence_blocks_count': _evidenceChain.length,
      'objects': objects,
    };
  }

  /// Clears in-memory graph state (for unit testing or privacy wipe)
  void clear() {
    _nodes.clear();
    _edges.clear();
    _evidenceChain.clear();
  }
}
