import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';

class VaultLockScreen extends StatefulWidget {
  const VaultLockScreen({super.key});

  @override
  State<VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends State<VaultLockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    // Auto-trigger auth on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMsg = '';
    });

    try {
      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Unlock SafeSignal to access your data',
      );

      if (didAuthenticate && mounted) {
        context.go('/home');
      } else {
        setState(() {
          _errorMsg = 'Authentication failed. Please try again.';
        });
      }
    } on PlatformException catch (e) {
      setState(() {
        _errorMsg = 'Biometric error: ${e.message}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // Always dark for vault
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_person_rounded,
              size: 80,
              color: AppTheme.primary,
            ).animate().scale(delay: 200.ms).shake(delay: 500.ms),
            const SizedBox(height: 24),
            const Text(
              'App Locked',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Use your fingerprint or face to unlock',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 40),
            if (_errorMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                child: Text(
                  _errorMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _isAuthenticating ? null : _authenticate,
              icon: _isAuthenticating
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.fingerprint, color: Colors.white),
              label: Text(_isAuthenticating ? 'Unlocking...' : 'Unlock Now', style: const TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
