import 'package:babblelon/screens/main_menu_screen.dart';
import 'package:babblelon/screens/main_screen/earth_globe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/game_screen.dart';
import 'utils/env_loader.dart';
import 'services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:babblelon/widgets/debug_dialog_test.dart';
import 'package:babblelon/widgets/shared/app_styles.dart';

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

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Babblelon',
      theme: AppStyles.mainTheme,
      home: const EarthGlobeScreen(),
      // home: const MainMenuScreen(), // Old main menu
      // home: const DebugDialogTest(), // Temporarily set to debug screen
    );
  }
} 