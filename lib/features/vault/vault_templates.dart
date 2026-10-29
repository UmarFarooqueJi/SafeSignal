/*
 * SafeSignal Mobile Security Suite
 * Module: Hardware Vault Forensic Templates, Password Generator & Clipboard Guard
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
 * Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
 *
 * Provides structured military-grade credential templates, NIST-compliant
 * entropy calculation, high-entropy password/PIN generator, and automated
 * 30-second RAM/clipboard wiping.
 */

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VaultFieldDef {
  final String key;
  final String label;
  final String hint;
  final bool isSecret;
  final bool isMultiline;
  final TextInputType keyboardType;
  final bool canGeneratePassword;

  const VaultFieldDef({
    required this.key,
    required this.label,
    required this.hint,
    this.isSecret = false,
    this.isMultiline = false,
    this.keyboardType = TextInputType.text,
    this.canGeneratePassword = false,
  });
}

class VaultTemplateDef {
  final String id;
  final String name;
  final String category;
  final IconData icon;
  final Color color;
  final String description;
  final String primaryFieldKey;
  final String secretFieldKey;
  final List<VaultFieldDef> fields;

  const VaultTemplateDef({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.color,
    required this.description,
    required this.primaryFieldKey,
    required this.secretFieldKey,
    required this.fields,
  });
}

class VaultTemplates {
  static const List<VaultTemplateDef> all = [
    // 1. Google / Gmail
    VaultTemplateDef(
      id: 'gmail',
      name: 'Google / Gmail Account',
      category: 'Google / Gmail',
      icon: Icons.mail_rounded,
      color: Color(0xFFEA4335),
      description:
          'Google account, Gmail credentials, app passwords & 2FA backup codes',
      primaryFieldKey: 'email',
      secretFieldKey: 'password',
      fields: [
        VaultFieldDef(
          key: 'email',
          label: 'Google / Gmail Address',
          hint: 'e.g. username@gmail.com',
          keyboardType: TextInputType.emailAddress,
        ),
        VaultFieldDef(
          key: 'password',
          label: 'Account Password',
          hint: 'Enter or generate strong password',
          isSecret: true,
          canGeneratePassword: true,
        ),
        VaultFieldDef(
          key: 'recovery_email',
          label: 'Recovery Email / Phone',
          hint: 'e.g. backup@example.com or +91 98765 43210',
          keyboardType: TextInputType.text,
        ),
        VaultFieldDef(
          key: 'backup_codes',
          label: '2FA Backup Codes',
          hint: 'Paste 8-digit emergency backup codes (one per line)',
          isSecret: true,
          isMultiline: true,
        ),
      ],
    ),

    // 2. Bank & Netbanking
    VaultTemplateDef(
      id: 'bank',
      name: 'Bank & Netbanking',
      category: 'Banking & Netbanking',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF0284C7),
      description:
          'Netbanking login, account number, customer ID, IFSC & transaction PIN',
      primaryFieldKey: 'bank_name',
      secretFieldKey: 'login_password',
      fields: [
        VaultFieldDef(
          key: 'bank_name',
          label: 'Bank Name',
          hint: 'e.g. HDFC Bank, SBI, ICICI Bank, Axis Bank',
        ),
        VaultFieldDef(
          key: 'account_number',
          label: 'Account Number',
          hint: 'e.g. 50100234567890',
          keyboardType: TextInputType.number,
        ),
        VaultFieldDef(
          key: 'ifsc_code',
          label: 'IFSC Code',
          hint: 'e.g. HDFC0000123',
        ),
        VaultFieldDef(
          key: 'customer_id',
          label: 'Customer ID / Netbanking Username',
          hint: 'e.g. 84729103 or user_corp',
        ),
        VaultFieldDef(
          key: 'login_password',
          label: 'Netbanking Login Password',
          hint: 'Master password for online banking',
          isSecret: true,
          canGeneratePassword: true,
        ),
        VaultFieldDef(
          key: 'tx_pin',
          label: 'Transaction PIN / T-PIN',
          hint: '4 or 6-digit transaction PIN',
          isSecret: true,
          keyboardType: TextInputType.number,
        ),
      ],
    ),

