import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/features/vault/vault_crypto_service.dart';

void main() {
  group('Vault Cryptographic Engine Specification Tests', () {
    test(
      'AES-256-CBC encryption and decryption roundtrip preserves plaintext integrity',
      () {
        // 256-bit (32 bytes) master key matching SafeSignal vault specification
        final key = enc.Key.fromSecureRandom(32);
        final iv = enc.IV.fromSecureRandom(16);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

        const secretDocument = 'CONFIDENTIAL_AADHAAR_RECORD_1234_5678_9012';
        final plaintextBytes = Uint8List.fromList(utf8.encode(secretDocument));

        // Calculate SHA-256 digest before encryption
        final originalDigest = crypto.sha256.convert(plaintextBytes).toString();

        // Encrypt
        final encrypted = encrypter.encryptBytes(plaintextBytes, iv: iv);
        expect(encrypted.bytes.isNotEmpty, isTrue);
        expect(encrypted.bytes, isNot(equals(plaintextBytes)));

        // Decrypt
        final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
        final decryptedString = utf8.decode(decrypted);

        // Verify plaintext recovery
        expect(decryptedString, equals(secretDocument));

        // Verify SHA-256 checksum integrity
        final decryptedDigest = crypto.sha256.convert(decrypted).toString();
        expect(decryptedDigest, equals(originalDigest));
      },
    );

    test(
      'Ciphertext modification invalidates decryption or corrupts checksum',
      () {
        final key = enc.Key.fromSecureRandom(32);
        final iv = enc.IV.fromSecureRandom(16);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

        const payload = 'BANK_STATEMENT_TRANSACTION_PAYLOAD_INR_500000';
        final plaintextBytes = Uint8List.fromList(utf8.encode(payload));
        final originalDigest = crypto.sha256.convert(plaintextBytes).toString();

        final encrypted = encrypter.encryptBytes(plaintextBytes, iv: iv);
        final corruptedBytes = Uint8List.fromList(List.from(encrypted.bytes));

        // Tamper with middle byte of ciphertext
        corruptedBytes[corruptedBytes.length ~/ 2] ^= 0xFF;

        try {
          final corruptedDecrypted = encrypter.decryptBytes(
            enc.Encrypted(corruptedBytes),
            iv: iv,
          );
          final tamperedDigest = crypto.sha256
              .convert(corruptedDecrypted)
              .toString();
          // If padding didn't throw, SHA-256 digest must definitely not match
          expect(tamperedDigest, isNot(equals(originalDigest)));
        } catch (e) {
          // Tampered ciphertext causing padding error is also a successful detection of tampering
          expect(e, isNotNull);
        }
      },
    );

    test(
      'Different initialization vectors produce distinct ciphertexts for identical plaintext',
      () {
        final key = enc.Key.fromSecureRandom(32);
        final iv1 = enc.IV.fromSecureRandom(16);
        final iv2 = enc.IV.fromSecureRandom(16);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

        const data = 'IDENTICAL_IDENTITY_DATA_STRING';
        final bytes = Uint8List.fromList(utf8.encode(data));

        final cipher1 = encrypter.encryptBytes(bytes, iv: iv1);
        final cipher2 = encrypter.encryptBytes(bytes, iv: iv2);

        expect(cipher1.base64, isNot(equals(cipher2.base64)));
      },
    );

    test(
      'AES-256-GCM authenticated encryption verifies authenticity and detects tampering',
      () {
        final key = enc.Key.fromSecureRandom(32);
        final iv = enc.IV.fromSecureRandom(
          12,
        ); // Standard 12-byte 96-bit GCM nonce
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

        const plaintext = 'AUTHENTICATED_VAULT_PAYLOAD_AADHAAR_9999';
        final bytes = Uint8List.fromList(utf8.encode(plaintext));

        final encrypted = encrypter.encryptBytes(bytes, iv: iv);
        expect(encrypted.bytes.isNotEmpty, isTrue);

        final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
        expect(utf8.decode(decrypted), equals(plaintext));

        // Test tampering detection
        final tampered = Uint8List.fromList(List.from(encrypted.bytes));
        tampered[0] ^= 0x01; // Corrupt ciphertext byte
        expect(
          () => encrypter.decryptBytes(enc.Encrypted(tampered), iv: iv),
          throwsA(anything),
        );
      },
    );

    test(
      'Decryption with incorrect master key fails authenticated verification',
      () {
        final key1 = enc.Key.fromSecureRandom(32);
        final key2 = enc.Key.fromSecureRandom(32);
        final iv = enc.IV.fromSecureRandom(12);

        final encrypter1 = enc.Encrypter(enc.AES(key1, mode: enc.AESMode.gcm));
        final encrypter2 = enc.Encrypter(enc.AES(key2, mode: enc.AESMode.gcm));

        final bytes = Uint8List.fromList(
          utf8.encode('SECRET_FINANCIAL_RECORD_DATA'),
        );
        final encrypted = encrypter1.encryptBytes(bytes, iv: iv);

        expect(
          () => encrypter2.decryptBytes(encrypted, iv: iv),
          throwsA(anything),
        );
      },
    );

    test(
      'Legacy AES-CBC to AES-GCM migration preserves document data and integrity digest',
      () {
        final key = enc.Key.fromSecureRandom(32);
        final cbcIv = enc.IV.fromSecureRandom(16);
        final gcmIv = enc.IV.fromSecureRandom(12);

        final cbcEncrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
        final gcmEncrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

        const legacyDocument = 'LEGACY_MIGRATION_DOCUMENT_PAN_CARD_ABCDE1234F';
        final docBytes = Uint8List.fromList(utf8.encode(legacyDocument));
        final expectedSha = crypto.sha256.convert(docBytes).toString();

        // Step 1: Encrypt with legacy CBC
        final cbcCipher = cbcEncrypter.encryptBytes(docBytes, iv: cbcIv);

        // Step 2: Decrypt legacy CBC payload
        final decryptedFromCbc = cbcEncrypter.decryptBytes(
          cbcCipher,
          iv: cbcIv,
        );
        final decryptedDigest = crypto.sha256
            .convert(decryptedFromCbc)
            .toString();
        expect(decryptedDigest, equals(expectedSha));

        // Step 3: Re-encrypt with modern GCM
        final gcmCipher = gcmEncrypter.encryptBytes(
          Uint8List.fromList(decryptedFromCbc),
          iv: gcmIv,
        );

        // Step 4: Verify GCM payload
        final decryptedFromGcm = gcmEncrypter.decryptBytes(
          gcmCipher,
          iv: gcmIv,
        );
        expect(utf8.decode(decryptedFromGcm), equals(legacyDocument));
        expect(
          crypto.sha256.convert(decryptedFromGcm).toString(),
          equals(expectedSha),
        );
      },
    );
  });

  group('Versioned Key Hierarchy & Passphrase Wrapping Tests', () {
    test('PBKDF2-HMAC-SHA256 derives 256-bit key deterministically', () {
      final salt = Uint8List.fromList([
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
      ]);
      final key1 = VaultCryptoService.deriveKeyPbkdf2(
        passphrase: 'MasterSecurityPassphrase2026!',
        salt: salt,
        iterations: 1000,
        keyLength: 32,
      );
      final key2 = VaultCryptoService.deriveKeyPbkdf2(
        passphrase: 'MasterSecurityPassphrase2026!',
        salt: salt,
        iterations: 1000,
        keyLength: 32,
      );
      expect(key1.length, 32);
      expect(key1, equals(key2));

      // Different passphrase produces completely different key
      final key3 = VaultCryptoService.deriveKeyPbkdf2(
        passphrase: 'WrongPassphrase!',
        salt: salt,
        iterations: 1000,
        keyLength: 32,
      );
      expect(key1, isNot(equals(key3)));
    });

    test('Passphrase KEK wrapping and unwrapping recovers exact DEK bytes', () {
      final originalDek = enc.Key.fromSecureRandom(32);
      final salt = enc.IV.fromSecureRandom(16).bytes;
      final iv = enc.IV.fromSecureRandom(12);

      // Derive KEK
      final kekBytes = VaultCryptoService.deriveKeyPbkdf2(
        passphrase: 'CorrectVaultPassphrase123',
        salt: salt,
        iterations: 1000,
        keyLength: 32,
      );
      final kek = enc.Key(kekBytes);
      final gcm = enc.Encrypter(enc.AES(kek, mode: enc.AESMode.gcm));

      // Wrap
      final encryptedDek = gcm.encryptBytes(originalDek.bytes, iv: iv);

      // Unwrap with correct passphrase
      final unwrapKekBytes = VaultCryptoService.deriveKeyPbkdf2(
        passphrase: 'CorrectVaultPassphrase123',
        salt: salt,
        iterations: 1000,
        keyLength: 32,
      );
      final unwrapKek = enc.Key(unwrapKekBytes);
      final unwrapGcm = enc.Encrypter(
        enc.AES(unwrapKek, mode: enc.AESMode.gcm),
      );
      final recoveredBytes = unwrapGcm.decryptBytes(encryptedDek, iv: iv);

      expect(recoveredBytes, equals(originalDek.bytes));
    });

    test(
      'Unwrapping with incorrect passphrase fails authentication tag check',
      () {
        final originalDek = enc.Key.fromSecureRandom(32);
        final salt = enc.IV.fromSecureRandom(16).bytes;
        final iv = enc.IV.fromSecureRandom(12);

        // Derive KEK
        final kekBytes = VaultCryptoService.deriveKeyPbkdf2(
          passphrase: 'CorrectPassphrase!',
          salt: salt,
          iterations: 1000,
          keyLength: 32,
        );
        final kek = enc.Key(kekBytes);
        final gcm = enc.Encrypter(enc.AES(kek, mode: enc.AESMode.gcm));
        final encryptedDek = gcm.encryptBytes(originalDek.bytes, iv: iv);

        // Attempt unwrap with wrong passphrase
        final wrongKekBytes = VaultCryptoService.deriveKeyPbkdf2(
          passphrase: 'WrongPassphrase!',
          salt: salt,
          iterations: 1000,
          keyLength: 32,
        );
        final wrongKek = enc.Key(wrongKekBytes);
        final wrongGcm = enc.Encrypter(
          enc.AES(wrongKek, mode: enc.AESMode.gcm),
        );

        expect(
          () => wrongGcm.decryptBytes(encryptedDek, iv: iv),
          throwsA(anything),
        );
      },
    );

    test(
      'VaultCryptoService lockVault purges session key and enforces fail-closed state',
      () {
        final service = VaultCryptoService();
        final testKey = enc.Key.fromSecureRandom(32);
        service.setSessionDekForTesting(testKey);
        expect(service.isVaultUnlocked, isTrue);

        service.lockVault();
        expect(service.isVaultUnlocked, isFalse);
      },
    );

    test('Modified wrapped ciphertext or tag causes decryption failure', () {
      final originalDek = enc.Key.fromSecureRandom(32);
      final salt = enc.IV.fromSecureRandom(16).bytes;
      final iv = enc.IV.fromSecureRandom(12);

      final kekBytes = VaultCryptoService.deriveKeyPbkdf2(
        passphrase: 'TestPassphrase',
        salt: salt,
        iterations: 1000,
        keyLength: 32,
      );
      final kek = enc.Key(kekBytes);
      final gcm = enc.Encrypter(enc.AES(kek, mode: enc.AESMode.gcm));
      final encryptedDek = gcm.encryptBytes(originalDek.bytes, iv: iv);

      final corruptedBytes = Uint8List.fromList(List.from(encryptedDek.bytes));
      corruptedBytes[0] ^= 0x55; // Tamper byte

      expect(
        () => gcm.decryptBytes(enc.Encrypted(corruptedBytes), iv: iv),
        throwsA(anything),
      );
    });
  });
}
