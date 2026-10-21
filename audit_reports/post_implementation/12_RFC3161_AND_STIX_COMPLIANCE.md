# 12 — RFC 3161 & STIX 2.1 STANDARDS COMPLIANCE AUDIT

**Audit Date:** October 21, 2026  
**Auditor:** Digital Forensics Specialist & Applied Cryptography Specialist  
**Component:** `lib/core/forensics/threat_graph_service.dart`

---

## 1. RFC 3161 COMPLIANCE EVALUATION

RFC 3161 specifies the *Internet X.509 Public Key Infrastructure Time-Stamp Protocol (TSP)*. The required elements of RFC 3161 compliance include:
1. Generation of an ASN.1 DER-encoded `TimeStampReq`.
2. Submission to an independent, accredited Time-Stamp Authority (TSA).
3. Receipt of a `TimeStampResp` containing a Cryptographic Message Syntax (CMS) / PKCS #7 `SignedData` structure.
4. Digital signature issued by the TSA’s private key.
5. TSA public key certificate chain anchoring back to a trusted root CA.

### What SafeSignal Actually Implements:
Lines 107–156 of `threat_graph_service.dart`:
```dart
class EvidenceBlock {
    final int index;
    final DateTime timestamp;
    final String eventType;
    final Map<String, dynamic> payload;
    final String dataHash;
    final String previousHash;
    final String blockHash;

    static String calculateDataHash(Map<String, dynamic> payload) {
        final canonicalJson = jsonEncode(payload);
        return sha256.convert(utf8.encode(canonicalJson)).toString();
    }

    static String calculateBlockHash(int index, DateTime timestamp, String dataHash, String previousHash) {
        final raw = '$index|${timestamp.toIso8601String()}|$dataHash|$previousHash';
        return sha256.convert(utf8.encode(raw)).toString();
    }
}
```

### Forensic Finding:
- **Zero RFC 3161 Mechanisms:** SafeSignal contains no TSA client, no ASN.1 encoding, no CMS SignedData, and no X.509 timestamp certificates.
- **Classification:** As mandated by the audit directive:
  > *"If the implementation only hashes records with SHA-256, classify it as: LOCAL TAMPER-EVIDENT HASH CHAIN. Do not call it RFC 3161 compliant."*
- **Official Verdict:** **LOCAL TAMPER-EVIDENT HASH CHAIN (MISLABELED AS RFC 3161)**.

### Tamper-Evidence Testing:
We tested altering the local hash chain:
1. **Modifying an event payload:** `dataHash` changes, causing `blockHash` mismatch in `verifyChainIntegrity()`. **Detected.**
2. **Deleting an intermediate block:** Index sequence breaks (`current.index != i`). **Detected.**
3. **Reordering events:** `previousHash != previous.blockHash`. **Detected.**
4. **Complete Chain Replacement / Wipe:** Because the chain is stored in volatile memory without an external anchor, an attacker with local device access can overwrite the entire chain with a newly forged genesis block (`000...000`). This **cannot be detected** locally without external anchoring.

---

## 2. STIX 2.1 SPECIFICATION COMPLIANCE EVALUATION

STIX 2.1 (OASIS Standard) defines structured JSON formats for sharing cyber threat intelligence. Lines 277–317 of `threat_graph_service.dart` implement `exportStixBundle()`.

### Compliance Check against OASIS STIX 2.1 Specification:

| STIX 2.1 Requirement | SafeSignal Implementation | OASIS Specification Verdict | Defect Detail |
| :--- | :--- | :--- | :--- |
| **Bundle Object Type** | `'type': 'bundle'` | **PASS** | Correct object type string. |
| **Spec Version** | `'spec_version': '2.1'` | **PASS** | Matches STIX 2.1 spec version. |
| **Bundle Identifier Format** | `'bundle--safesignal-${DateTime.now().millisecondsSinceEpoch}'` | **FAIL** | Non-compliant ID. STIX 2.1 Section 2.9 requires: `bundle--<UUIDv4>`. |
| **Indicator Identifier Format** | `'indicator--${node.id}'` (e.g. `indicator--node_url_1`) | **FAIL** | Non-compliant ID. STIX 2.1 requires: `indicator--<UUIDv4>`. |
| **Required Indicator Fields** | Emits `name`, `description`, `confidence`. Missing `pattern` and `pattern_type`. | **FAIL (INVALID)** | STIX 2.1 Section 4.7 mandates `pattern` (e.g. `[url:value = '...']`) and `pattern_type`. Missing both. |
| **Custom Properties** | Emits `'custom_properties': node.metadata` | **FAIL** | STIX 2.1 Section 11 mandates custom properties must prefix with `x_` (e.g. `x_safesignal_meta`). |
| **Bundle Top-Level Keys** | Adds `evidence_chain_verified`, `evidence_blocks_count` to bundle root | **FAIL** | Non-standard bundle properties. Strict SIEM parsers reject bundles with undeclared root keys. |

### Sanitized Sample Export Output:
```json
{
  "type": "bundle",
  "id": "bundle--safesignal-1729528800000",
  "spec_version": "2.1",
  "evidence_chain_verified": true,
  "evidence_blocks_count": 2,
  "objects": [
    {
      "type": "indicator",
      "spec_version": "2.1",
      "id": "indicator--url_123456",
      "created": "2026-10-21T18:00:00.000Z",
      "modified": "2026-10-21T18:00:00.000Z",
      "name": "https://evil-phish.xyz/login.apk",
      "description": "SafeSignal Observable: url",
      "confidence": 90,
      "custom_properties": {"verdict": "dangerous"}
    }
  ]
}
```

**Official STIX 2.1 Verdict:**  
**PARTIALLY COMPATIBLE / CUSTOM JSON STIX-LIKE EXPORT**.  
While the bundle structure mimics STIX 2.1 concepts, it will **fail validation** against the official `stix2-validator` (OASIS Open CTI) due to missing UUIDv4 compliance and missing `pattern` attributes on `indicator` objects.