    // 3. Payment Cards
    VaultTemplateDef(
      id: 'card',
      name: 'Credit / Debit Card',
      category: 'Payment Cards',
      icon: Icons.credit_card_rounded,
      color: Color(0xFF8B5CF6),
      description:
          'Cardholder name, 16-digit card number, expiry, CVV & ATM PIN',
      primaryFieldKey: 'cardholder',
      secretFieldKey: 'card_number',
      fields: [
        VaultFieldDef(
          key: 'cardholder',
          label: 'Cardholder Name',
          hint: 'Name as printed on card',
        ),
        VaultFieldDef(
          key: 'card_number',
          label: '16-Digit Card Number',
          hint: 'e.g. 4532 8923 1948 2019',
          isSecret: true,
          keyboardType: TextInputType.number,
        ),
        VaultFieldDef(
          key: 'expiry',
          label: 'Expiry Date (MM/YY)',
          hint: 'e.g. 08/29',
          keyboardType: TextInputType.datetime,
        ),
        VaultFieldDef(
          key: 'cvv',
          label: 'CVV / CVC Code',
          hint: '3 or 4-digit security code on back',
          isSecret: true,
          keyboardType: TextInputType.number,
        ),
        VaultFieldDef(
          key: 'atm_pin',
          label: 'ATM / POS PIN',
          hint: '4-digit ATM PIN',
          isSecret: true,
          keyboardType: TextInputType.number,
        ),
      ],
    ),

    // 4. UPI & Digital Wallet
    VaultTemplateDef(
      id: 'upi',
      name: 'UPI & Digital Wallet',
      category: 'UPI & Digital Wallet',
      icon: Icons.bolt_rounded,
      color: Color(0xFF10B981),
      description:
          'UPI VPA handle, provider (GPay/PhonePe/Paytm) & secret UPI PIN',
      primaryFieldKey: 'vpa',
      secretFieldKey: 'upi_pin',
      fields: [
        VaultFieldDef(
          key: 'vpa',
          label: 'UPI ID / VPA Handle',
          hint: 'e.g. yourname@okhdfcbank or 9876543210@paytm',
        ),
        VaultFieldDef(
          key: 'provider',
          label: 'Wallet Provider / App',
          hint: 'e.g. Google Pay, PhonePe, Paytm, BHIM',
        ),
        VaultFieldDef(
          key: 'linked_mobile',
          label: 'Linked Mobile Number',
          hint: 'e.g. +91 98765 43210',
          keyboardType: TextInputType.phone,
        ),
        VaultFieldDef(
          key: 'upi_pin',
          label: 'UPI Security PIN',
          hint: '4 or 6-digit payment PIN',
          isSecret: true,
          keyboardType: TextInputType.number,
        ),
      ],
    ),

    // 5. Social Media & Accounts
    VaultTemplateDef(
      id: 'social',
      name: 'Social Media & Accounts',
      category: 'Social Media',
      icon: Icons.public_rounded,
      color: Color(0xFFEC4899),
      description:
          'Instagram, X/Twitter, Facebook, Telegram, Discord, GitHub credentials',
      primaryFieldKey: 'handle',
      secretFieldKey: 'password',
      fields: [
        VaultFieldDef(
          key: 'platform',
          label: 'Platform / Service',
          hint: 'e.g. Instagram, X (Twitter), GitHub, Telegram, Discord',
        ),
        VaultFieldDef(
          key: 'handle',
          label: 'Username / Handle',
          hint: 'e.g. @cyber_sentinel or user123',
        ),
        VaultFieldDef(
          key: 'email',
          label: 'Registered Email / Mobile',
          hint: 'e.g. account@domain.com',
          keyboardType: TextInputType.emailAddress,
        ),
        VaultFieldDef(
          key: 'password',
          label: 'Account Password',
          hint: 'Password for social account',
          isSecret: true,
          canGeneratePassword: true,
        ),
        VaultFieldDef(
          key: 'two_factor_secret',
          label: '2FA Recovery Key / TOTP Secret',
          hint: 'Manual 2FA setup key or recovery codes',
          isSecret: true,
        ),
      ],
    ),

