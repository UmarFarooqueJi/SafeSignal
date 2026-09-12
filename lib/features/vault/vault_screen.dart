import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isVaultEnabled = false;
  bool _hasBiometrics = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    final canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();
    
    setState(() {
      _isVaultEnabled = prefs.getBool('isVaultEnabled') ?? false;
      _hasBiometrics = canAuthenticate;
      _isLoading = false;
    });
  }

  Future<void> _toggleVault(bool value) async {
    if (value && _hasBiometrics) {
      try {
        final didAuthenticate = await auth.authenticate(
          localizedReason: 'Verify your identity to enable SafeSignal Vault Lock',
        );
        if (didAuthenticate) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isVaultEnabled', true);
          setState(() {
            _isVaultEnabled = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('App Lock Enabled! 🔒'), backgroundColor: Colors.green),
            );
          }
        }
      } on PlatformException catch (e) {
        debugPrint(e.toString());
      }
    } else {
      // Disabling requires auth too
      try {
        final didAuthenticate = await auth.authenticate(
          localizedReason: 'Verify your identity to disable SafeSignal Vault Lock',
        );
        if (didAuthenticate) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isVaultEnabled', false);
          setState(() {
            _isVaultEnabled = false;
          });
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF06090F) : const Color(0xFFEBF3FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('App Lock & Vault', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security Vault',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Secure your SafeSignal app with fingerprint or Face ID. Nobody can access your scanned data or Cyber AI assistant without your biometrics.',
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
                  color: _isVaultEnabled 
                      ? Colors.green.withValues(alpha: 0.1) 
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isVaultEnabled ? Colors.green : Colors.orange,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isVaultEnabled ? Icons.lock : Icons.lock_open,
                      size: 64,
                      color: _isVaultEnabled ? Colors.green : Colors.orange,
                    ).animate(target: _isVaultEnabled ? 1 : 0).shake(),
                    const SizedBox(height: 16),
                    Text(
                      _isVaultEnabled ? 'VAULT LOCKED' : 'VAULT UNLOCKED',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isVaultEnabled ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 32),
              
              if (!_hasBiometrics)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No biometrics or screen lock found on this device. Please set up a PIN/Fingerprint in Android Settings first.',
                          style: TextStyle(color: isDark ? Colors.red.shade200 : Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Require Biometrics on Launch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 4),
                          Text('Protect this app with fingerprint', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isVaultEnabled,
                      onChanged: _toggleVault,
                      activeColor: AppTheme.primary,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
