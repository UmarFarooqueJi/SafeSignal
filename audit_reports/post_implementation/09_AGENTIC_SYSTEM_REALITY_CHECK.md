# 09 — AGENTIC SYSTEM REALITY CHECK: ARCHITECTURAL CLASSIFICATION

**Audit Date:** October 21, 2026  
**Auditor:** AI Agent Security Researcher  
**Components:** `AgenticInvestigator.dart`, `ToolRegistry.dart`, `AiExpertService.dart`

---

## 1. ARCHITECTURAL CLASSIFICATION MATRIX

The implementation was evaluated against the 6 standard AI architectures:

| Classification Category | Architectural Definition | Match Status | Forensic Proof from SafeSignal Codebase |
| :--- | :--- | :--- | :--- |
| **A. Rule-Based Decision Tree** | Static `if-else` or `switch` matching against hardcoded strings. | **Partial Match** | Used in `AiExpertService._generateOnDeviceExpertAnalysis()` for generating explanations. |
| **B. Fixed Sequential Workflow** | Hardcoded chain of functions executing in an immutable linear pipeline. | **Partial Match** | Core flow of `AgenticInvestigator`: Step A (URL) -> Step B (SMS) -> Step C (UPI). |
| **C. Dynamic Deterministic Tool Orchestrator** | Dispatches typed tools based on syntactic structure of input, with deterministic policy governance. | **PRIMARY MATCH** | `AgenticInvestigator.dart` and `ToolRegistry.dart` execute typed tools via regex observable dispatch. |
| **D. Local LLM-Guided Tool-Using Investigator** | Autonomous reasoning loop (ReAct / Plan-and-Solve) guided by on-device model inference. | **NO MATCH** | **Zero on-device LLMs exist**. No llama.cpp, ExecuTorch, or TFLite GenAI runtime is present. |
| **E. Autonomous Stateful Investigation System** | Self-directed agent that dynamically generates sub-goals and halts upon goal satisfaction. | **NO MATCH** | Investigation steps are statically hardcoded in code; max steps is an unvarying counter. |
| **F. Multi-Agent Architecture** | Multiple specialized autonomous agents communicating asynchronously over an agent bus. | **NO MATCH** | No agent message bus or multi-agent supervisor exists. |

**Official Architectural Verdict:**  
SafeSignal implements **Category C: Dynamic Deterministic Tool Orchestrator** with **Category A/B fallback logic**. It is **NOT** a local LLM-driven autonomous agent.

---

## 2. CODE-LEVEL EXECUTION DECONSTRUCTION (`AgenticInvestigator.dart`)

Lines 103–208 of `AgenticInvestigator.dart` show the exact execution loop:

```dart
// 1. Quarantines raw text
final isolatedContent = _sanitizeAndQuarantine(rawInput);

// 2. Extracts syntactic observables via Regex
final urls = _extractUrls(isolatedContent);
final upiVpas = _extractUpi(isolatedContent);

// 3. Statically calls Tool A if URLs present
for (final url in urls.take(2)) {
    final tool = toolRegistry.getTool('scan_url');
    final result = await tool.execute({'url': url});
    ...
}

// 4. Statically calls Tool B for SMS text
if (stepCount < maxExecutionSteps && rawInput.trim().isNotEmpty) {
    final smsTool = toolRegistry.getTool('analyze_sms');
    final result = await smsTool.execute({'text': isolatedContent, 'sender': sender});
    ...
}

// 5. Statically calls Tool C if UPI present
for (final vpa in upiVpas.take(1)) {
    final upiTool = toolRegistry.getTool('verify_upi');
    final result = await upiTool.execute({'vpa': vpa});
    ...
}

// 6. Hardcoded Synthesis
final isScam = findings.any((f) => f.contains('🚨') || f.contains('CRITICAL') || f.contains('MALWARE'));
final verdict = isScam ? 'CRITICAL' : (isSuspicious ? 'HIGH' : 'SAFE');
```

### Forensic Observations:
1. **Tool selection is hardcoded:** The agent does not "decide" which tool to use based on semantic understanding. If a string contains `http`, it calls `scan_url`. If a string contains `@`, it calls `verify_upi`.
2. **Synthesis is string matching:** The verdict is determined by `findings.any((f) => f.contains('🚨'))`.
3. **No planning or reflection:** There is no model generating reasoning traces, reflecting on tool failures, or revising investigation strategies.

---

## 3. ON-DEVICE AI ADVISOR REALITY CHECK (`AiExpertService.dart`)

Lines 316–410 of `AiExpertService.dart`:
```dart
String _generateOnDeviceExpertAnalysis(String domain, String context, String language) {
    final lower = context.toLowerCase();
    switch (domain) {
        case 'url':
            if (isDropper) return '...';
            if (isImpersonation) return '...';
            if (isDangerous) return '...';
            ...
```
The "on-device expert advisor" is a collection of static template strings selected via `if-else` substring checks on the word `dropper`, `impersonat`, `dangerous`, or `verified`.

**Conclusion:** Marketing or documentation describing SafeSignal as an "on-device SLM", "local generative AI", or "autonomous agentic AI" is an **exaggeration / marketing label** for deterministic rule-based tool orchestration and canned response synthesis.
