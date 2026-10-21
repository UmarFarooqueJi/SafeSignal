# OPERATION SAFESIGNAL: ENGINE-BY-ENGINE TECHNICAL DOSSIER

**Target:** SafeSignal Android Security Modules  
**Evaluation Methodology:** In-Depth Algorithmic Analysis, Source Code Auditing, and Empirical Attack Surface Mapping

---

## Engine 1: Local Rule & Heuristic Detection Engine

### A. Engine Identity
- **Technical Purpose:** Deterministic pattern recognition and risk scoring for SMS fraud, financial extortion, phishing URLs, and social engineering vectors.
- **Source Files:** `lib/core/services/local_rule_engine.dart`, `lib/core/constants/constants.dart`
- **Entry Points:** `LocalRuleEngine.analyzeSms(String text)`, `LocalRuleEngine.analyzeUrl(String url)`
- **Dependencies:** Standard Dart core libraries (`dart:core`, `RegExp`).
- **Public APIs:** `analyzeSms(text) -> VerdictModel`, `analyzeUrl(url) -> VerdictModel`

### B. Real Internal Working
The engine is a purely deterministic heuristic parser operating across three sequential stages:
1. **Keyword Dictionaries & Regex Matching:** Compares input strings against precompiled regex patterns and static lists:
   - *Digital Arrest / Law Enforcement:* `cbi`, `cyber crime`, `police`, `customs`, `arrest warrant`, `narcotics`.
   - *Utility / Disconnection Fraud:* `electricity bill`, `power cut`, `update kyc`, `eb bill`.
   - *Banking & Financial Scams:* `lottery`, `congratulations`, `winner`, `pan expired`, `account suspended`.
   - *Remote Access Trojans (RATs):* `anydesk`, `teamviewer`, `rustdesk`, `quicksupport`.
   - *Call Hijack Strings:* `*21*`, `*401*`, `**21*`.
2. **Scoring Accumulator:** Assigns weighted risk integers per hit (e.g., +40 for digital arrest, +35 for RAT keywords, +25 for urgency phrases like "immediately"). Scores are clamped between 0 and 100.
3. **Verdict Generation:** Returns a `VerdictModel` categorized as `Safe` (0-29), `Suspicious` (30-69), or `Scam/Critical` (70-100) with human-readable rationale strings.

### C. Security Effectiveness
- **Detectable Threats:** Traditional, un-obfuscated SMS scams containing standard English keywords (e.g., "Electricity power will be disconnected tonight. Call officer at 98xxxx").
- **Undetectable Threats:**
  - Multilingual / Hinglish / Regional scams (e.g., "Aapka bijli connection aaj raat kat diya jayega").
  - Obfuscated / Leetspeak variants (e.g., `El3ctricity`, `P0lice`, `C-B-I`, `K.Y.C`).
  - Zero-day scam templates without predefined lexical anchors.
- **Evasion Opportunities:** Zero linguistic stemming or homoglyph normalization. Replacing characters with unicode lookalikes completely defeats pattern matching.
- **Performance & Battery:** Extremely fast (<2ms execution time); minimal memory and zero battery impact.

### D. Ratings
- Implementation Completeness: **8.5 / 10**
- Detection Effectiveness: **4.0 / 10**
- Security Robustness: **5.0 / 10**
- Technical Sophistication: **3.5 / 10**
- Performance Engineering: **9.0 / 10**
- Production Readiness: **6.0 / 10**

---

## Engine 2: URL & Phishing Scanner

### A. Engine Identity
- **Technical Purpose:** Evaluates web links for malicious indicators, typo-squatting, APK droppers, and IP reputation.
- **Source Files:** `lib/features/url_scanner/url_scanner_screen.dart`, `lib/core/services/safesignal_threat_gateway.dart`
- **Entry Points:** `_scanUrl(String url)` in `UrlScannerScreen`
- **Dependencies:** `dio`, `url_launcher`
- **Public APIs:** Internal screen controller methods.

### B. Real Internal Working
1. **Syntactic Heuristics:**
   - Detects raw IP addresses as hosts (`RegExp(r'^https?://\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')`).
   - Checks for URL shorteners (`bit.ly`, `tinyurl.com`, `is.gd`, `t.co`).
   - Flags dangerous file extensions (`.apk`, `.exe`, `.scr`, `.bat`).
   - Flags suspicious high-risk TLDs (`.top`, `.xyz`, `.club`, `.work`).
2. **Live HTTP Probing (VULNERABILITY):**
   - Directly executes `_dio.get(url, options: Options(validateStatus: (_) => true))` with header `User-Agent: Mozilla/5.0 (SafeSignal Security Scanner 1.0)`.
   - Inspects response headers for redirect chains and content-type.

