import os

new_settings = '''import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import 'dart:ui';

// ─── Settings State ───────────────────────────────────────────────────────────
class SettingsState {
  final String language;
  final double textScale;
  final bool notificationsEnabled;

  const SettingsState({
    this.language = 'hi',
    this.textScale = 1.0,
    this.notificationsEnabled = true,
  });

  SettingsState copyWith(
      {String? language,
      double? textScale,
      bool? notificationsEnabled}) {
    return SettingsState(
      language: language ?? this.language,
      textScale: textScale ?? this.textScale,
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _load();
    return const SettingsState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      language: prefs.getString(AppConstants.prefLanguage) ?? 'hi',
      textScale: prefs.getDouble(AppConstants.prefTextScale) ?? 1.0,
      notificationsEnabled:
          prefs.getBool(AppConstants.prefNotifications) ?? true,
    );
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefLanguage, lang);
    state = state.copyWith(language: lang);
  }

  Future<void> setTextScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.prefTextScale, scale);
    state = state.copyWith(textScale: scale);
  }

  Future<void> setNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefNotifications, value);
    state = state.copyWith(notificationsEnabled: value);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

// ─── Profile Future Provider ──────────────────────────────────────────────────
final profileProvider = FutureProvider<Map<String, String?>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'name': prefs.getString('userName'),
    'image': prefs.getString('userProfileImage'),
  };
});

// ─── Settings Screen ──────────────────────────────────────────────────────────
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final profile = ref.watch(profileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0D1117), size: 22),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            'Settings',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: Color(0xFF0D1117),
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: false,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE3F2FD),
                Color(0xFFBBDEFB),
                Color(0xFF90CAF9),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              physics: const BouncingScrollPhysics(),
              children: [
                // ── Profile Card ─────────────────────────────────────────────────
                profile.when(
                  data: (data) => _PremiumCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                              image: data['image'] != null && File(data['image']!).existsSync()
                                  ? DecorationImage(
                                      image: FileImage(File(data['image']!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: data['image'] == null || !File(data['image']!).existsSync()
                                ? const Icon(Icons.person_rounded, size: 40, color: Color(0xFF2979FF))
                                : null,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name'] ?? 'Premium User',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0D1117),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C853).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_user_rounded, color: Color(0xFF00C853), size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'SafeSignal Active',
                                        style: TextStyle(
                                          color: Color(0xFF00C853),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.05),
                  loading: () => const SizedBox(),
                  error: (err, stack) => const SizedBox(),
                ),

                const SizedBox(height: 30),

                // ── General Settings ────────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    'GENERAL',
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ).animate().fadeIn(delay: 100.ms),
                
                _PremiumCard(
                  child: Column(
                    children: [
                      _SettingsTile(
                        title: 'Language',
                        subtitle: settings.language == 'hi' ? 'हिंदी (Hindi)' : 'English',
                        icon: Icons.language_rounded,
                        iconColor: const Color(0xFF2979FF),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                        onTap: () {
                          // Toggle language directly for simplicity
                          notifier.setLanguage(settings.language == 'hi' ? 'en' : 'hi');
                        },
                      ),
                      const Divider(height: 1, indent: 60, endIndent: 20),
                      _SettingsTile(
                        title: 'Notifications',
                        subtitle: 'Alerts & Security Updates',
                        icon: Icons.notifications_active_rounded,
                        iconColor: const Color(0xFFFF9100),
                        trailing: Switch.adaptive(
                          value: settings.notificationsEnabled,
                          activeColor: const Color(0xFF2979FF),
                          onChanged: (val) => notifier.setNotifications(val),
                        ),
                        onTap: () => notifier.setNotifications(!settings.notificationsEnabled),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),

                const SizedBox(height: 30),

                // ── Permissions ───────────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    'SECURITY & PERMISSIONS',
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),
                
                _PremiumCard(
                  child: const _ProtectionPermissionsWidget(),
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05),

                const SizedBox(height: 40),
                
                // ── Logout ───────────────────────────────────────────────────────
                GestureDetector(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    if (context.mounted) {
                       context.go('/');
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          color: Color(0xFFD32F2F),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Supporting Premium Widgets ────────────────────────────────────────────────

class _PremiumCard extends StatelessWidget {
  final Widget child;

  const _PremiumCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D1117),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtectionPermissionsWidget extends StatefulWidget {
  const _ProtectionPermissionsWidget();

  @override
  State<_ProtectionPermissionsWidget> createState() =>
      _ProtectionPermissionsWidgetState();
}

class _ProtectionPermissionsWidgetState
    extends State<_ProtectionPermissionsWidget> {
  bool _smsGranted = false;
  bool _notifGranted = false;
  bool _contactsGranted = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final sms = await Permission.sms.isGranted;
    final notif = await Permission.notification.isGranted;
    final contacts = await Permission.contacts.isGranted;
    if (mounted) {
      setState(() {
        _smsGranted = sms;
        _notifGranted = notif;
        _contactsGranted = contacts;
      });
    }
  }

  Future<void> _req(Permission p) async {
    await p.request();
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PermRow(
          title: 'SMS Scan Engine',
          subtitle: 'Detects fraud in incoming messages',
          icon: Icons.message_rounded,
          granted: _smsGranted,
          onTap: () => _req(Permission.sms),
        ),
        const Divider(height: 1, indent: 60, endIndent: 20),
        _PermRow(
          title: 'Real-time Alerts',
          subtitle: 'Instant threat notifications',
          icon: Icons.notifications_active_rounded,
          granted: _notifGranted,
          onTap: () => _req(Permission.notification),
        ),
        const Divider(height: 1, indent: 60, endIndent: 20),
        _PermRow(
          title: 'Call Shield',
          subtitle: 'Identifies spoofed or spam calls',
          icon: Icons.phone_in_talk_rounded,
          granted: _contactsGranted,
          onTap: () => _req(Permission.contacts),
        ),
      ],
    );
  }
}

class _PermRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool granted;
  final VoidCallback onTap;

  const _PermRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: granted ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (granted ? const Color(0xFF00C853) : const Color(0xFFD32F2F)).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: granted ? const Color(0xFF00C853) : const Color(0xFFD32F2F), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D1117),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (granted)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF00C853), size: 24)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2979FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Fix',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
'''
with open('lib/features/settings/settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_settings)
