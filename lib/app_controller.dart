import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/screens/main_screen/widgets/space_loading_screen.dart';

/// App controller that manages the main app flow
/// Shows the original 3D earth loading screen and main screen flow
class AppController extends ConsumerWidget {
  const AppController({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Return to the original beautiful 3D earth main screen flow
    // This will show: Loading → 3D Earth Main Screen → Game Selection
    return const SpaceLoadingScreen();
  }
}