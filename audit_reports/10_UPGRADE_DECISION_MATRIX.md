# OPERATION SAFESIGNAL: UPGRADE & REFACTORING DECISION MATRIX

**Engineering Roadmap:** Architectural Evolution from Vulnerable Prototype to Enterprise-Grade Cyber Defense Platform  
**Target Milestone:** SafeSignal v2.0 Production Architecture

---

## 1. Component Action Matrix

| Component / Subsystem | Current State | Recommendation | Justification & Architectural Strategy |
| :--- | :--- | :---: | :--- |
| `vault_crypto_service.dart` | AES-256-GCM + PBKDF2 functional, but lacks hardware key binding. | **KEEP & HARDEN** | Retain authenticated encryption and PBKDF2 key derivation. Bind encryption keys to Android KeyStore hardware using `setUserAuthenticationRequired(true)` via biometric `CryptoObject`. |
| `local_rule_engine.dart` | Static regex and keyword dictionaries in Dart. | **REFACTOR** | Migrate static regex lists to an optimized Aho-Corasick automaton or fast trie matcher to support high-throughput scanning. Add tokenizers and stemming for Hinglish and Indian dialects. |
| `app_scanner_screen.dart` | Monolithic UI screen with spoofable package name prefix whitelist. | **REFACTOR** | Completely remove package prefix whitelist. Extract native APK signing certificate SHA-256 fingerprints via Android `PackageManager`. Offload parsing to a background Dart isolate (`compute()`). |
| `device_audit_screen.dart` | Superficial userland path checks (`/system/bin/su`). | **REWRITE** | Build native C/C++ (JNI) integrity module. Inspect `/proc/self/mountinfo`, verify SELinux enforcing state, check for Zygote process hooks, and validate APK signature tampering. |
| `wifi_scanner_screen.dart` | Cleartext HTTP GET probe crashes on Android 9+. | **REWRITE** | Replace unhandled cleartext HTTP ping with native Android `ConnectivityManager` / `NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL` API via platform channel. |
| `chat_screen.dart` (OCR Engine) | Cloud HTTP POST to `api.ocr.space` with hardcoded public key. | **PURGE & REPLACE** | Immediately remove all external OCR network calls. Integrate on-device Google ML Kit Text Recognition (`google_mlkit_text_recognition`) or offline Tesseract. |
| `ai_expert_service.dart` | Unauthenticated public LLM proxy fallback (`pollinations.ai`). | **PURGE & REPLACE** | Remove `text.pollinations.ai` completely. Bundle a quantized local Small Language Model (e.g., Gemma-2B INT4 via ExecuTorch / llama.cpp) for true offline privacy-preserving inference. |
| `signin_screen.dart` | Mocked 300ms timer setting boolean flag in preferences. | **REWRITE** | Eliminate fake login. Implement either genuine local credential derivation (Argon2id master passphrase securing the local database) or standards-compliant OIDC / Passkeys. |
| `history_screen.dart` | SharedPreferences key lookup bug (`flutter.sms_inbox`). | **REFACTOR** | Correct key string from `flutter.sms_inbox` to `sms_inbox`. Migrate historical incident logs from SharedPreferences to an encrypted local SQLite/Drift database. |
| `LinkShieldAccessibilityService.kt` | Dormant Kotlin service omitted from `AndroidManifest.xml`. | **REWRITE / ACTIVATE** | Either declare and configure the accessibility service properly in `AndroidManifest.xml` with appropriate user disclosure, or replace with an on-device loopback `VpnService`. |
| `CallReceiver.kt` | Dormant Kotlin broadcast receiver omitted from `AndroidManifest.xml`. | **REFACTOR / ACTIVATE** | Declare in `AndroidManifest.xml` with `READ_PHONE_STATE` permission or consolidate into `SafeSignalCallScreeningService`. |
| `crowd_intel_service.dart` | Mocked JSON counters returning static placeholders. | **PURGE** | Delete mock service until real privacy-preserving federated threat intelligence backend (STIX/TAXII) is deployed. |

---

## 2. Phased Engineering Execution Roadmap

```
Phase 0: Quarantine & Remediate Critical Vulnerabilities (Days 1–7)
  ├── SEC-01: Remove api.ocr.space network call; embed on-device ML Kit OCR.
  ├── SEC-02: Remove text.pollinations.ai proxy; enforce strict local rule fallback.
  ├── SEC-03: Delete package name prefix whitelist; implement APK certificate fingerprint check.
  ├── SEC-04: Enforce mandatory master password/PIN fallback in VaultScreen.
  ├── SEC-05: Render decrypted vault images directly from memory (Image.memory).
  └── SEC-08: Fix SharedPreferences key lookup bug in HistoryScreen.

Phase 1: Architecture & Native Hardening (Days 8–21)
  ├── Cryptography: Bind Vault keys to Android Keystore Hardware (StrongBox / TEE) via CryptoObject.
  ├── Native OS: Declare and bind background services properly in AndroidManifest.xml.
  ├── Concurrency: Offload regex scanning and app audits to background Dart isolates.
  ├── Network Shield: Replace cleartext Wi-Fi probes with native NetworkCapabilities API.
  └── Database: Migrate local storage from SharedPreferences to encrypted SQLite (SQLCipher / Drift).

Phase 2: Autonomous Agentic Cyber Defense Integration (Days 22–45)
  ├── Local SLM Runtime: Integrate ExecuTorch / llama.cpp running Gemma-2B INT4 on-device.
  ├── Local Tool Registry: Implement native tool-calling interface (DEX parser, cert verifier, DNS sinkhole).
  ├── Autonomous ReAct Loop: Deploy multi-turn reasoning agent correlating multi-vector fraud attacks.
  └── Forensic Integrity: Implement RFC 3161 cryptographic timestamping for incident reports.
```
