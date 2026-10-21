# SAFESIGNAL X: BASELINE REPOSITORY & ARCHITECTURE INVENTORY

**Project:** SafeSignal  
**Branch:** `feature/safesignal-x-security-transformation`  
**Base Commit:** `0b98be8`  
**Date:** October 2026  
**Execution Lead:** Principal Platform & Application Security Engineering Team  

---

## 1. System & Runtime Baseline

- **Flutter SDK:** 3.38.8 (Channel stable, revision `bd7a4a6b55`)
- **Dart SDK:** 3.10.7
- **Kotlin Target / Version:** 1.9.0 / JVM 17
- **Android Gradle Plugin (AGP):** 8.1.0
- **Gradle Wrapper:** 8.14
- **Android SDK Targets:** `minSdk = 24` (Android 7.0 Nougat), `targetSdk = 35` (Android 15), `compileSdk = 35`
- **Application ID / Namespace:** `com.safesignal.safesignal`
- **Desugaring:** Core Library Desugaring enabled (`com.android.tools:desugar_jdk_libs:2.1.4`)
- **Graphics Pipeline:** Impeller explicitly disabled via AndroidManifest meta-data to ensure GPU stability on legacy Mali/Adreno chips

---

## 2. Dependency Graph Audit

### Core Frameworks & State Management
- `flutter_riverpod: ^3.3.2` — Declared state management provider
- `go_router: ^17.3.0` — Declarative application routing (14 configured routes)
- `hive: ^2.2.3` & `hive_flutter: ^1.1.0` — Key-value local NoSQL document storage
- `shared_preferences: ^2.5.5` — User settings & lightweight flags

### Cryptography & Security Primitives
- `encrypt: ^5.0.3` — AES encryption wrapper
- `crypto: ^3.0.6` — Cryptographic hash functions (SHA-1, SHA-256, HMAC)
- `flutter_secure_storage: ^10.3.1` — Android Keystore / EncryptedSharedPreferences wrapper
- `local_auth: ^3.0.2` — BiometricPrompt & device credential authentication
- `safe_device: ^1.4.1` — Root & emulator detection (declared in pubspec, previously unused)

### Hardware, Network & OS Integrations
- `dio: ^5.10.0` — HTTP client with timeout & interceptor support
- `connectivity_plus: ^7.2.0` & `network_info_plus: ^8.2.0` — Network interface state
- `permission_handler: ^12.0.3` — Dynamic runtime permission management
- `installed_apps: ^2.1.1` — PackageManager wrapper for installed applications
- `mobile_scanner: ^7.2.0` — Camera QR code scanner
- `google_mlkit_text_recognition: ^0.16.0` — On-device ML Kit OCR engine
- `google_mlkit_document_scanner: ^0.5.0` — Document bounds detection
- `pdf: ^3.12.0` & `printing: ^5.14.3` — Forensic PDF report generation
- `share_plus: ^13.2.0` — Android Sharesheet invocation

---

## 3. Screen & Navigation Inventory

All existing application routes registered in `lib/core/routing/app_router.dart`:

1. `/` — `SplashScreen` (`lib/features/onboarding/splash_screen.dart`)
2. `/onboarding` — `OnboardingScreen` (`lib/features/onboarding/onboarding_screen.dart`)
3. `/signin` — `SignInScreen` (`lib/features/onboarding/signin_screen.dart`)
4. `/profile-setup` — `ProfileSetupScreen` (`lib/features/onboarding/profile_setup_screen.dart`)
5. `/home` — `HomeScreen` (`lib/features/home/home_screen.dart`)
6. `/url-scanner` — `UrlScannerScreen` (`lib/features/url_scanner/url_scanner_screen.dart`)
7. `/app-scanner` — `AppScannerScreen` (`lib/features/app_scanner/app_scanner_screen.dart`)
8. `/device-audit` — `DeviceAuditScreen` (`lib/features/device_audit/device_audit_screen.dart`)
9. `/wifi-scanner` — `WifiScannerScreen` (`lib/features/wifi_scanner/wifi_scanner_screen.dart`)
10. `/sms-inbox` — `SmsInboxScreen` (`lib/features/sms_inbox/sms_inbox_screen.dart`)
11. `/otp-guard` — `OtpGuardScreen` (`lib/features/otp_guard/otp_guard_screen.dart`)
12. `/call-shield` — `CallShieldScreen` (`lib/features/call_shield/call_shield_screen.dart`)
13. `/chat` — `ChatScreen` (`lib/features/chat/chat_screen.dart`)
14. `/vault` — `VaultScreen` (`lib/features/vault/vault_screen.dart`)
15. `/vault/viewer` — `VaultDocumentViewerScreen` (`lib/features/vault/vault_document_viewer_screen.dart`)
16. `/email-breach` — `EmailBreachScreen` (`lib/features/email_breach/email_breach_screen.dart`)
17. `/feed` — `FeedScreen` (`lib/features/feed/feed_screen.dart`)
18. `/social-osint` — `SocialOsintScreen` (`lib/features/social_osint/social_osint_screen.dart`)
19. `/history` — `HistoryScreen` (`lib/features/history/history_screen.dart`)

---

## 4. Native Kotlin Architecture Baseline

Directory: `android/app/src/main/kotlin/com/safesignal/safesignal/`
- `MainActivity.kt`: Platform channels (`com.safesignal.app/accessibility`, `com.safesignal.app/battery`)
- `SmsReceiver.kt`: Intercepts `android.provider.Telephony.SMS_RECEIVED`, evaluates spam/scam keywords, triggers notifications
- `BootReceiver.kt`: Intercepts `BOOT_COMPLETED`, relaunches foreground service
- `SafeSignalService.kt`: Foreground service typed as `dataSync`
- `EmailNotificationService.kt`: NotificationListenerService for intercepting notification text
- `SafeSignalCallScreeningService.kt`: CallScreeningService for blocking numbers on Android 10+
- `LinkShieldAccessibilityService.kt`: DORMANT (not in manifest)
- `CallReceiver.kt`: DORMANT (not in manifest)
