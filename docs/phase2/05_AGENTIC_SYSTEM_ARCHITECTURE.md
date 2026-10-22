# 05 — POLICY-CONSTRAINED AGENTIC CYBER INVESTIGATOR ARCHITECTURE

**Project:** SafeSignal Mobile Security Suite & Research Platform  
**Modules:** `AgenticInvestigator`, `ToolRegistry`, `ThreatGraphService`  
**Revision:** Phase 2 Engineering Transformation  

---

## 1. AGENTIC DOCTRINE & DESIGN PRINCIPLES

SafeSignal's autonomous cyber investigation engine is built on four core principles:
1. **Policy-Constrained Bounded Execution:** The agent cannot execute unbounded or runaway loops. Steps are hard-capped at `maxExecutionSteps = 5`.
2. **Deterministic Tool Contracts:** Analytical tools (`scan_url`, `analyze_sms`, `verify_upi`, `inspect_app_permissions`) are typed and validated via strict JSON parameter schemas.
3. **State Modification Gating:** The agent has zero autonomous permission to modify device state, uninstall apps, or transfer funds. Any state-altering action requires explicit Human-In-The-Loop (HITL) confirmation (`requiresConfirmation: true`).
4. **Tamper-Evident Forensic Provenance:** Every tool invocation, parameter, returned data, and reasoning step is cryptographically hashed into an append-only SHA-256 ledger block and linked into a directed temporal threat graph.

---

## 2. SYSTEM ARCHITECTURE & TRAJECTORY FLOW

```
                          [Untrusted Suspicious Input]
                                       │
                                       ▼
                       ┌───────────────────────────────┐
                       │  Prompt-Injection Quarantine   │
                       │  - Strips instruction lures   │
                       │  - Delimiter isolation        │
                       └───────────────┬───────────────┘
                                       │
                                       ▼
                       ┌───────────────────────────────┐
                       │   Observable Extraction       │
                       │   - URLs / Hosts / TLDs       │
                       │   - UPI Payment Handles       │
                       │   - Phone Sender / TRAI IDs   │
                       └───────────────┬───────────────┘
                                       │
                                       ▼
                      ┌─────────────────────────────────┐
                      │    Bounded Tool Execution Loop  │
                      │    (Max 5 Steps + Loop Guard)   │
                      └───────┬─────────┬─────────┬─────┘
                              │         │         │
                 ┌────────────┘         │         └────────────┐
                 ▼                      ▼                      ▼
        ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
        │  scan_url Tool  │    │analyze_sms Tool │    │ verify_upi Tool │
        │  - DoH & SSRF   │    │- TRAI Validator │    │- Fraud Patterns │
        │  - Homographs   │    │- Urgency Lures  │    │- PIN Lures      │
        └────────┬────────┘    └────────┬────────┘    └────────┬────────┘
                 │                      │                      │
                 └──────────────────────┼──────────────────────┘
                                        │
                                        ▼
                      ┌──────────────────────────────────┐
                      │    Directed Threat Graph Edge    │
                      │    & SHA-256 Evidence Ledger     │
                      └─────────────────┬────────────────┘
                                        │
                                        ▼
                      ┌──────────────────────────────────┐
                      │   InvestigationReport Synthesis  │
                      │   - Verified Chain Integrity     │
                      │   - Actionable Mitigation        │
                      └──────────────────────────────────┘
```

---

## 3. TYPED TOOL REGISTRY SPECIFICATION

### 3.1 `scan_url`
- **Purpose:** On-device inspection of suspicious links, open redirects, brand impersonation, SSRF targets, and mobile droppers.
- **Confirmation Required:** `false` (Read-only analysis).

### 3.2 `analyze_sms`
- **Purpose:** Evaluates message bodies for digital arrest threats, electricity bill scams, lottery lures, and TRAI/DLT sender spoofing.
- **Confirmation Required:** `false` (Read-only analysis).

### 3.3 `verify_upi`
- **Purpose:** Analyzes UPI Virtual Payment Addresses for deceptive refund/reward prefixes (`refund@...`, `cashback@...`) designed to trick victims into entering UPI PINs.
- **Confirmation Required:** `false` (Read-only analysis).

### 3.4 `inspect_app_permissions`
- **Purpose:** Scans declared permissions of installed or sideloaded APK packages for dangerous trojan combinations (`BIND_ACCESSIBILITY_SERVICE`, `SYSTEM_ALERT_WINDOW`, `RECEIVE_SMS`, `REQUEST_INSTALL_PACKAGES`).
- **Confirmation Required:** `false` (Read-only analysis).

---

## 4. AUDIT RECORD STRUCTURE (`InvestigationReport`)

Every completed investigation yields an immutable `InvestigationReport`:
```json
{
  "incident_id": "inc_1729584000000",
  "summary": "Autonomous investigation confirmed high-confidence fraud or cyber attack indicators.",
  "verdict": "CRITICAL",
  "confidence": 95,
  "primary_findings": [
    "Deceptive brand impersonation domain (sbi-kyc-update.xyz)",
    "High-confidence mobile Trojan dropper detected (.apk)",
    "Urgency keywords targeting banking credentials"
  ],
  "recommended_actions": [
    "Do NOT click or navigate to http://bit.ly/power-bill.apk",
    "Block sender and report to 1930 / cybercrime.gov.in"
  ],
  "audit_trace": [
    {
      "step_number": 1,
      "action": "Scan URL Intelligence",
      "tool_name": "scan_url",
      "arguments": { "url": "http://bit.ly/power-bill.apk" },
      "result": { "success": true, "threat_score": 85, "verdict": "dangerous" },
      "reasoning": "Extracted active hyperlink from untrusted content for domain and threat analysis."
    }
  ],
  "evidence_chain_verified": true,
  "completed_at": "2026-10-22T04:42:50.000Z"
}
```
