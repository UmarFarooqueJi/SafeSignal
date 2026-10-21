# Remaining Security Gaps & Prioritized Remediation Roadmap

This document enumerates all remaining vulnerabilities, architectural flaws, cryptographic limitations, and operational defects identified during the independent re-audit of SafeSignal (commit `cdb7774`). Gaps are categorized by risk priority (P0 through P3) with root-cause analysis, proof-of-concept failure modes, and actionable remediation specifications.

---

## Priority Classification Framework

- **P0 (Critical):** Immediate security compromise, authentication bypass, data loss, or safety failure.
- **P1 (High):** Significant evasion surface, unhandled fatal exceptions, or misleading defensive verdicts.
- **P2 (Medium):** Architectural divergence from specifications, protocol non-compliance, or volatile state.
- **P3 (Low):** Dead code stubs, supply chain hygiene gaps, or documentation inaccuracies.

---

## Prioritized Remediation Matrix

| Defect ID | Priority | Subsystem | Description | Affected File & Lines |
|---|:---:|---|---|---|
| **GAP-01** | **P0** | URL Engine | Allowlist override blindly resets risk score to 0 on open redirects / credential injection. | `lib/core/services/url_intelligence_engine.dart:535` |
| **GAP-02** | **P0** | Vault Storage | Encryption key is decoupled from master passphrase and stored un-wrapped in KeyStore. | `lib/core/services/vault_service.dart:62-94` |
| **GAP-03** | **P1** | Wi-Fi Scanner | Cleartext HTTP captive-portal check throws unhandled `DioException` on Android 9+. | `lib/ui/screens/wifi_scanner_screen.dart:88-102` |
| **GAP-04** | **P1** | Call Screening | `CallScreeningService` fails to drop malicious calls and lacks in-call warning overlay. | `android/app/src/main/kotlin/.../CallScreeningServiceImpl.kt:45` |
| **GAP-05** | **P1** | SMS / DLT | DLT verification accepts spoofed sender IDs via unauthenticated regex matching. | `lib/core/services/sms_verification_service.dart:112-135` |
| **GAP-06** | **P1** | Threat Feed | Reliance on `api.rss2json.com` proxy leaks user IP and fabricates synthetic timestamps. | `lib/core/services/threat_feed_service.dart:74-98` |
| **GAP-07** | **P2** | Root Detection | Userland `/system/bin/su` path existence checks trivially bypassed by Magisk/KernelSU. | `lib/ui/screens/device_audit_screen.dart:130-155` |
| **GAP-08** | **P2** | AI / Injection | Claimed `<<<UNTRUSTED_ARTEFACT>>>` boundary delimiter is absent in production code. | `lib/core/services/cyber_advisor_service.dart:45-70` |
| **GAP-09** | **P2** | Threat Graph | Graph nodes and edges are stored entirely in RAM and wiped on application termination. | `lib/core/services/threat_graph_service.dart:34-62` |
| **GAP-10** | **P2** | Forensics | Local SHA-256 hash pointer chain falsely advertised as RFC 3161 compliant. | `lib/core/services/rfc3161_service.dart:28-55` |
| **GAP-11** | **P2** | STIX Export | Emits non-standard object IDs (`report--custom`) and lacks required `pattern` attributes. | `lib/core/services/stix_export_service.dart:85-110` |
| **GAP-12** | **P3** | Capability Tiers | Tiers 2 (Device Owner) and 3 (Root) are dead code stubs not implemented in Kotlin. | `lib/core/services/research_mode_service.dart:42-88` |
| **GAP-13** | **P3** | Supply Chain | CI/CD CycloneDX SBOM job executes standard `flutter pub deps --json` instead of spec. | `.github/workflows/ci.yml:68-82` |
| **GAP-14** | **P3** | UI Regression | UI/UX preservation lacks automated golden pixel tests to prevent layout drift. | `test/golden/` (Directory absent) |

---

## Detailed Gap Analyses & Remediation Specifications

### GAP-01: URL Intelligence Allowlist Blindness (P0)
- **Root Cause:** In `url_intelligence_engine.dart` at line 535, the engine checks if the host ends with `.gov.in` or exists in `_verifiedAuthorityDomains`. If matched, it executes `riskScore = 0;` without validating the path, query parameters, or authority userinfo.
- **Exploitation Scenario:**
  - An attacker constructs an open redirect: `https://uidai.gov.in/redirect?url=https://attacker.com/malware.apk`.
  - Or an HTTP basic auth confusion link: `https://uidai.gov.in@evil.com/login`.
  - The scanner reports: `Score: 0 (SAFE) - Verified Government Portal`.
- **Remediation Specification:**
  ```dart
  // REPLACE line 535 in lib/core/services/url_intelligence_engine.dart:
  if (isWhitelistedDomain) {
    if (parsedUri.userInfo.isNotEmpty || parsedUri.queryParameters.containsKey('url') || parsedUri.queryParameters.containsKey('redirect')) {
      riskScore = 75;
      findings.add("Potential Open Redirect or Credential Obfuscation on Allowlisted Domain");
    } else {
      riskScore = 0;
    }
  }
  ```

---

### GAP-02: Vault Key Decoupled from Master Passphrase (P0)
- **Root Cause:** In `vault_service.dart`, encryption uses a standalone 256-bit AES key generated at initialization and stored in `FlutterSecureStorage` (backed by Android Keystore). The master passphrase entered by the user is merely hashed with SHA-256 and compared to a stored hash. The AES key is not derived from or encrypted by the passphrase.
- **Exploitation Scenario:**
  - If an attacker obtains device access or runs in a rooted environment, extracting the AES key from SecureStorage allows instantaneous decryption of all vault blobs without knowing the master passphrase.
