# 11 — TEMPORAL THREAT GRAPH FORENSIC VERIFICATION

**Audit Date:** October 21, 2026  
**Auditor:** Digital Forensics Specialist & Threat Detection Engineer  
**Component:** `lib/core/forensics/threat_graph_service.dart` (326 LOC)

---

## 1. THREAT GRAPH ARCHITECTURE AUDIT

`ThreatGraphService` implements an entity-relationship graph model consisting of:
- **`ThreatNodeType`:** `url`, `domain`, `ipAddress`, `apkPackage`, `phoneSender`, `upiVpa`, `cryptoAddress`, `fileHash`.
- **`ThreatNode`:** Represents an observable entity with `id`, `type`, `value`, `threatScore` (0-100), `firstSeen`, `lastSeen`, and arbitrary `metadata`.
- **`ThreatEdge`:** Directed relationship between two nodes with `sourceNodeId`, `targetNodeId`, `relationship` (e.g. `hosted_on`, `drops_payload`), `confidence` (0.0-1.0), and `timestamp`.

---

## 2. SYNTHETIC MULTI-VECTOR INCIDENT RECONSTRUCTION TEST

A synthetic incident scenario was tested to verify graph construction:
- **Event 1:** Scam SMS from sender `+919876543210` claiming unpaid electricity bill.
- **Event 2:** Extracted link: `http://bit.ly/bijli-update`.
- **Event 3:** URL Redirect: `http://bit.ly/bijli-update` redirects to `https://fake-power-bill.xyz/update.apk`.
- **Event 4:** Malicious APK Dropper: `update.apk` (Package: `com.sbi.powerpay`, Hash: `a3b4c5...`).

### Test Execution:
```dart
final graph = ThreatGraphService();
graph.clear();

// 1. Add Nodes
graph.addOrUpdateNode(ThreatNode(id: 'phone_1', type: ThreatNodeType.phoneSender, value: '+919876543210', threatScore: 70, firstSeen: DateTime.now(), lastSeen: DateTime.now()));
graph.addOrUpdateNode(ThreatNode(id: 'url_short', type: ThreatNodeType.url, value: 'http://bit.ly/bijli-update', threatScore: 40, firstSeen: DateTime.now(), lastSeen: DateTime.now()));
graph.addOrUpdateNode(ThreatNode(id: 'url_dropper', type: ThreatNodeType.url, value: 'https://fake-power-bill.xyz/update.apk', threatScore: 95, firstSeen: DateTime.now(), lastSeen: DateTime.now()));
graph.addOrUpdateNode(ThreatNode(id: 'apk_1', type: ThreatNodeType.apkPackage, value: 'com.sbi.powerpay', threatScore: 90, firstSeen: DateTime.now(), lastSeen: DateTime.now()));

// 2. Add Relationships
graph.addEdge(sourceNodeId: 'phone_1', targetNodeId: 'url_short', relationship: 'sent_in_sms');
graph.addEdge(sourceNodeId: 'url_short', targetNodeId: 'url_dropper', relationship: 'redirects_to');
graph.addEdge(sourceNodeId: 'url_dropper', targetNodeId: 'apk_1', relationship: 'drops_payload');

// Assertions
expect(graph.nodes.length, equals(4));
expect(graph.edges.length, equals(3));
```

### Result:
- Graph node and edge linking executes cleanly.
- Updating an existing node updates `threatScore` to the maximum observed score and updates `lastSeen` timestamp while preserving `firstSeen`.
- Edge deduplication functions correctly based on `edge_${sourceNodeId}_${targetNodeId}_$relationship`.

---

## 3. CRITICAL LIMITATION: IN-MEMORY ONLY / ZERO PERSISTENCE

Inspection of lines 164–166 of `threat_graph_service.dart`:
```dart
final Map<String, ThreatNode> _nodes = {};
final List<ThreatEdge> _edges = [];
final List<EvidenceBlock> _evidenceChain = [];
```
1. **Volatile Storage:** All nodes, relationships, and evidence blocks are stored in private in-memory Dart collections.
2. **Loss on Termination:** If the Android OS terminates SafeSignal in the background (low memory killer, reboot, app close), **the entire threat graph is destroyed**.
3. **No Hive / SQLite Binding:** Despite Hive being initialized in `main.dart`, there are zero Hive TypeAdapters registered for `ThreatNode`, `ThreatEdge`, or `EvidenceBlock`.
4. **Isolated Integration:** Outside of `AgenticInvestigator.dart` (which adds URL nodes during investigation), the core UI screens (`HomeScreen`, `HistoryScreen`, `IncidentResponseScreen`) do not read from or display the threat graph.

**Verdict:** **PARTIALLY IMPLEMENTED (FUNCTIONAL IN-MEMORY LOGIC, BUT ZERO PERSISTENCE AND ISOLATED UI INTEGRATION)**.
