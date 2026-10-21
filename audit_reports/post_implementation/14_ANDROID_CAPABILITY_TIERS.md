# 14 — THREE-TIER ANDROID CAPABILITY FRAMEWORK AUDIT

**Audit Date:** October 21, 2026  
**Auditor:** Principal Android Security Engineer & Staff Kotlin Architect  
**Components:** `lib/core/services/research_mode_service.dart`, `android/app/src/main/kotlin/.../MainActivity.kt`

---

## 1. THREE-TIER SPECIFICATION VS CODE REALITY

The architecture documentation (`OPEN_SOURCE_RESEARCH_ARCHITECTURE.md`) defines a 3-tier capability framework:
- **Tier 1:** Standard Android Mode (Zero-root, user permissions, production defense).
- **Tier 2:** Managed Device Mode (Enterprise Device Owner / MDM research).
- **Tier 3:** Rooted Research Lab Mode (Privileged low-level testing on lab hardware).

We audited each tier against actual source code and native platform bindings:

| Tier | Claimed Capabilities | Actual Code in Repository | Native Platform Implementation (`MainActivity.kt`) | Production Runtime Availability | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Tier 1: Standard Android** | Phishing URL scan, Link Guard, SMS DLT parsing, Call screening, App permission audit, Vault encryption. | Fully implemented across `UrlIntelligenceEngine`, `SmsReceiver`, `VaultCryptoService`, etc. | Implemented via `appScannerHandler`, `safesignal/call_shield`, `safesignal/network`. | **100% OPERATIONAL** on stock unrooted Android devices. | **VERIFIED WORKING** |
| **Tier 2: Device Owner** | Enforce OS security baselines, cert authorities, silent package blocklist, kiosk locking. | Abstract data classes in `ResearchModeService.dart` lines 155–177. | **MISSING**. `MainActivity.kt` contains zero `DevicePolicyManager` device owner handlers. | **DEAD CODE**. `isDeviceOwner` method call fails with `notImplemented()`. | **DOCUMENTATION ONLY** |
| **Tier 3: Rooted Lab** | Kernel-level integrity, SELinux raw log analysis, raw partition forensic dumping. | Abstract data classes in `ResearchModeService.dart` lines 179–204. | **MISSING**. `MainActivity.kt` contains zero root execution bridges (`su -c`) or root handlers. | **DEAD CODE**. `isRooted` method call fails with `notImplemented()`. | **DOCUMENTATION ONLY** |

---

## 2. DETAILED PLATFORM CHANNEL DEFECT

In `ResearchModeService.dart`:
```dart
Future<bool> isDeviceManagementActive() async {
    final isDeviceOwner = await _platformChannel.invokeMethod<bool>('isDeviceOwner') ?? false;
    return isDeviceOwner;
}

Future<bool> isRootedLabEnvironment() async {
    final isRootedNative = await _platformChannel.invokeMethod<bool>('isRooted') ?? false;
    ...
}
```
Inspection of `android/app/src/main/kotlin/com/safesignal/safesignal/MainActivity.kt` (lines 80–267 and 273–355):
- The `safesignal/device` channel handles: `getInstalledApps`, `getAppIcon`, `getAppHash`, `getWifiSecurityType`, `openWifiSettings`, `requestOverlayPermission`, `isNotificationListenerEnabled`, `openNotificationSettings`, `isDeveloperOptionsEnabled`, `openDeveloperSettings`, `openSystemUpdateSettings`, `openAppSettings`, `openPermissionSettings`, `getMemoryInfo`, `getStorageInfo`, `scanSuspiciousFiles`, `deleteSuspiciousFile`, `getDangerousSettings`, `openAccessibilitySettings`, `openSecuritySettings`, `openDeviceAdminSettings`, `openInstallUnknownAppsSettings`, `getSharedText`.
- **`isDeviceOwner` is NOT handled.**
- **`isRooted` is NOT handled.**
- Any invocation throws a missing method exception caught silently by `catch (_) {}`, defaulting to `false`.

---

## 3. PRODUCTION USAGE AUDIT

- A search across all `lib/` files confirms that **no UI screen, service, or engine ever invokes `ResearchModeService.detectActiveTier()`**.
- `ResearchModeService` is an isolated conceptual file referenced only by its own unit test `test/research_mode_test.dart`.

**Conclusion:** SafeSignal is strictly a **Tier 1 (Standard Android)** consumer security application. Tiers 2 and 3 exist exclusively as descriptive documentation and stub profiles.
