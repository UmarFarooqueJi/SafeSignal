# 08 — CRYPTOGRAPHIC VAULT ARCHITECTURE & SECURITY AUDIT

**Audit Date:** October 21, 2026  
**Auditor:** Applied Cryptography Specialist  
**Components:** `VaultCryptoService.dart`, `VaultScreen.dart`, `VaultDocumentViewerScreen.dart`

---

## 1. CRYPTOGRAPHIC PRIMITIVES & ALGORITHMIC SPECIFICATION

| Parameter | Implemented Specification | Security Standard Compliance | Finding / Verdict |
| :--- | :--- | :--- | :--- |
| **Cipher Suite** | AES-256-GCM (Authenticated Encryption) | NIST SP 800-38D | **VERIFIED WORKING** |
| **Nonce / IV Generation** | 12-byte random IV (`enc.IV.fromSecureRandom(12)`) | NIST SP 800-38D Section 8.2.2 | **VERIFIED WORKING** |
| **Integrity Tag** | Standard 128-bit GCM authentication tag | FIPS 197 / GCM Auth | **VERIFIED WORKING** |
| **Payload Checksum** | SHA-256 computed on plaintext prior to encryption | FIPS 180-4 | **VERIFIED WORKING** |
| **Master Key Generation** | 256-bit secure random key (`enc.Key.fromSecureRandom(32)`) | NIST SP 800-133 | **VERIFIED WORKING** |
| **Key Storage** | Android KeyStore / TEE StrongBox via `FlutterSecureStorage` | Android KeyStore Provider | **VERIFIED WORKING** |
| **Key Derivation (KDF)** | **NONE** (No PBKDF2, Argon2id, or scrypt) | **NON-COMPLIANT** | **CRITICAL ARCHITECTURAL FLAW** |
| **Passphrase Salt** | **NONE** (Zero salt used for master password) | **NON-COMPLIANT** | **HIGH WEAKNESS** |
| **Passphrase Hash** | Single unsalted `sha256(pass)` | **NON-COMPLIANT** | **HIGH WEAKNESS** |

---

## 2. DEEP ARCHITECTURAL FLAW: PASSPHRASE DECOUPLING FROM ENCRYPTION KEY

In a standard zero-knowledge cryptographic vault (e.g. Bitwarden, Signal, KeePass):
1. The user's master passphrase derives an intermediate key via a memory-hard KDF (Argon2id or PBKDF2 with >= 600,000 iterations and random salt).
2. The derived key is used to unwrap/decrypt the master AES-256 key.
3. Without the master passphrase, the ciphertext is mathematically impossible to decrypt.

### What SafeSignal Actually Implements:
In `VaultCryptoService.dart` lines 53–68:
```dart
Future<enc.Key> _getMasterKey() async {
    if (_cachedKey != null) return _cachedKey!;
    final existing = await _storage.read(key: _kMasterKeyAlias);
    if (existing != null && existing.isNotEmpty) {
        final keyBytes = base64Decode(existing);
        _cachedKey = enc.Key(keyBytes);
        return _cachedKey!;
    }
    final newKey = enc.Key.fromSecureRandom(32);
    await _storage.write(key: _kMasterKeyAlias, value: base64Encode(newKey.bytes));
    _cachedKey = newKey;
    return newKey;
}
```
And in `VaultScreen.dart` lines 280–286:
```dart
final hash = sha256.convert(utf8.encode(pass)).toString();
await _storage.write(key: 'safesignal_vault_master_pass_hash', value: hash);
...
final enteredHash = sha256.convert(utf8.encode(pass)).toString();
if (enteredHash == storedHash) {
    if (mounted) await _loadItems();
}
```

### Forensic Finding:
1. **The Master Key is completely independent of the Master Passphrase.**
2. The passphrase is ONLY an application-level UI gate: it checks `enteredHash == storedHash`.
3. If an attacker extracts `safesignal_vault_master_aes_key` from KeyStore/SecureStorage, they can decrypt all vault documents immediately without knowing the user's master passphrase!
4. Storing the passphrase as an unsalted SHA-256 hash allows rapid offline dictionary attacks ($>10^{10}$ hashes/sec on modern GPUs).

---

## 3. EPHEMERAL VIEWER & RAM-ONLY LIFECYCLE

`VaultDocumentViewerScreen.dart` was tested for temporary disk exposure:
- **Decryption:** Decrypts directly into a `Uint8List` byte array in memory.
- **Rendering:** Renders using `Image.memory(_decryptedBytes!)` inside an `InteractiveViewer`.
- **Zero Disk Cache:** No file is written to `/data/user/0/.../cache` or `tempDir`.
- **Memory Zeroization on Dismiss:**
  ```dart
  @override
  void dispose() {
    if (_decryptedBytes != null) {
      for (int i = 0; i < _decryptedBytes!.length; i++) {
        _decryptedBytes![i] = 0;
      }
    }
    super.dispose();
  }
  ```
**Verdict:** Ephemeral viewer RAM-only hygiene is **VERIFIED WORKING**.
