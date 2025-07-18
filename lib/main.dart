import 'package:babblelon/screens/main_screen/widgets/space_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' as provider;
import 'utils/env_loader.dart';
import 'services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:babblelon/theme/app_theme.dart';
import 'package:babblelon/providers/motion_preferences_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set full screen mode
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
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

  runApp(
    provider.MultiProvider(
      providers: [
        provider.ChangeNotifierProvider(create: (context) => MotionPreferences()..init()),
      ],
      child: const ProviderScope(child: MyApp()),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Babblelon',
      theme: AppTheme.lightTheme, // Use modern unified theme
      home: const SpaceLoadingScreen(), // New loading system with splash screen
    );
  }
} 