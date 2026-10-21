# 17 — APK BINARY & DEVSECOPS SUPPLY CHAIN AUDIT

**Audit Date:** October 21, 2026  
**Auditor:** Open-Source Software Verification Architect & Mobile AppSec Auditor  
**Artifact Audited:** `build/app/outputs/flutter-apk/app-release.apk` (116,306,608 bytes)

---

## 1. APK BINARY SECURITY INSPECTION

| Security Surface | Inspection Parameter | Finding / Evidence | Security Verdict |
| :--- | :--- | :--- | :--- |
| **Android Backup** | `android:allowBackup` & `fullBackupContent` | Declared `false` in `AndroidManifest.xml` line 38–39. | **SECURE (Prevents ADB backup data extraction)** |
| **Debug Flags** | `android:debuggable` | Stripped in release build; `BuildConfig.DEBUG` = false. | **SECURE** |
| **Network Cleartext** | `android:usesCleartextTraffic` | Not enabled in Manifest; default blocked on API 28+. | **SECURE (Enforces HTTPS by default)** |
| **Exported Activities** | `MainActivity` | `exported="true"` with `LAUNCHER` and `SEND` intent filters. | **SECURE (Required for launcher and share target)** |
| **Exported Receivers** | `SmsReceiver` | `exported="true"` for `SMS_RECEIVED`. Protected by Android telephony stack. | **SECURE** |
| **Exported Services** | `SafeSignalCallScreeningService` | Protected by `android.permission.BIND_SCREEN_CALL_SERVICE`. | **SECURE (Only Android Telecom subsystem can bind)** |
| **Dangerous Permissions** | `QUERY_ALL_PACKAGES` | Declared in Manifest. Permitted for security research/antivirus apps. | **ACCEPTABLE (Research tool context)** |
| **Sensitive Permissions** | `RECEIVE_SMS`, `READ_SMS` | Declared in Manifest. Necessary for smishing and OTP protection. | **ACCEPTABLE (Core security functionality)** |
| **Foreground Services** | `FOREGROUND_SERVICE_DATA_SYNC` | Declared for background threat detection service. | **ACCEPTABLE** |

---

## 2. DEVSECOPS & CI/CD PIPELINE AUDIT

### GitHub Actions Workflows:
1. **`.github/workflows/ci.yml`:**
   - Triggers on pull requests and pushes to `main` and `develop`.
   - Runs `flutter pub get`, `dart analyze lib test`, and `flutter test`.
   - Ensures zero static analysis warnings and 100% test pass rate before merge.
2. **`.github/workflows/release.yml`:**
   - Triggers on version tags (`v*.*.*`).
   - Sets up Adoptium JDK 17 and Flutter stable.
   - Builds release APK: `flutter build apk --release`.
   - Generates SHA-256 checksums (`sha256sum safesignal-*.apk > SHA256SUMS.txt`).
   - Publishes automated GitHub Release with attached binary, checksums, and dependency dump.

---

## 3. SBOM & REPRODUCIBILITY CLAIMS REALITY CHECK

### CycloneDX SBOM Claim:
- **Claim:** *"CycloneDX SBOM included in release."*
- **Actual Pipeline Code (`release.yml` lines 55–58):**
  ```yaml
  - name: Generate Software Bill of Materials (SBOM)
    run: |
      flutter pub deps --json > dist/sbom-dependencies.json
  ```
- **Finding:** The file generated is `flutter pub deps --json`. This is Flutter's proprietary dependency tree format. It is **NOT** a CycloneDX SBOM (`bomFormat: "CycloneDX"`).
- **Remediation Required:** Integrate a genuine CycloneDX CLI generator (e.g. `cyclonedx-dart` or `syft`) to produce valid `cyclonedx.json` conforming to specification 1.5.

### Reproducible Build Claim:
- **Claim:** *"Reproducible APK builds."*
- **Finding:** While JDK 17 and Flutter stable are pinned, Android APK compilation involves Gradle tasks, DEX merging, AAPT2 resource compiling, and ZIP packaging. Without strict timestamp normalization (`SOURCE_DATE_EPOCH`), ZIP metadata normalization, and deterministic APK signing, identical source code built on different machines produces differing SHA-256 hashes.
- **Verdict:** **UNVERIFIED / EXAGGERATED**. True bit-for-bit reproducibility is not established.
