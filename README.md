<div align="center">

# 🛡️ SafeSignal X

### Open-Source Android Cybersecurity & Policy-Constrained Agentic AI Research Platform
**On-Device Smishing Detection • Temporal Threat Graph • Hardware Vault • 3-Tier Research Framework**

[![Flutter](https://img.shields.io/badge/Flutter-3.38.8-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10.7-0175C2?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-API%2026%20to%2035-3DDC84?logo=android)](https://developer.android.com)
[![Research Tier](https://img.shields.io/badge/Architecture-3--Tier%20Framework-blueviolet)](docs/safesignal_x/OPEN_SOURCE_RESEARCH_ARCHITECTURE.md)
[![Agentic AI](https://img.shields.io/badge/Agentic%20AI-Policy--Constrained-emerald.svg)](lib/core/agent/agentic_investigator.dart)
[![Evidence Chain](https://img.shields.io/badge/Evidence%20Chain-RFC%203161%20SHA--256-blue.svg)](lib/core/forensics/threat_graph_service.dart)
[![Tests](https://img.shields.io/badge/Tests-64%20Passing-brightgreen.svg)](test/)
[![Static Analysis](https://img.shields.io/badge/Static%20Analysis-0%20Issues-brightgreen.svg)](analysis_options.yaml)
[![License](https://img.shields.io/badge/License-Apache%202.0%20%2F%20Source--Available-orange.svg)](LICENSE)
[![Author](https://img.shields.io/badge/Author-Umar%20Farooque-0ea5e9?logo=github)](https://github.com/UmarFarooqueJi)

<p align="center">
  🔬 <b>Research Architecture:</b> <a href="docs/safesignal_x/OPEN_SOURCE_RESEARCH_ARCHITECTURE.md"><b>OPEN_SOURCE_RESEARCH_ARCHITECTURE.md</b></a> • 
  📦 <b>GitHub Releases:</b> <a href="https://github.com/UmarFarooqueJi/SafeSignal/releases"><b>APK & Checksums</b></a> • 
  🔒 <b>Security Policy:</b> <a href="SECURITY.md"><b>SECURITY.md</b></a>
</p>

<p align="center">
  <b>SafeSignal X</b> is an advanced, fully open-source Android cybersecurity and agentic AI research project. It combines client-side threat intelligence, homograph URL parsing, TRAI DLT banking SMS parsing, native telecom call screening, and policy-constrained autonomous incident investigation into a publicly inspectable, reproducible mobile defense platform.
</p>

</div>

---

## 🎯 Project Vision & Research Charter

SafeSignal X is **not** a commercial product, venture-backed startup, or Play Store consumer SaaS.

Our objective is to deliver a world-class, technically sophisticated, and publicly verifiable open-source mobile security architecture that senior Android engineers, reverse engineers, and malware researchers can inspect, reproduce, and build upon.

### Core Principles
- **No Commercial Bloat:** Zero third-party ad networks, telemetry trackers, proprietary billing SDKs, or paywalls.
- **On-Device Default:** Threat heuristics, OCR vision processing, cryptographic vaults, and forensic graphs execute locally without sending user messages or files to the cloud.
- **Genuine Implementations:** Zero mock scores, fake scanning delays, or placeholder AI responses. Every metric is backed by actual platform telemetry.
- **Direct GitHub Releases:** Distributed directly as signed APK releases accompanied by SHA-256 checksums (`SHA256SUMS.txt`) and CycloneDX Software Bill of Materials (SBOM).

---

## 🔬 Three-Tier Capability Framework

SafeSignal X cleanly separates capabilities into three transparent operational tiers:

```
+-----------------------------------------------------------------------------------+
|                        SAFESIGNAL X THREE-TIER ARCHITECTURE                       |
+-----------------------------------------------------------------------------------+
|  TIER 1: Standard Android Defense Mode (Zero-root, userland, standard SDK)        |
|  - On-device brand impersonation and homograph URL engine                         |
|  - Cross-app link interception via ACTION_SEND Intent Bridge                      |
|  - SMS smishing & TRAI DLT header validation (zero false positives on bank alerts)|
|  - Android 10+ Telecom CallScreeningService with emergency helpline bypass        |
|  - Hardware-backed AES-256 encrypted vault (RAM-only volatile viewer)             |
|  - On-device ML Kit OCR for screenshot analysis                                   |
|  - Policy-constrained agentic cyber investigation with RFC 3161 evidence chaining |
+-----------------------------------------------------------------------------------+
|  TIER 2: Advanced Device Management Mode (Enterprise Device Owner / MDM API)      |
|  - Enterprise hardware policy enforcement (camera, storage encryption)            |
|  - User-installed root CA store tampering audits                                  |
|  - Sideloading policy enforcement via DevicePolicyManager                         |
|  - Strictly isolated to provisioned organizational or lab test hardware           |
+-----------------------------------------------------------------------------------+
|  TIER 3: Rooted Research Laboratory Mode (Dedicated researcher-owned lab devices) |
|  - Deep system partition (/system, /vendor) checksum auditing                     |
|  - Kernel SELinux enforcing policy validation                                     |
|  - Low-level socket table inspection (/proc/net/tcp, /proc/net/udp)               |
|  - Volatile heap inspection and malware dropper extraction for static analysis    |
|  - Gated exclusively to owned lab devices; never escalates consumer devices       |
+-----------------------------------------------------------------------------------+
```

---

## 🤖 Policy-Constrained Agentic Cyber Investigator

SafeSignal X features an autonomous on-device investigation loop governed by strict security policies:

- **Prompt-Injection Quarantine:** Isolates untrusted messages, URLs, and OCR text inside rigid delimiter blocks (`<<<UNTRUSTED_ARTEFACT>>>`), neutralizing prompt injection attacks.
- **Typed Tool Registry:** Standardized, schema-validated tools:
  - `scan_url`: Deep URL canonicalization, punycode detection, and Cloudflare DoH resolution.
  - `analyze_sms`: Urgency keyword evaluation, coercion detection, and TRAI DLT header validation.
  - `verify_upi`: Audits Virtual Payment Addresses against known impersonation patterns.
- **Bounded Execution Budget:** Hard limit of 5 autonomous reasoning iterations to guarantee deterministic termination.
- **Safety Governor:** Read-only analytical tools execute automatically; any state-modifying action requires explicit interactive user consent.

---

## 📊 Temporal Threat Graph & RFC 3161 Evidence Chaining

For digital forensics and incident reporting (Section 66D IT Act / 1930 National Cyber Crime Portal), SafeSignal X constructs:

1. **Temporal Threat Graph:** Maps observable entities (`ThreatNode`: URL, Domain, IP, APK, Phone, UPI VPA) and directed relationships (`ThreatEdge`: `impersonates`, `drops_payload`, `redirects_to`).
2. **Immutable Evidence Ledger:** Cryptographic SHA-256 block hash chaining compliant with RFC 3161 principles:
   $$\text{BlockHash}_i = \text{SHA-256}(i \parallel \text{Timestamp}_i \parallel \text{DataHash}_i \parallel \text{BlockHash}_{i-1})$$
3. **Forensic Interoperability:** Generates standard STIX 2.1 JSON-LD export bundles compatible with OpenCTI, MISP, and legal complaint templates.

---

## 📱 Application Interface & Preserved UX

The application's visual layout, dark theme tokens (`#0A0E1A`, `#00E5FF`, `#FF1744`), typography, and dashboard navigation remain strictly preserved:

<div align="center">

### Core Defense & Investigation Surfaces
| Real-time Threat Command Center | Device Integrity & OS Audit | Installed Package Risk Profiling |
| :---: | :---: | :---: |
| <img src="docs/screenshots/02_home_screen.png" width="240" alt="Home Dashboard" /> | <img src="docs/screenshots/04_device_secured.png" width="240" alt="Device Audit" /> | <img src="docs/screenshots/03_app_spyware_audit.png" width="240" alt="App Audit" /> |
| **Active radar & quick actions** | **Root, bootloader & debug check** | **Permission cluster profiling** |

<br>

### Threat Intelligence & Golden Hour Incident Response
| Phishing & URL Analyzer | Emergency Bank Freeze Directory | Legal FIR Complaint Generator |
| :---: | :---: | :---: |
| <img src="docs/screenshots/05_website_analyzer.png" width="240" alt="URL Scanner" /> | <img src="docs/screenshots/05_incident_response_bank_directory.png" width="240" alt="Bank Directory" /> | <img src="docs/screenshots/06_incident_response_complaint_generator.png" width="240" alt="FIR Generator" /> |
| **Punycode & brand authority** | **Direct freeze lines for 10+ banks** | **Section 66D IT Act templates** |

</div>

---

## 🛠️ Build, Test & Reproducibility Instructions

### Prerequisites
- **Flutter SDK:** `3.38.8` (or compatible stable `3.x`)
- **Dart SDK:** `3.10.7`+
- **JDK:** OpenJDK 17
- **Android SDK:** Compile SDK 34, Min SDK 26

### Step-by-Step Build Commands
```bash
# 1. Clone repository
git clone https://github.com/UmarFarooqueJi/SafeSignal.git
cd SafeSignal/safesignal

# 2. Fetch pinned dependencies
flutter pub get

# 3. Verify static code analysis (0 issues required)
dart analyze lib test

# 4. Execute complete automated test suite (64/64 tests)
flutter test

# 5. Build signed production APK
flutter build apk --release
```

The compiled release binary is output to:  
`build/app/outputs/flutter-apk/app-release.apk`

---

## 📦 GitHub Releases & Supply Chain Verification

Download signed research APKs directly from [GitHub Releases](https://github.com/UmarFarooqueJi/SafeSignal/releases).

To verify the cryptographic integrity of your downloaded APK:
```bash
# Compute SHA-256 checksum
sha256sum safesignal-v1.2.0.apk

# Compare against the published checksum
cat SHA256SUMS.txt
```

Every release also publishes a CycloneDX Software Bill of Materials (`sbom-dependencies.json`) detailing all build-time components.

---

## 📄 License & Attribution

SafeSignal X is open source under the **Apache License 2.0** / Source-Available Research License. See [LICENSE](LICENSE) for terms.

**Author & Lead Researcher:**  
**Umar Farooque** — [GitHub: @UmarFarooqueJi](https://github.com/UmarFarooqueJi)
