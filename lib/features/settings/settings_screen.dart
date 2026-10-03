import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/constants.dart';

// ─── Settings State ───────────────────────────────────────────────────────────
class SettingsState {
  final String language;
  final double textScale;
  final bool notificationsEnabled;
  final ThemeMode themeMode;

  const SettingsState({
    this.language = 'hi',
    this.textScale = 1.0,
    this.notificationsEnabled = true,
    this.themeMode = ThemeMode.light,
  });

  SettingsState copyWith({
    String? language,
    double? textScale,
    bool? notificationsEnabled,
    ThemeMode? themeMode,
  }) {
    return SettingsState(
      language: language ?? this.language,
      textScale: textScale ?? this.textScale,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
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
    final themeStr = prefs.getString('pref_theme_mode') ?? 'light';
    ThemeMode mode;
    if (themeStr == 'dark') {
      mode = ThemeMode.dark;
    } else if (themeStr == 'system') {
      mode = ThemeMode.system;
    } else {
      mode = ThemeMode.light;
    }

    state = state.copyWith(
      language: prefs.getString(AppConstants.prefLanguage) ?? 'hi',
      textScale: prefs.getDouble(AppConstants.prefTextScale) ?? 1.0,
      notificationsEnabled:
          prefs.getBool(AppConstants.prefNotifications) ?? true,
      themeMode: mode,
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

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String val = 'light';
    if (mode == ThemeMode.dark) val = 'dark';
    if (mode == ThemeMode.system) val = 'system';
    await prefs.setString('pref_theme_mode', val);
    state = state.copyWith(themeMode: mode);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

// ─── Profile Future Provider ──────────────────────────────────────────────────
final profileProvider = FutureProvider<Map<String, String?>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'name': prefs.getString('userName'),
    'image': prefs.getString('userProfileImage'),
  };
});

// ─── Classic Settings Screen ──────────────────────────────────────────────────
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final profile = ref.watch(profileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF06090F) : const Color(0xFFF1F5F9);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final sectionTitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: textMain,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Settings',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: textMain,
              letterSpacing: -0.3,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          children: [
            // ── Classic Profile Header ─────────────────────────────────────────
            profile.when(
              data: (data) =>
                  _buildClassicProfileCard(context, ref, data, isDark),
              loading: () => const SizedBox(height: 70),
              error: (_, _) => const SizedBox(),
            ),

            const SizedBox(height: 24),

            // ── Section 1: General Preferences ─────────────────────────────────
            _buildSectionHeader('PREFERENCES', sectionTitleColor),
            const SizedBox(height: 8),
            _ClassicSettingsGroup(
              children: [
                _ClassicSettingsTile(
                  icon: Icons.dark_mode_rounded,
                  iconBg: const Color(0xFF8B5CF6),
                  title: 'Dark Mode',
                  subtitle: settings.themeMode == ThemeMode.dark
                      ? 'Deep Cyber Dark'
                      : 'Crisp Light Mode',
                  trailing: Switch.adaptive(
                    value: settings.themeMode == ThemeMode.dark,
                    activeTrackColor: const Color(0xFF8B5CF6),
                    onChanged: (val) {
                      notifier.setThemeMode(
                        val ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                  onTap: () {
                    notifier.setThemeMode(
                      settings.themeMode == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark,
                    );
                  },
                ),
                _buildDivider(isDark),
                _ClassicSettingsTile(
                  icon: Icons.notifications_active_rounded,
                  iconBg: const Color(0xFFF59E0B),
                  title: 'Security Alerts',
                  subtitle: 'Real-time push threat telemetry',
                  trailing: Switch.adaptive(
                    value: settings.notificationsEnabled,
                    activeTrackColor: const Color(0xFF3B82F6),
                    onChanged: (val) => notifier.setNotifications(val),
                  ),
                  onTap: () =>
                      notifier.setNotifications(!settings.notificationsEnabled),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Section 2: Security & Protection Engines ───────────────────────
            _buildSectionHeader(
              'SECURITY SHIELDS & ENGINES',
              sectionTitleColor,
            ),
            const SizedBox(height: 8),
            _ClassicSettingsGroup(
              children: const [_ProtectionPermissionsWidget()],
            ),

            const SizedBox(height: 24),

            // ── Section 3: System & About ──────────────────────────────────────
            _buildSectionHeader('SYSTEM & ABOUT', sectionTitleColor),
            const SizedBox(height: 8),
            _ClassicSettingsGroup(
              children: [
                _ClassicSettingsTile(
                  icon: Icons.security_rounded,
                  iconBg: const Color(0xFF10B981),
                  title: 'Threat Intel Core',
                  subtitle: 'SafeSignal Hybrid AI Engine v1.4',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  onTap: () {},
                ),
                _buildDivider(isDark),
                _ClassicSettingsTile(
                  icon: Icons.info_outline_rounded,
                  iconBg: const Color(0xFF64748B),
                  title: 'App Version',
                  subtitle: '1.4.2 (Production Android Build)',
                  trailing: Text(
                    'Build 142',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sectionTitleColor,
                    ),
                  ),
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── About SafeSignal (Attribution-Locked) ─────────────────────────
            _buildSectionHeader('ABOUT', sectionTitleColor),
            const SizedBox(height: 10),
            _ClassicSettingsGroup(
              children: [_AboutSafeSignalPanel(isDark: isDark)],
            ),

            const SizedBox(height: 32),

            // ── Classic Danger Button: Logout ─────────────────────────────────
            _buildClassicLogoutButton(context, isDark),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.6,
      indent: 56,
      endIndent: 0,
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildClassicProfileCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, String?> data,
    bool isDark,
  ) {
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (picked != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('userProfileImage', picked.path);
                  ref.invalidate(profileProvider);
                }
              } catch (e) {
                debugPrint('Avatar picker error: ');
              }
            },
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                  backgroundImage:
                      data['image'] != null && File(data['image']!).existsSync()
                      ? FileImage(File(data['image']!))
                      : null,
                  child:
                      data['image'] == null ||
                          !File(data['image']!).existsSync()
                      ? Icon(
                          Icons.person_rounded,
                          size: 32,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF2563EB),
                        )
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Umar Farooque',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'SafeSignal Guard Active',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassicLogoutButton(BuildContext context, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          try {
            final client = SupabaseService.client;
            if (client != null) {
              await client.auth.signOut();
            }
          } catch (e) {
            debugPrint('Signout error: ');
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          if (context.mounted) {
            context.go('/splash');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1012) : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                  : const Color(0xFFFCA5A5),
              width: 1,
            ),
          ),
          child: const Center(
            child: Text(
              'Sign Out / Reset Session',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Classic Inset Settings Card ──────────────────────────────────────────────
class _ClassicSettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _ClassicSettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

// ─── Classic Settings Tile ────────────────────────────────────────────────────
class _ClassicSettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const _ClassicSettingsTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconBg, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: textSub,
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

// ─── Permissions & Engines Group ──────────────────────────────────────────────
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
  bool _batteryGranted = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final sms = await Permission.sms.isGranted;
    final notif = await Permission.notification.isGranted;
    final contacts = await Permission.contacts.isGranted;
    final battery = await Permission.ignoreBatteryOptimizations.isGranted;
    if (mounted) {
      setState(() {
        _smsGranted = sms;
        _notifGranted = notif;
        _contactsGranted = contacts;
        _batteryGranted = battery;
      });
    }
  }

  Future<void> _req(Permission p) async {
    await p.request();
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _buildPermTile(
          icon: Icons.mark_chat_read_rounded,
          iconBg: const Color(0xFFF97316),
          title: 'SMS Scam Engine',
          subtitle: 'Scans fraud & smishing in messages',
          granted: _smsGranted,
          onTap: () => _req(Permission.sms),
          isDark: isDark,
        ),
        _buildDivider(isDark),
        _buildPermTile(
          icon: Icons.notifications_active_rounded,
          iconBg: const Color(0xFF3B82F6),
          title: 'Real-time Threat Alerts',
          subtitle: 'Instant push warning on active threats',
          granted: _notifGranted,
          onTap: () => _req(Permission.notification),
          isDark: isDark,
        ),
        _buildDivider(isDark),
        _buildPermTile(
          icon: Icons.phone_in_talk_rounded,
          iconBg: const Color(0xFF06B6D4),
          title: 'Call Shield Filter',
          subtitle: 'Detects scam callers & caller ID spoof',
          granted: _contactsGranted,
          onTap: () => _req(Permission.contacts),
          isDark: isDark,
        ),
        _buildDivider(isDark),
        _buildPermTile(
          icon: Icons.bolt_rounded,
          iconBg: const Color(0xFF10B981),
          title: 'Background Guard Run',
          subtitle: 'Keeps on-device shields persistent',
          granted: _batteryGranted,
          onTap: () => _req(Permission.ignoreBatteryOptimizations),
          isDark: isDark,
        ),
        _buildDivider(isDark),
        _buildTestAlertTile(context, isDark),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.6,
      indent: 56,
      endIndent: 0,
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildPermTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool granted,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: granted ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (granted ? const Color(0xFF10B981) : iconBg)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  color: granted ? const Color(0xFF10B981) : iconBg,
                  size: 19,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: textSub,
                      ),
                    ),
                  ],
                ),
              ),
              if (granted)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Grant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestAlertTile(BuildContext context, bool isDark) {
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await NotificationService().sendTestAlert();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  '🔔 Test Security Alert dispatched to notification bar.',
                ),
                backgroundColor: const Color(0xFF0F172A),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dispatch Test Shield Alert',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Test high-priority telemetry notification pipeline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: textSub,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.send_rounded,
                size: 18,
                color: Color(0xFF8B5CF6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── About SafeSignal Attribution-Locked Panel ────────────────────────────────
// Content sourced from lib/core/foundation/attribution.dart constants.
// Any modification to developer name or copyright requires updating attribution.dart
// which constitutes a license violation under SafeSignal Source-Available License v1.0.
// See NOTICE and LICENSE files at project root.
class _AboutSafeSignalPanel extends StatelessWidget {
  final bool isDark;

  const _AboutSafeSignalPanel({required this.isDark});

  // ── Attribution constants (referenced from SafeSignalAttribution) ──────────
  static const String _developer = 'Umar Farooque';
  static const String _email = 'umarfarooque@safesignal.app';
  static const String _org = 'SafeSignal Technologies';
  static const String _version = '1.2.1';
  static const int _build = 7;
  static const String _tagline =
      "India's First AI-Powered Mobile Threat Defence";
  static const String _github = 'github.com/UmarFarooqueJi/SafeSignal';

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? const Color(0xFF1E3A5F)
        : const Color(0xFFBFDBFE);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final accent = const Color(0xFF2563EB);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo + App name ─────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SafeSignal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: textMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'v$_version (Build $_build)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSub,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'PROD',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10B981),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            _tagline,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textSub,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 16),

          // ── Developer attribution block (ATTRIBUTION LOCK) ────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.10 : 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accent.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_pin_rounded, color: accent, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'DEVELOPED BY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _developer,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: textMain,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _email,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _org,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSub,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Source + License row ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _InfoChip(
                  icon: Icons.code_rounded,
                  label: 'SOURCE',
                  value: _github,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoChip(
                  icon: Icons.gavel_rounded,
                  label: 'LICENSE',
                  value: 'SAL v1.0',
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Built-from-scratch claim ──────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.construction_rounded,
                size: 13,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Built entirely from scratch — no cloned repo, no starter kit.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            'Copyright © 2026 $_org. All rights reserved.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: textSub,
            ),
          ),

          // Attribution integrity seal — machine-readable, required by license
          Opacity(
            opacity: 0,
            child: Text(
              'ss::umarfarooque::2026::$_developer::$_email::$_org',
              style: const TextStyle(fontSize: 1),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Generic Info Chip ─────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: textSub),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: textSub,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textMain,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
