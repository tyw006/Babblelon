import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/env_loader.dart';
import 'services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:babblelon/services/posthog_service.dart';
import 'package:babblelon/theme/app_theme.dart';
import 'package:babblelon/app_controller.dart';
import 'package:babblelon/providers/motion_preferences_provider.dart';
import 'package:provider/provider.dart' as provider;
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI mode for games without interfering with device scaling
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersive,
  );
  
  // Load environment variables
  await EnvLoader.initialize();
  
  // Initialize Supabase
  final supabaseUrl = EnvLoader.getString('SUPABASE_URL');
  final supabaseAnonKey = EnvLoader.getString('SUPABASE_ANON_KEY');
  
  debugPrint('🔐 Supabase URL: ${supabaseUrl.isNotEmpty ? '✅ Present' : '❌ Missing'}');
  debugPrint('🔐 Supabase Anon Key: ${supabaseAnonKey.isNotEmpty ? '✅ Present' : '❌ Missing'}');
  
  // Only initialize Supabase if credentials are provided
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await SupabaseService.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      debugPrint('✅ Supabase initialized successfully');
    } catch (e) {
      debugPrint('❌ Supabase initialization failed: $e');
    }
  } else {
    debugPrint('❌ Supabase initialization skipped - missing credentials');
  }

  // Initialize Isar DB
  await IsarService.init();

  // Initialize PostHog
  final postHogApiKey = EnvLoader.getString('POSTHOG_API_KEY');
  if (postHogApiKey.isNotEmpty) {
    final config = PostHogConfig(postHogApiKey);
    config.host = 'https://app.posthog.com';
    config.debug = true; // Enable debug logging for development
    config.captureApplicationLifecycleEvents = true; // Auto-track app lifecycle
    
    await Posthog().setup(config);
    
    // Initialize user session for tracking
    PostHogService.initializeUser();
    
    // Set device properties
    PostHogService.setDeviceProperties(
      deviceOs: Platform.operatingSystem,
      deviceModel: Platform.isAndroid ? 'Android Device' : 'iOS Device',
      soundEffectsEnabled: true, // Default value
      preferredLanguage: 'th', // Thai is the primary language for the game
    );
    
    print('✅ PostHog initialized successfully with user session and device properties (PRODUCTION VERSION)');
  } else {
    print('⚠️ PostHog API key not found, skipping initialization (PRODUCTION VERSION)');
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://fcc9d3cb494e44a232ff849d964da146@o4509771667341312.ingest.us.sentry.io/4509771668586496';
      // Adds request headers and IP for users, for more info visit:
      // https://docs.sentry.io/platforms/dart/guides/flutter/data-management/data-collected/
      options.sendDefaultPii = true;
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      options.profilesSampleRate = 1.0;
      // Configure Session Replay
      options.replay.sessionSampleRate = 0.1;
      options.replay.onErrorSampleRate = 1.0;
    },
    appRunner: () => runApp(SentryWidget(
      child: provider.MultiProvider(
        providers: [
          provider.ChangeNotifierProvider(create: (context) => MotionPreferences()..init()),
        ],
        child: const ProviderScope(child: MyApp()),
      ),
    )),
  );
  // TODO: Remove this line after sending the first sample event to sentry.
  await Sentry.captureException(StateError('This is a sample exception from production version.'));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Babblelon',
      theme: AppTheme.lightTheme, // Use cartoon unified theme
      home: const AppController(), // Production app controller with onboarding flow
    );
  }
} 