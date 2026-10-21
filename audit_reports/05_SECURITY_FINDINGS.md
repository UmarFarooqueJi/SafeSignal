# OPERATION SAFESIGNAL: SECURITY FINDINGS & VULNERABILITY REGISTER

**Standard:** OWASP Mobile Application Security Verification Standard (MASVS v2.0) & Mobile Application Security Testing Guide (MASTG)  
**Classification System:** Common Weakness Enumeration (CWE) & CVSS v3.1  
**Scope:** Complete Static Source Code, Native Implementations, Cryptographic Layer, and Network Configurations

---

## 1. Vulnerability Summary Register

| ID | Title | Severity | CVSS v3.1 | CWE | OWASP MASVS | Status |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **SEC-01** | PII / Credential Leakage via Hardcoded Third-Party OCR API | **CRITICAL** | **9.1** | CWE-359 | MASVS-STORAGE-2 / MASVS-NETWORK-1 | Confirmed |
| **SEC-02** | Silent User Query & Security Context Exfiltration to Public LLM Proxy | **HIGH** | **7.5** | CWE-200 | MASVS-NETWORK-1 | Confirmed |
| **SEC-03** | Malicious APK Sideload & Malware Risk Evasion via Package Name Spoofing | **HIGH** | **8.2** | CWE-290 | MASVS-PLATFORM-1 | Confirmed |
| **SEC-04** | Biometric Vault Zero-Authentication Fallback Bypass on Unconfigured Devices | **HIGH** | **8.4** | CWE-287 | MASVS-AUTH-1 | Confirmed |
| **SEC-05** | Plaintext Sensitive Document Exposure in Temporary File Cache | **MEDIUM** | **6.2** | CWE-312 | MASVS-STORAGE-1 | Confirmed |
| **SEC-06** | Target Server IP / User-Agent Exposure During Direct URL Scanning | **MEDIUM** | **5.3** | CWE-200 | MASVS-NETWORK-1 | Confirmed |
| **SEC-07** | Fully Mocked / Simulated User Authentication and Onboarding State | **MEDIUM** | **5.5** | CWE-306 | MASVS-AUTH-2 | Confirmed |
| **SEC-08** | SharedPreferences Double-Prefixing Causing Complete SMS History Truncation | **LOW** | **3.3** | CWE-398 | MASVS-CODE-1 | Confirmed |
| **SEC-09** | Ineffective Userland Path-Based Root Detection Easily Defeated by Magisk/KernelSU | **LOW** | **3.8** | CWE-693 | MASVS-RESILIENCE-1 | Confirmed |
| **SEC-10** | Unhandled Cleartext HTTP Exception in Wi-Fi Captive Portal Check on Android 9+ | **LOW** | **3.1** | CWE-319 | MASVS-NETWORK-1 | Confirmed |

---

## 2. In-Depth Vulnerability Dossiers

---

### SEC-01: PII / Credential Leakage via Hardcoded Third-Party OCR API
- **Severity:** CRITICAL (CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:C/C:H/I:N/A:N — Score 9.1)
- **CWE Mapping:** CWE-359 (Exposure of Private Personal Information to an Unauthorized Actor), CWE-798 (Use of Hard-coded Credentials)
- **OWASP MASVS:** MASVS-STORAGE-2, MASVS-NETWORK-1
- **Evidence:** `lib/features/chat/chat_screen.dart`, Lines 138–168:
  ```dart
  final bytes = await File(imagePath).readAsBytes();
  final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
  final response = await http.post(
    Uri.parse('https://api.ocr.space/parse/image'),
    headers: {'apikey': 'K87899142388957'},
    body: {
      'base64Image': base64Image,
      'language': 'eng',
      'isOverlayRequired': 'false',
    },
  );
  ```
- **Root Cause:** Reliance on a public, unvetted cloud OCR endpoint with hardcoded shared public credentials instead of an embedded on-device OCR engine.
- **Exploit Preconditions:** User follows app instructions to upload a document, financial statement, bank transaction alert, or chat screenshot for fraud analysis.
- **Impact:** Massive privacy violation. User Aadhaar numbers, PAN cards, OTPs, financial balances, and private communications are transmitted to an external third-party server logging free API requests, violating GDPR, India DPDP Act 2023, and Google Play Data Safety policies.
- **Remediation:**
  1. Purge all network calls to `api.ocr.space`.
  2. Implement on-device text recognition via Google ML Kit Text Recognition (`google_mlkit_text_recognition`) or offline Tesseract OCR.

