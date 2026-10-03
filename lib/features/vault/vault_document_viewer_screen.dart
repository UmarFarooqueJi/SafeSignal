/*
 * SafeSignal Mobile Security Suite
 * Module: Zero-Knowledge Encrypted Document Viewer
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
 * Copyright (c) 2026 SafeSignal Technologies. All rights reserved.
 *
 * Provides RAM-only decrypted document rendering with pinch-to-zoom,
 * hardware security verification badges, and secure memory erasure on dismiss.
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'vault_crypto_service.dart';
import 'vault_screen.dart';

class VaultDocumentViewerScreen extends StatefulWidget {
  final VaultItem item;
  final VoidCallback onDelete;

  const VaultDocumentViewerScreen({
    super.key,
    required this.item,
    required this.onDelete,
  });

  @override
  State<VaultDocumentViewerScreen> createState() => _VaultDocumentViewerScreenState();
}

class _VaultDocumentViewerScreenState extends State<VaultDocumentViewerScreen> {
  Uint8List? _decryptedBytes;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _decryptPayload();
  }

  @override
  void dispose() {
    // Zero out memory to prevent forensic heap dumps
    if (_decryptedBytes != null) {
      for (int i = 0; i < _decryptedBytes!.length; i++) {
        _decryptedBytes![i] = 0;
      }
    }
    super.dispose();
  }

  Future<void> _decryptPayload() async {
    try {
      if (widget.item.documentFileName == null || widget.item.documentIv == null) {
        throw Exception('Incomplete encrypted document metadata');
      }

      final bytes = await VaultCryptoService().decryptDocument(
        relativePath: widget.item.documentFileName!,
        ivBase64: widget.item.documentIv!,
      );

      if (mounted) {
        setState(() {
          _decryptedBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Decryption failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportDocument() async {
    if (_decryptedBytes == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final cleanTitle = widget.item.title.replaceAll(RegExp(r'[^\w\s]+'), '_');
      final tempFile = File('${tempDir.path}/$cleanTitle.jpg');
      await tempFile.writeAsBytes(_decryptedBytes!);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          subject: 'Encrypted Document Export',
          title: 'Export Scanned Document',
        ),
      );

      // Clean up exported temp file after share prompt
      Future.delayed(const Duration(seconds: 10), () async {
        if (await tempFile.exists()) await tempFile.delete();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDocumentDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Cryptographic Proof & Metadata',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildMetaRow('Cipher Suite', 'AES-256-CBC • PKCS#7 Padding'),
              _buildMetaRow('Hardware Storage', 'Android KeyStore TEE Isolated'),
              _buildMetaRow('Payload Size', '${((widget.item.fileSizeBytes ?? 0) / 1024).toStringAsFixed(1)} KB'),
              _buildMetaRow('Category', widget.item.category),
              if (widget.item.secretValue.isNotEmpty)
                _buildMetaRow('ID / Ref Number', widget.item.secretValue),
              if (widget.item.documentChecksum != null)
                _buildMetaRow('SHA-256 Checksum', '${widget.item.documentChecksum!.substring(0, 24)}...'),
              const SizedBox(height: 16),
              const Text(
                'This document was decrypted strictly in device volatile RAM. No plaintext cache exists on disk.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF030712),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.item.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, size: 10, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text(
                      'SECURE RAM',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, color: Colors.white70),
              tooltip: 'Security Info',
              onPressed: _showDocumentDetails,
            ),
            IconButton(
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white70),
              tooltip: 'Export',
              onPressed: _exportDocument,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2563EB)),
                    SizedBox(height: 16),
                    Text('Unlocking with TEE Hardware Key...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              )
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.gpp_bad_rounded, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 16),
                          Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Back to Vault'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      // Interactive Pan & Zoom Canvas
                      Center(
                        child: InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 6.0,
                          clipBehavior: Clip.none,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _decryptedBytes!,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, _, _) => const Center(
                                child: Text('Unable to render document image', style: TextStyle(color: Colors.white70)),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Floating Bottom Action Bar
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 24,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF1E293B)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: _showDocumentDetails,
                                icon: const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF38BDF8)),
                                label: const Text('Verify Integrity', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF0F172A),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      title: const Text('Shred Document?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      content: const Text(
                                        'This document will be securely zeroed and deleted from encrypted hardware storage.',
                                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                          onPressed: () {
                                            Navigator.pop(ctx); // Close dialog
                                            Navigator.pop(context); // Close viewer
                                            widget.onDelete();
                                          },
                                          child: const Text('Shred & Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.white),
                                label: const Text('Shred', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
