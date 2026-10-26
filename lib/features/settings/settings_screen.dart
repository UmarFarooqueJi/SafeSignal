import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/notification_service.dart';
import '../../core/constants.dart';
import '../../core/foundation/attribution.dart';
import '../../core/services/link_guard_service.dart';

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

// ─── Classic Settings Screen ──────────────────────────────────────────────────
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
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
            // ── Air-Gapped Security Node Status ────────────────────────────────
            _buildPrivacyNodeCard(context, isDark),

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
                _buildDivider(isDark),
                _ClassicSettingsTile(
                  icon: Icons.link_rounded,
                  iconBg: const Color(0xFF00E676),
                  title: 'WhatsApp Link Shield',
                  subtitle: 'Auto-scan links clicked in WhatsApp & Telegram',
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () async {
                    await LinkGuardService.requestBrowserRole();
                  },
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

            // ── Section 3: System & Diagnostics ─────────────────────────────────
            _buildSectionHeader('SYSTEM & DIAGNOSTICS', sectionTitleColor),
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
                  subtitle: 'v${SafeSignalAttribution.kVersion} (Build ${SafeSignalAttribution.kBuildNumber})',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'RELEASE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : Colors.black54,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  onTap: () {},
                ),
                _buildDivider(isDark),
                _ClassicSettingsTile(
                  icon: Icons.sync_rounded,
                  iconBg: const Color(0xFF3B82F6),
                  title: 'Flush Threat Cache & Resync',
                  subtitle: 'Reset local signature cache and refresh feeds',
                  trailing: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF3B82F6)),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('cached_threat_feed');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Threat feed cache refreshed. Ready for live sync.'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Section 4: About & Open Repository ──────────────────────────────
            _buildSectionHeader('ABOUT & OPEN SOURCE', sectionTitleColor),
            const SizedBox(height: 8),
            _ClassicSettingsGroup(
              children: [
                _buildAboutHeaderTile(isDark),
                _buildDivider(isDark),
                _ClassicSettingsTile(
                  icon: Icons.language_rounded,
                  iconBg: const Color(0xFF0284C7),
                  title: 'Official Website',
                  subtitle: 'safesignal-dx8.pages.dev',
                  trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.grey),
                  onTap: () async {
                    final uri = Uri.parse('https://safesignal-dx8.pages.dev');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                _buildDivider(isDark),
                _ClassicSettingsTile(
                  icon: Icons.code_rounded,
                  iconBg: const Color(0xFF8B5CF6),
                  title: 'Source Code (GitHub)',
                  subtitle: 'github.com/UmarFarooqueJi/SafeSignal',
                  trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.grey),
                  onTap: () async {
                    final uri = Uri.parse(SafeSignalAttribution.kRepositoryUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                _buildDivider(isDark),
                _ClassicSettingsTile(
                  icon: Icons.gavel_rounded,
                  iconBg: const Color(0xFF10B981),
                  title: 'License & Security Model',
                  subtitle: 'Source-Available v1.0 • 100% Air-Gapped',
                  trailing: const Icon(Icons.verified_user_rounded, size: 18, color: Color(0xFF10B981)),
                  onTap: () {},
                ),
                _buildDivider(isDark),
                _ClassicSettingsTile(
                  icon: Icons.verified_rounded,
                  iconBg: const Color(0xFF2563EB),
                  title: 'Architect & Research',
                  subtitle: '${SafeSignalAttribution.kDeveloper} • ${SafeSignalAttribution.kOrganization}',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'VERIFIED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Attribution & Integrity Seal Footer ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      SafeSignalAttribution.copyrightLine,
                      style: TextStyle(
                        fontSize: 11,
                        color: sectionTitleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '100% On-Device Air-Gapped • Zero Cloud Egress • Zero PII Required',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: sectionTitleColor.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    // Attribution integrity seal — machine-readable, required by license
                    Opacity(
                      opacity: 0,
                      child: Text(
                        'ss::umarfarooque::2026::${SafeSignalAttribution.kDeveloper}::${SafeSignalAttribution.kOrganization}',
                        style: const TextStyle(fontSize: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
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

  Widget _buildAboutHeaderTile(bool isDark) {
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SafeSignal Mobile Defense',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Built entirely from scratch • Zero telemetry',
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
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
    );
  }

  Widget _buildPrivacyNodeCard(BuildContext context, bool isDark) {
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00E676).withValues(alpha: 0.25),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.security_rounded,
                    size: 24,
                    color: Color(0xFF00E676),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Air-Gapped Defense Node',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: textMain,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ANONYMOUS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00E676),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '100% On-Device • Zero PII Required',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildNodeBadge(Icons.cloud_off_rounded, '0 Cloud Egress', const Color(0xFF38BDF8), isDark),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildNodeBadge(Icons.no_accounts_rounded, 'Zero PII Tracked', const Color(0xFFA78BFA), isDark),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildNodeBadge(Icons.lock_outline_rounded, 'AES-256 Vault', const Color(0xFF00E676), isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNodeBadge(IconData icon, String text, Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 11, color: accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
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
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Grant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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
