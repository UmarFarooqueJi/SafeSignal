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

  static const String _kMasterKeyAlias = 'safesignal_vault_master_aes_key';
  enc.Key? _cachedKey;

  /// Retrieves or provisions a hardware-backed 256-bit AES Master Key.
  Future<enc.Key> _getMasterKey() async {
    if (_cachedKey != null) return _cachedKey!;

    final existing = await _storage.read(key: _kMasterKeyAlias);
    if (existing != null && existing.isNotEmpty) {
      final keyBytes = base64Decode(existing);
      _cachedKey = enc.Key(keyBytes);
      return _cachedKey!;
    }

    // Provision new cryptographically secure 256-bit (32 bytes) master key
    final newKey = enc.Key.fromSecureRandom(32);
    await _storage.write(key: _kMasterKeyAlias, value: base64Encode(newKey.bytes));
    _cachedKey = newKey;
    return newKey;
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
