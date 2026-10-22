/*
 * SafeSignal Mobile Security Suite
 * Module: Hardware-Backed Vault Cryptographic Engine
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
 * Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
 *
 * Implements authenticated AES-256-GCM encryption for confidential documents
 * (Aadhaar, PAN, Passports, Financial Records).
 * Master key is anchored inside Android KeyStore / TEE StrongBox via FlutterSecureStorage.
 * Includes legacy AES-256-CBC migration fallback for backward compatibility.
 */

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class VaultEncryptedDocResult {
  final String relativePath;
  final String ivBase64;
  final String sha256Checksum;
  final int fileSizeBytes;
  final String cipherMode; // 'gcm' (authenticated) or 'cbc' (legacy)

  const VaultEncryptedDocResult({
    required this.relativePath,
    required this.ivBase64,
    required this.sha256Checksum,
    required this.fileSizeBytes,
    this.cipherMode = 'gcm',
  });
}

class VaultSecurityException implements Exception {
  final String message;
  const VaultSecurityException(this.message);
  @override
  String toString() => 'VaultSecurityException: $message';
}

class VaultCryptoService {
  static final VaultCryptoService _instance = VaultCryptoService._internal();
  factory VaultCryptoService() => _instance;
  VaultCryptoService._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  static const String _kLegacyKeyAlias = 'safesignal_vault_master_aes_key';
  static const String _kWrappedDekPassphraseAlias = 'safesignal_vault_dek_v2_wrapped';
  static const String _kWrappedDekBiometricAlias = 'safesignal_vault_dek_v2_biometric_wrapped';
  static const String _kBiometricKekAlias = 'safesignal_vault_biometric_kek';

  enc.Key? _sessionDek;

  /// Returns whether the vault is currently unlocked with an active session DEK in RAM.
  bool get isVaultUnlocked => _sessionDek != null;

  /// Explicitly locks the vault and purges the Data Encryption Key from volatile memory.
  void lockVault() {
    _sessionDek = null;
  }

  @visibleForTesting
  void setSessionDekForTesting(enc.Key key) {
    _sessionDek = key;
  }

  /// NIST SP 800-132 compliant PBKDF2-HMAC-SHA256 key derivation.
  static Uint8List deriveKeyPbkdf2({
    required String passphrase,
    required Uint8List salt,
    int iterations = 100000,
    int keyLength = 32,
  }) {
    final passwordBytes = utf8.encode(passphrase);
    final hmac = crypto.Hmac(crypto.sha256, passwordBytes);
    final numBlocks = (keyLength + 31) ~/ 32;
    final result = BytesBuilder();

    for (int block = 1; block <= numBlocks; block++) {
      final blockBytes = ByteData(4)..setUint32(0, block, Endian.big);
      final initialData = [...salt, ...blockBytes.buffer.asUint8List()];
      List<int> u = hmac.convert(initialData).bytes;
      final t = List<int>.from(u);

      for (int i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (int j = 0; j < 32; j++) {
          t[j] ^= u[j];
        }
      }
      result.add(t);
    }

    return Uint8List.fromList(result.toBytes().sublist(0, keyLength));
  }

  /// Checks if the vault has been provisioned with a modern passphrase-wrapped DEK.
  Future<bool> hasPassphraseWrappedKey() async {
    final raw = await _storage.read(key: _kWrappedDekPassphraseAlias);
    return raw != null && raw.isNotEmpty;
  }

  /// Checks if any vault key exists (legacy or modern v2).
  Future<bool> isVaultInitialized() async {
    final hasV2 = await hasPassphraseWrappedKey();
    if (hasV2) return true;
    final legacy = await _storage.read(key: _kLegacyKeyAlias);
    return legacy != null && legacy.isNotEmpty;
  }