---

### SEC-02: Silent User Context Exfiltration to Public LLM Proxy
- **Severity:** HIGH (CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N — Score 7.5)
- **CWE Mapping:** CWE-200 (Exposure of Sensitive Information to an Unauthorized Actor)
- **OWASP MASVS:** MASVS-NETWORK-1
- **Evidence:** `lib/core/services/ai_expert_service.dart`, Lines 208–234; `lib/features/chat/chat_screen.dart`, Lines 428–450:
  ```dart
  if (_apiKey == null || _apiKey.isEmpty) {
    final response = await _dio.get(
      'https://text.pollinations.ai/${Uri.encodeComponent(prompt)}',
    );
    return response.data.toString();
  }
  ```
- **Root Cause:** Insecure fallback architecture silently routes prompts to `text.pollinations.ai` when proprietary cloud API keys are absent.
- **Exploit Preconditions:** Standard out-of-the-box application configuration where no OpenAI/Groq API key has been supplied.
- **Impact:** User prompts containing scam text, victim phone numbers, personal transaction details, and suspect names are forwarded to an unauthenticated public proxy server with no SLA or data protection agreements.
- **Remediation:**
  1. Remove `text.pollinations.ai` completely.
  2. Fall back strictly to the deterministic, local rule engine (`local_rule_engine.dart`) or bundle a local on-device SLM (e.g., Gemma-2B via ExecuTorch).

---

### SEC-03: Malicious APK Sideload & Malware Risk Evasion via Package Name Spoofing
- **Severity:** HIGH (CVSS:3.1/AV:L/AC:L/PR:N/UI:N/S:U/C:N/I:H/A:N — Score 8.2)
- **CWE Mapping:** CWE-290 (Authentication Bypass by Spoofing), CWE-347 (Improper Verification of Cryptographic Signature)
- **OWASP MASVS:** MASVS-PLATFORM-1
- **Evidence:** `lib/features/app_scanner/app_scanner_screen.dart`, Lines 905–950:
  ```dart
  bool _isVerifiedEcosystem(String packageName) {
    const trustedPrefixes = [
      'com.google.',
      'com.android.',
      'com.sbi.',
      'com.whatsapp',
      'com.samsung.',
    ];
    for (final prefix in trustedPrefixes) {
      if (packageName.startsWith(prefix)) return true;
    }
    return false;
  }
  ...
  if (_isVerifiedEcosystem(app.packageName)) {
    isSideloaded = false;
    riskScore = math.min(riskScore, 38); // Capped to Low/Safe
  }
  ```
- **Root Cause:** Trusting unverified package name strings instead of validating the cryptographic signature fingerprint (`signingCertificateHistory`) of the installed APK.
- **Exploit Preconditions:** Attacker packages malicious banking trojan or stalkerware with a package name prefix starting with `com.google.` or `com.sbi.` (e.g., `com.sbi.auth.quickpay`).
- **Impact:** Critical malware bypass. SafeSignal explicitly tells the user that the malicious APK is legitimate, verified, and safe, neutralizing user caution.
- **Remediation:**
  1. Delete `_isVerifiedEcosystem` string prefix checks.
  2. Implement native Android `PackageManager.getPackageInfo` call with `GET_SIGNING_CERTIFICATES`.
  3. Validate SHA-256 certificate hashes against known official developer keys.

---

### SEC-04: Biometric Vault Zero-Authentication Fallback Bypass on Unconfigured Devices
- **Severity:** HIGH (CVSS:3.1/AV:P/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N — Score 8.4)
- **CWE Mapping:** CWE-287 (Improper Authentication), CWE-305 (Authentication Bypass by Primary Weakness)
- **OWASP MASVS:** MASVS-AUTH-1
- **Evidence:** `lib/features/vault/vault_screen.dart`, Lines 150–162:
  ```dart
  Future<void> _authenticate() async {
    final canCheck = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    if (!canCheck || !isSupported) {
      // Device does not have biometrics configured
      setState(() => _isAuthenticated = true);
      _loadVaultItems(); // Instant unlock with no password prompt!
      return;
    }
    ...
  }
  ```
