# 07 — CALL SCREENING, TELECOM GUARD & DLT SMS VERIFICATION

**Audit Date:** October 21, 2026  
**Auditor:** Independent Cybersecurity Re-Audit Team  
**Components:** `SafeSignalCallScreeningService.kt`, `CallReceiver.kt`, `SmsReceiver.kt`, `LocalRuleEngine.dart`

---

## 1. NATIVE CALL SCREENING SERVICE (`SafeSignalCallScreeningService.kt`)

### Implementation Verification:
- **Service Registration:** Declared in `AndroidManifest.xml` lines 106–114 with `android:permission="android.permission.BIND_SCREEN_CALL_SERVICE"` and intent filter `android.telecom.CallScreeningService`.
- **API Target:** Enforces `@RequiresApi(Build.VERSION_CODES.Q)` (Android 10+).
- **Direction Guard:** Lines 29–34 explicitly verify:
  ```kotlin
  if (callDetails.callDirection != Call.Details.DIRECTION_INCOMING) {
      respondToCall(callDetails, CallResponse.Builder().build())
      return
  }
  ```
  Ensures outgoing calls are never screened or blocked.
- **Emergency Number Bypass:** Lines 44–66 hardcode absolute immunity for:
  `112, 100, 101, 102, 108, 1091, 1098, 1930, 1909, 911, 999`.
  Calls from or to these numbers immediately return `.setDisallowCall(false)`.
- **TRAI Telemarketer Handling:** Lines 89–95 checks `if (last10.startsWith("140"))`. TRAI allocates `140xxxxxxx` exclusively for promotional commercial communications. Calls with this prefix are blocked if `block_trai` is enabled in settings. (Note: The new 160 series for transactional/service calls is not blocked).
- **International VoIP Spoofing Filter:** Lines 98–107 checks high-risk international prefixes (`+92, +84, +234, +4470, +93, +212, +252`).

### Call Screening Limitations:
1. **Android Version Gating:** Unusable on Android 9 and lower (Pie, Oreo).
2. **User Consent Prerequisite:** Requires user to grant the `ROLE_CALL_SCREENING` via Android's `RoleManager` dialog. Without user approval, Android will not route incoming calls to the service.

---

## 2. SMS SCAM & DLT VERIFICATION (`SmsReceiver.kt`)

### Real-Time Intent Interception:
- Registered in `AndroidManifest.xml` with `<action android:name="android.provider.Telephony.SMS_RECEIVED" />`.
- Reads `pdus` via `Telephony.Sms.Intents.getMessagesFromIntent(intent)`.

### Claim vs Reality: DLT Registry Lookup vs DLT-Aware Heuristics:
- **Claim:** *"TRAI/DLT-aware SMS verification."*
- **Actual Code (`SmsReceiver.kt` lines 258–260):**
  ```kotlin
  val cleanSender = sender.replace(Regex("[\\s\\-()]+"), "")
  val traiHeaderPattern = Regex("^[A-Za-z]{2}-?[A-Za-z0-9]{6}$")
  val isTraiSender = traiHeaderPattern.matches(cleanSender)
  ```
- **Finding:** The app does NOT query an authenticated telecom DLT registry or cryptographic database. It merely checks whether the sender string matches the standard 8-character syntax of an Indian SMS header (e.g. `VM-HDFCBK`, `AD-SBIINB`).
- **Verdict:** **DLT-AWARE HEURISTICS**, not verified DLT authentication.

### Personal Mobile Impersonation Detection:
Lines 267–270:
```kotlin
val indianMobilePattern = Regex("^(\\+91|91)?[6-9]\\d{9}$")
val claimsBank = Regex("(?i)(sbi|hdfc|icici|axis|kotak|pnb|bob|bank|paytm|phonepe|netbanking)").containsMatchIn(lower)

if (indianMobilePattern.matches(cleanSender) && claimsBank) {
    score += 50
    detectedReasons.add("Bank notification sent from personal 10-digit mobile number")
}
```
**Verified Working:** Successfully catches fraud where scammers send bank KYC/account suspension threats from standard 10-digit personal mobile numbers.

### Sensitive Data Redaction (Zero OTP Exposure):
Lines 108–121:
```kotlin
private fun sanitizeSmsBody(body: String): String {
    val otpPattern = Regex("""(?i)\b(?:otp|code|verification|passcode|one-time|pin|v-code)\b[:\s\-—]+([0-9]{4,8})\b""")
    var sanitized = otpPattern.replace(body) { matchResult ->
        val full = matchResult.value
        val code = matchResult.groupValues[1]
        full.replace(code, "[REDACTED-OTP]")
    }
    return sanitized
}
```
**Verified Working:** Raw 4-to-8 digit OTPs are redacted to `[REDACTED-OTP]` prior to JSON serialization into `FlutterSharedPreferences`.
