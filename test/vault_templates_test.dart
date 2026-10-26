import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/features/vault/vault_templates.dart';
import 'package:safesignal/features/vault/vault_screen.dart';

void main() {
  group('Hardware Vault Forensic Templates & Password Generator Tests', () {
    test('All 9 specialized forensic templates are defined with required attributes', () {
      expect(VaultTemplates.all.length, equals(9));

      final templateIds = VaultTemplates.all.map((t) => t.id).toSet();
      expect(templateIds, containsAll([
        'gmail',
        'bank',
        'card',
        'upi',
        'social',
        'id',
        'wifi',
        'crypto',
        'note',
      ]));

      for (final t in VaultTemplates.all) {
        expect(t.name.isNotEmpty, isTrue);
        expect(t.category.isNotEmpty, isTrue);
        expect(t.description.isNotEmpty, isTrue);
        expect(t.fields.isNotEmpty, isTrue);
        expect(t.primaryFieldKey.isNotEmpty, isTrue);
        expect(t.secretFieldKey.isNotEmpty, isTrue);
      }
    });

    test('VaultTemplates.findById retrieves correct template or falls back to note', () {
      final gmail = VaultTemplates.findById('gmail');
      expect(gmail.id, equals('gmail'));
      expect(gmail.name, contains('Gmail'));

      final fallback = VaultTemplates.findById('non_existent_template_id');
      expect(fallback.id, equals('note'));
    });

    test('VaultPasswordGenerator produces valid high-entropy passwords', () {
      final pass16 = VaultPasswordGenerator.generate(length: 16);
      expect(pass16.length, equals(16));

      final pass24 = VaultPasswordGenerator.generate(
        length: 24,
        upper: true,
        lower: true,
        digits: true,
        symbols: true,
      );
      expect(pass24.length, equals(24));
      expect(pass24, matches(RegExp(r'[A-Z]')));
      expect(pass24, matches(RegExp(r'[a-z]')));
      expect(pass24, matches(RegExp(r'[0-9]')));
      expect(pass24, matches(RegExp(r'[^a-zA-Z0-9]')));
    });

    test('VaultPasswordGenerator produces exact-length numeric PINs', () {
      final pin4 = VaultPasswordGenerator.generatePin(length: 4);
      expect(pin4.length, equals(4));
      expect(int.tryParse(pin4), isNotNull);

      final pin6 = VaultPasswordGenerator.generatePin(length: 6);
      expect(pin6.length, equals(6));
      expect(int.tryParse(pin6), isNotNull);
    });

    test('NIST Shannon entropy calculation gives accurate ratings', () {
      final strongPass = 'kP9#mX2\$vL8@qR4!';
      final entropy = VaultPasswordGenerator.calculateEntropy(strongPass);
      expect(entropy, greaterThanOrEqualTo(80.0));
      expect(VaultPasswordGenerator.getEntropyRating(entropy), anyOf([contains('Strong'), contains('Military Grade')]));

      final weakPass = '123456';
      final weakEntropy = VaultPasswordGenerator.calculateEntropy(weakPass);
      expect(weakEntropy, lessThan(35.0));
      expect(VaultPasswordGenerator.getEntropyRating(weakEntropy), contains('Weak'));
    });

    test('VaultItem serialization preserves structured template fields', () {
      final item = VaultItem(
        id: '1001',
        title: 'Primary Google Account',
        category: 'Google / Gmail',
        templateType: 'gmail',
        secretValue: 'SecretPass123!',
        fields: {
          'email': 'security.lead@gmail.com',
          'password': 'SecretPass123!',
          'recovery_email': 'backup@proton.me',
          'backup_codes': '82910394\n19284719',
        },
        notes: 'Forensic test account',
        createdAt: 1771928300000,
        type: 'text',
      );

      final jsonMap = item.toJson();
      expect(jsonMap['templateType'], equals('gmail'));
      expect(jsonMap['fields']['email'], equals('security.lead@gmail.com'));

      final deserialized = VaultItem.fromJson(jsonMap);
      expect(deserialized.id, equals('1001'));
      expect(deserialized.title, equals('Primary Google Account'));
      expect(deserialized.templateType, equals('gmail'));
      expect(deserialized.fields['recovery_email'], equals('backup@proton.me'));
      expect(deserialized.secretValue, equals('SecretPass123!'));
    });

    test('VaultItem deserialization backward compatibility for legacy records', () {
      // Legacy JSON record with NO templateType and NO fields
      final legacyJson = {
        'id': 'legacy-999',
        'title': 'SBI UPI PIN',
        'category': 'Banking & UPI',
        'secretValue': '491823',
        'notes': 'Legacy vault record created prior to templates',
        'createdAt': 1770000000000,
        'type': 'text',
      };

      final deserialized = VaultItem.fromJson(legacyJson);
      expect(deserialized.id, equals('legacy-999'));
      expect(deserialized.title, equals('SBI UPI PIN'));
      expect(deserialized.secretValue, equals('491823'));
      // Auto-inferred template from category 'Banking & UPI'
      expect(deserialized.templateType, equals('bank'));
      expect(deserialized.fields, isEmpty);
      expect(deserialized.notes, equals('Legacy vault record created prior to templates'));
    });

    test('Deep-Link external scheme routing interceptor logic', () {
      String? redirectCheck(Uri uri) {
        final loc = uri.toString();
        final scheme = uri.scheme.toLowerCase();
        if (scheme == 'http' || scheme == 'https' || loc.startsWith('http://') || loc.startsWith('https://')) {
          return '/url-scanner?url=${Uri.encodeComponent(loc)}';
        }
        return null;
      }

      final spotifyUri = Uri.parse('https://open.spotify.com/playlist/3uMh36cKmCn4rmcsngjuS3?si=_VM_FgGUQDOlgRygDEnuzA');
      final redirectRoute = redirectCheck(spotifyUri);

      expect(redirectRoute, isNotNull);
      expect(redirectRoute!.startsWith('/url-scanner?url='), isTrue);
      expect(Uri.decodeComponent(redirectRoute.replaceFirst('/url-scanner?url=', '')), equals(spotifyUri.toString()));

      final internalUri = Uri.parse('/home');
      expect(redirectCheck(internalUri), isNull);
    });
  });
}
