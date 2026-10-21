# Security & Vulnerability Disclosure Policy

SafeSignal is an open-source cybersecurity and agentic AI research platform. We take vulnerability reports, research inquiries, and responsible disclosures seriously.

---

## 1. Supported Versions

| Version | Supported | Description |
| :--- | :---: | :--- |
| **1.2.x (SafeSignal X)** | ✅ Active | Active research and security patch branch |
| **1.1.x** | ⚠️ Limited | Critical security patches only |
| **< 1.1.0** | ❌ End of Life | Unsupported legacy builds |

---

## 2. Research Scope & In-Scope Vulnerabilities

We welcome security research into the following core subsystems:

### In-Scope
- **Agentic AI & Prompt Injection:** Bypasses in the prompt-injection quarantine boundary (`<<<UNTRUSTED_ARTEFACT>>>`) that force unauthorized tool execution.
- **Cryptographic Vault & Key Storage:** Flaws in AES-256 GCM/CBC implementation, memory leakage during decrypted viewing, or master passphrase bypass.
- **Evidence Ledger Integrity:** Collisions, state manipulation, or forgery in RFC 3161 cryptographic hash chaining.
- **URL Intelligence & Homograph Evasion:** Techniques allowing spoofed domains to evade canonicalization or brand-authority checks.
- **SMS & Call Interception Boundaries:** Flaws in native Kotlin `CallScreeningService` or `SmsReceiver` leading to unauthorized privilege elevation or intent hijacking.
- **Local Data Privacy:** Unintended external network leaks of sensitive user data, scanned links, or device telemetry.

### Out-of-Scope
- Vulnerabilities requiring unassisted physical access to an unlocked device.
- Attacks relying on social engineering against end users.
- Attacks on upstream third-party dependencies (please report directly to the package maintainer).
- Issues on custom rooted ROMs with broken Android security guarantees (unless demonstrating a bug in Tier 3 laboratory telemetry).

---

## 3. Coordinated Vulnerability Disclosure Process

1. **Confidential Submission:**  
   Submit details confidentially via [GitHub Security Advisories](https://github.com/UmarFarooqueJi/SafeSignal/security/advisories).
2. **Required Details:**  
   - Precise description of the issue.
   - Proof-of-concept (PoC) code or deterministic reproduction steps.
   - Assessment of potential impact and affected components.
3. **SLA & Response Timeline:**  
   - Initial acknowledgment: Within **48 hours**.
   - Triage and reproduction: Within **5 business days**.
   - Remediation and patch release: Within **30 days** depending on severity.
4. **Coordinated Release:**  
   Advisories and CVEs are published concurrently with the remediated patch release. Public credit will be awarded in release notes and contributor lists.

---

## 4. Safe Harbor for Security Researchers

SafeSignal supports good-faith security research. If you conduct vulnerability research in compliance with this policy:
- We will not pursue legal action against you.
- We will work cooperatively with you to understand, reproduce, and resolve the issue promptly.
- Research must remain non-destructive, must not access or compromise third-party data, and must respect user privacy.

---

## 5. Security Contact & Maintainers

- **Principal Maintainer:** Umar Farooque ([@UmarFarooqueJi](https://github.com/UmarFarooqueJi))
- **Advisories Hub:** [github.com/UmarFarooqueJi/SafeSignal/security](https://github.com/UmarFarooqueJi/SafeSignal/security)
