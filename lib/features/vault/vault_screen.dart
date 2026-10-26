/*
 * SafeSignal Mobile Security Suite
 * Module: Hardware-Encrypted Security Vault & Document Guard
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
 * Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
 *
 * AES-256 hardware-backed vault using Android KeyStore, FlutterSecureStorage,
 * and on-device ML Kit Document Scanner. Provides edge-detected document
 * scanning, RAM-only decryption, and biometric authentication.
 */

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'vault_crypto_service.dart';
import 'vault_document_viewer_screen.dart';
import 'vault_templates.dart';

class VaultItem {
  final String id;
  final String title;
  final String category; // 'Aadhaar / ID', 'PAN Card', 'Passport', 'Banking & UPI', 'Crypto / Seed Phrase', 'Secret Note'
  final String templateType; // 'gmail', 'bank', 'card', 'upi', 'social', 'id', 'wifi', 'crypto', 'note', 'document'
  final String secretValue;
  final Map<String, String> fields;
  final String notes;
  final int createdAt;
  final String type; // 'text' or 'document'
  final String? documentFileName;
  final String? documentIv;
  final String? documentChecksum;
  final int? fileSizeBytes;
  final String cipherMode; // 'gcm' (authenticated) or 'cbc' (legacy)

  bool get isDocument => type == 'document';

