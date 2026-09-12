<div align="center">
  <img src="assets/images/logo_transparent.png" alt="SafeSignal Logo" width="140" />
  <h1>🛡️ SafeSignal</h1>
  <p><b>Next-Generation Open-Source AI Mobile Security & Anti-Fraud Suite for Android</b></p>

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
  [![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](#)
  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
  [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
  [![Security Policy](https://img.shields.io/badge/Security-Policy-red.svg)](SECURITY.md)
  <br>
  <b>🚀 Powered by Hybrid AI Orchestration & Real-time Threat Intelligence</b>
</div>

<br>

<div align="center">
  <img src="docs/screenshots/home.png" alt="SafeSignal Home Dashboard" width="240" style="margin-right: 12px; border-radius: 16px;" />
  <img src="docs/screenshots/sidebar.png" alt="SafeSignal Menu & Tools" width="240" style="border-radius: 16px;" />
</div>

<br>

## 🌟 Overview & Mission

**SafeSignal** is a privacy-first, community-driven mobile cybersecurity application built to shield users from digital fraud, financial cybercrimes, phishing traps, rogue wireless networks, and intrusive spyware. 

Whether it is a fake UPI QR code at a local store, a suspicious SMS claiming your bank account is blocked, a deceptive phishing link, or unauthorized device tampering, SafeSignal analyzes the threat in milliseconds using a combination of **local rule engines**, **crowd-sourced blocklists**, and **hybrid AI models** (via OpenRouter/DeepSeek).

---

## ⚡ Core Capabilities & Features

### 1. 🔍 Phishing & URL Shield
- Deep inspection of URLs for homograph attacks, typosquatting, shortener abuse, and malicious redirect chains.
- Multi-engine verification using **Google Safe Browsing** and **VirusTotal**.
- AI-synthesized security verdict explaining technical risk indicators in plain language.

### 2. 💸 UPI & QR Code Fraud Guard
- Instant scanning of UPI payment QR codes (`upi://pay`).
- Verifies merchant VPA legitimacy and warns against common **UPI Collect Request Scams** and fake refund traps.
- Integrated with local cache and real-time crowd-sourced threat intelligence.

### 3. 📱 Deep Device Security Audit
- Scans system integrity, root status, Magisk/SuperSU footprints, and bootloader status.
- Detects unsafe developer options and USB debugging states.
- Audits third-party applications against dangerous permission matrices (`READ_SMS`, `READ_CALL_LOG`, `SYSTEM_ALERT_WINDOW`).

### 4. ✉️ Data Breach & Identity Monitor
- Checks email credentials against public database leaks (via HaveIBeenPwned & XposedOrNot).
- Prioritized recovery steps and tailored advisories for compromised accounts.

### 5. 📶 WiFi Network Threat Inspector
- Identifies unencrypted open hotspots, captive portals (MITM traps), and rogue access points.
- Analyzes gateway routing anomalies and DNS security settings.

### 6. 🚨 Real-time SMS & Call Screening (Android)
- Automatic background screening of incoming SMS messages for smishing, fake KYC alerts, and OTP theft attempts.
- Incoming call pattern detection for commercial/telemarketing prefixes and international scam spoofs.

### 7. 📰 Live Cyber Threat Feed
- Real-time aggregation of cybersecurity advisories, fraud trends, and vulnerability reports with language localization (Hindi / English).

---

## 🏗️ Architecture & Tech Stack

SafeSignal is designed with modularity, privacy, and low battery consumption in mind:

```
┌─────────────────────────────────────────────────────────┐
│                   SafeSignal UI Layer                   │
│          Flutter 3.x + Material 3 + Riverpod            │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│                 Core Services & Routing                 │
│         GoRouter • Hive Local Cache • SecureStorage     │
└──────────────┬───────────────────────────┬──────────────┘
               │                           │
┌──────────────▼──────────────┐ ┌──────────▼──────────────┐
│     Hybrid AI Engine        │ │   Crowd Threat Intel    │
│  Local Rule Engine (Tier 1) │ │    Supabase Backend     │
│  OpenRouter / DeepSeek (T2) │ │  Decentralized Reports  │
└─────────────────────────────┘ └─────────────────────────┘
```

- **Framework**: Flutter (Dart 3.x)
- **State Management**: `flutter_riverpod`
- **Navigation**: `go_router`
- **Local Database**: Hive & SharedPreferences
- **Backend / Auth**: Supabase
- **Networking**: Dio
- **Native Platform Services**: Android Kotlin (`NotificationListenerService`, `BroadcastReceiver`, `ForegroundService`)

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.10.7`)
- Android Studio / VS Code with Flutter extension
- Android Device or Emulator (API level 26+)

### 1. Clone the Repository
```bash
git clone https://github.com/UmarFarooqueJi/SafeSignal.git
cd SafeSignal/safesignal
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Environment Variables
Copy the `.env.example` file to create your `.env`:
```bash
cp .env.example .env
```
Fill in your configuration keys:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
NEWS_DATA_API_KEY=your_newsdata_key
SAFE_BROWSING_API_KEY=your_google_safe_browsing_key
VIRUSTOTAL_API_KEY=your_virustotal_key
OPENROUTER_API_KEY=your_openrouter_key
```

### 4. Setup Supabase Database
Run the schema script provided in [`supabase_schema.sql`](supabase_schema.sql) in your Supabase SQL Editor. It creates all tables with secure Row Level Security (RLS) policies.

### 5. Run SafeSignal
```bash
flutter run
```

---

## 🔒 Security & Privacy First

- **Zero Data Harvesting**: Scans are processed locally or hashed via SHA-256 before threat intelligence queries.
- **Secrets Management**: No private keys are baked into client binaries.
- **Reporting Vulnerabilities**: See [SECURITY.md](SECURITY.md) for our disclosure policy.

---

## 🤝 Contributing

We love community contributions! Please read our [CONTRIBUTING.md](CONTRIBUTING.md) to learn about our code review process, coding standards, and how to submit pull requests.

---

## 📄 License

SafeSignal is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

---

<div align="center">
  <sub>Engineered with ❤️ by <b><a href="https://github.com/UmarFarooqueJi">Umar Farooque</a></b> for a safer digital world.</sub>
</div>