### C. Security Effectiveness
- **Critical Vulnerability (SEC-06):** Probing target links directly from the user's mobile device reveals the user's carrier IP address and cellular location to the attacker's infrastructure.
- **Evasion Opportunities:**
  - Punycode internationalized domain names (IDN homograph attacks) are NOT decoded or normalized before evaluation.
  - Phishing sites serving cloaked content to non-mobile user agents easily evade static heuristics.
- **False Positives:** Legitimate enterprise domains hosted on `.top` or using standard link shorteners receive elevated threat penalties.

### D. Ratings
- Implementation Completeness: **6.0 / 10**
- Detection Effectiveness: **4.5 / 10**
- Security Robustness: **3.0 / 10**
- Technical Sophistication: **4.0 / 10**
- Performance Engineering: **6.5 / 10**
- Production Readiness: **4.0 / 10**

---

## Engine 3: App & Permission Auditor

### A. Engine Identity
- **Technical Purpose:** Audits installed Android applications, inspects requested dangerous permissions, and flags potential stalkerware, banking trojans, and malicious sideloads.
- **Source Files:** `lib/features/app_scanner/app_scanner_screen.dart`
- **Entry Points:** `_loadInstalledApps()`, `_calculateRiskScore(AppInfo app)`
- **Dependencies:** `installed_apps: ^0.1.3`
- **Public APIs:** Internal UI state methods.

### B. Real Internal Working
1. **Package Discovery:** Queries Android `PackageManager` via `installed_apps` plugin to retrieve all installed applications with requested permissions and installer package names.
2. **Permission Weighting:** Adds risk weights for high-risk Android permissions:
   - `RECEIVE_SMS` / `READ_SMS`: +30
   - `SYSTEM_ALERT_WINDOW` (Overlay): +25
   - `RECORD_AUDIO` / `CAMERA`: +20
   - `ACCESS_FINE_LOCATION`: +15
   - `REQUEST_INSTALL_PACKAGES`: +20
3. **Flawed Ecosystem Whitelist (SEC-03):**
   - Invokes `_isVerifiedEcosystem(app.packageName)`.
   - Hardcoded string prefix check:
     ```dart
     if (packageName.startsWith('com.google.') ||
         packageName.startsWith('com.sbi.') ||
         packageName.startsWith('com.whatsapp') ||
         packageName.startsWith('com.android.')) {
       return true;
     }
     ```
   - If true, forcibly sets `isSideloaded = false` and clamps total risk score to maximum 38.

### C. Security Effectiveness
- **Detectable Threats:** Naive sideloaded APKs with generic package names requesting SMS and overlay permissions.
- **Undetectable Threats:**
  - Any malware adopting package names matching whitelisted prefixes (e.g., `com.sbi.security.update`, `com.google.play.service.installer`).
  - Malware utilizing native code execution (`.so` payloads) or reflection to bypass static manifest analysis.
  - Legitimate Play Store apps that have been trojanized via malicious dynamic code loading (DCL).
- **Architecture Weakness:** Operates synchronously on the UI isolate, causing noticeable UI frame drops when parsing 100+ installed packages.

### D. Ratings
- Implementation Completeness: **6.0 / 10**
- Detection Effectiveness: **3.0 / 10**
- Security Robustness: **2.5 / 10**
- Technical Sophistication: **3.5 / 10**
- Performance Engineering: **5.0 / 10**
- Production Readiness: **3.0 / 10**

---

## Engine 4: Cryptographic Vault Engine

### A. Engine Identity
- **Technical Purpose:** Provides authenticated AES-256-GCM encryption for storing sensitive identity documents (Aadhaar, PAN, passports) and private credentials locally.
- **Source Files:** `lib/core/services/vault_crypto_service.dart`, `lib/features/vault/vault_screen.dart`, `lib/features/vault/vault_document_viewer_screen.dart`
- **Entry Points:** `VaultCryptoService.encryptData()`, `VaultCryptoService.decryptData()`, `_authenticate()` in `VaultScreen`
- **Dependencies:** `cryptography: ^2.7.0`, `hive: ^2.2.3`, `local_auth: ^2.2.0`
- **Public APIs:** `encryptData(Uint8List, String password)`, `decryptData(Uint8List, String password)`

