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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load Environment Variables
  bool envLoaded = false;
  try {
    await dotenv.load(fileName: ".env");
    envLoaded = true;
  } catch (e) {
    debugPrint('CRITICAL: .env file not found or failed to load. Check .env.example.');
  }

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(VerdictModelAdapter());
  Hive.registerAdapter(AlertModelAdapter());
  Hive.registerAdapter(CheckHistoryModelAdapter());

  // Initialize Supabase only if valid configuration is present
  final sUrl = AppConstants.supabaseUrl;
  final sKey = AppConstants.supabaseAnonKey;
  final isValidSupabaseConfig = sUrl.isNotEmpty &&
      sKey.isNotEmpty &&
      !sUrl.contains('your-project-id') &&
      !sKey.contains('your-supabase-anon-key');

  if (isValidSupabaseConfig) {
    try {
      await Supabase.initialize(
        url: sUrl,
        anonKey: sKey,
      );
      debugPrint('SafeSignal: Supabase successfully initialized.');
    } catch (e) {
      debugPrint('CRITICAL: Failed to initialize Supabase: $e');
    }
  } else {
    debugPrint('SafeSignal: Operating in Offline Secure Vault mode.');
  }

  // Initialize Notification Service
  try {
    await NotificationService().init();
    debugPrint('SafeSignal: Notification channels initialized.');
  } catch (e) {
    debugPrint('SafeSignal: Notification initialization error: $e');
  }

  runApp(const ProviderScope(child: SafeSignalApp()));
}


class SafeSignalApp extends ConsumerWidget {
  const SafeSignalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'SafeSignal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
      ],
    );
  }
}
