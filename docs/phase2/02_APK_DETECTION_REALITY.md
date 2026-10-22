# 02 — APK DETECTION REALITY & FALSE POSITIVE REMEDIATION

**Project:** SafeSignal Mobile Security Suite & Research Platform  
**Module:** `UrlIntelligenceEngine` & `AppRiskEngine`  
**Revision:** Phase 2 Engineering Transformation  
**Verification Target:** Decoupled APK Evaluation & Elimination of Sideloading False Positives  

---

## 1. PRE-REMEDIATION DEFECT ANALYSIS

In earlier revisions of `UrlIntelligenceEngine`, any URL containing `.apk` in its path or query string was unconditionally treated as a high-confidence malware dropper:

```dart
// DEPRECATED DEFECTIVE PATTERN:
for (final ext in dangerousExtensions) {
  if (urlPath.endsWith(ext) || urlQuery.contains(ext)) {
    isDropper = true;
    riskScore += 65; // Blanket addition
    domainChecks.insert(0, DomainCheckItem(
      'Malicious Executable Dropper',
      false,
      'CRITICAL: URL directly downloads executable/mobile payload ($ext). Risk of Trojan or spyware installation.',
    ));
    break;
  }
}
```

This heuristic exhibited two critical flaws:
1. **Query-String False Positives:** A benign search URL such as `https://google.com/search?q=whatsapp.apk` was treated as an active payload dropper because `urlQuery.contains('.apk')` was true.
2. **Open-Source Repository False Positives:** Official open-source release downloads (e.g. `https://f-droid.org/F-Droid.apk`, `https://signal.org/android/apk/Signal-Android.apk`, `https://github.com/torproject/tor-browser/releases/download/v13/tor.apk`) received a critical threat score and were branded as Trojans, despite originating from authenticated, trusted repositories.

---

## 2. PHASE 2 CONTEXTUAL MULTI-FACTOR EVALUATION

Phase 2 replaces unconditional blanket scoring with a differentiated, 4-tier mobile payload evaluation engine:

### Tier A: Desktop & Script Binaries on Mobile (`.exe`, `.bat`, `.cmd`, `.vbs`, `.ps1`, `.msi`)
- Desktop executables served to Android users represent an extreme attack vector (cross-platform droppers, obfuscated command payloads).
- **Verdict:** `UrlVerdict.dangerous` (`riskScore += 65`, `knownMalicious`).
- **Audit Label:** `Malicious Executable Dropper`.

### Tier B: Hostile Mobile Droppers (Brand Impersonation / Scam Lures + APK)
- When a direct APK download is hosted on a domain that mimics a financial institution (e.g. `sbi-kyc-update.xyz/sbi.apk`) or utilizes urgency triggers (`power-bill`, `digital-arrest`), the confidence of a banking Trojan or spyware dropper is exceptionally high.
- **Verdict:** `UrlVerdict.dangerous` (`riskScore >= 75`, `UrlRiskLevel.knownMalicious`).
- **Audit Label:** `Brand Impersonation & Trojan Dropper` or `High-Risk Mobile Malware Dropper`.

### Tier C: Unverified Third-Party APK Sideloading
- When an APK download originates from a standard, unknown, or third-party web server without brand lures or high-risk TLDs.
- **Verdict:** `UrlVerdict.caution` (`riskScore: ~35`, `UrlRiskLevel.suspicious`).
- **Explanation:** `"APK download detected; file security has not been verified."`
- **Audit Label:** `Unverified APK Download`. It informs the user that sideloading bypasses OS marketplace sandbox controls without falsely asserting that the file is an active Trojan.

### Tier D: Verified Open-Source & Official Publisher Platforms
- SafeSignal maintains an on-device verified publisher registry:
  ```dart
  static const Set<String> verifiedApkPublishers = {
    'f-droid.org',
    'github.com',
    'gitlab.com',
    'signal.org',
    'telegram.org',
    'whatsapp.com',
    'mozilla.org',
    'torproject.org',
    'apkmirror.com',
  };
  ```
- APK links from these verified publishers (e.g. F-Droid, Signal, Mozilla) preserve legitimate standing without false alarm flags.
- **Verdict:** `UrlVerdict.safe`.
- **Audit Label:** `Verified Software Repository APK`: `"APK package hosted on recognized open-source or official release platform. Binary contents not dynamically inspected; verify cryptographic signature before installation."`

---

## 3. BENCHMARK VERIFICATION RESULTS

| Test Case | Destination URL | Verdict | Threat Classification | False Positive? |
| :--- | :--- | :--- | :--- | :--- |
| **F-Droid Client** | `https://f-droid.org/F-Droid.apk` | `safe` | Verified Open-Source Repo | **NO (Resolved)** |
| **Signal Android** | `https://signal.org/android/apk/Signal.apk` | `safe` | Verified Official Platform | **NO (Resolved)** |
| **Third-Party APK** | `https://example-mirror.org/sample.apk` | `caution` | Unverified APK Download | **NO (Cautious)** |
| **Banking Trojan** | `https://sbi-kyc-update.xyz/sbi.apk` | `dangerous` | Known Malicious Trojan Dropper | **NO (True Positive)** |
| **Desktop Executable**| `https://patch-update.com/agent.exe` | `dangerous` | Malicious Desktop Binary | **NO (True Positive)** |
