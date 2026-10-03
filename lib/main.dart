import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/models/verdict_model.dart';
import 'data/models/alert_model.dart';
import 'data/models/check_history_model.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/notification_service.dart';
import 'features/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Hive Storage
  await Hive.initFlutter();
  Hive.registerAdapter(VerdictModelAdapter());
  Hive.registerAdapter(AlertModelAdapter());
  Hive.registerAdapter(CheckHistoryModelAdapter());

  // Initialize Notification Service
  try {
    await NotificationService().init();
    debugPrint('SafeSignal: 100% On-Device Privacy Architecture Initialized.');
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
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'SafeSignal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
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
