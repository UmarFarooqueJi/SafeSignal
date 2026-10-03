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

class VaultItem {
  final String id;
  final String title;
  final String category; // 'Aadhaar / ID', 'PAN Card', 'Passport', 'Banking & UPI', 'Crypto / Seed Phrase', 'Secret Note'
  final String secretValue;
  final String notes;
  final int createdAt;
  final String type; // 'text' or 'document'
  final String? documentFileName;
  final String? documentIv;
  final String? documentChecksum;
  final int? fileSizeBytes;

  bool get isDocument => type == 'document';

  const VaultItem({
    required this.id,
    required this.title,
    required this.category,
    required this.secretValue,
    this.notes = '',
    required this.createdAt,
    this.type = 'text',
    this.documentFileName,
    this.documentIv,
    this.documentChecksum,
    this.fileSizeBytes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'secretValue': secretValue,
        'notes': notes,
        'createdAt': createdAt,
        'type': type,
        'documentFileName': documentFileName,
        'documentIv': documentIv,
        'documentChecksum': documentChecksum,
        'fileSizeBytes': fileSizeBytes,
      };

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String? ?? 'Secret Note',
        secretValue: json['secretValue'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        type: json['type'] as String? ?? 'text',
        documentFileName: json['documentFileName'] as String?,
        documentIv: json['documentIv'] as String?,
        documentChecksum: json['documentChecksum'] as String?,
        fileSizeBytes: json['fileSizeBytes'] as int?,
      );
}

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage();

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
    _initVault();
  }

  Future<void> _initVault() async {
    final prefs = await SharedPreferences.getInstance();
    final canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    final canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

    final isLockEnabled = prefs.getBool('isVaultEnabled') ?? false;

    setState(() {
      _isVaultEnabled = isLockEnabled;
      _hasBiometrics = canAuthenticate;
      _isLoading = false;
    });

    if (_hasBiometrics) {
      _authenticateAndLoad();
    } else {
      _loadItems();
    }
  }

  Future<void> _authenticateAndLoad() async {
    try {
      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Authenticate to decrypt your hardware-protected Vault',
      );
      if (didAuthenticate) {
        await _loadItems();
      }
    } catch (_) {}
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
    } catch (_) {
      if (mounted) setState(() => _isUnlocked = true);
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
                        label: Text(isEncrypting ? 'ENCRYPTING PAYLOAD...' : 'ENCRYPT & LOCK IN HARDWARE VAULT'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
    final titleCtrl = TextEditingController();
    final secretCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'Banking & UPI';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF111827) : Colors.white;
        final textMain = isDark ? Colors.white : const Color(0xFF0F172A);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Store Encrypted Secret Key / PIN',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textMain),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Banking & UPI', child: Text('Bank Account / UPI PIN')),
                        DropdownMenuItem(value: 'Crypto / Seed Phrase', child: Text('Wallet Seed Phrase / Private Key')),
                        DropdownMenuItem(value: 'Secret Note', child: Text('Password / Confidential Note')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Title / Label (e.g. HDFC UPI, Ledger Seed)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: secretCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Secret Value (Encrypted with AES-256)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Additional Notes (Optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (titleCtrl.text.trim().isEmpty || secretCtrl.text.trim().isEmpty) return;
                        final newItem = VaultItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleCtrl.text.trim(),
                          category: category,
                          secretValue: secretCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                          createdAt: DateTime.now().millisecondsSinceEpoch,
                          type: 'text',
                        );
                        setState(() => _items.insert(0, newItem));
                        _saveItems();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.lock_rounded, size: 18),
                      label: const Text('ENCRYPT & SAVE TO VAULT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
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
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.password_rounded, color: Color(0xFF8B5CF6), size: 24),
                  ),
                  title: Text('Store Secret PIN / Key / Note', style: TextStyle(fontWeight: FontWeight.bold, color: textMain)),
                  subtitle: const Text('Bank UPI PIN, recovery seeds, credentials in KeyStore', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddSecretDialog();
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
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _startDocumentScan,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
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
                                  SizedBox(width: 8),
                                  Text(
                                    'Scan Document',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showAddSecretDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderCol),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.password_rounded, color: Color(0xFF2563EB), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add Secret Key',
                                    style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
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
                          _buildFilterChip('Keys & PINs ($secretsCount)', 'secrets'),
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
                              label: Text(_activeFilter == 'secrets' ? 'Add Secret Key' : 'Scan First Document'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
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
                  const Text(
                    'DECRYPT & VIEW IN SECURE RAM',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB), letterSpacing: 0.3),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Secret Key / PIN Item Card ─────────────────────────────────────────────
  Widget _buildSecretCard(VaultItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? Colors.white60 : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final isRevealed = _revealedItemIds.contains(item.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                tooltip: 'Delete',
                onPressed: () => _deleteItem(item.id),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
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
                    Clipboard.setData(ClipboardData(text: item.secretValue));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (item.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.notes,
              style: TextStyle(fontSize: 12, color: textSub, fontStyle: FontStyle.italic),
            ),
          ],
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
