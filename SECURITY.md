# Security Policy

## Supported Versions

| Version | Supported |
|---------|----------|
| 1.2.x   | ✅ Current |
| 1.1.x   | ✅ Security patches only |
| < 1.1   | ❌ End of life |

## Reporting a Vulnerability

SafeSignal is a security-focused application. We take vulnerability reports seriously.

**Contact:** umarfarooque@safesignal.app
**PGP:** Contact via email to request encrypted channel
**Response SLA:** 72 hours acknowledgment, 7 days triage

### Scope

In-scope for responsible disclosure:
- Authentication bypass in Supabase integration
- Data leakage from Hive encrypted vault
- Man-in-the-middle vulnerabilities in threat API calls
- Local privilege escalation via native Kotlin services
- Biometric authentication bypass

Out-of-scope:
- Vulnerabilities in third-party libraries (report upstream)
- Social engineering attacks
- Physical device access scenarios

### Process

1. Email `umarfarooque@safesignal.app` with subject `[SECURITY] SafeSignal <brief>`
2. Include: affected version, reproduction steps, impact assessment
3. We will acknowledge within 72 hours
4. Coordinated disclosure after patch release
5. Credit will be given in release notes (unless you prefer anonymity)

### Attribution

SafeSignal was developed by **Umar Farooque** and is maintained by SafeSignal Technologies.
