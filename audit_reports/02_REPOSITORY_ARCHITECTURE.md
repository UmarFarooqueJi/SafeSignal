# OPERATION SAFESIGNAL: REPOSITORY ARCHITECTURE INVENTORY

**Target Repository:** `SafeSignal`  
**Root Path:** `c:\Users\umar farooque\Downloads\SafeSignal\safesignal`  
**Active Branch:** `main`  
**Git HEAD Commit:** `0b98be8`  
**Language Breakdown:** Dart (Flutter Framework), Kotlin (Android Native), XML, Gradle Groovy  
**State Management:** Flutter Riverpod (`flutter_riverpod: ^2.6.1`) + Ad-hoc `StatefulWidget` states

---

## 1. Annotated Repository Tree & Module Responsibilities

```
safesignal/
├── android/
│   ├── app/
│   │   ├── build.gradle                              [Gradle build config, compileSdk 35, minSdk 24, targetSdk 35]
│   │   └── src/main/
│   │       ├── AndroidManifest.xml                   [Manifest declarations: permissions, receivers, activities]
│   │       ├── kotlin/com/safesignal/app/
│   │       │   ├── BootReceiver.kt                   [BOOT_COMPLETED receiver: restarts SafeSignalService]
│   │       │   ├── CallReceiver.kt                   [DORMANT: PhoneStateListener implementation, NOT IN MANIFEST]
│   │       │   ├── EmailNotificationService.kt       [DORMANT: NotificationListenerService for email apps]
│   │       │   ├── LinkShieldAccessibilityService.kt [DORMANT: AccessibilityService for browser URL scraping, NOT IN MANIFEST]
│   │       │   ├── MainActivity.kt                   [FlutterActivity: platform channels for battery & accessibility settings]
│   │       │   ├── SafeSignalCallScreeningService.kt [CallScreeningService: blocks numbers in shared_preferences]
│   │       │   ├── SafeSignalService.kt              [PARTIAL: Foreground data-sync service stub, no active tasks]
│   │       │   └── SmsReceiver.kt                    [BroadcastReceiver: intercepts SMS, flags scam keywords, posts notification]
│   │       └── res/                                  [Drawables, mipmaps, XML accessibility service config]
│   └── build.gradle                                  [Project-level buildscript, Kotlin 1.9.0, AGP 8.1.0]
├── lib/
│   ├── main.dart                                     [Entry point: initializes Hive, SharedPreferences, Riverpod ProviderScope]
│   ├── core/
│   │   ├── constants/
│   │   │   └── constants.dart                        [Hardcoded UI strings, scam pattern dictionaries, bank keywords]
│   │   ├── models/
│   │   │   ├── alert_model.dart                      [Data model for system security alerts and severity levels]
│   │   │   └── verdict_model.dart                    [Data model for URL/SMS scan verdicts with confidence scores]
│   │   ├── routing/
│   │   │   └── app_router.dart                       [GoRouter configuration: 14 declarative application routes]
│   │   ├── services/
│   │   │   ├── ai_expert_service.dart                [LLM gateway: Groq/OpenAI client with unauthenticated pollinations.ai fallback]
│   │   │   ├── crowd_intel_service.dart              [MOCKED / PLACEHOLDER: Community threat hash submission]
│   │   │   ├── dio_client.dart                       [HTTP client config: Dio with timeouts and custom headers]
│   │   │   ├── hibp_service.dart                     [HIBP k-anonymity SHA-1 breach checker for email leak detection]
│   │   │   ├── llm_orchestrator.dart                 [Circuit breaker orchestrator: manages cloud LLM vs local fallback]
│   │   │   ├── local_rule_engine.dart                [Deterministic heuristic engine: regex-based SMS/URL threat scoring]
│   │   │   ├── pdf_report_service.dart               [PDF generation: compiles formal cyber fraud incident reports]
│   │   │   ├── safesignal_threat_gateway.dart        [Threat lookup gateway: routes queries to local or remote providers]
│   │   │   └── vault_crypto_service.dart             [Cryptographic engine: AES-256-GCM / PBKDF2 encryption for vault]
│   │   ├── theme/
│   │   │   ├── app_theme.dart                        [Material 3 dark theme, cyber-security color palette]
│   │   │   └── typography.dart                       [Custom text styles and font configurations]
│   │   └── utils/
│   │       ├── incident_response_constants.dart      [Indian bank helpline numbers, 1930 portal guidelines, legal templates]
│   │       └── mock_data.dart                        [Hardcoded simulated threat feed items and demo alerts]
│   └── features/
│       ├── app_scanner/
│       │   └── app_scanner_screen.dart               [Audits installed APK permissions, spoofable whitelist heuristic]
│       ├── call_shield/
│       │   └── call_shield_screen.dart               [UI to manage blocked call lists and call screening preferences]
│       ├── chat/
│       │   └── chat_screen.dart                      [Cyber advisor chat UI: triggers third-party OCR API and LLM queries]
│       ├── device_audit/
│       │   └── device_audit_screen.dart              [Audits ADB, screen lock, encryption, naive root detection]
│       ├── email_breach/
│       │   └── email_breach_screen.dart              [HIBP check interface with animated breach results]
│       ├── feed/
│       │   └── feed_screen.dart                      [Curated security threat intelligence feed from CERT-In / news]
│       ├── history/
│       │   └── history_screen.dart                   [Historical audit logs, contains SharedPreferences key prefix bug]
│       ├── home/
│       │   └── home_screen.dart                      [Executive dashboard: overall security score, quick action cards]
│       ├── onboarding/
│       │   ├── onboarding_screen.dart                [First-time user walkthrough slider]
│       │   ├── profile_setup_screen.dart             [Local profile creation: stores name/city in SharedPreferences]
│       │   └── signin_screen.dart                    [MOCKED: simulated 300ms login with no credential validation]
│       ├── otp_guard/
│       │   └── otp_guard_screen.dart                 [Monitors incoming OTPs, redacts sensitive codes, warns of scams]
│       ├── sms_inbox/
│       │   └── sms_inbox_screen.dart                 [Parses on-device SMS messages using local_rule_engine]
│       ├── social_osint/
│       │   └── social_osint_screen.dart              [Privacy checklist and profile hygiene auditor]
│       ├── url_scanner/
│       │   └── url_scanner_screen.dart               [Parses and scores URLs, executes direct GET probe to scanned sites]
│       ├── vault/
│       │   ├── vault_screen.dart                     [Encrypted document vault: contains zero-auth biometric fallback]
│       │   └── vault_document_viewer_screen.dart     [Decrypted image viewer: writes unencrypted files to temporary cache]
│       └── wifi_scanner/
│           └── wifi_scanner_screen.dart              [Audits Wi-Fi SSID/BSSID, crashes on cleartext captive portal probe]
├── test/
│   ├── app_scanner_test.dart                         [RiskEngine unit tests: 5 tests]
│   ├── device_audit_test.dart                        [Device audit history tests: 3 tests]
│   ├── incident_response_test.dart                   [FIR generator & bank directory tests: 2 tests]
│   ├── rule_engine_test.dart                         [LocalRuleEngine regex tests: 3 tests]
│   ├── url_analysis_test.dart                        [URL threat pattern tests: 7 tests]
│   ├── vault_crypto_test.dart                        [AES-256-GCM / CBC encryption tests: 6 tests]
│   └── widget_test.dart                              [App smoke test: 1 test]
└── pubspec.yaml                                      [Project dependencies and assets definition]
```

