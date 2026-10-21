# 13 — THREAT INTELLIGENCE FEED & ADVISORY PROVENANCE AUDIT

**Audit Date:** October 21, 2026  
**Auditor:** Threat Intelligence Engineer  
**Components:** `lib/data/models/alert_model.dart`, `lib/features/feed/feed_screen.dart`

---

## 1. ADVISORY SOURCE VERIFICATION (ONLINE VS OFFLINE)

SafeSignal claims integration with genuine Indian threat intelligence feeds from CERT-In, I4C, RBI, NPCI, and TRAI. We verified the actual data acquisition pipelines:

### Pipeline A: Online Real-Time Fetching (`feed_screen.dart` lines 56–70)
```dart
final inQuery = Uri.encodeComponent('https://news.google.com/rss/search?q=cyber+scam+OR+fraud+OR+"digital+arrest"+india&hl=en-IN&gl=IN&ceid=IN:en');
final thnQuery = Uri.encodeComponent('https://feeds.feedburner.com/TheHackersNews');

final rssResults = await Future.wait([
    dio.get('https://api.rss2json.com/v1/api.json?rss_url=$inQuery'),
    dio.get('https://api.rss2json.com/v1/api.json?rss_url=$thnQuery'),
]);
```
- **Finding:** SafeSignal does **NOT connect directly** to the official API endpoints or RSS feeds of CERT-In, RBI, NPCI, or I4C.
- **Mechanism:** It queries an unauthenticated third-party commercial conversion proxy (`api.rss2json.com`), which parses Google News keyword queries (`cyber scam OR fraud OR "digital arrest" india`) and The Hacker News FeedBurner feed.
- **Limitation:** If `api.rss2json.com` is rate-limited, unreachable, or shuts down, online feed fetching completely fails.

---

### Pipeline B: Offline Threat Advisories (`alert_model.dart` lines 76–143)
When offline or when the network query fails, SafeSignal falls back to `AlertModel.offlineThreatAdvisories()`.
The hardcoded list contains 6 authentic advisories based on real Indian cyber advisories:
1. `digital_arrest_scam_alert`: "Digital Arrest / Fake Police Video Call Extortion" (Attributed to `cybercrime.gov.in`).
2. `cert_in_banking_trojans`: "CERT-In Advisory: Android Banking Trojans Masquerading as APK Updates" (Attributed to `cert-in.org.in`).
3. `npci_rbi_upi_collect`: "NPCI & RBI Alert: UPI PIN is Exclusively for Debiting Money" (Attributed to `npci.org.in`).
4. `trai_sim_deactivation`: "TRAI Alert: Automated IVR Calls Threatening 2-Hour SIM Deactivation" (Attributed to `sancharsaathi.gov.in`).
5. `telegram_task_fraud_advisory`: "I4C Warning: Transnational Telegram 'Like & Rating' Scams" (Attributed to `cybercrime.gov.in`).
6. `electricity_bill_scam_warning`: "Power Ministry Alert: Fraudulent Electricity Disconnection SMSes" (Attributed to `cybercrime.gov.in`).

---

## 2. FORENSIC DEFECT: SYNTHETIC DYNAMIC TIMESTAMPS ON STATIC ADVISORIES

Inspection of `alert_model.dart` reveals how publication dates are assigned in the static fallback:
```dart
publishedAt: DateTime.now().subtract(const Duration(hours: 1)), // Advisory 1
publishedAt: DateTime.now().subtract(const Duration(hours: 3)), // Advisory 2
publishedAt: DateTime.now().subtract(const Duration(hours: 6)), // Advisory 3
publishedAt: DateTime.now().subtract(const Duration(hours: 12)),// Advisory 4
publishedAt: DateTime.now().subtract(const Duration(hours: 18)),// Advisory 5
publishedAt: DateTime.now().subtract(const Duration(hours: 24)),// Advisory 6
```

### Forensic Impact:
- **Misleading Timestamps:** Even if the app has been offline for months or years, every time the offline feed is loaded, the hardcoded advisories claim to have been published *"1 hour ago"*, *"3 hours ago"*, etc.
- **Audit Directive Violation:**
  > *"Never display static or stale data as live threat intelligence."*
- **Remediation Required:** Hardcoded advisories should declare their authentic historical release dates (e.g. `2024-05-14T10:00:00Z` for the CERT-In Chameleon advisory), accompanied by an explicit badge indicating *"Archived Offline Advisory"*.
