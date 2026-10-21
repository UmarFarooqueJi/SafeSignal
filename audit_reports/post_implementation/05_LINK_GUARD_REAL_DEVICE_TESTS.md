# 05 — LINK GUARD ARCHITECTURAL TRACE & SHARE TARGET VERIFICATION

**Audit Date:** October 21, 2026  
**Auditor:** Independent Cybersecurity Re-Audit Team  
**Focus:** Verification of the user flow:  
`WhatsApp / Telegram / Chrome / SMS -> Share to SafeSignal -> URL Extraction -> Deep Analysis -> Verdict Screen -> User-Approved Open`.

---

## 1. END-TO-END ARCHITECTURAL TRACE

### Step 1: Android Intent Declaration (`AndroidManifest.xml`)
Lines 59–65 of `android/app/src/main/AndroidManifest.xml`:
```xml
<!-- SafeSignal Link Guard: Share Target for Links and Text -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/plain" />
</intent-filter>
```
SafeSignal registers as a system-wide Share Target for `text/plain` across WhatsApp, Telegram, Chrome, SMS apps, etc.

### Step 2: Native Android Intent Caching (`MainActivity.kt`)
Lines 45, 50, 66–75 of `MainActivity.kt`:
```kotlin
private var sharedText: String? = null

override fun onCreate(savedInstanceState: Bundle?) {
    installSplashScreen()
    super.onCreate(savedInstanceState)
    handleSendIntent(intent) // Handles Cold Start
}

override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    handleSendIntent(intent) // Handles Warm Start (app already open)
}

private fun handleSendIntent(intent: Intent?) {
    if (intent?.action == Intent.ACTION_SEND && 
       (intent.type == "text/plain" || intent.type?.startsWith("text/") == true)) {
        sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
    }
}
```
And exposed to Flutter via MethodChannel:
```kotlin
"getSharedText" -> {
    val text = sharedText
    sharedText = null // Prevents duplicate triggers
    result.success(text)
}
```

### Step 3: Flutter Native Bridge (`LinkGuardService.dart`)
Lines 9–17:
Calls `_channel.invokeMethod('getSharedText')`. Returns extracted URL or null.

### Step 4: URL Extraction Heuristics (`LinkGuardService.extractUrl`)
1. **Direct Scheme URLs:** `https://example.com/path` -> standard extraction.
2. **URLs Embedded in Chat:** `RegExp(r'https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}...')` matches URLs embedded within chat messages.
3. **Bare Domains:** `paytm-bonus.click/claim` -> prepends `https://`.
4. **Pure Non-URL Text:** Returns `null`.

### Step 5: Cold & Warm Start Navigation
- **Cold Start:** `AppRouter.dart` line 195–200 checks `LinkGuardService.checkPendingSharedUrl()`. If present, navigates directly to `context.go('/url-scanner', extra: pendingUrl)`.
- **Warm Start:** `HomeScreen.dart` line 44–53 listens to `didChangeAppLifecycleState(AppLifecycleState.resumed)` and calls `context.push('/url-scanner', extra: pendingUrl)`.

### Step 6: Safe Opening & Analysis (`UrlScannerScreen.dart`)
- Initial URL automatically triggers `_scan()`.
- Deep forensic analysis executes via `UrlIntelligenceEngine.analyze()`.
- Result is rendered with a speedometer gauge and severity warnings.
- The link is **NOT opened automatically**. The user must explicitly press the "Open Link ↗" button (`launchUrl(uri, mode: LaunchMode.externalApplication)`).

---

## 2. CAPABILITY CLASSIFICATION

It is critical to distinguish between the four capabilities mentioned in the audit brief:

1. **SHARE TO SAFESIGNAL:** **VERIFIED WORKING**. Any application can share text/links to SafeSignal via standard Android `ACTION_SEND`.
2. **OPEN WITH SAFESIGNAL:** **NOT IMPLEMENTED**. SafeSignal does NOT declare `ACTION_VIEW` for `http://` or `https://` schemes in `AndroidManifest.xml`. It cannot be chosen as the default web browser.
3. **AUTOMATIC PRE-CLICK INTERCEPTION:** **PROTOTYPE ONLY**. An unmanifested prototype file `LinkShieldAccessibilityService.kt` exists in the repository, but is commented out and absent from `AndroidManifest.xml`. SafeSignal does NOT silently intercept clicks across other apps in real time.
4. **VPN-BASED DOMAIN PROTECTION:** **NOT IMPLEMENTED**. No local loopback `VpnService` is declared or implemented.

---

## 3. IDENTIFIED LIMITATIONS & EDGE CASES

1. **Dangerous Schemes in Open Link Button:**
   `UrlScannerScreen` line 623 parses `Uri.parse(result.url)` and launches it directly in the external browser. It does not enforce a secondary confirmation dialog if the link verdict is `dangerous`.
2. **Text with Multiple URLs:**
   `LinkGuardService.extractUrl` extracts only the *first* matching URL. If a message contains multiple links (e.g. one legitimate decoy link and one phishing link), subsequent links are ignored.