- **Remediation Specification:**
  - Use PBKDF2 (100,000 iterations of HMAC-SHA256) or Argon2id with a unique 16-byte salt to derive a Key Encryption Key (KEK).
  - Use the KEK to wrap (encrypt) the AES-256 Vault Data Encryption Key (DEK). Store only the encrypted DEK and salt.

---

### GAP-03: Wi-Fi Scanner Cleartext HTTP Crash on Android 9+ (P1)
- **Root Cause:** In `wifi_scanner_screen.dart`, the captive portal detector issues a raw HTTP GET request to `http://connectivitycheck.gstatic.com/generate_204`. Android 9+ (API 28+) enforces `usesCleartextTraffic=false` by default, triggering an uncaught `DioException (CLEARTEXT_NOT_PERMITTED)` that crashes the scanner thread.
- **Remediation Specification:**
  - Delegate the captive portal check to the native Kotlin platform channel via `ConnectivityManager.getNetworkCapabilities()`, which queries `NET_CAPABILITY_CAPTIVE_PORTAL` natively without making cleartext HTTP requests from Dart.

---

### GAP-04: CallScreeningService Does Not Drop Malicious Calls (P1)
- **Root Cause:** In `CallScreeningServiceImpl.kt`, when a call is flagged as malicious (fraud / vishing), the service builds a response with `setDisallowCall(false)` and `setRejectCall(false)`, only toggling `setSkipCallLog(false)`.
- **Exploitation Scenario:**
  - The phone continues to ring when an identified scammer calls; the user is not actively protected.
- **Remediation Specification:**
  - When `isMalicious == true`, invoke:
    ```kotlin
    val response = CallResponse.Builder()
        .setDisallowCall(true)
        .setRejectCall(true)
        .setSkipNotification(true)
        .setSkipCallLog(false)
        .build()
    respondToCall(callDetails, response)
    ```

---

### GAP-05: Unauthenticated DLT Regex Header Matching (P1)
- **Root Cause:** In `sms_verification_service.dart`, headers matching `^[A-Z]{2}-[A-Z0-9]{6}$` are classified as legitimate TRAI DLT headers. No cryptographic signature or local database lookup against the telecom authority registry is performed.
- **Exploitation Scenario:**
  - An attacker sending SMS from a cheap GSM modem with a spoofed alphanumeric sender ID (e.g., `VK-HDFCBK`) automatically receives a "Verified DLT Banking Header" badge.
- **Remediation Specification:**
  - Bundle an offline SQLite database containing the registered 6-character Entity IDs of top Indian banks and institutions. Verify both format and registered entity ownership.

---

### GAP-06: Threat Feed rss2json Proxy Dependency (P1)
- **Root Cause:** `threat_feed_service.dart` queries `https://api.rss2json.com/v1/api.json?rss_url=...` to bypass CORS/XML parsing.
- **Exploitation Scenario:**
  - The user's IP and viewing patterns are exposed to a third-party commercial conversion service. If `rss2json.com` experiences an outage or blocks the app's requests, threat intelligence fetching fails.
- **Remediation Specification:**
  - Integrate `xml2json` or a native Dart RSS/Atom XML parser (`webfeed`) to fetch and parse official CERT-In, RBI, and NPCI RSS feeds directly over HTTPS.

---

### GAP-07: Trivial Userland Root Detection Bypass (P2)
- **Root Cause:** `device_audit_screen.dart` checks for `/system/bin/su`, `/system/xbin/su`, and common root packages using Dart `File(path).existsSync()`.
- **Exploitation Scenario:**
  - Magisk DenyList or KernelSU mount-namespace hiding prevents userland `stat()` calls from detecting `su` binaries. The audit screen reports the device as uncompromised.
- **Remediation Specification:**
  - Use native C/Kotlin JNI system checks that inspect read-only properties via `__system_property_get("ro.build.tags")`, detect active Frida/Xposed hooks in `/proc/self/maps`, and attempt root execution via `Runtime.getRuntime().exec()`.

---

## Action Plan & Phased Implementation

```
Phase 1: Critical Security (Immediate / P0)
  ├── GAP-01: Patch URL Allowlist logic to inspect query params & userInfo.
  └── GAP-02: Implement PBKDF2 DEK wrapping for AES-256-GCM Vault.

Phase 2: Reliability & Evasion Resistance (Next Sprint / P1)
  ├── GAP-03: Route captive portal checks through Android ConnectivityManager.
  ├── GAP-04: Enable active call blocking in CallScreeningServiceImpl.
  ├── GAP-05: Bundle authentic TRAI entity database for DLT checks.
  └── GAP-06: Replace rss2json with direct on-device XML parser.

Phase 3: Hardening & Compliance (Subsequent / P2 & P3)
  ├── GAP-07: Implement native JNI root and hook detection.
  ├── GAP-08: Add <<<UNTRUSTED_ARTEFACT>>> delimiters to Cyber Advisor.
  ├── GAP-09: Add SQLite / Hive persistence to Threat Graph.
  ├── GAP-10: Rename RFC 3161 service to LocalHashChainService or integrate RFC 3161 TSA.
  ├── GAP-11: Validate STIX 2.1 JSON schema with real UUIDv4 identifiers.
  ├── GAP-12: Implement or formally remove Tier 2/3 dead stubs.
  └── GAP-13: Install true cyclonedx-cli tool in CI workflow.
```