### B. Real Internal Working
1. **Key Derivation:** Uses PBKDF2 with HMAC-SHA256, 10,000 iterations, and a randomly generated 16-byte salt to derive a 256-bit symmetric encryption key from the user-provided password.
2. **Authenticated Encryption:** Uses AES-256-GCM with a 12-byte initialization vector (IV) and a 16-byte authentication tag to guarantee confidentiality and ciphertext integrity.
3. **Data Serialization:** Prepends salt (16 bytes) and IV (12 bytes) to the ciphertext and auth tag for single-blob storage.
4. **Legacy Migration:** Detects legacy AES-256-CBC payloads from prior releases and automatically migrates them to AES-GCM upon successful decryption.
5. **Decoupled Biometric Access (SEC-04):**
   - Biometric authentication is handled independently via `local_auth.authenticate()`.
   - On devices where biometrics are unavailable or not enrolled (`_hasBiometrics == false`), the application executes:
     ```dart
     if (!_hasBiometrics) {
       _loadItems(); // Automatically decrypts vault with default master key!
       return;
     }
     ```
6. **Decrypted File Leakage (SEC-05):**
   - In `vault_document_viewer_screen.dart`, viewing an image writes plaintext `.jpg` bytes to the system temporary directory (`getTemporaryDirectory()`), relying on an ephemeral 10-second timer to shred it.

### C. Security Effectiveness
- **Cryptographic Primitives:** The algorithmic implementation of AES-256-GCM and PBKDF2 in `vault_crypto_service.dart` is technically sound, RFC-compliant, and successfully validated across 6 unit tests.
- **Architectural Failure:** The cryptographic keys are NOT bound to Android Keystore `CryptoObject` or hardware-backed StrongBox/TEE.
- **Critical Auth Bypass:** The unauthenticated fallback on non-biometric devices nullifies the cryptographic protection, allowing anyone holding the device to view all stored identity records.

### D. Ratings
- Implementation Completeness: **7.5 / 10**
- Detection Effectiveness: **N/A (Cryptographic Engine)**
- Security Robustness: **4.0 / 10** (Crippled by auth bypass & temp file exposure)
- Technical Sophistication: **7.0 / 10**
- Performance Engineering: **8.0 / 10**
- Production Readiness: **4.5 / 10**

---

## Engine 5: Device Security Auditor

### A. Engine Identity
- **Technical Purpose:** Evaluates underlying Android OS configuration, developer options, screen lock status, and rootkit compromise.
- **Source Files:** `lib/features/device_audit/device_audit_screen.dart`
- **Entry Points:** `_runAudit()`
- **Dependencies:** `device_info_plus`, `local_auth`, `flutter_secure_storage`
- **Public APIs:** Internal UI state methods.

### B. Real Internal Working
1. **Screen Lock Verification:** Checks `local_auth.isDeviceSupported()` and `canCheckBiometrics`.
2. **Developer Mode / ADB Detection:** Reads Android OS flags to determine if ADB debugging is active.
3. **Root Detection:** Checks for the presence of 6 static binary files:
   - `/system/bin/su`, `/system/xbin/su`, `/sbin/su`, `/system/sd/xbin/su`, `/system/bin/failsafe/su`, `/data/local/su`.
4. **Historical Score Normalization:** Reads prior audit scores from SharedPreferences and plots trends on a historical chart.

### C. Security Effectiveness
- **Root Detection Efficacy:** Extremely poor. Modern root solutions (Magisk, KernelSU, APatch) utilize mount namespace separation, isolated user mounts, and dynamic DenyList mechanisms that completely hide `su` binaries from userland path checks.
- **Unused Dependency:** `safe_device` is declared in `pubspec.yaml` but is NEVER imported in `device_audit_screen.dart`.
- **TAMPERING IMMUNITY:** Zero integrity checks on own APK signature or DEX bytecode.

### D. Ratings
- Implementation Completeness: **6.0 / 10**
- Detection Effectiveness: **3.0 / 10**
- Security Robustness: **3.5 / 10**
- Technical Sophistication: **3.5 / 10**
- Performance Engineering: **8.0 / 10**
- Production Readiness: **4.5 / 10**

---

## Engine 6: Network & Wi-Fi Inspector

### A. Engine Identity
- **Technical Purpose:** Audits connected Wi-Fi networks for rogue AP indicators, captive portal redirection, and insecure open protocols.
- **Source Files:** `lib/features/wifi_scanner/wifi_scanner_screen.dart`
- **Entry Points:** `_scanWifi()`
- **Dependencies:** `network_info_plus: ^5.0.1`, `http: ^1.2.2`
- **Public APIs:** Internal screen controller methods.

### B. Real Internal Working
1. **Network Metadata:** Queries `NetworkInfo().getWifiName()`, `getWifiBSSID()`, and `getWifiIP()`.
2. **Captive Portal Check:** Attempts an HTTP GET request to `http://connectivitycheck.gstatic.com/generate_204`.
   - If response status is not 204 or redirect occurs, flags captive portal presence.
   - **Critical Bug (SEC-10):** Because `android:usesCleartextTraffic="false"` is enforced in `AndroidManifest.xml` (API 28+ default), cleartext HTTP calls throw an unhandled `SocketException`, falsely penalizing network security scores.