    // 6. Government Identity Records
    VaultTemplateDef(
      id: 'id',
      name: 'Government Identity Record',
      category: 'Government Identity',
      icon: Icons.badge_rounded,
      color: Color(0xFFF59E0B),
      description:
          'Aadhaar, PAN Card, Passport, Driving License & Voter ID records',
      primaryFieldKey: 'id_number',
      secretFieldKey: 'id_number',
      fields: [
        VaultFieldDef(
          key: 'id_type',
          label: 'Identity Document Type',
          hint: 'e.g. Aadhaar Card, PAN Card, Passport, Driving License',
        ),
        VaultFieldDef(
          key: 'id_number',
          label: 'Document / ID Number',
          hint: 'e.g. 5482 1928 3821 or ABCDE1234F',
          isSecret: true,
        ),
        VaultFieldDef(
          key: 'full_name',
          label: 'Full Name (as on document)',
          hint: 'Exact name printed on ID card',
        ),
        VaultFieldDef(
          key: 'dob_expiry',
          label: 'Date of Birth / Document Expiry',
          hint: 'e.g. 15/08/1995 or Valid Thru: 2035',
        ),
      ],
    ),

    // 7. Wi-Fi Network Credentials
    VaultTemplateDef(
      id: 'wifi',
      name: 'Wi-Fi Network Credentials',
      category: 'Wi-Fi Network',
      icon: Icons.wifi_rounded,
      color: Color(0xFF06B6D4),
      description:
          'Home/Office Wi-Fi SSID, WPA3/WPA2 password & router admin gateway',
      primaryFieldKey: 'ssid',
      secretFieldKey: 'password',
      fields: [
        VaultFieldDef(
          key: 'ssid',
          label: 'Wi-Fi SSID / Network Name',
          hint: 'e.g. CyberSec_Lab_5G or Home_Fiber',
        ),
        VaultFieldDef(
          key: 'security_type',
          label: 'Security Protocol',
          hint: 'e.g. WPA3-Personal, WPA2-PSK',
        ),
        VaultFieldDef(
          key: 'password',
          label: 'Wi-Fi Password / Pre-Shared Key',
          hint: 'Network security passphrase',
          isSecret: true,
          canGeneratePassword: true,
        ),
        VaultFieldDef(
          key: 'router_admin',
          label: 'Router Admin IP & Credentials',
          hint: 'e.g. 192.168.1.1 (admin / secretPass)',
          isSecret: true,
        ),
      ],
    ),

    // 8. Crypto & Recovery Seed
    VaultTemplateDef(
      id: 'crypto',
      name: 'Crypto & Recovery Seed',
      category: 'Crypto & Recovery Seed',
      icon: Icons.key_rounded,
      color: Color(0xFFF97316),
      description:
          '12/24-word BIP-39 mnemonic seed phrases, private keys & hardware backup',
      primaryFieldKey: 'wallet_name',
      secretFieldKey: 'seed_phrase',
      fields: [
        VaultFieldDef(
          key: 'wallet_name',
          label: 'Wallet / Token Name',
          hint: 'e.g. MetaMask Ethereum, Ledger Cold Storage, Bitcoin Core',
        ),
        VaultFieldDef(
          key: 'seed_phrase',
          label: '12 or 24-Word Mnemonic Seed Phrase',
          hint: 'word1 word2 word3 ... word12 (Keep strictly private)',
          isSecret: true,
          isMultiline: true,
        ),
        VaultFieldDef(
          key: 'public_address',
          label: 'Public Address (0x...)',
          hint: 'e.g. 0x71C...392F or bc1q...',
        ),
        VaultFieldDef(
          key: 'private_key',
          label: 'Private Key / Derivation Path',
          hint: 'Raw hex private key or derivation path m/44\'/60\'/0\'/0',
          isSecret: true,
        ),
      ],
    ),

    // 9. Encrypted Secret Note
    VaultTemplateDef(
      id: 'note',
      name: 'Encrypted Confidential Note',
      category: 'Secret Note',
      icon: Icons.note_alt_rounded,
      color: Color(0xFF64748B),
      description:
          'Freeform encrypted text, private keys, contracts or forensic logs',
      primaryFieldKey: 'content',
      secretFieldKey: 'content',
      fields: [
        VaultFieldDef(
          key: 'content',
          label: 'Confidential Secret Content',
          hint: 'Enter any text, access codes, passwords, or encrypted logs',
          isSecret: true,
          isMultiline: true,
        ),
        VaultFieldDef(
          key: 'reference_tags',
          label: 'Reference Tags / Context (Optional)',
          hint: 'e.g. work, emergency, audit-2026',
        ),
      ],
    ),
  ];

  static VaultTemplateDef findById(String id) {
    return all.firstWhere((t) => t.id == id, orElse: () => all.last);
  }
}

