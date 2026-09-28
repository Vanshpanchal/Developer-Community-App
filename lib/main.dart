import 'dart:async';
import 'dart:ui';

import 'package:developer_community_app/firebase_options.dart';
import 'package:developer_community_app/wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'ai_service.dart';
import 'messagemodel.dart';
import 'utils/app_theme.dart';
import 'services/analytics_service.dart';
import 'ThemeController.dart';
import 'utils/app_logger.dart';
import 'utils/secure_hive_helper.dart';
import 'core/update/presentation/widgets/android_update_gate.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      AppLogger.error('Uncaught Flutter error', details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.error('Uncaught platform error', error, stack);
      return true;
    };

    // Set system UI overlay style with transparent system bars for edge-to-edge compatibility
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e, st) {
      AppLogger.error('Firebase initialization failed', e, st);
      runApp(const _StartupErrorApp());
      return;
    }

    // Independent local storage initialisation runs in parallel.
    await Future.wait([
      GetStorage.init(),
      GetStorage.init('firebase_cache'),
      Hive.initFlutter(),
      dotenv.load(fileName: '.env').catchError((e) {
        AppLogger.debug('dotenv load skipped: $e');
      }),
    ]);

    Hive.registerAdapter(MessageAdapter());
    // Use encrypted storage for sensitive chat messages. If the key cannot be
    // read (e.g. after a backup restore onto a new device), start with a fresh
    // box rather than blocking app launch.
    try {
      await SecureHiveHelper.instance.openEncryptedBox<Message>('chat_messages');
    } catch (e, st) {
      AppLogger.error('Failed to open encrypted chat box, resetting it', e, st);
      try {
        await Hive.deleteBoxFromDisk('chat_messages');
        await SecureHiveHelper.instance.openEncryptedBox<Message>('chat_messages');
      } catch (e2, st2) {
        AppLogger.error('Encrypted chat box unavailable', e2, st2);
      }
    }

    Get.put(ThemeController(), permanent: true);
    runApp(const MyApp());

    // Non-critical initialisation happens after the first frame is scheduled.
    AIService().syncModelFromFirebase().catchError((_) {});
  }, (error, stack) {
    AppLogger.error('Uncaught zone error', error, stack);
  });
}

/// Shown when Firebase cannot be initialised, instead of a frozen splash.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Plain themes: ThemeController is not registered on this path.
      theme: ThemeData(
          useMaterial3: true, colorSchemeSeed: ThemeController.defaultColor),
      darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: ThemeController.defaultColor),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong while starting DevSphere.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check your connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: main,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize Analytics Service
    final analyticsService = AnalyticsService();

    // Obx rebuilds the theme as soon as the user picks a new colour.
    return Obx(() => GetMaterialApp(
      title: 'DevSphere',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      // Framework widgets (dialogs, pickers, text fields) follow the device
      // locale. App strings are still English-only; add ARB files via
      // `flutter gen-l10n` to translate them.
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en')],
      navigatorObservers: [
        analyticsService.getAnalyticsObserver(),
      ],
      builder: (context, child) {
        return AndroidUpdateGate(
          navigatorKey: Get.key,
          child: child ?? const SplashScreen(),
        );
      },
      home: const SplashScreen(),
    ));
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Skip the entrance animation when the user has reduced motion on.
      if (mounted && MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      }
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => wrapper(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            // Dark enough for the white title and tagline to pass WCAG AA.
            colors: [
              Color(0xFF1976D2),
              Color(0xFF1565C0),
              Color(0xFF0D47A1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo Container
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Lottie.asset(
                        'assets/images/discussion_animation.json',
                        height: 150,
                        width: 150,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // App Name
                    const Text(
                      'DevSphere',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Tagline
                    Text(
                      'Connect • Help • Collaborate',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Loading indicator
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