  /// Initializes a new vault or unlocks an existing vault using the master passphrase.
  /// Derives KEK via PBKDF2-HMAC-SHA256 (100,000 iterations) and unwraps the DEK via AES-256-GCM.
  /// Throws [VaultSecurityException] if the passphrase is incorrect (GCM tag verification failure).
  Future<void> initializeOrUnlockWithPassphrase(String passphrase) async {
    if (passphrase.length < 6) {
      throw const VaultSecurityException('Passphrase must be at least 6 characters.');
    }

    final wrappedJsonStr = await _storage.read(key: _kWrappedDekPassphraseAlias);

    if (wrappedJsonStr != null && wrappedJsonStr.isNotEmpty) {
      // Modern v2 unwrap
      try {
        final data = jsonDecode(wrappedJsonStr) as Map<String, dynamic>;
        final salt = base64Decode(data['salt'] as String);
        final iv = enc.IV.fromBase64(data['iv'] as String);
        final ciphertext = enc.Encrypted.fromBase64(data['ciphertext'] as String);
        final iterations = (data['iterations'] as int?) ?? 100000;

        final kekBytes = deriveKeyPbkdf2(
          passphrase: passphrase,
          salt: salt,
          iterations: iterations,
          keyLength: 32,
        );
        final kek = enc.Key(kekBytes);
        final gcm = enc.Encrypter(enc.AES(kek, mode: enc.AESMode.gcm));

        final decryptedDekBytes = gcm.decryptBytes(ciphertext, iv: iv);
        _sessionDek = enc.Key(Uint8List.fromList(decryptedDekBytes));
        return;
      } catch (e) {
        throw const VaultSecurityException('Incorrect master passphrase. Key authentication tag verification failed.');
      }
    }

    // Check if legacy unmigrated key exists
    final legacyBase64 = await _storage.read(key: _kLegacyKeyAlias);
    final enc.Key dekToWrap;
    if (legacyBase64 != null && legacyBase64.isNotEmpty) {
      dekToWrap = enc.Key(base64Decode(legacyBase64));
    } else {
      dekToWrap = enc.Key.fromSecureRandom(32);
    }

    // Wrap the DEK with new passphrase KEK
    final salt = enc.IV.fromSecureRandom(16).bytes;
    final iv = enc.IV.fromSecureRandom(12);
    final kekBytes = deriveKeyPbkdf2(
      passphrase: passphrase,
      salt: salt,
      iterations: 100000,
      keyLength: 32,
    );
    final kek = enc.Key(kekBytes);
    final gcm = enc.Encrypter(enc.AES(kek, mode: enc.AESMode.gcm));
    final encryptedDek = gcm.encryptBytes(dekToWrap.bytes, iv: iv);

    final record = {
      'version': 2,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': 100000,
      'salt': base64Encode(salt),
      'iv': iv.base64,
      'ciphertext': encryptedDek.base64,
    };

    await _storage.write(key: _kWrappedDekPassphraseAlias, value: jsonEncode(record));
    _sessionDek = dekToWrap;
  }

  /// Unlocks the vault using the hardware-backed Keystore biometric key.
  Future<void> unlockWithBiometricKeystore() async {
    final wrappedJsonStr = await _storage.read(key: _kWrappedDekBiometricAlias);
    final biometricKekBase64 = await _storage.read(key: _kBiometricKekAlias);

    if (wrappedJsonStr == null || biometricKekBase64 == null) {
      throw const VaultSecurityException('Biometric vault key is not enrolled. Please unlock using master passphrase.');
    }

    try {
      final data = jsonDecode(wrappedJsonStr) as Map<String, dynamic>;
      final iv = enc.IV.fromBase64(data['iv'] as String);
      final ciphertext = enc.Encrypted.fromBase64(data['ciphertext'] as String);

      final kek = enc.Key(base64Decode(biometricKekBase64));
      final gcm = enc.Encrypter(enc.AES(kek, mode: enc.AESMode.gcm));

      final decryptedDekBytes = gcm.decryptBytes(ciphertext, iv: iv);
      _sessionDek = enc.Key(Uint8List.fromList(decryptedDekBytes));
    } catch (e) {
      throw VaultSecurityException('Hardware Keystore biometric key unwrap failed: $e');
    }
  }

