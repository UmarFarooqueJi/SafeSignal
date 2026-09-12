# Security Policy

SafeSignal takes the security of its users and code very seriously. We appreciate the responsible disclosure of vulnerabilities.

## Supported Versions

Only the latest release and the main branch receive active security updates.

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a potential vulnerability or security issue:

1. **Do NOT open a public GitHub issue.**
2. Email the maintainers directly or use GitHub's private vulnerability reporting feature on the repository.
3. Provide detailed steps to reproduce the issue, including environment details, payloads, and expected vs actual behavior.
4. Allow reasonable time for the maintainers to investigate and issue a patch before publishing any details publicly.

## Secrets & API Hygiene

- SafeSignal relies on various third-party security intelligence providers (Supabase, VirusTotal, Google Safe Browsing, OpenRouter).
- Under no circumstances should actual production API keys or environment variables be committed to the repository.
- Always use `.env.example` as a template and keep `.env` strictly gitignored.
