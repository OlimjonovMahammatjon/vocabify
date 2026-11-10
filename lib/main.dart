import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_theme.dart';
import 'core/services/supabase_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/offline_queue_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/widget_service.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/decks_provider.dart';
import 'providers/cards_provider.dart';
import 'providers/study_provider.dart';
import 'providers/quiz_provider.dart';
import 'providers/stats_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge system navigation style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Start the essential bootstrap, but do not hold the first frame for
  // platform storage or Supabase session restoration.
  final coreInitialization = _initializeCoreServicesAfterFirstFrame();

  runApp(buildVocabifyApp(coreInitialization: coreInitialization));

  // Notifications and outbox hydration are not required for the first frame.
  // TTS initializes lazily when the user first asks to hear a word.
  unawaited(_initializeBackgroundServices(coreInitialization));
}

Widget buildVocabifyApp({required Future<void> coreInitialization}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(
        create: (_) => AuthProvider(coreInitialization: coreInitialization),
      ),
      ChangeNotifierProvider(create: (_) => DecksProvider()),
      ChangeNotifierProvider(create: (_) => CardsProvider()),
      ChangeNotifierProvider(create: (_) => StudyProvider()),
      ChangeNotifierProvider(create: (_) => QuizProvider()),
      ChangeNotifierProvider(create: (_) => StatsProvider()),
    ],
    child: const VocabifyApp(),
  );
}

Future<void> _initializeCoreServices() async {
  try {
    await SupabaseService.initialize();
    CacheService.instance.activateUser(SupabaseService.currentUser?.id);
  } catch (error) {
    debugPrint('Core service initialization error: $error');
    rethrow;
  }
}

Future<void> _initializeCoreServicesAfterFirstFrame() async {
  await WidgetsBinding.instance.endOfFrame;
  await _initializeCoreServices();
}

Future<void> _initializeBackgroundServices(
  Future<void> coreInitialization,
) async {
  try {
    await coreInitialization;
    // Let auth restoration, cache hydration and the splash transition finish
    // before starting platform-channel work. TTS already initializes lazily
    // on first use and does not need startup work.
    await Future<void>.delayed(const Duration(seconds: 2));
    await Future.wait([
      OfflineQueueService.instance.initialize(),
      NotificationService.instance.initialize(),
      WidgetService.init(),
    ]);
  } catch (error) {
    debugPrint('Background service initialization error: $error');
  }
}

class VocabifyApp extends StatelessWidget {
  const VocabifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Vocabify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: theme.themeMode,
      home: const SplashScreen(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/hero-study.png',
                height: 100,
                cacheWidth: 320,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.menu_book_rounded,
                  size: 64,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (auth.isAuthenticated) {
      return const MainNavigationScreen();
    }

    return const AuthScreen();
  }
}
