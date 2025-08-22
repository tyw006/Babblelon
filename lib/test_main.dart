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
import 'package:babblelon/screens/test_navigation_screen.dart';
import 'package:babblelon/providers/motion_preferences_provider.dart';
import 'package:babblelon/providers/tutorial_database_providers.dart';
import 'package:babblelon/services/auth_service_interface.dart';
import 'package:babblelon/services/test_auth_service.dart';
import 'package:provider/provider.dart' as provider;
import 'dart:io';

/// Test implementation of TutorialCompletionNotifier that marks all tutorials as completed
class TestTutorialCompletionNotifier extends TutorialCompletionNotifier {
  TestTutorialCompletionNotifier() : super() {
    // Initialize with all tutorials marked as completed
    state = {
      'initial_movement': true,
      'conversation_basics': true,
      'tracing_introduction': true,
      'pronunciation_basics': true,
      'inventory_basics': true,
      'quest_system': true,
      'npc_interaction': true,
      'boss_battle_intro': true,
      'item_management': true,
      'combat_basics': true,
      'character_tracing': true,
      'pronunciation_assessment': true,
      'npc_dialogue': true,
    };
  }

  @override
  bool isTutorialCompleted(String tutorialId) {
    // Always return true for any tutorial in test mode
    return true;
  }
}

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
  
  // Only initialize Supabase if credentials are provided
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await SupabaseService.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // Initialize Isar DB
  await IsarService.init();
  
  // Initialize test authentication service for testing
  AuthServiceFactory.setInstance(TestAuthService());
  debugPrint('✅ Test authentication service initialized');
  
  // Note: Test environment now uses mock authentication and tutorial bypass
  // This allows testing all features without authentication barriers
  debugPrint('✅ Test environment initialized with mock authentication');

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
    
    print('✅ PostHog initialized successfully with user session and device properties (TEST VERSION)');
  } else {
    print('⚠️ PostHog API key not found, skipping initialization (TEST VERSION)');
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
      // Test version environment tag
      options.environment = 'test';
    },
    appRunner: () => runApp(SentryWidget(
      child: provider.MultiProvider(
        providers: [
          provider.ChangeNotifierProvider(create: (context) => MotionPreferences()..init()),
        ],
        child: ProviderScope(
          overrides: [
            // Override tutorial completion provider to mark all tutorials as completed
            tutorialCompletionProvider.overrideWith((ref) {
              return TestTutorialCompletionNotifier();
            }),
          ],
          child: const TestApp(),
        ),
      ),
    )),
  );
  // TODO: Remove this line after sending the first sample event to sentry.
  await Sentry.captureException(StateError('This is a sample exception from test version.'));
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Babblelon (Test)',
      theme: AppTheme.lightTheme, // Use cartoon unified theme
      home: const TestNavigationScreen(), // Testing menu with component tests and game flow
    );
  }
}