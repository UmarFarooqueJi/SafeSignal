# 01 — EXACT BUILD AND COMMIT IDENTITY AUDIT

**Audit Date:** October 21, 2026  
**Auditor:** Independent Cybersecurity Re-Audit Team  
**Target Repository:** `SafeSignal` (C:\Users\umar farooque\Downloads\SafeSignal\safesignal)  
**Remote Origin:** `https://github.com/UmarFarooqueJi/SafeSignal.git`  
**Distribution:** Free, Open-Source Android Cybersecurity Research Platform (GitHub Release)

---

## 1. REPOSITORY IDENTIFICATION & GIT METADATA

| Property | Value | Evidence / Command Output |
| :--- | :--- | :--- |
| **Active Git Branch** | `feature/safesignal-x-security-transformation` | `git status` -> `On branch feature/safesignal-x-security-transformation` |
| **Current HEAD Commit SHA** | `cdb77748f13a5c06ca3c44f1de52be97c9977c4b` | `git rev-parse HEAD` |
| **Original Audited Baseline** | `0b98be8` | Audit engagement baseline commit |
| **Commit Subject** | `build(android): configure Adoptium JDK 17 java.home for reproducible release builds` | `git log -1` |
| **Working Tree State** | Clean (0 uncommitted modifications) | `nothing to commit, working tree clean` |
| **Total Files Changed (0b98be8..HEAD)** | 57 files | `git diff --stat 0b98be8..HEAD` (5,100 insertions, 1,494 deletions) |

---

## 2. BUILD TOOLCHAIN ENVIRONMENT

```
Flutter Version: 3.38.8 (Channel stable, revision bd7a4a6b55)
Dart SDK: 3.10.7 (DevTools 2.51.1)
Java Runtime: OpenJDK 17.0.20.1 (Temurin-17.0.20.1+1, 64-bit)
Android Gradle Plugin: 8.9.0
Gradle Wrapper: 8.11.1
Kotlin Version: 2.1.0
Android Compile SDK: 35 (Android 15)
Android Min SDK: 24 (Android 7.0 Nougat)
Android Target SDK: 34 (Android 14 UpsideDownCake)
```

---

## 3. RELEASE APK BINARY IDENTITY

The compiled release artifact was located in `build/app/outputs/flutter-apk/app-release.apk` (and mirrored in `build/app/outputs/apk/release/app-release.apk`).

- **File Name:** `app-release.apk`
- **Absolute Path:** `C:\Users\umar farooque\Downloads\SafeSignal\safesignal\build\app\outputs\flutter-apk\app-release.apk`
- **File Size:** `116,306,608 bytes` (~110.92 MB)
- **Compilation Timestamp:** October 21, 2026, 20:54:12 IST
- **SHA-256 Checksum:** `BDE90DE6BFCFC24B4212CA484F31DB417F49B8809C330258D584E7FAE8FE700D`
- **Application Package ID:** `com.safesignal.safesignal`
- **Version Code:** `13`
- **Version Name:** `1.3.0`
- **Supported ABIs in APK:** `arm64-v8a`, `armeabi-v7a`, `x86_64`

### Internal APK Asset & Binary Decomposition:
1. **DEX Files:** `classes.dex`, `classes2.dex` (MultiDex enabled)
2. **Bundled Native Libraries (`lib/`):**
   - `libmlkit_google_ocr_pipeline.so` (On-device Google ML Kit OCR text engine)
   - `libtoolChecker.so` (Native root detection heuristics from `safe_device`)
   - `libbarhopper_v3.so` (Offline QR/Barcode scanner engine)
   - `libflutter.so`, `libapp.so`, `libdartjni.so` (Flutter engine & AOT application code)
3. **Bundled ML Models (`assets/`):**
   - `assets/mlkit-google-ocr-models/taser/detector/rpn_text_detector_mobile_space_to_depth_quantized_mbv2_v1.tflite`
   - `assets/mlkit-google-ocr-models/gocr/gocr_models/line_recognition_legacy_mobile/tflite_langid.tflite`
   - `assets/mlkit-google-ocr-models/aksara/` (Page layout analysis binary protobuf models)
   - `assets/mlkit_barcode_models/barcode_ssd_mobilenet_v1_dmp25_quant.tflite`
4. **Local Generative AI / Large Language Models:** **NONE** (No GGUF, ONNX, or LLM weights are bundled inside the APK).

---

## 4. BUILD PROVENANCE & REPRODUCIBILITY ASSESSMENT

- **Provenance Verdict:** **VERIFIED** — The compiled APK contains DEX signatures, resources, and Native libraries corresponding to the active branch code up to commit `cdb7774`.
- **Reproducible Build Verdict:** **UNVERIFIED / EXAGGERATED** — While JDK 17 is pinned in `android/gradle.properties` (`org.gradle.java.home`), the project lacks deterministic zip header timestamp stripping (`strip-nondeterminism`) and `SOURCE_DATE_EPOCH` enforcement. Successive builds produce differing SHA-256 signatures due to timestamp drift in ZIP headers.
