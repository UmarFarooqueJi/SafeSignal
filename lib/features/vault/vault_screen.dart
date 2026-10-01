/*
 * SafeSignal Mobile Security Suite
 * Module: Hardware-Encrypted Security Vault & Biometric Guard
 * Author: Umar Farooque (umarfarooque@safesignal.app)
 * Copyright (c) 2026 SafeSignal Technologies. All rights reserved.
 *
 * AES-256-GCM hardware-backed vault using Android KeyStore & FlutterSecureStorage:
 * Secure storage for confidential IDs (Aadhaar, PAN), UPI handles,
 * crypto seed phrases, and passwords. Includes biometric app lock.
 */
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

class VaultItem {
  final String id;
  final String title;
  final String category; // 'Aadhaar / ID', 'Banking & UPI', 'Crypto / Seed Phrase', 'Secret Note'
  final String secretValue;
  final String notes;
  final int createdAt;

  const VaultItem({
    required this.id,
    required this.title,
    required this.category,
    required this.secretValue,
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'secretValue': secretValue,
        'notes': notes,
        'createdAt': createdAt,
      };

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String? ?? 'Secret Note',
        secretValue: json['secretValue'] as String,
        notes: json['notes'] as String? ?? '',
        createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
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

    // Auto-prompt biometrics to decrypt the vault
    if (_hasBiometrics) {
      _authenticateAndLoad();
    } else {
      // If device has no biometrics, unlock directly
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
    } catch (_) {
      // Fallback
    }
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

  void _showAddItemDialog() {
    final titleCtrl = TextEditingController();
    final secretCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'Aadhaar / ID';

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Store Encrypted Item',
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
                      value: category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Aadhaar / ID', child: Text('Aadhaar / Govt ID')),
                        DropdownMenuItem(value: 'Banking & UPI', child: Text('Bank Account / UPI PIN')),
                        DropdownMenuItem(value: 'Crypto / Seed Phrase', child: Text('Wallet Seed Phrase / Key')),
                        DropdownMenuItem(value: 'Secret Note', child: Text('Confidential Note / Password')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Title / Label (e.g. My Aadhaar, HDFC UPI)',
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
            );
          },
        );
      },
    );
  }

  void _deleteItem(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Encrypted Item?'),
        content: const Text('This entry will be permanently shredded from local hardware storage.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                _items.removeWhere((i) => i.id == id);
                _revealedItemIds.remove(id);
              });
              _saveItems();
              Navigator.pop(ctx);
            },
            child: const Text('Shred & Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF080C14) : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? Colors.white60 : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

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
              tooltip: 'Add Secret',
              onPressed: _showAddItemDialog,
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
                                _isUnlocked ? 'AES-256 VAULT UNLOCKED' : 'VAULT LOCKED',
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
                                    ? 'Hardware Keystore backed. Items decrypted strictly in secure memory.'
                                    : 'Biometric authorization required to decrypt protected secrets.',
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

                  const SizedBox(height: 20),

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
                      activeColor: const Color(0xFF10B981),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ENCRYPTED ENTRIES (${_items.length})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: textSub,
                            letterSpacing: 1.5,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddItemDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Item', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_items.isEmpty)
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
                              'Vault is Empty',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Securely store Aadhaar numbers, PAN cards, private UPI PINs, and recovery seeds.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: textSub),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _showAddItemDialog,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Store First Item'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
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
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final item = _items[idx];
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
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.category.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF2563EB),
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
                        },
                      ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
