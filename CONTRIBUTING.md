# Contributing to SafeSignal X

Thank you for your interest in contributing to **SafeSignal X**! 

SafeSignal X is an open-source, non-commercial Android cybersecurity and agentic AI research platform. We welcome contributions from software engineers, mobile security researchers, cryptographers, and reverse engineers worldwide.

---

## 🔬 Research & Engineering Ethos

- **Real Implementations Only:** We strictly reject fake security scores, simulated progress bars, placeholder AI responses, or dummy telemetry. Every capability must provide genuine, verifiable functionality.
- **Privacy-Preserving by Default:** All scanning, parsing, heuristic evaluation, and evidence generation must execute locally on the device without unauthorized network egress.
- **Preserve Existing UI/UX:** The approved SafeSignal visual identity, color scheme, typography, and existing screen workflows must remain preserved. New research surfaces must be additive and conform to the established design system.

---

## 🚀 Development Setup

### 1. Prerequisites
- **Flutter SDK:** 3.10.7+ (Stable Channel)
- **Dart SDK:** ^3.10.7
- **Java JDK:** OpenJDK 17
- **Android SDK:** Platform API 34+ / Build-Tools 34.0.0+
- **Git**

### 2. Clone & Bootstrap
```bash
git clone https://github.com/UmarFarooqueJi/SafeSignal.git
cd SafeSignal/safesignal
flutter pub get
```

### 3. Run Tests & Static Analysis
Before writing or proposing any changes, verify that the existing test suite passes:
```bash
# Execute all 60+ unit and integration tests
flutter test

# Verify clean static analysis (Zero issues allowed)
dart analyze lib test
```

---

## 🛠️ Contribution Areas

We actively invite research and engineering contributions in:

1. **Adversarial Test Datasets (`test/`):**
   - New synthetic SMS phishing samples (digital arrest, utility scams, loan fraud).
   - Deceptive homograph, punycode, and typosquatting domain test fixtures.
   - Bank SMS transaction samples ensuring zero false positives.
2. **Policy-Constrained Agentic Tools (`lib/core/agent/`):**
   - New read-only analytical tools for threat observable extraction.
   - Hardened prompt-injection defense filters and safety governor policies.
3. **Forensic Evidence & Graph Enhancements (`lib/core/forensics/`):**
   - STIX 2.1 / JSON-LD export extensions.
   - RFC 3161 evidence chaining optimizations.
4. **Native Android Platform Hardening (`android/app/`):**
   - Telecom `CallScreeningService` threat scoring heuristics.
   - Hardware-backed KeyStore envelope encryption.

---

## 📋 Pull Request Requirements

1. **Focused Changes:** Each PR should address a single feature, heuristic rule update, or bug fix.
2. **Deterministic Tests:** Every new feature or heuristic must be accompanied by unit tests in `test/`.
3. **Clean Static Analysis:** PRs must produce 0 errors and 0 warnings in `dart analyze lib test`.
4. **Conventional Commits:** Follow conventional commit format:
   - `feat(agent): add DoH resolution tool to agent registry`
   - `fix(call-shield): ensure 1930 emergency bypass on Android 14`
   - `test(url-guard): add punycode Cyrillic homograph test cases`
5. **UI Preservation:** If modifying UI files, ensure zero visual regressions against the baseline design.

---

## 🔒 Security Vulnerabilities
To report a security vulnerability, please refer to our [SECURITY.md](SECURITY.md) for confidential coordinated disclosure instructions.