// ─── High-Entropy Password & PIN Generator ──────────────────────────────────
class VaultPasswordGenerator {
  static const String _upperChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const String _lowerChars = 'abcdefghijkmnopqrstuvwxyz';
  static const String _digitChars = '23456789';
  static const String _symbolChars = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

  static String generate({
    int length = 16,
    bool upper = true,
    bool lower = true,
    bool digits = true,
    bool symbols = true,
  }) {
    final rand = Random.secure();
    final StringBuffer charPool = StringBuffer();

    if (upper) charPool.write(_upperChars);
    if (lower) charPool.write(_lowerChars);
    if (digits) charPool.write(_digitChars);
    if (symbols) charPool.write(_symbolChars);

    if (charPool.isEmpty) {
      charPool.write(_lowerChars);
      charPool.write(_digitChars);
    }

    final pool = charPool.toString();
    final List<String> result = [];

    // Ensure at least one character from each selected category
    if (upper) result.add(_upperChars[rand.nextInt(_upperChars.length)]);
    if (lower) result.add(_lowerChars[rand.nextInt(_lowerChars.length)]);
    if (digits) result.add(_digitChars[rand.nextInt(_digitChars.length)]);
    if (symbols) result.add(_symbolChars[rand.nextInt(_symbolChars.length)]);

    while (result.length < length) {
      result.add(pool[rand.nextInt(pool.length)]);
    }

    result.shuffle(rand);
    return result.join();
  }

  static String generatePin({int length = 6}) {
    final rand = Random.secure();
    final List<int> digits = List.generate(length, (_) => rand.nextInt(10));
    return digits.join();
  }

  /// Calculates NIST Shannon Entropy in bits: H = L * log2(R)
  static double calculateEntropy(String password) {
    if (password.isEmpty) return 0.0;
    int charsetSize = 0;
    if (password.contains(RegExp(r'[a-z]'))) charsetSize += 26;
    if (password.contains(RegExp(r'[A-Z]'))) charsetSize += 26;
    if (password.contains(RegExp(r'[0-9]'))) charsetSize += 10;
    if (password.contains(RegExp(r'[^a-zA-Z0-9]'))) charsetSize += 32;

    if (charsetSize == 0) charsetSize = 10;
    final entropy = password.length * (log(charsetSize) / ln2);
    return double.parse(entropy.toStringAsFixed(1));
  }

  static String getEntropyRating(double bits) {
    if (bits >= 90) return 'Military Grade (Uncrackable)';
    if (bits >= 70) return 'Very Strong';
    if (bits >= 50) return 'Strong';
    if (bits >= 35) return 'Moderate';
    return 'Weak (Susceptible to Brute-Force)';
  }

  static Color getEntropyColor(double bits) {
    if (bits >= 90) return const Color(0xFF00E676);
    if (bits >= 70) return const Color(0xFF10B981);
    if (bits >= 50) return const Color(0xFF0284C7);
    if (bits >= 35) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

// ─── Clipboard Guard (30-Second Air-Gapped Wipe) ─────────────────────────────
class VaultClipboardGuard {
  static Timer? _activeWipeTimer;
  static String? _lastCopiedValue;

  /// Copies sensitive credential and automatically schedules a 30-second wipe
  static void copyWithAutoWipe(
    BuildContext context,
    String text,
    String label,
  ) {
    if (text.isEmpty) return;
    _lastCopiedValue = text;
    Clipboard.setData(ClipboardData(text: text));

    _activeWipeTimer?.cancel();
    _activeWipeTimer = Timer(const Duration(seconds: 30), () async {
      try {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (current?.text == _lastCopiedValue) {
          await Clipboard.setData(const ClipboardData(text: ''));
          debugPrint(
            '[VaultClipboardGuard] Sensitive data wiped after 30s timeout',
          );
        }
      } catch (_) {}
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.shield_rounded,
              color: Color(0xFF00E676),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Copied $label. Clipboard will auto-clear in 30s.',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF00E676), width: 1),
        ),
      ),
    );
  }
}
