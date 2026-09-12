import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants.dart';
import 'data/models/verdict_model.dart';
import 'data/models/alert_model.dart';
import 'data/models/check_history_model.dart';
import 'l10n/app_localizations.dart';
import 'features/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load Environment Variables - secure, not bundled in assets
  bool envLoaded = false;
  try {
    await dotenv.load(fileName: ".env");
    envLoaded = true;
  } catch (e) {
    debugPrint('INFO: .env file not found, using compile-time env or defaults. Check .env.example');
  }

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(VerdictModelAdapter());
  Hive.registerAdapter(AlertModelAdapter());
  Hive.registerAdapter(CheckHistoryModelAdapter());

  // Initialize Supabase only if env is loaded and keys are present
  if (envLoaded && AppConstants.supabaseUrl.isNotEmpty && AppConstants.supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('CRITICAL: Failed to initialize Supabase: $e');
    }
  } else {
    debugPrint('INFO: Skipping Supabase initialization due to missing env. Offline mode active.');
  }

  runApp(const ProviderScope(child: SafeSignalApp()));
}

class SafeSignalApp extends ConsumerWidget {
  const SafeSignalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'SafeSignal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(settings.language),
      builder: (context, child) {
        // Apply user text scale preference globally
        final mediaQuery = MediaQuery.of(context);
        final scale = settings.textScale.clamp(0.8, 1.5);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        );
      },
    );
  }
}