  const VaultItem({
    required this.id,
    required this.title,
    required this.category,
    this.templateType = 'note',
    required this.secretValue,
    this.fields = const {},
    this.notes = '',
    required this.createdAt,
    this.type = 'text',
    this.documentFileName,
    this.documentIv,
    this.documentChecksum,
    this.fileSizeBytes,
    this.cipherMode = 'gcm',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'templateType': templateType,
        'secretValue': secretValue,
        'fields': fields,
        'notes': notes,
        'createdAt': createdAt,
        'type': type,
        'documentFileName': documentFileName,
        'documentIv': documentIv,
        'documentChecksum': documentChecksum,
        'fileSizeBytes': fileSizeBytes,
        'cipherMode': cipherMode,
      };

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'] as Map<String, dynamic>?;
    final Map<String, String> parsedFields = {};
    if (rawFields != null) {
      rawFields.forEach((k, v) => parsedFields[k] = v.toString());
    }

    String detectedTemplate = json['templateType'] as String? ?? '';
    if (detectedTemplate.isEmpty) {
      if (json['type'] == 'document') {
        detectedTemplate = 'document';
      } else {
        final cat = (json['category'] as String? ?? '').toLowerCase();
        if (cat.contains('gmail') || cat.contains('google')) {
          detectedTemplate = 'gmail';
        } else if (cat.contains('bank')) {
          detectedTemplate = 'bank';
        } else if (cat.contains('card')) {
          detectedTemplate = 'card';
        } else if (cat.contains('upi')) {
          detectedTemplate = 'upi';
        } else if (cat.contains('crypto') || cat.contains('seed')) {
          detectedTemplate = 'crypto';
        } else if (cat.contains('wifi')) {
          detectedTemplate = 'wifi';
        } else if (cat.contains('aadhaar') || cat.contains('pan') || cat.contains('passport') || cat.contains('license')) {
          detectedTemplate = 'id';
        } else {
          detectedTemplate = 'note';
        }
      }
    }

    return VaultItem(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String? ?? 'Secret Note',
      templateType: detectedTemplate,
      secretValue: json['secretValue'] as String? ?? '',
      fields: parsedFields,
      notes: json['notes'] as String? ?? '',
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      type: json['type'] as String? ?? 'text',
      documentFileName: json['documentFileName'] as String?,
      documentIv: json['documentIv'] as String?,
      documentChecksum: json['documentChecksum'] as String?,
      fileSizeBytes: json['fileSizeBytes'] as int?,
      cipherMode: json['cipherMode'] as String? ??
          ((json['documentFileName'] as String?)?.contains('_gcm_') == true ? 'gcm' : 'cbc'),
    );
  }
}

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> with WidgetsBindingObserver {
  final LocalAuthentication auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  bool _isVaultEnabled = false;
  bool _hasBiometrics = false;
  bool _isUnlocked = false;
  bool _isLoading = true;
  List<VaultItem> _items = [];
  final Set<String> _revealedItemIds = {};
  String _activeFilter = 'all'; // 'all', 'docs', 'secrets'
  static final Map<String, Uint8List> _documentThumbCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVault();
  }

  @override
  void dispose() {
    VaultCryptoService().lockVault();
    WidgetsBinding.instance.removeObserver(this);
    _documentThumbCache.clear();
    _revealedItemIds.clear();
    _items.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      VaultCryptoService().lockVault();
      if (mounted) {
        setState(() {
          _isUnlocked = false;
          _items = [];
          _revealedItemIds.clear();
          _documentThumbCache.clear();
        });
      }
    }
  }

  Future<void> _initVault() async {
    final prefs = await SharedPreferences.getInstance();
    final canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    final canAuthenticateWithDevice = await auth.isDeviceSupported();
    final canAuthenticate = canAuthenticateWithBiometrics || canAuthenticateWithDevice;

    final isLockEnabled = prefs.getBool('isVaultEnabled') ?? true;

    setState(() {
      _isVaultEnabled = isLockEnabled;
      _hasBiometrics = canAuthenticate;
      _isLoading = false;
      _isUnlocked = false; // Always start in locked state until authenticated
    });

    if (canAuthenticate) {
      _authenticateAndLoad();
    } else {
      // Hardware biometrics not configured: fail-closed, keep locked until master passphrase entered
      debugPrint('[VaultAuth] Biometrics not enrolled or supported. Fail-closed: vault remains locked.');
    }
  }

  Future<void> _authenticateAndLoad() async {
    if (!_hasBiometrics) {
      _showMasterPassphraseDialog();
      return;
    }
    try {
      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Authenticate to decrypt your hardware-protected Vault',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (didAuthenticate) {
        try {
          await VaultCryptoService().unlockWithBiometricKeystore();
          await _loadItems();
        } catch (e) {
          debugPrint('[VaultAuth] Biometric unwrap not configured: $e');
          if (mounted) {
            _showMasterPassphraseDialog();
          }
        }
      } else {
        setState(() => _isUnlocked = false);
      }
    } catch (e) {
      debugPrint('[VaultAuth] Biometric/Device authentication error: $e');
      setState(() => _isUnlocked = false);
      if (mounted) {
        _showMasterPassphraseDialog();
      }
    }
  }

  Future<void> _showMasterPassphraseDialog() async {
    final hasWrappedKey = await VaultCryptoService().hasPassphraseWrappedKey();
    final isNewPassphrase = !hasWrappedKey;
    final ctrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorText;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF1E293B)),
            ),
            title: Row(
              children: [
                const Icon(Icons.password_rounded, color: Color(0xFF00E5FF), size: 24),
                const SizedBox(width: 10),
                Text(
                  isNewPassphrase ? 'Create Vault Passphrase' : 'Enter Vault Passphrase',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNewPassphrase
                      ? 'Set a master security passphrase (PBKDF2-HMAC-SHA256) to cryptographically wrap and protect your vault key.'
                      : 'Enter your master passphrase to unwrap the AES-256 vault encryption key.',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: isNewPassphrase ? 'Master Passphrase (min 6 chars)' : 'Passphrase',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    errorText: errorText,
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                if (isNewPassphrase) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Confirm Master Passphrase',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final pass = ctrl.text;
                  if (isNewPassphrase) {
                    if (pass.length < 6) {
                      setDialogState(() => errorText = 'Passphrase must be at least 6 characters');
                      return;
                    }
                    if (pass != confirmCtrl.text) {
                      setDialogState(() => errorText = 'Passphrases do not match');
                      return;
                    }
                    try {
                      await VaultCryptoService().initializeOrUnlockWithPassphrase(pass);
                      if (_hasBiometrics) {
                        try {
                          await VaultCryptoService().enableBiometricKeystore();
                        } catch (_) {}
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) await _loadItems();
                    } catch (e) {
                      setDialogState(() => errorText = 'Initialization error: $e');
                    }
                  } else {
                    try {
                      await VaultCryptoService().initializeOrUnlockWithPassphrase(pass);
                      if (_hasBiometrics) {
                        try {
                          await VaultCryptoService().enableBiometricKeystore();
                        } catch (_) {}
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) await _loadItems();
                    } catch (_) {
                      setDialogState(() => errorText = 'Incorrect master passphrase');
                    }
                  }
                },
                child: Text(isNewPassphrase ? 'Set & Decrypt' : 'Unlock Vault'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadItems() async {
    try {
      final raw = await _storage.read(key: 'safesignal_vault_entries');
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        final items = list.map((e) => VaultItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        if (mounted) {
          setState(() {
            _items = items;
            _isUnlocked = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _items = [];
            _isUnlocked = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _items = [];
          _isUnlocked = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading vault: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  Future<void> _saveItems() async {
    final raw = jsonEncode(_items.map((e) => e.toJson()).toList());
    await _storage.write(key: 'safesignal_vault_entries', value: raw);
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value && _hasBiometrics) {
      try {
        final didAuth = await auth.authenticate(
          localizedReason: 'Verify identity to enable Biometric App Lock',
        );
        if (didAuth) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isVaultEnabled', true);
          setState(() => _isVaultEnabled = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('App Lock Activated! 🔒'), backgroundColor: Color(0xFF10B981)),
            );
          }
        }
      } catch (_) {}
    } else {
      try {
        final didAuth = await auth.authenticate(
          localizedReason: 'Verify identity to disable Biometric App Lock',
        );
        if (didAuth) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isVaultEnabled', false);
          setState(() => _isVaultEnabled = false);
        }
      } catch (_) {}
    }
  }

  // ─── Document OCR Auto-Extraction Engine ────────────────────────────────────
  Future<Map<String, String>> _analyzeDocumentWithOcr(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final fullText = recognizedText.text;
      final upper = fullText.toUpperCase();

      String detectedCategory = 'Aadhaar / ID';
      String detectedTitle = 'Scanned Document';
      String detectedId = '';

      // 1. PAN Card Detection
      final panRegex = RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]\b');
      final panMatch = panRegex.firstMatch(upper);
      if (panMatch != null || upper.contains('INCOME TAX') || upper.contains('PERMANENT ACCOUNT NUMBER')) {
        detectedCategory = 'PAN Card';
        detectedTitle = 'PAN Card';
        if (panMatch != null) {
          detectedId = panMatch.group(0)!;
        }
      }
      // 2. Aadhaar Card Detection
      else if (upper.contains('AADHAAR') ||
          upper.contains('UIDAI') ||
          upper.contains('MERA AADHAAR') ||
          upper.contains('UNIQUE IDENTIFICATION') ||
          (upper.contains('GOVERNMENT OF INDIA') && (upper.contains('DOB') || upper.contains('YEAR OF BIRTH')))) {
        detectedCategory = 'Aadhaar / ID';
        detectedTitle = 'Aadhaar Card';

        final aadhaarRegex = RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b');
        final aadhaarMatch = aadhaarRegex.firstMatch(fullText);
        if (aadhaarMatch != null) {
          detectedId = aadhaarMatch.group(0)!;
        } else {
          final pure12 = RegExp(r'\b[2-9]\d{11}\b').firstMatch(fullText.replaceAll('-', ' '));
          if (pure12 != null) {
            final raw = pure12.group(0)!;
            detectedId = '${raw.substring(0, 4)} ${raw.substring(4, 8)} ${raw.substring(8, 12)}';
          }
        }
      }
      // 3. Indian Driving License Detection
      else if (upper.contains('DRIVING') || upper.contains('LICENCE') || upper.contains('TRANSPORT') || upper.contains('DL NO')) {
        detectedCategory = 'Driving License';
        detectedTitle = 'Driving License';
        final dlRegex = RegExp(r'\b[A-Z]{2}[-\s]?[0-9]{2}[-\s]?[0-9]{4}[-\s]?[0-9]{7}\b|\b[A-Z]{2}[0-9]{13,15}\b');
        final dlMatch = dlRegex.firstMatch(upper);
        if (dlMatch != null) {
          detectedId = dlMatch.group(0)!;
        }
      }
      // 4. Passport Detection
      else if (upper.contains('PASSPORT') || upper.contains('REPUBLIC OF INDIA') || upper.contains('P<IND')) {
        detectedCategory = 'Passport';
        detectedTitle = 'Passport';
        final passRegex = RegExp(r'\b[A-PR-WYZ][0-9]{7}\b');
        final passMatch = passRegex.firstMatch(upper);
        if (passMatch != null) {
          detectedId = passMatch.group(0)!;
        }
      }
      // 5. Banking / IFSC / Cheque Detection
      else if (upper.contains('BANK') || upper.contains('IFSC') || upper.contains('ACCOUNT NUMBER') || upper.contains('CHEQUE')) {
        detectedCategory = 'Banking & Tax';
        detectedTitle = 'Bank Document';
        final ifscRegex = RegExp(r'\b[A-Z]{4}0[A-Z0-9]{6}\b');
        final ifscMatch = ifscRegex.firstMatch(upper);
        if (ifscMatch != null) {
          detectedId = 'IFSC: ${ifscMatch.group(0)!}';
        }
      }
      // 6. Generic Fallback Regex Search
      else {
        if (panMatch != null) {
          detectedCategory = 'PAN Card';
          detectedTitle = 'PAN Card';
          detectedId = panMatch.group(0)!;
        } else {
          final aadhaarMatch = RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b').firstMatch(fullText);
          if (aadhaarMatch != null) {
            detectedCategory = 'Aadhaar / ID';
            detectedTitle = 'Aadhaar Card';
            detectedId = aadhaarMatch.group(0)!;
          }
        }
      }

      return {
        'category': detectedCategory,
        'title': detectedTitle,
        'idNumber': detectedId,
      };
    } catch (e) {
      debugPrint('OCR extraction error: $e');
      return {
        'category': 'Aadhaar / ID',
        'title': 'Scanned Document',
        'idNumber': '',
      };
    } finally {
      await textRecognizer.close();
    }
  }

  // ─── Scan Document with Google ML Kit Edge Detection ───────────────────────
  Future<void> _startDocumentScan() async {
    try {
      final scanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: const {DocumentFormat.jpeg},
          mode: ScannerMode.base, // Clean original colors, zero over-contrast filter distortion
          isGalleryImport: true,
          pageLimit: 1,
        ),
      );

      final result = await scanner.scanDocument();
      await scanner.close();

      if (result.images != null && result.images!.isNotEmpty) {
        final scannedFilePath = result.images!.first;
        await _handleScannedImage(scannedFilePath);
      }
    } catch (e) {
      debugPrint('ML Kit Document Scanner fallback: $e');
      _fallbackImagePicker(ImageSource.camera);
    }
  }

  Future<void> _captureCameraHd() async {
    _fallbackImagePicker(ImageSource.camera);
  }

  Future<void> _pickDocumentFromGallery() async {
    _fallbackImagePicker(ImageSource.gallery);
  }

  Future<void> _fallbackImagePicker(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 100, // Maximum crystal-clear 100% quality, zero compression loss
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked != null) {
        await _handleScannedImage(picked.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleScannedImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();

      // Run on-device OCR for auto-detecting document category and ID
      final ocrData = await _analyzeDocumentWithOcr(imagePath);

      if (!mounted) return;
      _showSaveDocumentDialog(bytes, imagePath, ocrData: ocrData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing document: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSaveDocumentDialog(Uint8List rawBytes, String tempPath, {Map<String, String>? ocrData}) {
    String category = ocrData?['category'] ?? 'Aadhaar / ID';
    final titleCtrl = TextEditingController(text: ocrData?['title'] ?? 'Aadhaar Card');
    final docIdCtrl = TextEditingController(text: ocrData?['idNumber'] ?? '');
    final notesCtrl = TextEditingController();
    bool isEncrypting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final textMain = isDark ? Colors.white : const Color(0xFF0F172A);

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.document_scanner_rounded, color: Color(0xFF10B981), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Lock Scanned Document',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textMain),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Document Thumbnail Preview & Specs
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                rawBytes,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Auto-Cropped & Enhanced',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Size: ${(rawBytes.length / 1024).toStringAsFixed(1)} KB',
                                    style: TextStyle(fontSize: 12, color: textMain, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Cipher: AES-256-CBC • TEE KeyStore',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (ocrData != null && (ocrData['idNumber']?.isNotEmpty == true || ocrData['category'] != 'Secret Note')) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF10B981)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ocrData['idNumber']!.isNotEmpty
                                      ? 'Smart OCR: ${ocrData['category']} • ${ocrData['idNumber']}'
                                      : 'Smart OCR: ${ocrData['category']}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Category Selector
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: InputDecoration(
                          labelText: 'Document Type',
                          prefixIcon: const Icon(Icons.category_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Aadhaar / ID', child: Text('Aadhaar Card / Govt ID')),
                          DropdownMenuItem(value: 'PAN Card', child: Text('PAN Card (Income Tax)')),
                          DropdownMenuItem(value: 'Passport', child: Text('Passport / Visa Document')),
                          DropdownMenuItem(value: 'Driving License', child: Text('Driving License / RC')),
                          DropdownMenuItem(value: 'Banking & Tax', child: Text('Bank Passbook / Cheque / ITR')),
                          DropdownMenuItem(value: 'Medical Record', child: Text('Health / Medical Record')),
                          DropdownMenuItem(value: 'Secret Note', child: Text('Confidential Contract / Paper')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              category = val;
                              if (val == 'Aadhaar / ID') titleCtrl.text = 'Aadhaar Card';
                              if (val == 'PAN Card') titleCtrl.text = 'PAN Card';
                              if (val == 'Passport') titleCtrl.text = 'Passport';
                              if (val == 'Driving License') titleCtrl.text = 'Driving License';
                              if (val == 'Banking & Tax') titleCtrl.text = 'Bank Passbook / Cheque';
                              if (val == 'Medical Record') titleCtrl.text = 'Medical Prescription';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Document Title (e.g. My Aadhaar Front)',
                          prefixIcon: const Icon(Icons.title_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: docIdCtrl,
                        decoration: InputDecoration(
                          labelText: 'Document / ID Number (Optional)',
                          prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                          hintText: 'e.g. 5482 1928 3821 or ABCDE1234F',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Confidential Notes (Optional)',
                          prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: isEncrypting
                            ? null
                            : () async {
                                if (titleCtrl.text.trim().isEmpty) return;
                                setModalState(() => isEncrypting = true);

                                try {
                                  final encResult = await VaultCryptoService().encryptAndStoreDocument(
                                    documentBytes: rawBytes,
                                    sourceTempPath: tempPath,
                                  );

                                  final newItem = VaultItem(
                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                    title: titleCtrl.text.trim(),
                                    category: category,
                                    secretValue: docIdCtrl.text.trim(),
                                    notes: notesCtrl.text.trim(),
                                    createdAt: DateTime.now().millisecondsSinceEpoch,
                                    type: 'document',
                                    documentFileName: encResult.relativePath,
                                    documentIv: encResult.ivBase64,
                                    documentChecksum: encResult.sha256Checksum,
                                    fileSizeBytes: encResult.fileSizeBytes,
                                    cipherMode: encResult.cipherMode,
                                  );

                                  _documentThumbCache[encResult.relativePath] = rawBytes;
                                  setState(() => _items.insert(0, newItem));
                                  await _saveItems();

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                                            SizedBox(width: 8),
                                            Text('Document encrypted & stored in Hardware Vault!'),
                                          ],
                                        ),
                                        backgroundColor: Color(0xFF10B981),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isEncrypting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Encryption error: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                        icon: isEncrypting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.lock_rounded, size: 18),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isEncrypting ? 'ENCRYPTING PAYLOAD...' : 'ENCRYPT & STORE IN VAULT',
                            maxLines: 1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddSecretDialog() {
    _showTemplatePickerSheet();
  }

  // ─── Forensic Template Picker ───────────────────────────────────────────────
  void _showTemplatePickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
        final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSub = isDark ? Colors.white60 : const Color(0xFF64748B);

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Select Credential Template',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textMain),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Zero-cloud, KeyStore AES-256-GCM hardware protection for every record.',
                style: TextStyle(fontSize: 12, color: textSub),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: VaultTemplates.all.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final t = VaultTemplates.all[idx];
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showTemplateEditorDialog(template: t);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: t.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(t.icon, color: t.color, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    t.description,
                                    style: TextStyle(fontSize: 11.5, color: textSub, height: 1.3),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right_rounded, color: t.color, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Template Editor & Credential Builder ──────────────────────────────────
  void _showTemplateEditorDialog({required VaultTemplateDef template, VaultItem? existingItem}) {
    final titleCtrl = TextEditingController(text: existingItem?.title ?? template.name);
    final notesCtrl = TextEditingController(text: existingItem?.notes ?? '');
    final Map<String, TextEditingController> fieldControllers = {};
    final Set<String> visibleSecretKeys = {};

    for (var f in template.fields) {
      final initialVal = existingItem?.fields[f.key] ?? (existingItem != null && f.key == template.secretFieldKey ? existingItem.secretValue : '');
      fieldControllers[f.key] = TextEditingController(text: initialVal);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
            final textSub = isDark ? Colors.white60 : const Color(0xFF64748B);

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: template.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(template.icon, color: template.color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                existingItem != null ? 'Edit ${template.name}' : 'Lock ${template.name}',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textMain),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Item Title / Label
                      TextField(
                        controller: titleCtrl,
                        style: TextStyle(color: textMain, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Title / Label',
                          labelStyle: TextStyle(color: textSub),
                          prefixIcon: Icon(Icons.label_outline_rounded, color: template.color, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Dynamic Template Fields
                      ...template.fields.map((field) {
                        final ctrl = fieldControllers[field.key]!;
                        final isRevealed = visibleSecretKeys.contains(field.key);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: ctrl,
                                obscureText: field.isSecret && !isRevealed,
                                maxLines: field.isMultiline ? 3 : 1,
                                keyboardType: field.keyboardType,
                                style: TextStyle(
                                  color: textMain,
                                  fontFamily: field.isSecret && isRevealed ? 'monospace' : null,
                                ),
                                decoration: InputDecoration(
                                  labelText: field.label,
                                  hintText: field.hint,
                                  labelStyle: TextStyle(color: textSub),
                                  hintStyle: TextStyle(color: textSub.withValues(alpha: 0.5), fontSize: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (field.canGeneratePassword)
                                        IconButton(
                                          icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 20),
                                          tooltip: 'Generate Strong Password',
                                          onPressed: () {
                                            _showPasswordGeneratorDialog(onInsert: (generated) {
                                              ctrl.text = generated;
                                              setModalState(() {
                                                visibleSecretKeys.add(field.key);
                                              });
                                            });
                                          },
                                        ),
                                      if (field.isSecret)
                                        IconButton(
                                          icon: Icon(
                                            isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            size: 20,
                                            color: textSub,
                                          ),
                                          onPressed: () {
                                            setModalState(() {
                                              if (isRevealed) {
                                                visibleSecretKeys.remove(field.key);
                                              } else {
                                                visibleSecretKeys.add(field.key);
                                              }
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Additional Notes
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        style: TextStyle(color: textMain),
                        decoration: InputDecoration(
                          labelText: 'Confidential Notes (Optional)',
                          labelStyle: TextStyle(color: textSub),
                          prefixIcon: Icon(Icons.note_alt_outlined, color: template.color, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Save Button
                      ElevatedButton.icon(
                        onPressed: () {
                          if (titleCtrl.text.trim().isEmpty) return;

                          final Map<String, String> fieldsMap = {};
                          for (var f in template.fields) {
                            fieldsMap[f.key] = fieldControllers[f.key]!.text.trim();
                          }

                          final primarySecret = fieldControllers[template.secretFieldKey]?.text.trim() ??
                              fieldControllers.values.first.text.trim();

                          final newItem = VaultItem(
                            id: existingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                            title: titleCtrl.text.trim(),
                            category: template.category,
                            templateType: template.id,
                            secretValue: primarySecret,
                            fields: fieldsMap,
                            notes: notesCtrl.text.trim(),
                            createdAt: existingItem?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
                            type: 'text',
                          );

                          setState(() {
                            if (existingItem != null) {
                              final idx = _items.indexWhere((i) => i.id == existingItem.id);
                              if (idx != -1) _items[idx] = newItem;
                            } else {
                              _items.insert(0, newItem);
                            }
                          });

                          _saveItems();
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 18),
                                  const SizedBox(width: 8),
                                  Text('${template.name} encrypted & stored in Hardware Vault!'),
                                ],
                              ),
                              backgroundColor: const Color(0xFF0F172A),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.lock_rounded, size: 18),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            existingItem != null ? 'UPDATE ENCRYPTED RECORD' : 'ENCRYPT & STORE IN VAULT',
                            maxLines: 1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── High-Entropy Password & PIN Generator Modal ───────────────────────────
  void _showPasswordGeneratorDialog({Function(String)? onInsert}) {
    int length = 16;
    bool upper = true;
    bool lower = true;
    bool digits = true;
    bool symbols = true;
    bool isPinMode = false;
    int pinLength = 6;
    String currentPassword = VaultPasswordGenerator.generate(
      length: length,
      upper: upper,
      lower: lower,
      digits: digits,
      symbols: symbols,
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final textMain = isDark ? Colors.white : const Color(0xFF0F172A);

            final entropy = isPinMode
                ? double.parse((pinLength * 3.32).toStringAsFixed(1))
                : VaultPasswordGenerator.calculateEntropy(currentPassword);
            final entropyRating = VaultPasswordGenerator.getEntropyRating(entropy);
            final entropyColor = VaultPasswordGenerator.getEntropyColor(entropy);

            return AlertDialog(
              backgroundColor: bg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFF1E293B)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isPinMode ? 'Secure PIN Generator' : 'Password Generator',
                    style: TextStyle(color: textMain, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Password Preview Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF06090F) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: entropyColor.withValues(alpha: 0.5), width: 1.2),
                      ),
                      child: Column(
                        children: [
                          SelectableText(
                            currentPassword,
                            style: TextStyle(
                              color: textMain,
                              fontSize: isPinMode ? 26 : 17,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: isPinMode ? 4 : 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: entropyColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$entropy bits • $entropyRating',
                                  style: TextStyle(color: entropyColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8), size: 20),
                                tooltip: 'Regenerate',
                                onPressed: () {
                                  setDialogState(() {
                                    currentPassword = isPinMode
                                        ? VaultPasswordGenerator.generatePin(length: pinLength)
                                        : VaultPasswordGenerator.generate(
                                            length: length,
                                            upper: upper,
                                            lower: lower,
                                            digits: digits,
                                            symbols: symbols,
                                          );
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mode Toggle (Password vs PIN)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('Password'),
                          selected: !isPinMode,
                          onSelected: (val) {
                            setDialogState(() {
                              isPinMode = false;
                              currentPassword = VaultPasswordGenerator.generate(
                                length: length,
                                upper: upper,
                                lower: lower,
                                digits: digits,
                                symbols: symbols,
                              );
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Numeric PIN'),
                          selected: isPinMode,
                          onSelected: (val) {
                            setDialogState(() {
                              isPinMode = true;
                              currentPassword = VaultPasswordGenerator.generatePin(length: pinLength);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (!isPinMode) ...[
                      // Length Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Length: $length characters', style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(length >= 20 ? 'Max Armor' : (length >= 14 ? 'Recommended' : 'Minimum'),
                              style: TextStyle(color: entropyColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: length.toDouble(),
                        min: 8,
                        max: 32,
                        divisions: 24,
                        activeColor: const Color(0xFF00E676),
                        onChanged: (val) {
                          setDialogState(() {
                            length = val.round();
                            currentPassword = VaultPasswordGenerator.generate(
                              length: length,
                              upper: upper,
                              lower: lower,
                              digits: digits,
                              symbols: symbols,
                            );
                          });
                        },
                      ),
                      // Toggles
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Uppercase Letters (A-Z)', style: TextStyle(color: textMain, fontSize: 13)),
                        value: upper,
                        onChanged: (val) {
                          setDialogState(() {
                            upper = val ?? true;
                            currentPassword = VaultPasswordGenerator.generate(
                              length: length,
                              upper: upper,
                              lower: lower,
                              digits: digits,
                              symbols: symbols,
                            );
                          });
                        },
                      ),
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Lowercase Letters (a-z)', style: TextStyle(color: textMain, fontSize: 13)),
                        value: lower,
                        onChanged: (val) {
                          setDialogState(() {
                            lower = val ?? true;
                            currentPassword = VaultPasswordGenerator.generate(
                              length: length,
                              upper: upper,
                              lower: lower,
                              digits: digits,
                              symbols: symbols,
                            );
                          });
                        },
                      ),
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Digits (0-9)', style: TextStyle(color: textMain, fontSize: 13)),
                        value: digits,
                        onChanged: (val) {
                          setDialogState(() {
                            digits = val ?? true;
                            currentPassword = VaultPasswordGenerator.generate(
                              length: length,
                              upper: upper,
                              lower: lower,
                              digits: digits,
                              symbols: symbols,
                            );
                          });
                        },
                      ),
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Special Symbols (!@#\$%)', style: TextStyle(color: textMain, fontSize: 13)),
                        value: symbols,
                        onChanged: (val) {
                          setDialogState(() {
                            symbols = val ?? true;
                            currentPassword = VaultPasswordGenerator.generate(
                              length: length,
                              upper: upper,
                              lower: lower,
                              digits: digits,
                              symbols: symbols,
                            );
                          });
                        },
                      ),
                    ] else ...[
                      // PIN Length Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [4, 6, 8].map((l) {
                          return ChoiceChip(
                            label: Text('$l Digits'),
                            selected: pinLength == l,
                            onSelected: (val) {
                              setDialogState(() {
                                pinLength = l;
                                currentPassword = VaultPasswordGenerator.generatePin(length: pinLength);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    VaultClipboardGuard.copyWithAutoWipe(context, currentPassword, isPinMode ? 'PIN' : 'Password');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy to RAM'),
                ),
                if (onInsert != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black),
                    onPressed: () {
                      onInsert(currentPassword);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Insert & Use', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Decrypted Record Details Sheet ─────────────────────────────────────────
  void _showItemDetailsSheet(VaultItem item) {
    final template = VaultTemplates.findById(item.templateType);
    final Set<String> revealedKeys = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
            final textSub = isDark ? Colors.white60 : const Color(0xFF64748B);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: template.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(template.icon, color: template.color, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textMain),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${template.name} • AES-256 KeyStore',
                                  style: TextStyle(fontSize: 11, color: template.color, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Structured Field Cards
                    ...template.fields.map((field) {
                      final val = item.fields[field.key] ?? (field.key == template.secretFieldKey ? item.secretValue : '');
                      if (val.isEmpty) return const SizedBox.shrink();

                      final isRevealed = revealedKeys.contains(field.key);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              field.label.toUpperCase(),
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: textSub, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    field.isSecret && !isRevealed ? '•••• •••• •••• ••••' : val,
                                    style: TextStyle(
                                      color: textMain,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: (field.isSecret && isRevealed) || field.key.contains('number') || field.key.contains('pin')
                                          ? 'monospace'
                                          : null,
                                    ),
                                  ),
                                ),
                                if (field.isSecret)
                                  IconButton(
                                    icon: Icon(
                                      isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 18,
                                      color: textSub,
                                    ),
                                    onPressed: () {
                                      setSheetState(() {
                                        if (isRevealed) {
                                          revealedKeys.remove(field.key);
                                        } else {
                                          revealedKeys.add(field.key);
                                        }
                                      });
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF2563EB)),
                                  tooltip: 'Copy',
                                  onPressed: () {
                                    VaultClipboardGuard.copyWithAutoWipe(context, val, field.label);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    if (item.notes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CONFIDENTIAL NOTES', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: textSub)),
                            const SizedBox(height: 6),
                            Text(item.notes, style: TextStyle(color: textMain, fontSize: 13, height: 1.35)),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF38BDF8)),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF38BDF8)),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Edit Fields', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showTemplateEditorDialog(template: template, existingItem: item);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Shred Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _deleteItem(item.id);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
        final textMain = isDark ? Colors.white : const Color(0xFF0F172A);

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add to Hardware Vault',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textMain),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.security_rounded, color: Color(0xFF00E676), size: 24),
                  ),
                  title: Text('Add Credential (9 Templates)', style: TextStyle(fontWeight: FontWeight.bold, color: textMain)),
                  subtitle: const Text('Gmail, Netbanking, Cards, UPI, Social Media, Wi-Fi & Crypto Seeds', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showTemplatePickerSheet();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 24),
                  ),
                  title: Text('Password & PIN Generator', style: TextStyle(fontWeight: FontWeight.bold, color: textMain)),
                  subtitle: const Text('Military-grade 128-bit entropy passwords & numeric PINs', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPasswordGeneratorDialog();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.document_scanner_rounded, color: Color(0xFF10B981), size: 24),
                  ),
                  title: Text('Scan Document (Auto Edge-Crop HD)', style: TextStyle(fontWeight: FontWeight.bold, color: textMain)),
                  subtitle: const Text('Clean edge-detection without filter distortion', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startDocumentScan();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF06B6D4), size: 24),
                  ),
                  title: Text('Camera HD Capture (100% Quality)', style: TextStyle(fontWeight: FontWeight.bold, color: textMain)),
                  subtitle: const Text('Direct high-res photo with zero compression loss', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureCameraHd();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF38BDF8), size: 24),
                  ),
                  title: Text('Import Document from Gallery', style: TextStyle(fontWeight: FontWeight.bold, color: textMain)),
                  subtitle: const Text('Pick existing identity doc image to encrypt with AES-256', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickDocumentFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteItem(String id) {
    final item = _items.firstWhere((i) => i.id == id, orElse: () => _items.first);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Shred Encrypted Item?'),
        content: Text(
          item.isDocument
              ? 'The document ciphertext will be permanently shredded from disk and KeyStore.'
              : 'This secret entry will be permanently deleted from local hardware storage.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (item.isDocument && item.documentFileName != null) {
                await VaultCryptoService().shredDocument(item.documentFileName!);
              }
              setState(() {
                _items.removeWhere((i) => i.id == id);
                _revealedItemIds.remove(id);
              });
              await _saveItems();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Shred & Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<VaultItem> get _filteredItems {
    if (_activeFilter == 'docs') {
      return _items.where((i) => i.isDocument).toList();
    } else if (_activeFilter == 'gmail') {
      return _items.where((i) => i.templateType == 'gmail').toList();
    } else if (_activeFilter == 'bank') {
      return _items.where((i) => i.templateType == 'bank' || i.templateType == 'card').toList();
    } else if (_activeFilter == 'upi') {
      return _items.where((i) => i.templateType == 'upi').toList();
    } else if (_activeFilter == 'secrets') {
      return _items.where((i) => !i.isDocument).toList();
    }
    return _items;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF080C14) : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? Colors.white60 : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

    final docsCount = _items.where((i) => i.isDocument).length;
    final gmailCount = _items.where((i) => i.templateType == 'gmail').length;
    final bankCount = _items.where((i) => i.templateType == 'bank' || i.templateType == 'card').length;
    final upiCount = _items.where((i) => i.templateType == 'upi').length;
    final secretsCount = _items.where((i) => !i.isDocument).length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textMain, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Hardware Security Vault',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: textMain),
        ),
        actions: [
          if (_isUnlocked)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2563EB)),
              tooltip: 'Add Entry',
              onPressed: _showAddActionSheet,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Vault Hero Card ──
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isUnlocked
                            ? [const Color(0xFF0A2540), const Color(0xFF0F172A)]
                            : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                            color: const Color(0xFF38BDF8),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isUnlocked ? 'AES-256 HARDWARE VAULT' : 'VAULT LOCKED',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isUnlocked
                                    ? 'TEE Android KeyStore active. Documents & secrets encrypted locally with zero cloud exposure.'
                                    : 'Biometric authorization required to decrypt protected documents and secrets.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Quick Action Scan & Add Bar ──
                  if (_isUnlocked)
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _showTemplatePickerSheet,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00E676).withValues(alpha: 0.25),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_moderator_rounded, color: Colors.black, size: 18),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Add Credential',
                                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: _startDocumentScan,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.document_scanner_rounded, color: Colors.white, size: 18),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Scan Document',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => _showPasswordGeneratorDialog(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderCol),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 16),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Generate Strong Password / PIN',
                                    style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // ── Biometric App Lock Switch ──
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderCol),
                    ),
                    child: SwitchListTile(
                      value: _isVaultEnabled,
                      onChanged: _hasBiometrics ? _toggleAppLock : null,
                      activeThumbColor: const Color(0xFF10B981),
                      title: Text(
                        'Biometric App Lock on Launch',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain),
                      ),
                      subtitle: Text(
                        _hasBiometrics
                            ? 'Requires fingerprint or Face ID whenever SafeSignal is opened.'
                            : 'Device biometric hardware not available.',
                        style: TextStyle(fontSize: 11.5, color: textSub),
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Encrypted Item List ──
                  if (!_isUnlocked)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: ElevatedButton.icon(
                          onPressed: _authenticateAndLoad,
                          icon: const Icon(Icons.fingerprint, size: 20),
                          label: const Text('DECRYPT VAULT ENTRIES'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    // Filter Chips Bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildFilterChip('All (${_items.length})', 'all'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Scanned Documents ($docsCount)', 'docs'),
                          const SizedBox(width: 8),
                          if (gmailCount > 0) ...[
                            _buildFilterChip('Google / Gmail ($gmailCount)', 'gmail'),
                            const SizedBox(width: 8),
                          ],
                          if (bankCount > 0) ...[
                            _buildFilterChip('Banking & Cards ($bankCount)', 'bank'),
                            const SizedBox(width: 8),
                          ],
                          if (upiCount > 0) ...[
                            _buildFilterChip('UPI & Wallets ($upiCount)', 'upi'),
                            const SizedBox(width: 8),
                          ],
                          _buildFilterChip('All Keys & PINs ($secretsCount)', 'secrets'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (_filteredItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.shield_moon_outlined, size: 40, color: textSub.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              _activeFilter == 'docs' ? 'No Scanned Documents' : (_activeFilter == 'secrets' ? 'No Secrets Stored' : 'Vault is Empty'),
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _activeFilter == 'docs'
                                  ? 'Scan Aadhaar card, PAN card, passport, or confidential contracts with on-device edge detection.'
                                  : 'Securely store private UPI PINs, seed recovery phrases, and credentials.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: textSub),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _activeFilter == 'secrets' ? _showAddSecretDialog : _startDocumentScan,
                              icon: Icon(_activeFilter == 'secrets' ? Icons.add_rounded : Icons.document_scanner_rounded, size: 16),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(_activeFilter == 'secrets' ? 'Add Secret Key' : 'Scan First Document', maxLines: 1),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final item = _filteredItems[idx];
                          return item.isDocument ? _buildDocumentCard(item) : _buildSecretCard(item);
                        },
                      ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _activeFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
          boxShadow: [
            if (isSelected) BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // ─── World-Class Document Item Card ─────────────────────────────────────────
  Widget _buildDocumentCard(VaultItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderCol = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

    final sizeStr = item.fileSizeBytes != null ? '${(item.fileSizeBytes! / 1024).toStringAsFixed(0)} KB' : 'Encrypted';

    Color categoryColor = const Color(0xFF10B981);
    IconData categoryIcon = Icons.badge_rounded;
    if (item.category.contains('PAN')) {
      categoryColor = const Color(0xFFF97316);
      categoryIcon = Icons.credit_card_rounded;
    } else if (item.category.contains('Passport')) {
      categoryColor = const Color(0xFF8B5CF6);
      categoryIcon = Icons.flight_takeoff_rounded;
    } else if (item.category.contains('License')) {
      categoryColor = const Color(0xFF06B6D4);
      categoryIcon = Icons.directions_car_rounded;
    } else if (item.category.contains('Medical')) {
      categoryColor = const Color(0xFFEC4899);
      categoryIcon = Icons.medical_services_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Document Image Thumbnail Preview
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => VaultDocumentViewerScreen(
                          item: item,
                          onDelete: () => _deleteItem(item.id),
                        ),
                      ),
                    );
                  },
                  child: _DocumentThumbnailWidget(
                    item: item,
                    categoryColor: categoryColor,
                    categoryIcon: categoryIcon,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.category.toUpperCase(),
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: categoryColor),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'AES-256 • $sizeStr',
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
                      ),
                      if (item.secretValue.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'ID: ${item.secretValue}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              letterSpacing: 0.5,
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                  tooltip: 'Shred',
                  onPressed: () => _deleteItem(item.id),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 1-Tap Decrypt & View in RAM Action Bar
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => VaultDocumentViewerScreen(
                    item: item,
                    onDelete: () => _deleteItem(item.id),
                  ),
                ),
              );
            },
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_open_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'DECRYPT & VIEW IN SECURE RAM',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB), letterSpacing: 0.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Forensic Structured Credential Card ────────────────────────────────────
  Widget _buildSecretCard(VaultItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? Colors.white60 : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final isRevealed = _revealedItemIds.contains(item.id);
    final template = VaultTemplates.findById(item.templateType);

    // Primary field preview (e.g. email, username, cardholder)
    String primaryFieldValue = item.fields[template.primaryFieldKey] ?? '';
    if (primaryFieldValue.isEmpty && item.fields.isNotEmpty) {
      primaryFieldValue = item.fields.values.first;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: template.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(template.icon, color: template.color, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: template.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        template.name.toUpperCase(),
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: template.color),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF38BDF8)),
                      tooltip: 'Edit',
                      onPressed: () => _showTemplateEditorDialog(template: template, existingItem: item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      tooltip: 'Shred',
                      onPressed: () => _deleteItem(item.id),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
                ),
                if (primaryFieldValue.isNotEmpty && primaryFieldValue != item.title) ...[
                  const SizedBox(height: 3),
                  Text(
                    primaryFieldValue,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                // Masked / Revealed Secret Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isRevealed ? item.secretValue : '•••• •••• •••• ••••',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: isRevealed ? 'monospace' : null,
                            fontWeight: FontWeight.w700,
                            letterSpacing: isRevealed ? 0.5 : 2,
                            color: textMain,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                          color: textSub,
                        ),
                        onPressed: () {
                          setState(() {
                            if (isRevealed) {
                              _revealedItemIds.remove(item.id);
                            } else {
                              _revealedItemIds.add(item.id);
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF2563EB)),
                        tooltip: 'Copy',
                        onPressed: () {
                          VaultClipboardGuard.copyWithAutoWipe(context, item.secretValue, 'Password / Secret');
                        },
                      ),
                    ],
                  ),
                ),
                if (item.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.notes,
                    style: TextStyle(fontSize: 11.5, color: textSub, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1E293B)),
          // Action Bar to View All Decrypted Fields
          InkWell(
            onTap: () => _showItemDetailsSheet(item),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 15, color: template.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'VIEW ALL DECRYPTED FIELDS (${item.fields.length} ITEMS)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: template.color, letterSpacing: 0.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: template.color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Live Decrypted Document Thumbnail Widget ─────────────────────────────────
class _DocumentThumbnailWidget extends StatefulWidget {
  final VaultItem item;
  final Color categoryColor;
  final IconData categoryIcon;

  const _DocumentThumbnailWidget({
    required this.item,
    required this.categoryColor,
    required this.categoryIcon,
  });

  @override
  State<_DocumentThumbnailWidget> createState() => _DocumentThumbnailWidgetState();
}

class _DocumentThumbnailWidgetState extends State<_DocumentThumbnailWidget> {
  Uint8List? _cachedBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resolveThumbnail();
  }

  @override
  void didUpdateWidget(covariant _DocumentThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.documentFileName != widget.item.documentFileName) {
      _resolveThumbnail();
    }
  }

  Future<void> _resolveThumbnail() async {
    final fileName = widget.item.documentFileName;
    final ivBase64 = widget.item.documentIv;
    if (fileName == null || ivBase64 == null) return;

    if (_VaultScreenState._documentThumbCache.containsKey(fileName)) {
      setState(() {
        _cachedBytes = _VaultScreenState._documentThumbCache[fileName];
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final decrypted = await VaultCryptoService().decryptDocument(
        relativePath: fileName,
        ivBase64: ivBase64,
        cipherMode: widget.item.cipherMode,
        expectedSha256: widget.item.documentChecksum,
      );
      _VaultScreenState._documentThumbCache[fileName] = decrypted;
      if (mounted) {
        setState(() {
          _cachedBytes = decrypted;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedBytes != null) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.categoryColor.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                _cachedBytes!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
              Positioned(
                bottom: 3,
                right: 3,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, size: 10, color: Color(0xFF10B981)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: widget.categoryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.categoryColor.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.categoryColor,
                ),
              )
            : Icon(widget.categoryIcon, color: widget.categoryColor, size: 30),
      ),
    );
  }
}
