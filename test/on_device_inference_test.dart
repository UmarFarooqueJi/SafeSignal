import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/inference/on_device_inference_engine.dart';

void main() {
  group('OnDeviceInferenceEngine - Hardware Profile & Memory Guard Tests', () {
    late OnDeviceInferenceEngine engine;

    setUp(() {
      engine = OnDeviceInferenceEngine();
      engine.configureHardwareProfile(
        totalRamMb: 4096,
        availableCores: 8,
        deviceModel: 'Realme RMX3268',
        osVersion: 'Android 11',
      );
    });

    test('Budgets RAM allocation strictly within 25% threshold on 4GB device', () {
      final profile = engine.hardwareProfile;
      expect(profile.totalRamMb, equals(4096));
      expect(profile.maxModelRamBudgetMb, equals(1024));
      expect(profile.recommendedThreads, equals(2));
      expect(profile.deviceModel, equals('Realme RMX3268'));
    });

    test('Rejects oversized models when device RAM is constrained', () async {
      engine.configureHardwareProfile(totalRamMb: 2048, availableCores: 4);
      final loaded = await engine.loadModel(architecture: ModelArchitecture.llama_3_2_1b);
      expect(loaded, isFalse);
      expect(engine.state, equals(ModelInferenceState.fallbackRuleEngine));
      expect(engine.activeArchitecture, equals(ModelArchitecture.ruleEngineFallback));
    });

    test('Seamlessly falls back to deterministic rule engine when weights are absent', () async {
      final loaded = await engine.loadModel(architecture: ModelArchitecture.qwen2_5_0_5b);
      expect(loaded, isTrue);
      expect(engine.state, equals(ModelInferenceState.fallbackRuleEngine));
      expect(engine.activeArchitecture, equals(ModelArchitecture.ruleEngineFallback));
    });

    test('Executes air-gapped offline inference with zero network transmission', () async {
      final result = await engine.infer(
        prompt: 'URGENT: Police Digital Arrest notice. Transfer Rs 25,000 to avoid immediate arrest.',
        systemPrompt: 'You are an offline mobile security analyzer.',
        taskType: 'sms',
      );

      expect(result.success, isTrue);
      expect(result.usedDeterministicFallback, isTrue);
      expect(result.structuredJson, isNotNull);
      expect(result.structuredJson!['verdict'], equals('SCAM'));
      expect(result.structuredJson!['riskScore'], greaterThanOrEqualTo(60));
      expect(result.inferenceLatency.inMilliseconds, lessThan(100)); // Sub-100ms instant execution
    });

    test('Accurately verifies legitimate messages with zero false positives', () async {
      final result = await engine.infer(
        prompt: 'Dear Customer, your electricity bill of Rs 450 has been successfully paid. Ref: TXN12345.',
        systemPrompt: 'You are an offline mobile security analyzer.',
        taskType: 'sms',
      );

      expect(result.success, isTrue);
      expect(result.structuredJson!['verdict'], equals('SAFE'));
      expect(result.structuredJson!['riskScore'], lessThanOrEqualTo(20));
    });
  });
}