### C. Security Effectiveness
- **Detectable Threats:** Basic open/unencrypted Wi-Fi networks (SSIDs without WPA2/WPA3).
- **Undetectable Threats:**
  - Evil Twin attacks with cloned BSSID and SSID.
  - SSL-stripping proxies and DNS hijacking.
  - ARP cache poisoning (no native `/proc/net/arp` inspection).
- **Reliability:** Defective on modern Android versions due to cleartext network policy violations.

### D. Ratings
- Implementation Completeness: **5.0 / 10**
- Detection Effectiveness: **3.0 / 10**
- Security Robustness: **3.0 / 10**
- Technical Sophistication: **3.0 / 10**
- Performance Engineering: **6.0 / 10**
- Production Readiness: **3.0 / 10**

---

## Engine 7: LLM Orchestration & AI Gateway

### A. Engine Identity
- **Technical Purpose:** Provides intelligent natural-language reasoning for cyber fraud inquiries, scam analysis, and emergency incident advice.
- **Source Files:** `lib/core/services/llm_orchestrator.dart`, `lib/core/services/ai_expert_service.dart`, `lib/core/services/safesignal_threat_gateway.dart`
- **Entry Points:** `AiExpertService.askAssistant()`, `LlmOrchestrator.queryWithFallback()`
- **Dependencies:** `dio`, `http`, `flutter_dotenv`
- **Public APIs:** `askAssistant(String prompt) -> Future<String>`

### B. Real Internal Working
1. **API Key Routing:** Checks for configured API keys (OpenAI / Groq) via environment variables or settings.
2. **Circuit Breaker:** Attempts remote cloud inference if API keys are available.
3. **Unauthenticated Public Proxy Fallback (SEC-02):**
   - If cloud API keys are empty or fail, it makes an unauthenticated HTTP GET request to:
     `https://text.pollinations.ai/prompt?model=openai`
   - Transmits full user context, question strings, and security parameters to a public, unvetted server without user knowledge or opt-in.
4. **Deterministic Fallback:** If Pollinations fails, falls back to static hardcoded advice strings from `LocalRuleEngine`.

### C. Security Effectiveness
- **Operational Reality:** There is ZERO on-device AI or SLM execution. Claims of "On-Device AI" are completely false.
- **Privacy Impact:** Direct exfiltration of user sensitive queries to third-party public AI proxies.
- **Adversarial Robustness:** Highly vulnerable to prompt injection if the user feeds untrusted SMS strings directly into the chat prompt.

### D. Ratings
- Implementation Completeness: **5.5 / 10**
- Detection Effectiveness: **5.0 / 10**
- Security Robustness: **2.0 / 10**
- Technical Sophistication: **4.0 / 10**
- Performance Engineering: **6.0 / 10**
- Production Readiness: **2.5 / 10**

---

## Engine 8: Threat Intelligence & OSINT

### A. Engine Identity
- **Technical Purpose:** Queries known credential leak databases, social engineering feeds, and community threat repositories.
- **Source Files:** `lib/core/services/hibp_service.dart`, `lib/core/services/crowd_intel_service.dart`, `lib/features/social_osint/social_osint_screen.dart`
- **Entry Points:** `HibpService.checkBreach(String email)`
- **Dependencies:** `http`, `crypto`
- **Public APIs:** `checkBreach(email) -> Future<List<BreachResult>>`

### B. Real Internal Working
1. **HIBP Implementation:**
   - Computes SHA-1 hash of target email/password.
   - Implements k-anonymity: transmits first 5 characters of SHA-1 hash to `https://api.pwnedpasswords.com/range/{prefix}`.
   - Searches response body locally for matching suffix and breach count.
2. **Crowd Intelligence:**
   - `crowd_intel_service.dart` is entirely mocked/placeholder code; returns simulated JSON counts with zero active backend API endpoints.
3. **Social OSINT:**
   - `social_osint_screen.dart` is an interactive questionnaire checklist; executes zero network intelligence or API queries.

### C. Security Effectiveness
- **HIBP:** Sound implementation preserving user privacy via k-anonymity.
- **Crowd Intel & OSINT:** Non-functional; provides cosmetic reassurance without substantive intelligence.

### D. Ratings
- Implementation Completeness: **4.0 / 10**
- Detection Effectiveness: **4.0 / 10**
- Security Robustness: **6.0 / 10**
- Technical Sophistication: **4.5 / 10**
- Performance Engineering: **7.5 / 10**
- Production Readiness: **4.0 / 10**