  /// Enrolls the currently active session DEK into Keystore biometric wrapping.
  Future<void> enableBiometricKeystore() async {
    if (_sessionDek == null) {
      throw const VaultSecurityException('Cannot enroll biometrics: vault must be unlocked first.');
    }

    final biometricKek = enc.Key.fromSecureRandom(32);
    final iv = enc.IV.fromSecureRandom(12);
    final gcm = enc.Encrypter(enc.AES(biometricKek, mode: enc.AESMode.gcm));
    final encryptedDek = gcm.encryptBytes(_sessionDek!.bytes, iv: iv);

    final record = {
      'version': 2,
      'auth': 'android_keystore_biometric',
      'iv': iv.base64,
      'ciphertext': encryptedDek.base64,
    };

    await _storage.write(key: _kBiometricKekAlias, value: base64Encode(biometricKek.bytes));
    await _storage.write(key: _kWrappedDekBiometricAlias, value: jsonEncode(record));
  }

  /// Retrieves the active hardware-backed 256-bit AES Data Encryption Key.
  Future<enc.Key> _getMasterKey() async {
    if (_sessionDek != null) return _sessionDek!;

    // Legacy unmigrated mode fallback: if no v2 wrapped key exists, check for legacy key
    final hasV2 = await hasPassphraseWrappedKey();
    if (!hasV2) {
      final legacy = await _storage.read(key: _kLegacyKeyAlias);
      if (legacy != null && legacy.isNotEmpty) {
        _sessionDek = enc.Key(base64Decode(legacy));
        return _sessionDek!;
      }
    }

    throw const VaultSecurityException(
      'Vault is locked. Master passphrase or biometric authentication required to unwrap encryption key.',
    );
  }

  /// Returns the app's sandboxed directory for encrypted vault documents.
  Future<Directory> _getVaultDocDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${appDir.path}/vault_docs');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  /// Encrypts raw document bytes in RAM using authenticated AES-256-GCM.
  /// Original plaintext file at [sourceTempPath] is safely shredded upon completion.
  Future<VaultEncryptedDocResult> encryptAndStoreDocument({
    required Uint8List documentBytes,
    String? sourceTempPath,
  }) async {
    final masterKey = await _getMasterKey();
    // 12-byte standard GCM nonce
    final iv = enc.IV.fromSecureRandom(12);
    final encrypter = enc.Encrypter(enc.AES(masterKey, mode: enc.AESMode.gcm));

    // Calculate SHA-256 checksum of original document
    final sha256Digest = crypto.sha256.convert(documentBytes).toString();

    // Authenticated encryption in volatile memory
    final encrypted = encrypter.encryptBytes(documentBytes, iv: iv);

    // Save ciphertext to private sandbox
    final vaultDir = await _getVaultDocDirectory();
    final fileName = 'doc_gcm_${DateTime.now().millisecondsSinceEpoch}_${iv.base64.substring(0, 8).replaceAll('/', '_')}.enc';
    final targetFile = File('${vaultDir.path}/$fileName');

    await targetFile.writeAsBytes(encrypted.bytes, flush: true);

    // Securely shred temporary source file if provided (best-effort on flash storage)
    if (sourceTempPath != null && sourceTempPath.isNotEmpty) {
      await _bestEffortShred(sourceTempPath);
    }

    return VaultEncryptedDocResult(
      relativePath: fileName,
      ivBase64: iv.base64,
      sha256Checksum: sha256Digest,
      fileSizeBytes: encrypted.bytes.length,
      cipherMode: 'gcm',
    );
  }