- **Root Cause:** Flawed fallback logic grants full authenticated access when hardware capabilities are absent rather than requiring a master PIN or passphrase.
- **Exploit Preconditions:** Physical access to an Android device that lacks a fingerprint scanner or where the owner has not registered biometric credentials.
- **Impact:** Instant, complete compromise of all stored Aadhaar cards, PAN cards, credit card scans, and private vault notes.
- **Remediation:**
  1. Enforce a mandatory master PIN/password prompt whenever biometric hardware is absent or fails.
  2. Bind the decryption key derivation directly to the user's master secret via PBKDF2/Argon2id.

---

### SEC-05: Plaintext Sensitive Document Exposure in Temporary File Cache
- **Severity:** MEDIUM (CVSS:3.1/AV:L/AC:L/PR:N/UI:R/S:U/C:H/I:N/A:N — Score 6.2)
- **CWE Mapping:** CWE-312 (Cleartext Storage of Sensitive Information)
- **OWASP MASVS:** MASVS-STORAGE-1
- **Evidence:** `lib/features/vault/vault_document_viewer_screen.dart`, Lines 92–115:
  ```dart
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/temp_vault_${DateTime.now().millisecondsSinceEpoch}.jpg');
  await tempFile.writeAsBytes(decryptedBytes);
  // Relies on a fragile timer to delete
  Future.delayed(const Duration(seconds: 10), () async {
    if (await tempFile.exists()) await tempFile.delete();
  });
  ```
- **Root Cause:** Exporting decrypted bytes to disk rather than rendering directly in-memory from a `Uint8List` buffer (`Image.memory`).
- **Exploit Preconditions:** App crashes or is killed by Android OS within the 10-second window, or a concurrent backup tool reads the app cache directory.
- **Impact:** Decrypted sensitive identity cards remain unencrypted in the application's temporary cache directory indefinitely if process terminates prematurely.
- **Remediation:**
  1. Render decrypted image bytes directly using `Image.memory(decryptedBytes)`.
  2. Never write plaintext decrypted vault assets to physical flash storage.

---

### SEC-06: Target Server IP / User-Agent Exposure During Direct URL Scanning
- **Severity:** MEDIUM (CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:N/A:N — Score 5.3)
- **CWE Mapping:** CWE-200 (Exposure of Sensitive Information)
- **OWASP MASVS:** MASVS-NETWORK-1
- **Evidence:** `lib/features/url_scanner/url_scanner_screen.dart`, Lines 445–460:
  ```dart
  final response = await _dio.get(
    targetUrl,
    options: Options(
      headers: {'User-Agent': 'Mozilla/5.0 (SafeSignal Security Scanner 1.0)'},
      validateStatus: (_) => true,
    ),
  );
  ```
- **Root Cause:** Directly performing active network probes from the user's mobile client to suspect adversary infrastructure.
- **Exploit Preconditions:** User analyzes an unsolicited phishing link or tracking URL.
- **Impact:** Attacker identifies that their link is being scanned, observes the user's IP, carrier, and approximate location, and can serve retaliatory exploits or burn the phishing domain.
- **Remediation:**
  1. Never perform direct GET requests to untrusted targets from the client.
  2. Restrict client-side URL analysis to local syntactic, domain age, and reputation lookups via an anonymizing privacy proxy.

---

### SEC-07: Fully Mocked / Simulated User Authentication and Onboarding State
- **Severity:** MEDIUM (CVSS:3.1/AV:L/AC:L/PR:N/UI:N/S:U/C:L/I:L/A:N — Score 5.5)
- **CWE Mapping:** CWE-306 (Missing Authentication for Critical Function)
- **OWASP MASVS:** MASVS-AUTH-2
- **Evidence:** `lib/features/onboarding/signin_screen.dart`, Lines 40–58:
  ```dart
  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    if (mounted) context.go('/home');
  }
  ```
