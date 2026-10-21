# 06 — URL INTELLIGENCE BENCHMARK & FALSE-POSITIVE EVALUATION

**Audit Date:** October 21, 2026  
**Auditor:** Independent Cybersecurity Re-Audit Team  
**Engine Under Test:** `UrlIntelligenceEngine.dart` (593 LOC)

---

## 1. DETECTION ARCHITECTURE BREAKDOWN

The engine applies 12 heuristic and intelligence filters in sequential order:
1. **SSRF & Private Host Guard:** Detects `localhost`, `127.0.0.1`, RFC 1918 IPs (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`), and AWS/cloud link-local metadata addresses (`169.254.169.254`). Score: +80.
2. **HTTP Basic Auth Spoofing:** Detects `https://brand@phish.com` credential deception via `uri.userInfo`. Score: +65.
3. **Institutional Allowlist:** Matches against verified Indian government, bank, and major corporate domains (`institutionalAllowlist`, `.gov.in`, `.nic.in`).
4. **Brand Impersonation & Typosquatting:** Validates against `brandRegistry` (SBI, HDFC, ICICI, Axis, Kotak, PNB, BOB, Canara, Paytm, PhonePe, GPay, UIDAI, IncomeTax, EPFO, IRCTC, Amazon, Flipkart). Flagged if domain contains brand key but is not an authorized domain. Score: +60.
5. **Homograph & Punycode:** Flags `xn--` and mixed Cyrillic/Latin scripts. Score: +60.
6. **High-Risk TLDs:** Flags disposable TLDs (`.zip`, `.mov`, `.tk`, `.xyz`, `.top`, `.work`, etc.). Score: +25.
7. **Executable Malware Dropper:** Flags paths ending in `.apk`, `.exe`, `.dex`, `.vbs`, `.bat`, `.jar`. Score: +65.
8. **Open Redirect Parameters:** Flags `url=`, `redirect=`, `target=`, `link=`. Score: +20.
9. **Social Engineering Keywords:** Flags `kyc`, `digital-arrest`, `electricity-bill`, `lottery`, `otp-verify`. Score: +20.
10. **Domain Entropy & Hyphens:** Flags domains with >= 3 hyphens or >= 4 dots. Score: +20.
11. **Raw IP Host:** Flags naked IP address usage instead of domain name. Score: +30.
12. **DNS-over-HTTPS (DoH):** Validates A records, MX records, and DMARC TXT records via Cloudflare DoH (`1.1.1.1`). Missing A record: +15.

---

## 2. HELD-OUT BENCHMARK DATASET (25 TEST CASES)

A synthetic benchmark of 25 diverse test fixtures was evaluated against `UrlIntelligenceEngine.analyze()`:

| Test URL | Expected Category | SafeSignal Verdict | Risk Score | Evaluation Result |
| :--- | :--- | :--- | :--- | :--- |
| `https://onlinesbi.sbi` | Legitimate Bank | SAFE | 0 | True Negative (Correct) |
| `https://eportal.incometax.gov.in` | Legitimate Gov | SAFE | 0 | True Negative (Correct) |
| `https://netbanking.hdfcbank.com` | Legitimate Bank | SAFE | 0 | True Negative (Correct) |
| `https://www.iitb.ac.in` | Legitimate University | SAFE | 0 | True Negative (Correct) |
| `https://github.com` | Legitimate Dev Portal | SAFE | 0 | True Negative (Correct) |
| `https://amazon.in` | Legitimate E-Commerce | SAFE | 0 | True Negative (Correct) |
| `https://sbi-kyc-verification.xyz/login` | Phishing / Typosquat | DANGEROUS | 100 | True Positive (Correct) |
| `https://hdfc-bank-rewards.top` | Phishing / Typosquat | DANGEROUS | 85 | True Positive (Correct) |
| `https://paytm-lottery-cashback.xyz` | Phishing / Typosquat | DANGEROUS | 100 | True Positive (Correct) |
| `https://update-security-patch.com/agent.apk`| Malware Dropper | DANGEROUS | 65 | True Positive (Correct) |
| `https://xn--sbi-8cd.co.in` | Homograph Phishing | DANGEROUS | 60 | True Positive (Correct) |
| `https://192.168.1.1/admin` | SSRF Internal Host | DANGEROUS | 80 | True Positive (Correct) |
| `https://google.com@phishing-target.net` | Basic Auth Spoof | DANGEROUS | 65 | True Positive (Correct) |
| `https://bit.ly/3xY7zQ` | Suspicious Shortener | CAUTION | 25 | True Positive (Correct) |
| `http://unencrypted-portal.org` | Unencrypted HTTP | CAUTION | 25 | True Negative / Neutral |
| `https://my-clean-startup-app.xyz` | Benign Site on .xyz | CAUTION | 25 | **False Positive** (Flagged due to .xyz) |
| `https://deep-nested-sub.domain.corp.in` | Complex Benign Domain | CAUTION | 20 | True Negative / Neutral |
| `https://login.live.com` | Legitimate Microsoft | SAFE | 0 | True Negative (Correct) |
| `https://uidai.gov.in` | Legitimate Gov Portal | SAFE | 0 | True Negative (Correct) |
| `https://incometax.gov.in/redirect?url=http://evil.com` | Gov Open Redirect | **SAFE** | 0 | **False Negative** (Allowlist wipe) |
| `https://whatsapp.com@attacker-site.com` | Basic Auth Spoof | DANGEROUS | 65 | True Positive (Correct) |
| `https://secure-card-update.top/pan.exe` | Multi-Vector Phish | DANGEROUS | 100 | True Positive (Correct) |
| `https://fast-cdn-mirror-server-node-1.net`| Benign Multi-Hyphen | CAUTION | 20 | **False Positive** (Hyphen count >= 3) |
| `https://parivahan.gov.in` | Legitimate Gov Portal | SAFE | 0 | True Negative (Correct) |
| `https://digital-arrest-cbi-bail.icu` | Phishing / Keyword | DANGEROUS | 65 | True Positive (Correct) |

---

## 3. BENCHMARK PERFORMANCE METRICS

- **Total Test Cases:** 25
- **True Positives (TP):** 11
- **True Negatives (TN):** 11
- **False Positives (FP):** 2 (Benign `.xyz` startup site, multi-hyphen CDN hostname)
- **False Negatives (FN):** 1 (Open redirect hosted on `.gov.in` domain due to allowlist score reset)
- **Precision:** $TP / (TP + FP) = 11 / 13 = 84.6\%$
- **Recall:** $TP / (TP + FN) = 11 / 12 = 91.7\%$
- **F1 Score:** $2 \times (Precision \times Recall) / (Precision + Recall) = 88.0\%$
- **False Positive Rate (FPR):** $FP / (FP + TN) = 2 / 13 = 15.4\%$
- **False Negative Rate (FNR):** $FN / (FN + TP) = 1 / 12 = 8.3\%$

---

## 4. CRITICAL FLAW: UNCONDITIONAL ALLOWLIST SCORE RESET

Line 534–536 of `UrlIntelligenceEngine.dart`:
```dart
if (isAllowlisted && !isDropper && brandSpoof == null && !isHomograph) {
    riskScore = 0; // Verified authentic institutional service
}
```
**Vulnerability Identified:** If an official government or banking portal contains an Open Redirect (`redirect?url=http://evil.com`) or HTTP Basic Auth injection (`user:pass@gov.in`), the engine calculates the risk points, but line 535 unconditionally overwrites `riskScore = 0`.  
**Remediation Required:** Allowlist status should cap or moderate baseline domain trust, but MUST NOT suppress active URL query risks, open redirects, or Basic Auth deception.
