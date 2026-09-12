import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';

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

// ─── Settings Screen ──────────────────────────────────────────────────────────
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF060A12) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0D1117);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: textColor,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: textColor, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Language ────────────────────────────────────────────────────
          _Section(
            title: 'Bhasha / Language',
            icon: Icons.translate_rounded,
            iconColor: const Color(0xFF2979FF),
            isDark: isDark,
            child: Row(
              children: [
                Expanded(
                  child: _LangOption(
                    label: 'हिंदी',
                    sublabel: 'Hindi',
                    selected: settings.language == 'hi',
                    onTap: () => notifier.setLanguage('hi'),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LangOption(
                    label: 'English',
                    sublabel: 'English',
                    selected: settings.language == 'en',
                    onTap: () => notifier.setLanguage('en'),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.04),

          const SizedBox(height: 14),

          // ── Permissions ─────────────────────────────────────────────────
          _Section(
            title: 'Background Protection',
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF4CAF50),
            isDark: isDark,
            child: const _ProtectionPermissionsWidget(),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.04),

          const SizedBox(height: 14),

          // ── Text Size ────────────────────────────────────────────────────
          _Section(
            title: 'Text Size / Akshar Aakaar',
            icon: Icons.text_fields_rounded,
            iconColor: const Color(0xFF7C4DFF),
            isDark: isDark,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TextSizeBtn(
                        label: 'Normal',
                        scale: 1.0,
                        current: settings.textScale,
                        onTap: () => notifier.setTextScale(1.0),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TextSizeBtn(
                        label: 'Bada',
                        scale: 1.2,
                        current: settings.textScale,
                        onTap: () => notifier.setTextScale(1.2),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TextSizeBtn(
                        label: 'Bahut\nBada',
                        scale: 1.5,
                        current: settings.textScale,
                        onTap: () => notifier.setTextScale(1.5),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF7C4DFF)
                            .withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    'Preview: Yeh ek nमूना text hai.',
                    style: TextStyle(
                      fontSize: 15 * settings.textScale,
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.04),

          const SizedBox(height: 14),

          // ── Notifications ────────────────────────────────────────────────
          _Section(
            title: 'Notifications / Suchnayen',
            icon: Icons.notifications_outlined,
            iconColor: const Color(0xFFFFB300),
            isDark: isDark,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Scam Alerts',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Roz naye scam ke baare mein jaankari',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.notificationsEnabled,
                  onChanged: notifier.setNotifications,
                  activeThumbColor: const Color(0xFF2979FF),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.04),

          const SizedBox(height: 14),

          // ── About ────────────────────────────────────────────────────────
          _Section(
            title: 'App ke Baare Mein',
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF00ACC1),
            isDark: isDark,
            child: Column(
              children: [
                _AboutRow(icon: Icons.shield_rounded, label: 'SafeSignal v2.0', isDark: isDark),
                _AboutRow(icon: Icons.support_agent_rounded, label: 'Cybercrime Helpline: 1930', isDark: isDark),
                _AboutRow(icon: Icons.lock_outline_rounded, label: 'Aapka data sirf aapke phone mein', isDark: isDark),
                _AboutRow(icon: Icons.money_off_rounded, label: 'Bilkul muft — koi fees nahi', isDark: isDark),
                _AboutRow(icon: Icons.smart_toy_rounded, label: 'AI-Powered Scam Detection', isDark: isDark),
              ],
            ),
          ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.04),

          const SizedBox(height: 24),

          // ── Disclaimer ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6F00).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFF6F00).withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_rounded, color: Color(0xFFFF6F00), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'SafeSignal ek AI assistant hai. Real fraud ke liye turant 1930 pe call karein ya cybercrime.gov.in pe report karein.',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFFFB74D)
                          : const Color(0xFFE65100),
                      fontSize: 12,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 260.ms),

          const SizedBox(height: 32),

          // ── Logout Button ────────────────────────────────────────────────
          GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', false);
              if (context.mounted) {
                context.go('/signin');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B27) : const Color(0xFFF5F7FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2A3347) : const Color(0xFFE0E6F5),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Logout',
                    style: TextStyle(
                      color: Color(0xFFE53935),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 300.ms),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final bool isDark;

  const _Section({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1724) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3347) : const Color(0xFFE8EEF8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF0D1117),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Language Option ──────────────────────────────────────────────────────────
class _LangOption extends StatelessWidget {
  final String label, sublabel;
  final bool selected, isDark;
  final VoidCallback onTap;

  const _LangOption({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2979FF).withValues(alpha: 0.1)
              : (isDark ? const Color(0xFF161B27) : const Color(0xFFF5F7FF)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF2979FF)
                : (isDark ? const Color(0xFF2A3347) : const Color(0xFFE0E6F5)),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: selected
                    ? const Color(0xFF2979FF)
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? const Color(0xFF2979FF).withValues(alpha: 0.7)
                    : (isDark ? Colors.white38 : Colors.black38),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Text Size Button ─────────────────────────────────────────────────────────
class _TextSizeBtn extends StatelessWidget {
  final String label;
  final double scale, current;
  final VoidCallback onTap;
  final bool isDark;

  const _TextSizeBtn({
    required this.label,
    required this.scale,
    required this.current,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final selected = (scale - current).abs() < 0.01;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7C4DFF).withValues(alpha: 0.1)
              : (isDark ? const Color(0xFF161B27) : const Color(0xFFF5F7FF)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF7C4DFF)
                : (isDark ? const Color(0xFF2A3347) : const Color(0xFFE0E6F5)),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'A',
              style: TextStyle(
                fontSize: 14 * scale,
                fontWeight: FontWeight.w900,
                color: selected
                    ? const Color(0xFF7C4DFF)
                    : (isDark ? Colors.white54 : Colors.black45),
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: selected
                    ? const Color(0xFF7C4DFF)
                    : (isDark ? Colors.white38 : Colors.black38),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── About Row ────────────────────────────────────────────────────────────────
class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _AboutRow(
      {required this.icon, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2979FF)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Permissions Widget ───────────────────────────────────────────────────────
class _ProtectionPermissionsWidget extends StatefulWidget {
  const _ProtectionPermissionsWidget();

  @override
  State<_ProtectionPermissionsWidget> createState() =>
      _ProtectionPermissionsWidgetState();
}

class _ProtectionPermissionsWidgetState
    extends State<_ProtectionPermissionsWidget>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.safesignal/app_scanner');

  bool _smsGranted = false;
  bool _phoneGranted = false;
  bool _overlayGranted = false;
  bool _notificationGranted = false;

  final _perms = [
    (
      'SMS Shield',
      'Scam SMS detect karta hai',
      Icons.sms_outlined,
      const Color(0xFF4CAF50),
    ),
    (
      'Call Shield',
      'Scam caller ID detect karta hai',
      Icons.call_outlined,
      const Color(0xFF2979FF),
    ),
    (
      'Call Overlay',
      'Call pe warning popup dikhata hai',
      Icons.layers_outlined,
      const Color(0xFF7C4DFF),
    ),
    (
      'Email/Notification Shield',
      'Email notifications scan karta hai',
      Icons.email_outlined,
      const Color(0xFFFF6F00),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final sms = await Permission.sms.isGranted;
    final phone = await Permission.phone.isGranted;
    bool overlay = false, notification = false;
    if (Platform.isAndroid) {
      try {
        overlay = await _channel
                .invokeMethod<bool>('requestOverlayPermission') ??
            false;
        notification = await _channel
                .invokeMethod<bool>('isNotificationListenerEnabled') ??
            false;
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _smsGranted = sms;
        _phoneGranted = phone;
        _overlayGranted = overlay;
        _notificationGranted = notification;
      });
    }
  }

  bool _isGranted(int i) {
    switch (i) {
      case 0:
        return _smsGranted;
      case 1:
        return _phoneGranted;
      case 2:
        return _overlayGranted;
      default:
        return _notificationGranted;
    }
  }

  Future<void> _request(int i) async {
    switch (i) {
      case 0:
        final s = await Permission.sms.request();
        if (s.isPermanentlyDenied) openAppSettings();
        break;
      case 1:
        final s = await Permission.phone.request();
        if (s.isPermanentlyDenied) openAppSettings();
        break;
      case 2:
        if (Platform.isAndroid) {
          await _channel.invokeMethod('requestOverlayPermission');
        }
        break;
      default:
        if (Platform.isAndroid) {
          await _channel.invokeMethod('openNotificationSettings');
        }
    }
    await _checkPermissions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _isGranted(i) ? Icons.check_circle : Icons.info_outline,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _isGranted(i)
                    ? '${_perms[i].$1} activated! ✅'
                    : 'Permission required — please allow in settings',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          backgroundColor: _isGranted(i)
              ? const Color(0xFF2E7D32)
              : const Color(0xFFE65100),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Overall protection score
    final granted = [
      _smsGranted, _phoneGranted, _overlayGranted, _notificationGranted
    ].where((g) => g).length;
    final pct = (granted / 4 * 100).round();
    final protColor = granted == 4
        ? const Color(0xFF4CAF50)
        : granted >= 2
            ? const Color(0xFFFFB300)
            : const Color(0xFFEF5350);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score bar
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: granted / 4,
                  backgroundColor: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(protColor),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$pct% Protected',
              style: TextStyle(
                color: protColor,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Permission rows
        ...List.generate(_perms.length, (i) {
          final p = _perms[i];
          final granted = _isGranted(i);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: granted
                  ? p.$4.withValues(alpha: 0.06)
                  : (isDark
                      ? const Color(0xFF161B27)
                      : const Color(0xFFF5F7FF)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: granted
                    ? p.$4.withValues(alpha: 0.3)
                    : (isDark
                        ? const Color(0xFF2A3347)
                        : const Color(0xFFE0E6F5)),
              ),
            ),
            child: Row(
              children: [
                Icon(p.$3, color: granted ? p.$4 : Colors.grey, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.$1,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF0D1117),
                        ),
                      ),
                      Text(
                        p.$2,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                granted
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: p.$4.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '✓ Active',
                          style: TextStyle(
                            color: p.$4,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: () => _request(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2979FF), Color(0xFF7C4DFF)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Enable',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
