# 04 — NETWORK EGRESS & ZERO-CLOUD PRIVACY VERIFICATION

**Audit Date:** October 21, 2026  
**Auditor:** Independent Cybersecurity Re-Audit Team  
**Evaluation:** Testing the claim: *"SafeSignal is a completely air-gapped, zero-cloud cybersecurity platform."*

---

## 1. COMPREHENSIVE NETWORK EGRESS ENUMERATION

Every outbound network endpoint present in the production codebase was audited line-by-line:

| Component | Target URL / Host | Protocol | Payload / Telemetry Emitted | Trigger Condition | Air-Gapped Egress? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `UrlIntelligenceEngine` | `https://cloudflare-dns.com/dns-query` | DoH (HTTPS) | Queried domain name only (A, MX, NS, DMARC TXT). No path or query params. | Automatic during URL scan when online. | **No (Egress to Cloudflare)** |
| `UrlScannerScreen` | `https://www.google.com/s2/favicons?domain=...` | HTTPS | Target domain name sent to Google Favicon API. | When viewing scanned URL results. | **No (Egress to Google)** |
| `FeedScreen` | `https://api.rss2json.com/v1/api.json?rss_url=...` | HTTPS | Proxied RSS query for Google News and Hacker News. | When user opens Threat Feed tab online. | **No (Egress to rss2json)** |
| `SocialOsintScreen` | `api.fxtwitter.com`, `instagram.com`, `threads.net`, `api.github.com`, etc. | HTTPS | Usernames entered in social OSINT profile lookups. | User clicks "Audit Identity / Username". | **No (Egress to Social APIs)** |
| `WifiScannerScreen` | `http://connectivitycheck.gstatic.com/generate_204` | HTTP (Cleartext) | Empty GET request (fails on Android 9+). | User initiates Wi-Fi scan. | **No (Egress to Google)** |
| `WifiScannerScreen` | `https://1.1.1.1` | HTTPS | Ping/SSL handshake request to Cloudflare DNS IP. | User initiates Wi-Fi scan. | **No (Egress to Cloudflare)** |
| `AiExpertService` | `openrouter.ai`, `api.deepseek.com`, `api.x.ai`, `googleapis.com`, `api.cloudflare.com` | HTTPS | User prompt, context report, system instructions. | Optional: ONLY if user configures custom API keys. | **No (When keys configured)** |
| `ChatScreen` | `openrouter.ai`, `api.deepseek.com`, `api.cloudflare.com` | HTTPS | OCR text from screenshot, user questions, conversation history. | Optional: ONLY if user configures custom API keys. | **No (When keys configured)** |

---

## 2. PRIVACY ASSESSMENT: OFFLINE VS ONLINE BEHAVIOR

### Completely Air-Gapped / Offline Modules (100% On-Device):
1. **Document & Screenshot OCR:** Uses bundled Google ML Kit native libraries (`libmlkit_google_ocr_pipeline.so`) and neural models in `assets/`. Zero bytes leave the phone.
2. **SMS Smishing & OTP Protection:** `SmsReceiver.kt` runs 100% offline regex heuristics and redacts OTPs before storing in SharedPreferences.
3. **Hardware-Backed Document Vault:** `VaultCryptoService.dart` executes AES-256-GCM locally using KeyStore keys. Decryption occurs purely in volatile RAM.
4. **App Permission & Sideload Audit:** `AppRiskEngine.dart` and `MainActivity.kt` query Android `PackageManager` directly on-device.
5. **Call Shield & Emergency Screening:** `SafeSignalCallScreeningService.kt` screens incoming calls locally using device SharedPreferences settings.
6. **Local Rule Engine & Incident Report Generator:** Generates PDF incident reports and runs heuristic threat analysis entirely in-memory.

### Online Mode Contradiction & Telemetry Leaks:
When an internet connection is active, the app is **NOT strictly air-gapped**:
1. **DNS Egress:** Scanning any URL generates 4 HTTPS requests to Cloudflare (`1.1.1.1`). While DNS-over-HTTPS protects against local ISP snooping, Cloudflare receives every domain queried by the user.
2. **Third-Party Proxy for Feeds:** Threat advisories do not originate directly from official Indian government endpoints (CERT-In, RBI); they are retrieved through a third-party intermediary, `api.rss2json.com`.
3. **Favicon Leak:** `UrlScannerScreen` fetches website favicons from `google.com/s2/favicons?domain=...`, leaking the domain to Google servers.

---

## 3. VERDICT ON ZERO-CLOUD PRIVACY CLAIM

**Verdict:** **VERIFIED WITH ARCHITECTURAL LIMITATIONS**.
- The core sensitive processing (OCR, Vault, SMS scanning, malware scanning) is genuinely 100% offline and zero-cloud.
- However, describing the application as an unconditionally "air-gapped, zero-network" platform is inaccurate. It operates in **Hybrid Mode**: fully functional offline, but generating passive external network traffic to Cloudflare, Google, and rss2json when network connectivity is present.
