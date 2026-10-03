# Security Policy

## Supported Versions

| Version | Supported |
|---------|----------|
| 1.2.x   | ✅ Current |
| 1.1.x   | ✅ Security patches only |
| < 1.1   | ❌ End of life |

## Reporting a Vulnerability

SafeSignal is a security-focused application. We take vulnerability reports seriously.

**Contact:** Open a confidential GitHub Security Advisory at [SafeSignal Security Advisories](https://github.com/UmarFarooqueJi/SafeSignal/security/advisories)
**Discussions:** [GitHub Discussions](https://github.com/UmarFarooqueJi/SafeSignal/discussions)
**Response SLA:** 72 hours acknowledgment, 7 days triage

### Scope

In-scope for responsible disclosure:
- Authentication bypass in local vault
- Data leakage from Hive encrypted vault
- Local privilege escalation via native Kotlin services
- Biometric authentication bypass

Out-of-scope:
- Vulnerabilities in third-party libraries (report upstream)
- Social engineering attacks
- Physical device access scenarios

### Process

1. Submit a confidential advisory via [GitHub Security Advisories](https://github.com/UmarFarooqueJi/SafeSignal/security/advisories)
2. Include: affected version, reproduction steps, impact assessment
3. We will acknowledge within 72 hours
4. Coordinated disclosure after patch release
5. Credit will be given in release notes (unless you prefer anonymity)

### Attribution

SafeSignal was developed and is maintained by **Umar Farooque**.