---

## 2. Technical Implementation Status Categorization

Every file and feature was subjected to static verification against source code.

| Component / File Path | Implementation Status | Real Technical Responsibility |
| :--- | :---: | :--- |
| `lib/core/services/vault_crypto_service.dart` | **IMPLEMENTED** | AES-256-GCM authenticated encryption with PBKDF2 (10,000 iterations) key derivation, HMAC-SHA256 integrity verification, and legacy CBC backward migration. |
| `lib/core/services/local_rule_engine.dart` | **IMPLEMENTED** | Deterministic regex and keyword matching for SMS fraud, electricity bill scams, APK dropper URLs, and digital arrest threats. |
| `lib/core/services/hibp_service.dart` | **IMPLEMENTED** | Real k-anonymity API query (`api.pwnedpasswords.com` / HIBP range API) transmitting only the first 5 characters of SHA-1 hash. |
| `lib/features/chat/chat_screen.dart` | **PARTIALLY IMPLEMENTED (UNSAFE)** | UI functional, but image scanning relies on external unvetted HTTP POST to `api.ocr.space` using hardcoded public API keys. |
| `lib/features/url_scanner/url_scanner_screen.dart` | **PARTIALLY IMPLEMENTED** | Regex parsing functional; live HTTP probing exposes device IP to adversary servers; punycode homograph conversion is absent. |
| `lib/features/app_scanner/app_scanner_screen.dart` | **PARTIALLY IMPLEMENTED** | Queries installed packages via `installed_apps`, but heuristic risk engine contains package name prefix bypass. |
| `lib/features/vault/vault_screen.dart` | **PARTIALLY IMPLEMENTED (BROKEN AUTH)** | Secure encryption logic exists, but biometric check contains complete unauthenticated bypass when biometrics are unconfigured. |
| `lib/features/device_audit/device_audit_screen.dart` | **PARTIALLY IMPLEMENTED** | Screen lock and ADB detection functional; root detection checks 6 static paths; `safe_device` plugin is declared but never imported. |
| `lib/features/wifi_scanner/wifi_scanner_screen.dart` | **PARTIALLY IMPLEMENTED** | Network info retrieved via `network_info_plus`; captive portal detection crashes due to unpermitted cleartext HTTP on Android 9+. |
| `lib/features/onboarding/signin_screen.dart` | **MOCKED** | Authentication is completely simulated with a 300ms `Future.delayed` timer; writes `isLoggedIn: true` without credential verification. |
| `lib/features/feed/feed_screen.dart` | **HARDCODED** | Displays static mock list of security advisories; does not query dynamic CERT-In or threat feeds at runtime. |
| `lib/features/social_osint/social_osint_screen.dart` | **UI-ONLY** | Static educational checklist of social media privacy settings; zero automated OSINT discovery or analysis. |
| `android/src/main/kotlin/.../LinkShieldAccessibilityService.kt` | **DORMANT / NOT IN MANIFEST** | Kotlin source exists to scrape browser URLs, but omitted from `AndroidManifest.xml` and lacks required BIND_ACCESSIBILITY_SERVICE permission. |
| `android/src/main/kotlin/.../CallReceiver.kt` | **DORMANT / NOT IN MANIFEST** | Broadcast receiver for phone state changes exists in Kotlin, but undeclared in manifest; zero runtime execution. |
| `android/src/main/kotlin/.../SafeSignalService.kt` | **STUB / PARTIALLY IMPLEMENTED** | Declared as `dataSync` foreground service, but executes zero background sync tasks, creating Play Store policy compliance risk. |

