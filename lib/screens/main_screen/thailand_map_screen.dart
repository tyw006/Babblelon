import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:babblelon/screens/main_screen/character_selection_screen.dart';
import 'package:babblelon/screens/main_screen/widgets/location_marker_widget.dart';
import 'package:babblelon/widgets/shared/app_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:babblelon/screens/game_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:babblelon/screens/main_screen/earth_globe_screen.dart';

class ThailandMapScreen extends ConsumerStatefulWidget {
  const ThailandMapScreen({super.key});

  @override
  ConsumerState<ThailandMapScreen> createState() => _ThailandMapScreenState();
}

class _ThailandMapScreenState extends ConsumerState<ThailandMapScreen> 
    with TickerProviderStateMixin {
  late AnimationController _mapController;
  late AnimationController _markersController;
  
  final List<LocationData> _locations = [
    LocationData(
      name: 'Bangkok (Yaowarat)',
      id: 'yaowarat',
      latLng: LatLng(13.7563, 100.5018),
      position: const Offset(0.52, 0.65),
      isAvailable: true,
      description: 'Explore the vibrant Chinatown district',
    ),
    LocationData(
      name: 'Chiang Mai',
      id: 'chiang_mai',
      latLng: LatLng(18.7883, 98.9853),
      position: const Offset(0.45, 0.25),
      isAvailable: false,
      description: 'Northern cultural capital',
    ),
    LocationData(
      name: 'Phuket',
      id: 'phuket',
      latLng: LatLng(7.8804, 98.3923),
      position: const Offset(0.4, 0.85),
      isAvailable: false,
      description: 'Beautiful island paradise',
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _mapController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _markersController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // Start animations
    _mapController.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      _markersController.forward();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _markersController.dispose();
    super.dispose();
  }

  Future<void> _onLocationSelected(LocationData location) async {
    if (!location.isAvailable) {
      _showComingSoonDialog(location);
      return;
    }
    
    // Check if this is the first time playing
    final prefs = await SharedPreferences.getInstance();
    final hasSelectedCharacter = prefs.getBool('has_selected_character') ?? false;
    
    if (!hasSelectedCharacter) {
      // Navigate to character selection first
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => 
              CharacterSelectionScreen(selectedLocation: location),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                )),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    } else {
      // Go directly to the game
      _navigateToGame(location);
    }
  }

  void _navigateToGame(LocationData location) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => GameScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              // Zoom transition effect
              if (animation.value < 0.5) {
                return Container(
                  color: Colors.black.withValues(alpha: animation.value * 2),
                  child: Transform.scale(
                    scale: 1 + (animation.value * 0.2),
                    child: Opacity(
                      opacity: 1 - (animation.value * 2),
                      child: const SizedBox.expand(),
                    ),
                  ),
                );
              } else {
                return Container(
                  color: Colors.black.withValues(alpha: 2 - (animation.value * 2)),
                  child: Transform.scale(
                    scale: 1.2 - ((animation.value - 0.5) * 0.2),
                    child: Opacity(
                      opacity: (animation.value - 0.5) * 2,
                      child: child,
                    ),
                  ),
                );
              }
            },
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 1500),
      ),
    );
  }

  void _showComingSoonDialog(LocationData location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D4A7A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.construction, color: Colors.orange),
            const SizedBox(width: 10),
            Text(
              location.name,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This adventure is coming soon!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              location.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A472A), // Forest green
              Color(0xFF2D5B3D), // Medium green
              Color(0xFF4A7C59), // Lighter green
            ],
          ),
        ),
        child: Stack(
          children: [
            // Back button
            Positioned(
              top: 60,
              left: 20,
              child: IconButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EarthGlobeScreen(),
                  ),
                ),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 28,
                ),
              ).animate()
                .fadeIn(delay: 500.ms)
                .slideX(begin: -50, duration: 600.ms, delay: 500.ms),
            ),
            
            // Title
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Text(
                'Choose Your Destination',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
              ).animate()
                .fadeIn(duration: 1000.ms)
                .slideY(begin: -30, duration: 800.ms),
            ),
            
            // Thailand map
            Center(
              child: AnimatedBuilder(
                animation: _mapController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _mapController.value,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(15.8700, 100.9925), // Center of Thailand
                        initialZoom: 5.0,
                        minZoom: 4.0,
                        maxZoom: 10.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.babblelon',
                        ),
                        MarkerLayer(
                          markers: _locations.map((location) {
                            return Marker(
                              point: location.latLng,
                              width: 80,
                              height: 80,
                              child: GestureDetector(
                                onTap: () => _onLocationSelected(location),
                                child: AnimatedBuilder(
                                  animation: _markersController,
                                  builder: (context, child) {
                                    final delay = _locations.indexOf(location) * 0.3;
                                    final progress = (_markersController.value - delay).clamp(0.0, 1.0);
                                    return Transform.scale(
                                      scale: progress,
                                      child: Opacity(
                                        opacity: progress,
                                        child: LocationMarkerWidget(
                                          location: location,
                                          onTap: () => _onLocationSelected(location),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationData {
  final String name;
  final String id;
  final LatLng latLng; // Add this
  final Offset position; // Keep for compatibility if needed
  final bool isAvailable;
  final String description;

  const LocationData({
    required this.name,
    required this.id,
    required this.latLng,
    required this.position,
    required this.isAvailable,
    required this.description,
  });
}