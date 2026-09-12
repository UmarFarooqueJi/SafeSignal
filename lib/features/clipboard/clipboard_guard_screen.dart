import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';


class ClipboardGuardScreen extends StatefulWidget {
  const ClipboardGuardScreen({super.key});

  @override
  State<ClipboardGuardScreen> createState() => _ClipboardGuardScreenState();
}

class _ClipboardGuardScreenState extends State<ClipboardGuardScreen> {
  bool _isScanning = false;
  String _clipboardData = '';
  String _threatLevel = 'SAFE'; // SAFE, WARNING, DANGER
  String _analysis = 'Clipboard is empty or contains no sensitive data.';
  Timer? _pollingTimer;
  bool _autoWipeEnabled = false;

  @override
  void initState() {
    super.initState();
    _scanClipboard();
    // Poll clipboard every 5 seconds if we were making a real background service, 
    // but Android 10+ restricts background clipboard access anyway.
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _scanClipboard();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _scanClipboard() async {
    if (!mounted) return;
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text ?? '';
      
      if (text == _clipboardData && text.isNotEmpty) return; // No change
      
      setState(() {
        _isScanning = true;
      });

      await Future.delayed(const Duration(milliseconds: 600)); // Simulate AI scan
      
      if (mounted) {
        setState(() {
          _clipboardData = text;
          _isScanning = false;
          _analyzeText(text);
        });
      }
    } catch (e) {
      debugPrint('Clipboard scan error: $e');
    }
  }

  void _analyzeText(String text) {
    if (text.isEmpty) {
      _threatLevel = 'SAFE';
      _analysis = 'Clipboard is empty. You are safe.';
      return;
    }

    final otpRegex = RegExp(r'\b\d{4,8}\b');
    final passwordRegex = RegExp(r'(password|pin|passcode|secret)[\s=:]*([^\s]+)', caseSensitive: false);
    final upiRegex = RegExp(r'[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}');
    final cryptoRegex = RegExp(r'^(bc1|[13])[a-zA-HJ-NP-Z0-9]{25,39}$'); // Basic BTC

    bool hasOtp = otpRegex.hasMatch(text) && text.length < 20;
    bool hasPwd = passwordRegex.hasMatch(text);
    bool hasUpi = upiRegex.hasMatch(text);
    bool hasCrypto = cryptoRegex.hasMatch(text);

    if (hasOtp) {
      _threatLevel = 'DANGER';
      _analysis = 'OTP DETECTED! Malicious background apps can read your clipboard and steal this OTP. Auto-wipe recommended.';
    } else if (hasPwd || hasCrypto) {
      _threatLevel = 'DANGER';
      _analysis = 'SENSITIVE SECRET DETECTED (Password/Crypto Key)! Apps can easily steal this from your clipboard.';
    } else if (hasUpi) {
      _threatLevel = 'WARNING';
      _analysis = 'UPI ID detected. Be careful which app you paste this into.';
    } else {
      _threatLevel = 'SAFE';
      _analysis = 'Normal text detected. No sensitive financial footprints found.';
    }

    if (_autoWipeEnabled && _threatLevel == 'DANGER') {
      _wipeClipboard();
      _analysis += '\n\nAUTO-WIPED to protect you!';
    }
  }

  Future<void> _wipeClipboard() async {
    await Clipboard.setData(const ClipboardData(text: ''));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Clipboard wiped successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      _scanClipboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF06090F) : const Color(0xFFEBF3FA);
    
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Clipboard Guard', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Clipboard Monitoring',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Background apps can silently read your copied OTPs and passwords. SafeSignal monitors your clipboard to protect sensitive data.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              
              // Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _isScanning 
                      ? Colors.blue.withValues(alpha: 0.1) 
                      : (_threatLevel == 'SAFE' 
                          ? Colors.green.withValues(alpha: 0.1) 
                          : (_threatLevel == 'WARNING' ? Colors.orange.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1))),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isScanning 
                      ? Colors.blue 
                      : (_threatLevel == 'SAFE' 
                          ? Colors.green 
                          : (_threatLevel == 'WARNING' ? Colors.orange : Colors.red)),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isScanning 
                          ? Icons.sync 
                          : (_threatLevel == 'SAFE' 
                              ? Icons.shield 
                              : Icons.warning_amber_rounded),
                      size: 64,
                      color: _isScanning 
                      ? Colors.blue 
                      : (_threatLevel == 'SAFE' 
                          ? Colors.green 
                          : (_threatLevel == 'WARNING' ? Colors.orange : Colors.red)),
                    ).animate(onPlay: (c) => _isScanning ? c.repeat() : c.stop()).rotate(duration: 1.seconds),
                    const SizedBox(height: 16),
                    Text(
                      _isScanning ? 'SCANNING CLIPBOARD...' : 'STATUS: $_threatLevel',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isScanning 
                        ? Colors.blue 
                        : (_threatLevel == 'SAFE' 
                            ? Colors.green 
                            : (_threatLevel == 'WARNING' ? Colors.orange : Colors.red)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _analysis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 32),
              
              // Data Preview (Masked if danger)
              if (_clipboardData.isNotEmpty) ...[
                Text(
                  'Current Clipboard Data:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _threatLevel == 'DANGER' ? '•••••••• [SENSITIVE DATA HIDDEN]' : _clipboardData,
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontStyle: FontStyle.italic),
                  ),
                ),
              ],

              const Spacer(),

              // Auto-Wipe Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Auto-Wipe Sensitive Data', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        Text('Automatically clear clipboard if OTPs are found', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoWipeEnabled,
                    onChanged: (v) {
                      setState(() {
                        _autoWipeEnabled = v;
                        if (v) _analyzeText(_clipboardData); // re-trigger to wipe if danger
                      });
                    },
                    activeColor: AppTheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Manual Wipe Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _clipboardData.isNotEmpty ? _wipeClipboard : null,
                  icon: const Icon(Icons.delete_sweep, color: Colors.white),
                  label: const Text('WIPE CLIPBOARD NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
