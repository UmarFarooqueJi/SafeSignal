# SAFESIGNAL X: ANDROID CAPABILITY & PLATFORM REALITY MATRIX

**Scope:** Android 10 (API 29) through Android 15 (API 35)  
**Standard:** Google Play Policy, Platform Permissions, and Android Sandbox Constraints  

---

## 1. Platform Capability & Restriction Matrix

| Android Capability | Android 10 (API 29) | Android 11–12 (API 30–31) | Android 13–14 (API 33–34) | Android 15 (API 35) | SafeSignal Integration Doctrine |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Cross-App Link Interception** | `ACTION_VIEW` intent disambiguation dialog possible. | `ACTION_VIEW` with `CATEGORY_BROWSABLE` permitted. | Android 12+ strictly directs unverified web domains to default browser. | Same as Android 12+. Generic web hijacking blocked. | **Use `ACTION_SEND` (Share Target) and `ACTION_PROCESS_TEXT`.** Do not claim universal click interception. |
| **Package Visibility** | Unrestricted access to all installed packages via `PackageManager`. | `QUERY_ALL_PACKAGES` restricted by Google Play policy; requires justification. | Requires declared `QUERY_ALL_PACKAGES` or `<queries>` intent declarations. | Same as API 33+. Play Store audit strictly enforced. | **Declare `QUERY_ALL_PACKAGES` for security suite.** Handle security exception gracefully if revoked. |
| **Call Screening** | `CallScreeningService` supported; requires default role or explicit prompt. | Official `RoleManager.ROLE_CALL_SCREENING` required. | `RoleManager` required. Strict background restrictions on call metadata. | Same. Caller ID inspection strictly controlled. | **Implement `SafeSignalCallScreeningService` using `RoleManager`.** Honest prompt if role not held. |
| **SMS Monitoring** | `RECEIVE_SMS` broadcast receiver supported. | `RECEIVE_SMS` permitted. Play Store requires default SMS app or security exception. | `RECEIVE_SMS` permitted. Runtime notification permission required. | Strict SMS background restrictions. | **Keep clean `SmsReceiver`.** Provide manual text paste & share alternatives if SMS permission not granted. |
| **Foreground Services** | General foreground service allowed. | Must specify foreground service type in manifest. | Must declare specific permissions (e.g. `FOREGROUND_SERVICE_DATA_SYNC`). | Strict timeout and justification. Misuse triggers Play rejection. | **Bind service strictly to functional background scans.** Do not keep empty dummy foreground loops. |
| **Biometrics & KeyStore** | `BiometricPrompt` supported. Software key fallback. | `BiometricPrompt.CryptoObject` supported. TEE/StrongBox key generation. | `setUserAuthenticationRequired(true)` with timeout or per-use auth. | Hardware-backed StrongBox keys prioritized. | **Bind vault AES-256 keys to KeyStore `CryptoObject`.** Mandatory fallback PIN if no biometric hardware. |
| **Accessibility Services** | `AccessibilityService` permitted. | Play Store strictly forbids generic accessibility scraping. | Accessibility services heavily audited. User warned of high risk. | Enhanced security dialog for sideloaded apps using accessibility. | **Do NOT use Accessibility for background WhatsApp/browser scraping.** Keep Link Shield share-driven. |
| **Network & Wi-Fi Probing** | Basic Wi-Fi info available. | `ACCESS_FINE_LOCATION` required to read SSID. | `NEARBY_WIFI_DEVICES` permission introduced. | Strict redaction of BSSID/MAC addresses. | **Use `NetworkCapabilities` API.** Remove unpermitted cleartext HTTP calls that crash Android 9+. |
| **Loopback VpnService** | Single active VPN service permitted per device profile. | Same. Cannot run concurrently with enterprise/commercial VPN. | User explicitly warned when VPN starts. | Same. | **Optional opt-in module only.** Disclose single-VPN restriction clearly to the user. |

---

## 2. Supported Integration Paths vs Prohibited Illusions

### REALITY CHECK 1: Universal Web Link Interception
- **False Claim:** "SafeSignal intercepts every link clicked in WhatsApp, Chrome, or Telegram automatically."
- **Android Truth:** Starting in Android 12, Android App Links strictly direct verified domain links to official apps and all other HTTP/HTTPS links directly to the user's default browser. Third-party apps cannot inject themselves between a click in WhatsApp and the launch of Chrome without being set as the default browser or using an accessibility hack (which Google Play bans).
- **SafeSignal X Solution:** Implement native Android **Share Target (`ACTION_SEND`)** and **Selected Text (`ACTION_PROCESS_TEXT`)**. When a user shares a link or selects text in any app, SafeSignal provides an instant pre-open threat assessment.

### REALITY CHECK 2: Background Accessibility Spying
- **False Claim:** "SafeSignal runs an Accessibility Service that reads every incoming message and URL in WhatsApp without user intervention."
- **Android Truth:** Using an Accessibility Service for generic data collection or threat detection violates Google Play Accessibility API Policies and triggers immediate app removal and Play Protect warnings.
- **SafeSignal X Solution:** Deactivate dormant accessibility scraping. Rely on user-initiated sharing, standard broadcast receivers (`SmsReceiver`), and notification listeners with explicit user consent.
