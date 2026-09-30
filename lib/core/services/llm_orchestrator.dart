// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: Hybrid AI Orchestration Engine with Circuit Breaker
// Author: Umar Farooque (umarfarooque@safesignal.app)
// Copyright (c) 2026 SafeSignal Technologies. All rights reserved.
// Circuit-breaker: OpenRouter → DeepSeek → Local Rule Engine (degraded)
// -----------------------------------------------------------------------------
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants.dart';
import '../models/ai_verdict.dart';
import 'local_rule_engine.dart';

/// LLM Orchestration Layer with circuit breaker + failover.
/// Priority: Gemini (primary) → GPT-class → Rule-engine (degraded)
class LlmOrchestrator {
  static final LlmOrchestrator _instance = LlmOrchestrator._internal();
  factory LlmOrchestrator() => _instance;
  LlmOrchestrator._internal();

  final _ruleEngine = LocalRuleEngine();
  final _dio = Dio();

  // Circuit breaker state per provider
  final Map<String, int> _failureCount = {};
  final Map<String, DateTime?> _circuitOpenedAt = {};
  static const int _failureThreshold = 3;
  static const Duration _circuitResetDuration = Duration(minutes: 2);

  // ─── Main entry point ──────────────────────────────────────────────────────
  Future<AiVerdict> analyze({
    required String text,
    required String type, // 'sms', 'url', 'chat'
    String language = 'hi',
  }) async {
    // Always run rule engine first (Tier 1 — instant, offline)
    final ruleVerdict = _ruleEngine.analyze(text, type: type);

    // If rule engine is very confident (>85), skip cloud
    if (ruleVerdict.confidence >= 0.90) {
      debugPrint('[LLM] High confidence from rule engine — skipping cloud');
      return ruleVerdict;
    }

    // Try cloud providers in order: OpenRouter Claude (primary) → DeepSeek (secondary)
    final providers = [
      _Provider(name: 'openrouter', analyze: (t, l) => _callOpenRouter(t, l)),
      _Provider(name: 'deepseek', analyze: (t, l) => _callDeepSeek(t, l)),
    ];

    for (final provider in providers) {
      if (_isCircuitOpen(provider.name)) {
        debugPrint('[LLM] Circuit open for ${provider.name}, skipping');
        continue;
      }

      try {
        final verdict = await provider
            .analyze(text, language)
            .timeout(const Duration(seconds: 20));
        _recordSuccess(provider.name);
        return verdict.copyWith(provider: provider.name);
      } catch (e) {
        debugPrint('[LLM] ${provider.name} failed: $e');
        _recordFailure(provider.name);
      }
    }

    // All cloud providers failed → degraded mode with rule engine
    debugPrint(
      '[LLM] All providers failed — using rule engine (degraded mode)',
    );
    return ruleVerdict.copyWith(isOffline: true);
  }

  // ─── OpenRouter provider (Claude Haiku) ───────────────────────────────────
  Future<AiVerdict> _callOpenRouter(String text, String language) async {
    final langName = language == 'hi'
        ? 'Hindi (Devanagari or Hinglish acceptable)'
        : 'English';

    final systemPrompt =
        '''
You are SafeSignal — India's elite AI cybersecurity expert. Analyze the following content for scams, fraud, and security threats.

RESPOND ONLY WITH A VALID JSON OBJECT — no markdown, no code blocks:
{
  "verdict": "SCAM" or "SUSPICIOUS" or "SAFE",
  "riskScore": 0 to 100,
  "confidence": 0.0 to 1.0,
  "reasons": ["specific red flag 1", "specific red flag 2", "specific red flag 3"],
  "whatToDo": ["clear step 1", "clear step 2", "report to 1930 or cybercrime.gov.in"],
  "summary": "2-3 sentence plain language summary"
}
Write ALL text in $langName.
''';

    final response = await _dio.post(
      'https://openrouter.ai/api/v1/chat/completions',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConstants.openRouterApiKey}',
          'HTTP-Referer': 'https://safesignal.app',
        },
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
      data: {
        'model': 'anthropic/claude-3-haiku',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': 'Analyze this content:\n$text'},
        ],
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
      },
    );

    final content = response.data['choices'][0]['message']['content'] as String;
    String jsonStr = content.trim();
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replaceAll(RegExp(r'```[a-z]*\n?'), '').trim();
    }
    if (jsonStr.endsWith('```')) {
      jsonStr = jsonStr.substring(0, jsonStr.length - 3).trim();
    }

    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return AiVerdict.fromJson({...json, 'provider': 'openrouter'});
  }

  // ─── DeepSeek provider (failover) ─────────────────────────────────────────
  Future<AiVerdict> _callDeepSeek(String text, String language) async {
    final langName = language == 'hi'
        ? 'Hindi (Devanagari or Hinglish acceptable)'
        : 'English';

    final systemPrompt =
        '''
You are SafeSignal — India's elite AI cybersecurity expert. Analyze the following for scams and fraud.
RESPOND ONLY WITH A VALID JSON OBJECT:
{
  "verdict": "SCAM" or "SUSPICIOUS" or "SAFE",
  "riskScore": 0 to 100,
  "confidence": 0.0 to 1.0,
  "reasons": ["red flag 1", "red flag 2"],
  "whatToDo": ["step 1", "step 2"],
  "summary": "2 sentence summary"
}
Write ALL text in $langName.
''';

    final response = await _dio.post(
      'https://api.deepseek.com/v1/chat/completions',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConstants.deepSeekApiKey}',
        },
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
      data: {
        'model': 'deepseek-chat',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': 'Analyze this content:\n$text'},
        ],
        'temperature': 0.1,
      },
    );

    final content = response.data['choices'][0]['message']['content'] as String;
    String jsonStr = content.trim();
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replaceAll(RegExp(r'```[a-z]*\n?'), '').trim();
    }
    if (jsonStr.endsWith('```')) {
      jsonStr = jsonStr.substring(0, jsonStr.length - 3).trim();
    }

    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return AiVerdict.fromJson({...json, 'provider': 'deepseek'});
  }

  // ─── Circuit breaker logic ─────────────────────────────────────────────────
  bool _isCircuitOpen(String provider) {
    final count = _failureCount[provider] ?? 0;
    if (count < _failureThreshold) return false;

    final openedAt = _circuitOpenedAt[provider];
    if (openedAt == null) return false;

    if (DateTime.now().difference(openedAt) > _circuitResetDuration) {
      // Reset circuit
      _failureCount[provider] = 0;
      _circuitOpenedAt[provider] = null;
      debugPrint('[LLM] Circuit reset for $provider');
      return false;
    }
    return true;
  }

  void _recordFailure(String provider) {
    _failureCount[provider] = (_failureCount[provider] ?? 0) + 1;
    if ((_failureCount[provider] ?? 0) >= _failureThreshold) {
      _circuitOpenedAt[provider] ??= DateTime.now();
      debugPrint('[LLM] Circuit OPENED for $provider');
    }
  }

  void _recordSuccess(String provider) {
    _failureCount[provider] = 0;
    _circuitOpenedAt[provider] = null;
  }
}

class _Provider {
  final String name;
  final Future<AiVerdict> Function(String text, String language) analyze;
  const _Provider({required this.name, required this.analyze});
}
