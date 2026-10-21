# OPERATION SAFESIGNAL: PRIVACY & DATA-FLOW FORENSICS

**Evaluation Focus:** Truth in Data Safety, Privacy Guarantee Integrity, Forensic Egress Mapping, and Regulatory Compliance (India DPDP Act 2023 / GDPR)

---

## 1. End-to-End Data Flow Forensic Matrix

| Data Category | Ingress Source | Processing Pipeline | Local Storage Mechanism | Encryption State | External Network Egress | Retention Policy | Deletion Mechanism |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **User Identity Documents** (Aadhaar, PAN, Passports) | Gallery / Camera image picker in `VaultScreen` | In-memory byte conversion, PBKDF2 key derivation | Hive encrypted box (`vault_box`) | AES-256-GCM (Auth Tag: 16 bytes, IV: 12 bytes) | **NO DIRECT EGRESS** (Except if scanned via Chat OCR: sent to `api.ocr.space`) | Indefinite until manual deletion | User swipe-to-delete invokes `box.delete(id)` |
| **Chat Uploaded Screenshots** | File picker in `ChatScreen` | Base64 string encoding in `_handleImageSelection()` | Temporary cache directory | **PLAINTEXT** | **CRITICAL EGRESS:** HTTP POST to `https://api.ocr.space/parse/image` with public API key | Transient on server (per third-party OCR policy) | Deleted locally on chat exit |
| **Incoming SMS Messages** | Native `SmsReceiver.kt` BroadcastReceiver | Regex heuristic analysis in `LocalRuleEngine` | Android `SharedPreferences` (`sms_inbox`) | **PLAINTEXT** (Stored as unencrypted JSON) | **NONE** (Local processing only) | Indefinite until SharedPreferences cleared | No automated expiration; manual wipe |
| **Suspicious URLs** | User manual paste or deep link in `UrlScannerScreen` | Regex pattern matching, TLD parsing, protocol check | History box in Hive (`url_history`) | **PLAINTEXT** | **ACTIVE EGRESS:** Direct HTTP GET request to scanned URL (`_dio.get`) | Indefinite | Clear history button in settings |
| **User Prompts & Fraud Queries** | User keyboard input in `ChatScreen` | Circuit breaker check in `LlmOrchestrator` | SharedPreferences / In-memory list | **PLAINTEXT** | **ACTIVE EGRESS:** Sent to `https://text.pollinations.ai` or Groq/OpenAI APIs | Retained in third-party server logs | Ephemeral session state in app |
| **Installed APK Metadata** | Android `PackageManager` via `installed_apps` plugin | Package prefix check, dangerous permission counter | In-memory `StatefulWidget` state | **NOT STORED** (Calculated dynamically) | **NONE** | Transient | Discarded on screen disposal |
| **User Profile & Credentials** | `ProfileSetupScreen`, `SigninScreen` | Name and city string assignments | Android `SharedPreferences` (`user_profile`) | **PLAINTEXT** | **NONE** | Indefinite | Clear app data |
| **Wi-Fi Network Metadata** | `network_info_plus` via Android Wi-Fi API | SSID, BSSID, and IP address extraction | In-memory state | **NOT STORED** | **ACTIVE EGRESS:** Probes `http://connectivitycheck.gstatic.com` | Transient | Discarded on screen disposal |
| **Email Address for Breach Check** | User manual entry in `EmailBreachScreen` | SHA-1 hashing, first 5 characters extracted | History box (`breach_history`) | **PLAINTEXT** | **ACTIVE EGRESS:** 5-char hash prefix sent to `api.pwnedpasswords.com` | Indefinite | Clear history button |
| **Incident PDF Reports** | User incident export in `IncidentResponseScreen` | PDF canvas rendering via `pdf` package | Stored in public external Downloads directory | **PLAINTEXT** (Standard PDF format) | User-initiated sharing via Android Sharesheet | Indefinite | Standard Android OS file management |

---

## 2. Privacy Guarantee vs Runtime Reality Audit

SafeSignal prominently advertises three core privacy commitments in its promotional copy and UI banners:
1. *"Zero Data Collection — Nothing ever leaves your phone."*
2. *"100% On-Device Artificial Intelligence."*
3. *"Air-Gapped Privacy Architecture."*

### Empirical Reality Check:
- **Total Network Calls Identified in Static Code:** 5 distinct external network destinations:
  1. `api.ocr.space` (Public OCR cloud service — transmits user document screenshots).
  2. `text.pollinations.ai` (Public unauthenticated LLM proxy — transmits user conversational text).
  3. `api.pwnedpasswords.com` (Cloud breach database — transmits k-anonymity SHA-1 prefixes).
  4. Scanned URLs (Target server infrastructure — transmits direct HTTP GET with custom SafeSignal user-agent).
  5. `connectivitycheck.gstatic.com` (Google network connectivity server — transmits cleartext HTTP ping).

### Regulatory & Compliance Impact:
- **India Digital Personal Data Protection (DPDP) Act 2023:** Under Section 6 and Section 8, transmitting personal identity documents (Aadhaar/PAN) or personal text to third-party offshore processors without explicit, granular user consent constitutes an unauthorized data transfer subject to severe statutory penalties.
- **Google Play Data Safety Declaration:** SafeSignal's manifest and code violate Play Store policies if submitted under a "No Data Collected / No Data Shared" declaration due to undeclared third-party network egress in `ChatScreen` and `AiExpertService`.