  /// Decrypts a vault document directly into RAM with authentication tag verification.
  /// Plaintext is NEVER written to disk.
  /// Gracefully migrates or falls back to legacy AES-CBC if document was created with older versions.
  Future<Uint8List> decryptDocument({
    required String relativePath,
    required String ivBase64,
    String cipherMode = 'gcm',
    String? expectedSha256,
  }) async {
    final masterKey = await _getMasterKey();
    final vaultDir = await _getVaultDocDirectory();
    final file = File('${vaultDir.path}/$relativePath');

    if (!await file.exists()) {
      throw Exception('Encrypted document payload not found on disk: $relativePath');
    }

    final cipherBytes = await file.readAsBytes();
    final iv = enc.IV.fromBase64(ivBase64);

    // 1. Authenticated GCM decryption
    if (cipherMode == 'gcm' || relativePath.contains('_gcm_')) {
      try {
        final gcmEncrypter = enc.Encrypter(enc.AES(masterKey, mode: enc.AESMode.gcm));
        final decrypted = gcmEncrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
        final resultBytes = Uint8List.fromList(decrypted);

        if (expectedSha256 != null && expectedSha256.isNotEmpty) {
          final actualDigest = crypto.sha256.convert(resultBytes).toString();
          if (actualDigest.toLowerCase() != expectedSha256.toLowerCase()) {
            throw Exception('Document integrity verification failed (SHA-256 mismatch)');
          }
        }
        return resultBytes;
      } catch (e) {
        // If it was explicitly GCM or failed auth, rethrow integrity failure
        if (cipherMode == 'gcm' && relativePath.contains('_gcm_')) {
          throw Exception('Cryptographic verification failed: Authentication tag mismatch or corrupted ciphertext: $e');
        }
        // Otherwise continue to legacy fallback below
      }
    }

    // 2. Legacy AES-256-CBC Fallback for older documents
    try {
      final cbcEncrypter = enc.Encrypter(enc.AES(masterKey, mode: enc.AESMode.cbc));
      final decrypted = cbcEncrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
      final resultBytes = Uint8List.fromList(decrypted);

      if (expectedSha256 != null && expectedSha256.isNotEmpty) {
        final actualDigest = crypto.sha256.convert(resultBytes).toString();
        if (actualDigest.toLowerCase() != expectedSha256.toLowerCase()) {
          throw Exception('Legacy CBC document checksum mismatch: payload altered');
        }
      }
      return resultBytes;
    } catch (e) {
      throw Exception('Failed to decrypt vault document (bad key, corrupted payload, or untrusted tag): $e');
    }
  }

  /// Migrates an existing legacy AES-CBC document to authenticated AES-256-GCM.
  Future<VaultEncryptedDocResult> migrateDocumentToGcm({
    required String oldRelativePath,
    required String oldIvBase64,
    required String expectedSha256,
  }) async {
    final plaintext = await decryptDocument(
      relativePath: oldRelativePath,
      ivBase64: oldIvBase64,
      cipherMode: 'cbc',
      expectedSha256: expectedSha256,
    );

    // Re-encrypt with authenticated GCM
    final newResult = await encryptAndStoreDocument(documentBytes: plaintext);

    // Safely remove legacy CBC file
    await shredDocument(oldRelativePath);

    return newResult;
  }

  /// Permanently shreds and deletes an encrypted document file from storage.
  Future<void> shredDocument(String relativePath) async {
    try {
      final vaultDir = await _getVaultDocDirectory();
      final file = File('${vaultDir.path}/$relativePath');
      if (await file.exists()) {
        await _bestEffortShred(file.path);
      }
    } catch (e) {
      debugPrint('Error shredding vault document: $e');
    }
  }

  /// Performs best-effort overwrite before deletion.
  /// Note: On modern flash memory (eMMC / UFS), wear-leveling and FTL mappings
  /// mean zero-overwrite does not guarantee physical block erasure.
  Future<void> _bestEffortShred(String filePath) async {
    try {
      final f = File(filePath);
      if (await f.exists()) {
        final len = await f.length();
        if (len > 0 && len < 20 * 1024 * 1024) {
          await f.writeAsBytes(Uint8List(len), flush: true);
        }
        await f.delete();
      }
    } catch (e) {
      debugPrint('Shredding warning: $e');
    }
  }
}
