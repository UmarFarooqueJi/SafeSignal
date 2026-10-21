# SAFESIGNAL X: FEATURE PRESERVATION MATRIX

**Strict Directive:** RULE 2 (DO NOT BREAK OR REMOVE EXISTING FUNCTIONALITY)  

---

## Feature Preservation Ledger

| Feature Name | Source File | Existing User Workflow | Hardening & Remediation Mandate | Preservation Guarantee |
| :--- | :--- | :--- | :--- | :--- |
| **Home Dashboard** | `lib/features/home/home_screen.dart` | Displays overall security score, scan stats, feature cards, quick actions. | Connect to honest, non-fabricated metrics. Remove synthetic score jitter. | **100% Visual & Interaction Match** |
| **URL Scanner** | `lib/features/url_scanner/url_scanner_screen.dart` | User pastes URL or scans QR code; gets threat breakdown. | Remove direct `_dio.get` from mobile device. Implement robust local canonicalization & punycode decoding. | **100% Visual & Workflow Match** |
| **App Scanner** | `lib/features/app_scanner/app_scanner_screen.dart` | Lists installed apps, calculates risk score, shows permissions. | Remove package prefix whitelist (`com.google.*`, `com.sbi.*`). Add native certificate fingerprint checking. | **100% Visual & Workflow Match** |
| **Device Audit** | `lib/features/device_audit/device_audit_screen.dart` | Checks screen lock, ADB, root status, encryption, and displays history. | Replace naive 6-file check with `safe_device` + native Linux environment inspection. | **100% Visual & Workflow Match** |
| **Wi-Fi Scanner** | `lib/features/wifi_scanner/wifi_scanner_screen.dart` | Checks SSID, BSSID, captive portal status, IP address. | Remove crashing cleartext HTTP probe. Use Android NetworkCapabilities API. | **100% Visual & Workflow Match** |
| **SMS Inbox Scanner** | `lib/features/sms_inbox/sms_inbox_screen.dart` | Scans incoming SMS for financial fraud, digital arrest, utility scams. | Expand regex engine to support Hinglish, Romanized Hindi, and character leetspeak variants. | **100% Visual & Workflow Match** |
| **OTP Guard** | `lib/features/otp_guard/otp_guard_screen.dart` | Redacts OTP codes, flags urgency, warns against sharing. | Retain OTP redaction; add detection for call-forwarding bypass dialers. | **100% Visual & Workflow Match** |
| **Call Shield** | `lib/features/call_shield/call_shield_screen.dart` | Manages blocked callers and spam screening rules. | Connect to official Android `CallScreeningService` role handling. | **100% Visual & Workflow Match** |
| **AI Cyber Chat** | `lib/features/chat/chat_screen.dart` | User asks cyber fraud questions, uploads scam screenshots. | Purge external `api.ocr.space` and `pollinations.ai`. Use on-device ML Kit OCR and local rule/SLM reasoning. | **100% Visual & Workflow Match** |
| **Encrypted Vault** | `lib/features/vault/vault_screen.dart` | Biometric access to encrypted identity cards (Aadhaar, PAN). | Fix zero-auth bypass. Require master PIN/passphrase when biometrics are unconfigured. Bind to Android KeyStore. | **100% Visual & Workflow Match** |
| **Vault Document Viewer** | `lib/features/vault/vault_document_viewer_screen.dart` | Displays decrypted identity card image. | Render directly from in-memory byte buffer (`Image.memory`); stop writing plaintext `.jpg` to disk cache. | **100% Visual & Workflow Match** |
| **Email Breach Checker** | `lib/features/email_breach/email_breach_screen.dart` | Checks email breach history using HIBP. | Maintain k-anonymity SHA-1 prefix protocol; handle offline/network errors gracefully. | **100% Visual & Workflow Match** |
| **Threat Feed** | `lib/features/feed/feed_screen.dart` | Displays security advisories and CERT-In alerts. | Retain curated offline advisory list; enable honest caching. | **100% Visual & Workflow Match** |
| **Social OSINT** | `lib/features/social_osint/social_osint_screen.dart` | Interactive questionnaire for social media privacy audit. | Preserve interactive checklist and privacy score calculator. | **100% Visual & Workflow Match** |
| **Incident Response** | `lib/core/utils/incident_response_constants.dart` | Indian bank freeze numbers, 1930 portal guidelines, FIR generator. | Retain full directory and legal compliance templates; integrate with secure incident history. | **100% Visual & Workflow Match** |
| **Historical Logs** | `lib/features/history/history_screen.dart` | Shows past scans and threat detections. | Fix SharedPreferences `flutter.sms_inbox` double-prefix key bug. | **100% Visual & Workflow Match** |
| **Onboarding & Sign-In** | `lib/features/onboarding/signin_screen.dart` | Walkthrough, login, profile setup. | Eliminate fake authentication claim; transparently establish local secure device profile. | **100% Visual & Workflow Match** |
