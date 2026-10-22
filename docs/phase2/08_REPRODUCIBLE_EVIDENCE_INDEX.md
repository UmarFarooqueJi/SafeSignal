# 08 — REPRODUCIBLE EVIDENCE INDEX

**Project:** SafeSignal Mobile Security Suite & Research Platform  
**Branch:** `feature/phase2-engine-transformation`  
**Purpose:** Independent Verification Commands and Artifact Mapping  

---

## 1. COMPREHENSIVE VERIFICATION COMMAND MATRIX

All test and validation suites are 100% reproducible on the physical codebase without mock networks or simulated outcomes:

| Verification Target | Command Line | Expected Outcome | Execution Time |
| :--- | :--- | :--- | :--- |
| **STIX 2.1 OASIS Schema** | `dart run test/stix_export_runner.dart`<br>`stix2_validator test/stix_bundle_output.json` | `[+] STIX JSON: Valid` (Exit code 0) | ~3s |
| **URL Intelligence & APK Tests** | `flutter test test/url_intelligence_test.dart` | 32/32 tests passed | ~15s |
| **On-Device Inference Tests** | `flutter test test/on_device_inference_test.dart` | 5/5 tests passed | ~3s |
| **Agentic Investigation Tests** | `flutter test test/agentic_investigator_test.dart` | 5/5 tests passed | ~3s |
| **AES-256-GCM Vault & PBKDF2** | `flutter test test/vault_crypto_test.dart` | 11/11 tests passed | ~4s |
| **Threat Graph & RFC 3161 Ledger** | `flutter test test/threat_graph_test.dart` | 4/4 tests passed | ~2s |
| **Static Code Analysis** | `flutter analyze lib/` | `No issues found!` (0 errors, 0 warnings) | ~8s |
| **Total Automated Test Suite** | `flutter test` | **93/93 tests passed** | ~40s |

---

## 2. PRODUCTION SOURCE CODE ARTIFACT MAPPING

| Module Name | File Path | Key Classes & Functions |
| :--- | :--- | :--- |
| **URL Intelligence Engine** | `lib/core/services/url_intelligence_engine.dart` | `UrlIntelligenceEngine`, `validateAndParse()`, `analyze()`, `UrlInputStatus`, `UrlResult` |
| **STIX 2.1 & Forensic Ledger** | `lib/core/forensics/threat_graph_service.dart` | `ThreatGraphService`, `exportStixBundle()`, `verifyChainIntegrity()`, `EvidenceBlock` |
| **On-Device SLM Inference** | `lib/core/inference/on_device_inference_engine.dart` | `OnDeviceInferenceEngine`, `infer()`, `loadModel()`, `DeviceHardwareProfile` |
| **Agentic Cyber Investigator** | `lib/core/agent/agentic_investigator.dart` | `AgenticInvestigator`, `investigate()`, `_sanitizeAndQuarantine()`, `InvestigationReport` |
| **Typed Tool Registry** | `lib/core/agent/tool_registry.dart` | `ToolRegistry`, `ScanUrlTool`, `AnalyzeSmsTool`, `VerifyUpiTool`, `InspectAppPermissionsTool` |
| **Vault Cryptography Service** | `lib/features/vault/vault_crypto_service.dart` | `VaultCryptoService`, `wrapDataEncryptionKey()`, `unwrapDataEncryptionKey()` |
| **Local Rule Engine** | `lib/core/services/local_rule_engine.dart` | `LocalRuleEngine`, `analyze()` (Deterministic Tier 1 Core) |

---

## 3. RELEASE APK BUILD PROVENANCE

| Metric / Parameter | Value |
| :--- | :--- |
| **Artifact Path** | `build/app/outputs/flutter-apk/app-release.apk` |
| **File Size** | `116,404,912 bytes` (111.0 MB) |
| **SHA-256 Checksum** | `4991B88BBC7775831E140516CF1B815A0DB60D279B2D1C3305A717920BBB4FCA` |
| **Build Command** | `flutter build apk --release` |
| **Build Status** | Successful (`assembleRelease` exit code 0) |
| **Target OS / Architecture** | Android 7.0+ (API 24+), Tested on Android 11 (Realme RMX3268) |

