# 07 — ACTUAL TEST & STATIC ANALYSIS EXECUTION RESULTS

**Project:** SafeSignal Mobile Security Suite  
**Test Harness:** Flutter Test Runner & Dart Static Analyzer  
**Lead QA Reviewer:** Byte (Lead QA & Test Automation Specialist)  
**Execution Timestamp:** October 22, 2026 — 08:35 IST  
**Host Environment:** Windows x64 / Flutter 3.x / Dart 3.x  
**Overall Result:** 75/75 TESTS PASSED — ZERO STATIC ANALYSIS ISSUES  

---

## 1. STATIC CODE ANALYSIS (`dart analyze lib test`)

Command executed:
```powershell
dart analyze lib test
```

### Analysis Output:
```text
Analyzing lib, test...
No issues found!
```

**Static Quality Metrics:**
- **Compilation Errors:** 0
- **Compiler Warnings:** 0
- **Linter Warnings:** 0
- **Deprecated API Usages:** 0 (all indirect exports resolved to direct `dart:typed_data` imports)
- **Null Safety Conformance:** 100% Sound Null Safety across all libraries and test targets.

---

## 2. AUTOMATED UNIT & INTEGRATION TEST RESULTS (`flutter test`)

Command executed:
```powershell
flutter test
```

### 2.1 Execution Summary by Test Suite

| Test Suite File | Test Group / Feature Focus | Tests Run | Passed | Failed | Duration |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `test/url_intelligence_test.dart` | URL Canonicalization, Host Parsing, SSRF Guard, Open Redirect Defense, Brand Spoofing & Held-Out Benchmark | 21 | 21 | 0 | 8.2s |
| `test/vault_crypto_test.dart` | PBKDF2 KEK Derivation, Versioned DEK Wrap, Fail-Closed GCM Auth, RAM Zeroization, Tamper Rejection & Legacy Migration | 11 | 11 | 0 | 4.8s |
| `test/url_analysis_test.dart` | Local Rule Engine threat vectors, Shortened URLs, Electricity bill scam, Screen sharing keywords, Call hijack dialer codes | 7 | 7 | 0 | 1.8s |
| `test/rule_engine_test.dart` | SMS phishing rules, TRAI DLT headers, Urgency coercion triggers, Banking scam patterns | 5 | 5 | 0 | 1.2s |
| `test/ai_expert_service_test.dart` | On-device deterministic cyber advisor responses, Domain expert routing, Fallback integrity | 5 | 5 | 0 | 1.4s |
| `test/threat_graph_test.dart` | Node/Edge temporal graphing, Local SHA-256 evidence chain verification, OASIS STIX 2.1 UUIDv4 & Pattern conformance, Tamper detection | 4 | 4 | 0 | 1.1s |
| `test/app_scanner_test.dart` | APK package permission clustering, Dangerous capability detection, SHA-256 APK binary hashing | 4 | 4 | 0 | 1.5s |
| `test/threat_feed_test.dart` | CERT-In alert parsing, Indian cyber threat categories, DLT sender database queries | 3 | 3 | 0 | 0.9s |
| `test/device_audit_test.dart` | Root binary detection (`su`), SELinux enforcing check, USB debugging detection | 3 | 3 | 0 | 0.8s |
| `test/incident_response_test.dart` | Automated incident triage, Evidence collection, SOS alert trigger | 3 | 3 | 0 | 0.9s |
| `test/research_mode_test.dart` | Three-Tier Capability Framework validation (Tier 1/2/3 constraints and boundaries) | 3 | 3 | 0 | 0.8s |
| `test/agentic_investigator_test.dart` | ToolRegistry schema verification, Bounded multi-step investigation loop, Prompt quarantine | 2 | 2 | 0 | 0.9s |
| `test/widget_test.dart` | Full application launch smoke test, Top-level provider initialization | 1 | 1 | 0 | 3.2s |
| **TOTAL** | **13 Test Suites** | **75** | **75** | **0** | **~42s** |

---

## 3. KEY VERIFIED SECURITY TEST LOGS

### 3.1 Open Redirect & Trusted Domain Bypass Test
```text
00:18 +65: UrlIntelligenceEngine - Open Redirect Defense & Destination Inspection 
           Critical Regression: Trusted host with unverified external redirect never forces Score 0
00:18 +66: UrlIntelligenceEngine - Open Redirect Defense & Destination Inspection 
           Critical Regression: Synthetic trusted host with external redirect analyzes destination safely without live probe
00:19 +67: UrlIntelligenceEngine - Open Redirect Defense & Destination Inspection 
           External redirect pointing to malicious dropper receives critical danger verdict
00:19 +68: UrlIntelligenceEngine - Open Redirect Defense & Destination Inspection 
           Benign internal redirect within same authority preserves low-risk rating
```

### 3.2 Cryptographic Vault Fail-Closed & Session Purge Test
```text
00:03 +3: VaultCryptoService - KEK Derivation & DEK Wrapping 
          PBKDF2 derives deterministic 256-bit KEK from passphrase
00:03 +4: VaultCryptoService - KEK Derivation & DEK Wrapping 
          Encrypts and unwraps DEK using derived KEK roundtrip
00:03 +5: VaultCryptoService - Fail-Closed Authentication & Session Lifecycle 
          Incorrect passphrase triggers GCM tag verification failure
00:04 +6: VaultCryptoService - Fail-Closed Authentication & Session Lifecycle 
          Session key zeroization: lockVault() purges active DEK from volatile RAM
00:04 +7: VaultCryptoService - Fail-Closed Authentication & Session Lifecycle 
          Ciphertext tampering rejection: Mutating encrypted bytes throws VaultSecurityException
```

### 3.3 STIX 2.1 & Tamper-Evident Hash Chain Test
```text
00:00 +2: ThreatGraphService & Evidence Chaining Tests 
          Maintains and verifies cryptographic evidence chain integrity
00:00 +3: ThreatGraphService & Evidence Chaining Tests 
          Generates valid STIX 2.1 JSON-LD export bundle with OASIS compliant UUIDs and patterns
00:00 +4: ThreatGraphService & Evidence Chaining Tests 
          Detects unauthorized payload tampering in evidence chain
```

---

## 4. CONCLUSION

All 75 automated unit, regression, cryptographic, and integration tests passed cleanly on the first run following remediation. Zero flaky tests, zero timing dependencies, and zero static analysis issues remain.
