import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', _nameCtrl.text.trim());
      if (_imageFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = path.basename(_imageFile!.path);
        final savedImage = await _imageFile!.copy('${appDir.path}/$fileName');
        await prefs.setString('userProfileImage', savedImage.path);
      }
      await prefs.setBool('isProfileSetupDone', true);
      
      // Update Supabase profile if logged in & connected
      final client = SupabaseService.client;
      if (client != null) {
        final currentUser = client.auth.currentUser;
        if (currentUser != null) {
          try {
            await client.from('profiles').upsert({
              'id': currentUser.id,
              'name': _nameCtrl.text.trim(),
              'updated_at': DateTime.now().toIso8601String(),
            });
          } catch (dbError) {
            debugPrint('Supabase profile upsert error: $dbError');
          }
        }
      }
      
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                        : [const Color(0xFFFFF3E0), const Color(0xFFF3E5F5), const Color(0xFFE8EAF6)],
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
                left: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF6C63FF).withOpacity(0.12),
                  ),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                 .scale(end: const Offset(1.2, 1.2), duration: 5.seconds, curve: Curves.easeInOut)
                 .blur(end: const Offset(50, 50)),
              ),
              Positioned(
                bottom: -80,
                right: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00F2FE).withOpacity(0.08),
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
                      const SizedBox(height: 20),
                      // Top Page Header
                      Text(
                        'Setup Profile',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          letterSpacing: -1.5,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
                      const SizedBox(height: 8),
                      Text(
                        'Let\'s personalize your SafeSignal experience.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                      
                      const SizedBox(height: 36),

                      // Glassmorphic Card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
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
                                // Glowing Image Picker
                                Center(
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 116,
                                          height: 116,
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
                                                color: const Color(0xFF6C63FF).withOpacity(0.25),
                                                blurRadius: 20,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF0F0C29) : Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: ClipOval(
                                              child: _imageFile != null
                                                  ? Image.file(_imageFile!, fit: BoxFit.cover)
                                                  : Padding(
                                                      padding: const EdgeInsets.all(16.0),
                                                      child: Image.asset(
                                                        'assets/images/logo_transparent.png',
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ).animate().scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack, duration: 600.ms),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF6C63FF), Color(0xFF8A84FF)],
                                              ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isDark ? const Color(0xFF0F0C29) : Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt_rounded, 
                                              color: Colors.white, 
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 36),

                                // Name Input Field
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                                      child: Text(
                                        'Full Name',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white70 : const Color(0xFF1A1A2E),
                                        ),
                                      ),
                                    ),
                                    TextField(
                                      controller: _nameCtrl,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Enter your full name',
                                        hintStyle: TextStyle(
                                          color: isDark ? Colors.white30 : Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                        filled: true,
                                        fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                                        prefixIcon: Icon(
                                          Icons.badge_rounded, 
                                          color: const Color(0xFF6C63FF).withOpacity(0.8),
                                          size: 20,
                                        ),
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
                                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),

                                const SizedBox(height: 32),

                                // Save / Continue Button
                                GestureDetector(
                                  onTap: _isLoading ? null : _saveProfile,
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
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white, 
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : const Text(
                                              'Continue',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05),
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
