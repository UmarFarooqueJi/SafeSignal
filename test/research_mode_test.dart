import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/services/research_mode_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ResearchModeService - Three-Tier Capability Framework Tests', () {
    final service = ResearchModeService();

    test('Defaults to Tier 1 Standard Android Mode on standard platforms', () async {
      final tier = await service.detectActiveTier();
      expect(tier, equals(ResearchTier.tier1Standard));
    });

    test('Provides comprehensive capability profiles for all 3 tiers', () {
      final tier1 = service.getProfile(ResearchTier.tier1Standard);
      expect(tier1.requiresElevation, isFalse);
      expect(tier1.availableCapabilities.isNotEmpty, isTrue);
      expect(tier1.technicalLimitations.isNotEmpty, isTrue);
      expect(tier1.ethicalBoundaries.isNotEmpty, isTrue);

      final tier2 = service.getProfile(ResearchTier.tier2DeviceManagement);
      expect(tier2.requiresElevation, isTrue);
      expect(tier2.title, contains('Enterprise Device Management'));

      final tier3 = service.getProfile(ResearchTier.tier3RootedLab);
      expect(tier3.requiresElevation, isTrue);
      expect(tier3.title, contains('Rooted Research Laboratory'));
    });
  });
}