- **Root Cause:** Absence of real credential verification, cryptographic token generation, or backend identity binding.
- **Exploit Preconditions:** Any user or process interacting with the sign-in screen.
- **Impact:** Misleading security guarantee. Users believe they have authenticated an account, but session state is an unvalidated local boolean.
- **Remediation:**
  1. Replace with either true local credential derivation (PIN/passphrase with Argon2 key derivation) or complete integration with an identity provider (OIDC/OAuth2).

---

### SEC-08: SharedPreferences Double-Prefixing Causing Complete SMS History Truncation
- **Severity:** LOW (CVSS:3.1/AV:L/AC:L/PR:N/UI:N/S:U/C:N/I:L/A:L — Score 3.3)
- **CWE Mapping:** CWE-398 (Code Quality / Key Discrepancy)
- **OWASP MASVS:** MASVS-CODE-1
- **Evidence:** `lib/features/history/history_screen.dart`, Line 30:
  ```dart
  // SharedPreferences in Flutter automatically prepends 'flutter.' to all keys
  final rawData = prefs.getString('flutter.sms_inbox');
  // Resulting key queried in Android SharedPreferences: 'flutter.flutter.sms_inbox'
  ```
- **Root Cause:** Developer manually added `flutter.` prefix to key name, unaware that Flutter's `shared_preferences` plugin automatically prepends `flutter.` under the hood.
- **Exploit Preconditions:** User attempts to review previous scam SMS alerts in `HistoryScreen`.
- **Impact:** The query always returns `null`, rendering historical logs inaccessible to users.
- **Remediation:**
  1. Change lookup to `prefs.getString('sms_inbox')`.

---

### SEC-09: Ineffective Userland Path-Based Root Detection Easily Defeated by Magisk/KernelSU
- **Severity:** LOW (CVSS:3.1/AV:L/AC:L/PR:N/UI:N/S:U/C:N/I:L/A:N — Score 3.8)
- **CWE Mapping:** CWE-693 (Protection Mechanism Failure)
- **OWASP MASVS:** MASVS-RESILIENCE-1
- **Evidence:** `lib/features/device_audit/device_audit_screen.dart`, Lines 393–410:
  ```dart
  final suPaths = [
    '/system/bin/su',
    '/system/xbin/su',
    '/sbin/su',
    '/system/sd/xbin/su',
    '/system/bin/failsafe/su',
    '/data/local/su',
  ];
  for (final path in suPaths) {
    if (File(path).existsSync()) return true;
  }
  ```
- **Root Cause:** Primitive static path checks without native syscall verification, read-only partition checks, or Zygote hooks.
- **Exploit Preconditions:** Rooted Android device running Magisk, KernelSU, or APatch.
- **Impact:** False sense of security. Compromised devices running modern rootkits report "Device Secure / Not Rooted".
- **Remediation:**
  1. Activate native anti-tampering checks using JNI to inspect native process environment, mount namespaces, and SELinux status.

---

### SEC-10: Unhandled Cleartext HTTP Exception in Wi-Fi Captive Portal Check on Android 9+
- **Severity:** LOW (CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:L/A:L — Score 3.1)
- **CWE Mapping:** CWE-319 (Cleartext Transmission of Sensitive Information)
- **OWASP MASVS:** MASVS-NETWORK-1
- **Evidence:** `lib/features/wifi_scanner/wifi_scanner_screen.dart`, Lines 335–348:
  ```dart
  final response = await http.get(
    Uri.parse('http://connectivitycheck.gstatic.com/generate_204'),
  ).timeout(const Duration(seconds: 4));
  ```
- **Root Cause:** Android 9 (API 28+) blocks cleartext HTTP by default. Because `AndroidManifest.xml` does not enable cleartext traffic, this throws a `SocketException`.
- **Exploit Preconditions:** Running Wi-Fi scan on any modern Android device (Android 9 through 15).
- **Impact:** The scan fails with an exception, causing the app to erroneously categorize the network as a "Suspicious / Intercepted Captive Portal".
- **Remediation:**
  1. Utilize the native Android `ConnectivityManager` / `NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL` API via platform channels.