---

## 3. Platform Channels & Native Android Integration

The Flutter app communicates with native Android code via two distinct Platform Channels defined in `MainActivity.kt`:

1. **`com.safesignal.app/accessibility` (MethodChannel):**
   - Implements `isAccessibilityServiceEnabled` and `openAccessibilitySettings`.
   - Checks whether `LinkShieldAccessibilityService` is enabled in `Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES`.
   - **Flaw:** Because `LinkShieldAccessibilityService` is not declared in `AndroidManifest.xml`, Android OS will never register it as a valid accessibility provider, causing this check to always return `false`.

2. **`com.safesignal.app/battery` (MethodChannel):**
   - Implements `isIgnoringBatteryOptimizations` and `requestIgnoreBatteryOptimizations`.
   - Prompts the user to whitelist SafeSignal from Android OEM aggressive battery killers (`PowerManager.isIgnoringBatteryOptimizations`).
   - Works as intended on standard Android builds.

---

## 4. State Management Architecture

The application adopts `flutter_riverpod` (v2.6.1) as its declared architectural standard, but implementation discipline is highly fragmented:
- **Global Providers:** Declared in `lib/core/` for theme, router, and simple SharedPreferences wrappers.
- **Screen-Level State:** Over 80% of feature screens (`app_scanner_screen.dart`, `vault_screen.dart`, `url_scanner_screen.dart`, `wifi_scanner_screen.dart`, `device_audit_screen.dart`) bypass Riverpod entirely, managing complex async operations, scanning lifecycles, and cryptographic keys using monolithic `StatefulWidget` classes and direct `setState()` calls.
- **Isolate Architecture:** Zero compute isolates are spawned for CPU-intensive cryptographic hashing, regex batch scanning, or APK package parsing. All calculations execute directly on the Dart UI isolate, causing noticeable UI frame drops when processing large sets of installed packages or SMS messages.
