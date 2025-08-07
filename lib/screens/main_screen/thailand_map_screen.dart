import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/screens/main_screen/widgets/location_marker_widget.dart';
import 'package:babblelon/screens/game_screen.dart';
import 'package:babblelon/services/background_audio_service.dart';
import 'package:babblelon/screens/main_screen/combined_selection_screen.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart' as cartoon;
import 'package:babblelon/widgets/modern_design_system.dart';
import 'package:babblelon/widgets/popups/base_popup_widget.dart';

class ThailandMapScreen extends ConsumerStatefulWidget {
  const ThailandMapScreen({super.key});

  @override
  ConsumerState<ThailandMapScreen> createState() => _ThailandMapScreenState();
}

class _ThailandMapScreenState extends ConsumerState<ThailandMapScreen> 
    with TickerProviderStateMixin {
  late AnimationController _mapController;
  late AnimationController _markersController;
  
  final BackgroundAudioService _audioService = BackgroundAudioService();
  
  final List<LocationData> _locations = [
    const LocationData(
      name: 'Bangkok (Yaowarat)',
      id: 'yaowarat',
      position: Offset(0.50, 0.55), // Moved up from 0.65 to 0.58
      isAvailable: true,
      description: 'Explore the vibrant Chinatown district',
    ),
    const LocationData(
      name: 'Chiang Mai',
      id: 'chiang_mai',
      position: Offset(0.35, 0.35), // Keep northern Thailand positioning
      isAvailable: false,
      description: 'Northern cultural capital',
    ),
    const LocationData(
      name: 'Phuket',
      id: 'phuket',
      position: Offset(0.30, 0.72), // Moved up from 0.85 to 0.78, and left from 0.32 to 0.28
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
    
    // Show confirmation dialog before traveling
    final confirmed = await _showTravelConfirmationDialog(location);
    if (confirmed) {
      _navigateToGame(location);
    }
  }

  void _navigateToGame(LocationData location) {
    // Stop background music before transitioning to game
    _audioService.stopBackgroundMusic();
    
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => GameScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              // First half: fade to black
              if (animation.value < 0.5) {
                final blackOpacity = animation.value * 2;
                final contentOpacity = (1 - blackOpacity).clamp(0.0, 1.0);
                return Container(
                  color: Colors.black,
                  child: Transform.scale(
                    scale: contentOpacity,
                    child: const SizedBox.expand(),
                  ),
                );
              }
              // Second half: fade in new screen
              else {
                final blackOpacity = (2 - (animation.value * 2)).clamp(0.0, 1.0);
                final contentOpacity = ((animation.value - 0.5) * 2).clamp(0.0, 1.0);
                return Stack(
                  children: [
                    Transform.scale(
                      scale: contentOpacity,
                      child: child,
                    ),
                    if (blackOpacity > 0)
                      Container(
                        color: Colors.black,
                        child: const SizedBox.expand(),
                      ),
                  ],
                );
              }
            },
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void _showComingSoonDialog(LocationData location) {
    BasePopup.showPopup(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.construction,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  location.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'This adventure is coming soon!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            location.description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: BasePopup.primaryButtonStyle,
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showTravelConfirmationDialog(LocationData location) async {
    return await BasePopup.showPopup<bool>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(
                Icons.flight_takeoff,
                color: Colors.orange,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Travel Confirmation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Travel to ${location.name}?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            location.description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Are you ready to begin your Thai language adventure?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: BasePopup.secondaryButtonStyle,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: BasePopup.primaryButtonStyle,
                  child: const Text('Let\'s Go!'),
                ),
              ),
            ],
          ),
        ],
      ),
    ) ?? false;
  }

  void _handleBackNavigation() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const CombinedSelectionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child!;
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: ModernDesignSystem.spaceGradient,
        ),
        child: Stack(
          children: [
            // Thailand static map with markers (Full Screen)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _mapController,
                builder: (context, child) {
                  final screenSize = MediaQuery.of(context).size;
                  
                  return Stack(
                    children: [
                      // Thailand map image (Full Screen with BoxFit.cover, optimized for 1280x1920)
                      Positioned(
                          left: -30, // Reduced shift for new aspect ratio
                          top: 0,
                          right: -30,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/maps/map_thailand.png',
                              fit: BoxFit.cover, // Use cover to fill entire screen
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: ModernDesignSystem.deepSpaceBlue,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.map,
                                          color: Colors.white,
                                          size: 64,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Thailand Map',
                                          style: cartoon.CartoonDesignSystem.headlineMedium.copyWith(
                                            color: ModernDesignSystem.electricCyan,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        
                      // Location markers (positioned based on screen proportions)
                      ...(_locations.map((location) {
                        return AnimatedBuilder(
                          animation: _markersController,
                          builder: (context, child) {
                            final delay = _locations.indexOf(location) * 0.3;
                            
                            // Calculate pin position based on screen size and location proportions
                            // Center the 60x60 pin widget
                            final pinX = (location.position.dx * screenSize.width) - 30;
                            final pinY = (location.position.dy * screenSize.height) - 30;
                            
                            final fade = CurvedAnimation(
                              parent: _markersController,
                              curve: Interval(delay, 1.0),
                            );
                            
                            return Positioned(
                              left: pinX,
                              top: pinY,
                              child: ScaleTransition(
                                scale: fade,
                                child: GestureDetector(
                                  onTap: () => _onLocationSelected(location),
                                  child: LocationMarkerWidget(
                                    location: location,
                                    onTap: () => _onLocationSelected(location),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }).toList()),
                    ],
                  );
                },
              ),
            ),
            
            // Back button (positioned on top of map)
            Positioned(
              top: 60,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: ModernDesignSystem.electricCyan.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ModernDesignSystem.electricCyan.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _handleBackNavigation,
                  icon: const Icon(
                    Icons.arrow_back_ios_rounded,
                    color: ModernDesignSystem.electricCyan,
                    size: 24,
                  ),
                ),
              ),
            ),
            
            // Title (positioned on top of map, matching Select Language style)
            Positioned(
              top: 60,
              left: 80, // Leave space for back button
              right: 20,
              child: Text(
                'Choose Your Destination',
                style: cartoon.CartoonDesignSystem.headlineMedium.copyWith(
                  fontSize: 18,
                  color: ModernDesignSystem.electricCyan,
                  fontWeight: FontWeight.w600,
                ),
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
  final Offset position; // Relative position on the map (0.0 to 1.0)
  final bool isAvailable;
  final String description;

  const LocationData({
    required this.name,
    required this.id,
    required this.position,
    required this.isAvailable,
    required this.description,
  });
}