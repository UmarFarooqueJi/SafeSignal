# 08 — RESIDUAL RISKS, THREAT BOUNDARIES & OPERATIONAL LIMITATIONS

**Target:** SafeSignal Mobile Security Suite  
**Risk Appraisal Lead:** Byte (Senior Offensive Security Engineer & Malware Researcher)  
**Execution Date:** October 22, 2026  
**Security Posture:** DEFENSE-IN-DEPTH WITH DOCUMENTED BOUNDARIES  

---

## 1. PRINCIPLE OF HONEST THREAT MODELING

In cybersecurity engineering, claims of "100% invulnerability" or "complete defense against all threats" are deceptive. Every security system is bounded by the operational constraints of the underlying hardware, operating system kernel, permissions model, and mathematical trade-offs.

This document explicitly defines SafeSignal's residual risks and operational boundaries following the successful remediation of P0/P1 defects.

---

## 2. ANDROID OS SANDBOXING & PRIVILEGE BOUNDARIES

### 2.1 Cross-Application Memory & Data Isolation
- **Boundary:** In compliance with the Android Linux kernel security model (SELinux and UID separation), SafeSignal operates within its own application sandbox (`uid = u0_aXXX`).
- **Limitation:** SafeSignal cannot inspect the private application directories (`/data/data/<package_name>/*`) of third-party apps, nor can it inspect the runtime heap memory of external processes.
- **Threat Implication:** If a malicious application does not declare suspicious manifest permissions and downloads an obfuscated payload directly into its private storage, SafeSignal cannot audit the payload on a non-rooted device (Tier 1). Detection must occur at the ingress boundary (Link Guard or SMS/Download scanner).

### 2.2 Cross-App Network Traffic & TLS Encrypted Streams
- **Boundary:** SafeSignal does not inject a system-wide VPN loopback proxy or install a custom user CA certificate.
- **Limitation:** SafeSignal cannot decrypt or inspect HTTPS/TLS traffic originating from third-party browsers (Chrome, Firefox) or messaging apps (WhatsApp, Telegram).
- **Remediation Reliance:** Link Guard relies on user-initiated actions (Android Share Sheet / incoming Intent receiver or clipboard monitoring) to inspect links before navigation.

### 2.3 Telephony & SMS Platform Permissions (Android 10–14)
- **Call Screening:** Android's `CallScreeningService` API requires explicit user designation in System Settings as the active Call Screening Assistant. If OEM battery optimization kills the background service, or if the user revokes the role, real-time call screening ceases.
- **SMS Interception:** Google Play restricts `RECEIVE_SMS` and `READ_SMS`. While SafeSignal is an open-source GitHub research APK sideloaded by users (and thus free from Play Store policy bans), users must manually grant SMS permissions in Android Settings for real-time scam alert processing.

---

## 3. URL INTELLIGENCE ENGINE RESIDUAL BOUNDARIES

### 3.1 Passive Heuristics vs. Active Network Probing
- **Design Trade-Off:** SafeSignal intentionally performs **passive heuristic scanning** to preserve 100% privacy, zero telemetry, and avoid alerting threat actors that an automated scanner is probing their infrastructure.
- **Limitation:** 
  1. **Novel Zero-Day Domains:** Newly registered phishing domains ($< 24\text{ hours}$ old) utilizing randomized character strings without brand keywords (e.g. `https://kq89xza.com/p`) will be classified as `UNKNOWN` or `SUSPICIOUS` rather than `CRITICAL DANGER`.
  2. **Cloaked / Multi-Hop Shorteners:** Advanced phishing campaigns utilizing multi-hop URL shorteners with conditional IP/user-agent cloaking cannot be fully unmasked without following the live HTTP redirection chain.

---

## 4. VAULT CRYPTOGRAPHY & PHYSICAL ATTACK SURFACES

### 4.1 Passphrase Entropy & Dictionary Attacks
- **Mitigation:** The vault implements PBKDF2-HMAC-SHA256 with 100,000 iterations, adding significant computational cost ($\sim 120\text{ ms}$ per guess on modern mobile CPUs) to impede brute-force cracking.
- **Residual Risk:** If a user chooses an extremely weak, predictable passphrase (e.g., `123456`, `password`), and an adversary extracts the encrypted vault database via physical hardware JTAG or rooted ADB extraction, the ciphertext remains vulnerable to offline dictionary attack clusters. SafeSignal recommends a minimum of 12 alphanumeric characters.

### 4.2 Compromised Host OS (Kernel Rootkit / Magisk Hooks)
- **Threat:** If an attacker has established root persistence (Tier 3) on the host device before SafeSignal is run:
  - The attacker can hook zygote or use Frida/eBPF to dump process memory while the vault is legitimately unlocked by the user.
  - While SafeSignal's `lockVault()` zeroizes the DEK in memory upon background transition, the key is necessarily present in memory while the user is actively viewing a document. Hardware security boundary protections cannot withstand a compromised kernel running at the same or higher privilege level.

---

## 5. LOCAL HASH CHAIN VS. DISTRIBUTED TIME-STAMPING

### 5.1 Local Tamper-Evidence Guarantee
- **What It Guarantees:** Any modification, deletion, or reordering of intermediate blocks within the SHA-256 evidence chain is mathematically detected by `verifyChainIntegrity()`.
- **Limitation:** Because the evidence chain is stored locally on the device (maintaining zero-cloud air-gap privacy) without external anchor publication (such as a public blockchain, distributed ledger, or RFC 3161 TSA server), an adversary with root access could theoretically delete the entire database file and initialize a clean genesis block. Detection of total chain replacement requires exporting the STIX 2.1 bundle to an off-device SIEM repository.

---

## 6. RISK ACCEPTANCE MATRIX

| Component | Risk Vector | Mitigation Implemented | Residual Severity | Operational Action |
| :--- | :--- | :--- | :--- | :--- |
| **URL Engine** | Zero-day phishing domains with novel grammar | Passive heuristic scoring + High-Risk TLD flags | **LOW** | User education: exercise caution on `UNKNOWN` links |
| **Document Vault** | Weak user master passphrases | PBKDF2 100,000 rounds + KeyStore wrapping | **LOW** | Enforce passphrase strength meter in UI |
| **SMS Shield** | OEM background process termination | Foreground service sticky flags + Battery guide | **MEDIUM** | Prompt user to disable OEM battery optimization |
| **Evidence Ledger**| Full local database deletion by root attacker | STIX 2.1 SIEM export bundle generation | **LOW** | Periodically export evidence bundles to secure storage |

SafeSignal's security posture is mathematically sound, ethically grounded, and transparently communicated.
