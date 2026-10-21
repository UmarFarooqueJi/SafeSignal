/*
 * SafeSignal Mobile Security Suite & Research Platform
 * Module: Temporal Threat Graph & RFC 3161 Cryptographic Evidence Engine
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
 * Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
 *
 * Provides a directed temporal threat graph for forensic incident reconstruction,
 * combined with a tamper-evident cryptographic hash chain (RFC 3161 evidence chaining).
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

/// Tamper-evident evidence block in an RFC 3161-style cryptographic hash chain
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

  /// Export the complete graph and evidence chain in standard STIX 2.1 / JSON-LD format
  Map<String, dynamic> exportStixBundle() {
    final objects = <Map<String, dynamic>>[];

    // Add nodes as STIX Cyber Observables (SCOs)
    for (final node in _nodes.values) {
      objects.add({
        'type': 'indicator',
        'spec_version': '2.1',
        'id': 'indicator--${node.id}',
        'created': node.firstSeen.toIso8601String(),
        'modified': node.lastSeen.toIso8601String(),
        'name': node.value,
        'description': 'SafeSignal Observable: ${node.type.name}',
        'confidence': node.threatScore,
        'custom_properties': node.metadata,
      });
    }

    // Add relationships
    for (final edge in _edges) {
      objects.add({
        'type': 'relationship',
        'spec_version': '2.1',
        'id': 'relationship--${edge.id}',
        'created': edge.timestamp.toIso8601String(),
        'relationship_type': edge.relationship,
        'source_ref': 'indicator--${edge.sourceNodeId}',
        'target_ref': 'indicator--${edge.targetNodeId}',
        'confidence': (edge.confidence * 100).toInt(),
      });
    }

    return {
      'type': 'bundle',
      'id': 'bundle--safesignal-${DateTime.now().millisecondsSinceEpoch}',
      'spec_version': '2.1',
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
