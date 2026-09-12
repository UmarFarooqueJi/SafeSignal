import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';

import '../../core/constants.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _passVisible = false;
  bool _isLoading = false;
  bool _isEmailMode = true;
  bool _isSignUpMode = false;

  Future<void> _continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefOnboardingDone, true);
    await prefs.setBool('isLoggedIn', true);
    final isProfileSetupDone = prefs.getBool('isProfileSetupDone') ?? false;
    if (mounted) {
      if (isProfileSetupDone) {
        context.go('/home');
      } else {
        context.go('/profile-setup');
      }
    }
  }



  Future<void> _signInWithEmail() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final client = SupabaseService.client;
      if (client != null) {
        AuthResponse response;
        if (_isSignUpMode) {
          response = await client.auth.signUp(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          );
        } else {
          response = await client.auth.signInWithPassword(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          );
        }
      } else {
        debugPrint('Supabase offline or not initialized. Operating in local account mode.');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefOnboardingDone, true);
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', _emailCtrl.text.trim());
      final isProfileSetupDone = prefs.getBool('isProfileSetupDone') ?? false;
      
      if (mounted) {
        if (isProfileSetupDone) {
          context.go('/home');
        } else {
          context.go('/profile-setup');
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll('AuthException: ', '').trim();
        if (errorMsg.contains('Invalid login credentials')) {
          errorMsg = 'Email ya password galat hai. Kripya dobara check karein.';
        } else if (errorMsg.contains('User already registered')) {
          errorMsg = 'Yeh email pehle se hi registered hai. Kripya "Sign Up" ki jagah "Log In" karein.';
        } else if (errorMsg.contains('Email not confirmed')) {
          errorMsg = 'Aapka email verify nahi hua hai. Supabase me "Confirm email" OFF karke naya account banayein.';
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent),
                SizedBox(width: 10),
                Text('Error', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              errorMsg,
              style: const TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF080710) : const Color(0xFFF4F6FA),
        body: Stack(
          children: [
            // Breathing background glow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                        ? [const Color(0xFF0F0C29), const Color(0xFF1D1B48), const Color(0xFF24243E)]
                        : [const Color(0xFFF0F4FF), const Color(0xFFE5ECFF), const Color(0xFFF9FAFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Background ambient light blobs
            if (isDark) ...[
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF6C63FF).withOpacity(0.15),
                  ),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                 .scale(end: const Offset(1.2, 1.2), duration: 5.seconds, curve: Curves.easeInOut)
                 .blur(end: const Offset(50, 50)),
              ),
              Positioned(
                bottom: -80,
                left: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00F2FE).withOpacity(0.1),
                  ),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                 .scale(end: const Offset(1.3, 1.3), duration: 6.seconds, curve: Curves.easeInOut)
                 .blur(end: const Offset(40, 40)),
              ),
            ],

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo + Title
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6C63FF), Color(0xFF00F2FE)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F0C29) : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Image.asset(
                                  'assets/images/logo_transparent.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ).animate().scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack, duration: 800.ms).fadeIn(),
                            const SizedBox(height: 16),
                            RichText(
                              text: TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Safe',
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF6C63FF),
                                      letterSpacing: -1.5,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Signal',
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                      letterSpacing: -1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
                            const SizedBox(height: 6),
                            Text(
                              'India\'s AI Scam Protection',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                            ).animate().fadeIn(delay: 200.ms),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Glassmorphic Card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? Colors.white.withOpacity(0.04) 
                                  : Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: isDark 
                                    ? Colors.white.withOpacity(0.08) 
                                    : Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _isEmailMode 
                                      ? (_isSignUpMode ? 'Create Secure Account' : 'Secure Log In') 
                                      : 'Welcome Back',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                    letterSpacing: -0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ).animate().fadeIn(delay: 250.ms),
                                const SizedBox(height: 6),
                                Text(
                                  _isEmailMode
                                      ? (_isSignUpMode ? 'Sign up to protect your digital life' : 'Enter your credentials to continue')
                                      : 'Choose how you\'d like to continue',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ).animate().fadeIn(delay: 300.ms),

                                const SizedBox(height: 28),

                                if (_isEmailMode) ...[
                                  // Email Field
                                  _PremiumTextField(
                                    controller: _emailCtrl,
                                    label: 'Email Address',
                                    hint: 'Enter your email',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                  ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.05),
                                  const SizedBox(height: 16),

                                  // Password Field
                                  _PremiumTextField(
                                    controller: _passCtrl,
                                    label: 'Password',
                                    hint: 'Enter your password',
                                    icon: Icons.lock_outline_rounded,
                                    isPassword: true,
                                    isPasswordVisible: _passVisible,
                                    onTogglePassword: () =>
                                        setState(() => _passVisible = !_passVisible),
                                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),

                                  if (!_isSignUpMode)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () {},
                                        child: const Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                            color: Color(0xFF6C63FF),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 12),

                                  const SizedBox(height: 8),

                                  // Submit button
                                  _PrimaryButton(
                                    label: _isSignUpMode ? 'Create Account' : 'Log In',
                                    isLoading: _isLoading,
                                    onTap: _signInWithEmail,
                                    color: const Color(0xFF6C63FF),
                                  ).animate().fadeIn(delay: 150.ms),

                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _isSignUpMode ? 'Already have an account? ' : 'Don\'t have an account? ',
                                        style: TextStyle(
                                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(() => _isSignUpMode = !_isSignUpMode),
                                        child: const Text(
                                          'Sign Up',
                                          style: TextStyle(
                                            color: Color(0xFF6C63FF),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  // Divider
                                  Row(
                                    children: [
                                      Expanded(
                                          child: Divider(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          'or',
                                          style: TextStyle(
                                            color: isDark ? Colors.white30 : Colors.grey.shade400,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                          child: Divider(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Guest / Skip
                                  Center(
                                    child: TextButton(
                                      onPressed: _continueAsGuest,
                                      child: Text(
                                        'Continue without account →',
                                        style: TextStyle(
                                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ).animate().fadeIn(delay: 200.ms),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05),

                      const SizedBox(height: 24),

                      // Terms
                      Center(
                        child: Text(
                          'By continuing, you agree to our Terms & Privacy Policy',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey.shade50,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ).animate().fadeIn(delay: 400.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Supporting Widgets ────────────────────────────────────────────────────────

class _PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool isPassword;
  final bool isPasswordVisible;
  final VoidCallback? onTogglePassword;

  const _PremiumTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.isPasswordVisible = false,
    this.onTogglePassword,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF1A1A2E),
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword && !isPasswordVisible,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white30 : Colors.grey.shade400, 
              fontSize: 14,
            ),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
            prefixIcon: Icon(icon, color: const Color(0xFF6C63FF).withOpacity(0.7), size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                      size: 20,
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF6C63FF), 
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String icon;
  final Widget iconWidget;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.iconWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200, 
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.1 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;
  final Color color;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF8A84FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }
}
