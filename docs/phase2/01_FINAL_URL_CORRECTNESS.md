# 01 — FINAL URL CORRECTNESS & INPUT STATUS SPECIFICATION

**Project:** SafeSignal Mobile Security Suite & Research Platform  
**Module:** `UrlIntelligenceEngine` (`lib/core/services/url_intelligence_engine.dart`)  
**Revision:** Phase 2 Engineering Transformation  
**Verification Target:** Malformed URL Ingestion, Typed Status Handling & Zero-Bypass Remediation  

---

## 1. EXECUTIVE SUMMARY & PROBLEM STATEMENT

Prior to Phase 2 remediation, malformed, broken, or unparseable URLs ingested by `UrlIntelligenceEngine.analyze()` fell through to an unhandled error branch:
```dart
// DEPRECATED DEFECTIVE CODE:
factory UrlResult.error(String url, {String message = 'Analysis could not be completed'}) {
  return UrlResult(
    url: url,
    domain: '',
    riskScore: 0, // <--- CRITICAL FLAW: Reported 0 (Clean) risk
    verdict: UrlVerdict.caution,
    ...
```
This produced a dangerous false sense of security: malformed URLs such as `http://invalid:::host:::99999/malware` or unsupported schemes like `javascript:alert(1)` yielded `riskScore: 0`, which downstream consumers or user dashboards could easily interpret as clean. Furthermore, there was no structural distinction between unparsable syntax, unsupported protocols, and actual benign host reputation.

---

## 2. PHASE 2 ARCHITECTURAL REMEDIATION

### 2.1 Typed Input Status Classification
We introduced an explicit enumeration `UrlInputStatus` that decouples syntactic input parsing validity from threat risk scoring:

```dart
enum UrlInputStatus {
  validUrl,           // Syntactically valid HTTP/HTTPS URL ready for full inspection
  invalidUrl,         // Broken syntax, unbracketed IPv6, missing host, or invalid port
  unsupportedScheme,  // Non-HTTP/HTTPS protocol (ftp, file, javascript, data, blob)
  unknownReputation,  // Valid syntax but dead host or unresolvable DNS
  analysisError,      // Unexpected runtime or parsing failure
}
```

### 2.2 Strict Syntactic Validation (`validateAndParse`)
Before triggering canonicalization, DoH queries, or threat heuristic checks, input strings undergo strict pre-flight parsing in `UrlIntelligenceEngine.validateAndParse(String input)`:

1. **Blank / Empty Input Guard:** Empty or whitespace-only strings immediately yield `UrlInputStatus.invalidUrl` with a cautious non-zero score (`riskScore: 35`).
2. **ASCII Control Character Guard:** Strings containing ASCII non-printable bytes (`[\x00-\x1F\x7F]`) are rejected immediately as `invalidUrl`.
3. **Scheme Whitelist Enforcement:** Only `http` and `https` schemes are accepted for active analysis. Any URL with explicit non-HTTP schemes (`ftp:`, `file:`, `javascript:`, `data:`, `blob:`, `intent:`) returns `UrlInputStatus.unsupportedScheme` with `riskScore: 25`, `verdict: UrlVerdict.caution`, and `isVerifiedSafe: false`.
4. **Percent-Encoding Conformance:** Percent signs not followed by two valid hexadecimal characters (`%(?![0-9a-fA-F]{2})`) are rejected as `invalidUrl`.
5. **Authority & Host Completeness:** URLs lacking an authority segment or having an empty host (e.g. `http:///path`) are rejected as `invalidUrl`.
6. **Network Port Boundary Check:** Explicit network ports are validated to lie strictly within `1 <= port <= 65535`. Ports outside this range (e.g. `http://example.com:99999`) or non-numeric port characters return `invalidUrl`.
7. **IPv6 Literal Conformance:** IPv6 addresses in hostname position must be enclosed in brackets `[...]` and pass RFC 4291 validation via `Uri.parseIPv6Address()`. Unbracketed colons in the host trigger an immediate `invalidUrl` verdict.
8. **Hostname Structural Integrity:** Hostnames containing consecutive dots (`example..com`), leading/trailing dots, or embedded spaces are rejected as `invalidUrl`.

---

## 3. VERIFIED TEST MATRIX & GROUND TRUTH FIXTURES

All test cases are codified in `test/url_intelligence_test.dart` under the `UrlIntelligenceEngine - Malformed & Invalid URL Handling` suite:

| Input Fixture | Status Verdict | Risk Score | Verified Safe | Risk Explanation |
| :--- | :--- | :--- | :--- | :--- |
| `""` (Empty string) | `UrlInputStatus.invalidUrl` | 35 | `false` | Input URL string cannot be empty or blank. |
| `http:///path/test` | `UrlInputStatus.invalidUrl` | 35 | `false` | URL is missing valid authority or host specification. |
| `http://example.com:99999/test` | `UrlInputStatus.invalidUrl` | 35 | `false` | Invalid network port specified in authority (99999). |
| `http://[:::1]/test` | `UrlInputStatus.invalidUrl` | 35 | `false` | Malformed IPv6 address literal inside brackets. |
| `http://example.com/%zz/test` | `UrlInputStatus.invalidUrl` | 35 | `false` | Malformed percent-encoding in URL. |
| `ftp://ftp.example.com/file.zip` | `UrlInputStatus.unsupportedScheme` | 25 | `false` | Unsupported URI scheme (ftp). Only HTTP and HTTPS supported. |
| `file:///sdcard/download/app.apk` | `UrlInputStatus.unsupportedScheme` | 25 | `false` | Unsupported URI scheme (file). |
| `javascript:alert(1)` | `UrlInputStatus.unsupportedScheme` | 25 | `false` | Unsupported URI scheme (javascript). |
| `http://example.com/\x00evil` | `UrlInputStatus.invalidUrl` | 35 | `false` | URL contains illegal ASCII control characters. |
| `http://invalid:::host:::99999/malware` | `UrlInputStatus.invalidUrl` | 35 | `false` | Authority contains malformed port delimiter or non-numeric port. |
| `http://example..com/path` | `UrlInputStatus.invalidUrl` | 35 | `false` | Malformed host structure: invalid dot placement. |

---

## 4. CONCLUSION

Malformed, corrupted, or unsupported URL inputs can never bypass security checks or return a score of 0 in SafeSignal. All inputs return typed, deterministic results with appropriate caution classifications.
