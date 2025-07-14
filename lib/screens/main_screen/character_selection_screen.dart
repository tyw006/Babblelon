import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:babblelon/screens/main_screen/thailand_map_screen.dart';
import 'package:babblelon/screens/game_screen.dart';

class CharacterSelectionScreen extends ConsumerStatefulWidget {
  final LocationData selectedLocation;

  const CharacterSelectionScreen({
    super.key,
    required this.selectedLocation,
  });

  @override
  ConsumerState<CharacterSelectionScreen> createState() => 
      _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends ConsumerState<CharacterSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _characterController;
  String? _selectedCharacter;
  bool _isConfirming = false;

  final List<CharacterOption> _characters = [
    CharacterOption(
      id: 'male',
      name: 'Male Tourist',
      assetPath: 'assets/images/player/sprite_male_tourist.png',
      description: 'Ready for adventure!',
    ),
    CharacterOption(
      id: 'female',
      name: 'Female Tourist',
      assetPath: 'assets/images/player/sprite_female_tourist.png',
      description: 'Excited to explore!',
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _characterController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      _characterController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _characterController.dispose();
    super.dispose();
  }

  void _selectCharacter(String characterId) {
    setState(() {
      _selectedCharacter = characterId;
    });
  }

  Future<void> _confirmSelection() async {
    if (_selectedCharacter == null || _isConfirming) return;
    
    setState(() {
      _isConfirming = true;
    });
    
    // Save character selection and first-time flag
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_character', _selectedCharacter!);
    await prefs.setBool('has_selected_character', true);
    
    // Navigate to game
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => GameScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 1000),
        ),
      );
    }
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
              Color(0xFF2D1B69), // Deep purple
              Color(0xFF5B2C87), // Medium purple
              Color(0xFF8E44AD), // Light purple
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Choose Your Avatar',
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
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ).animate()
                .fadeIn(duration: 800.ms)
                .slideY(begin: -30, duration: 600.ms),
              
              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'You can customize and improve your hero as you explore ${widget.selectedLocation.name}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ).animate()
                .fadeIn(duration: 1000.ms, delay: 200.ms)
                .slideY(begin: 20, duration: 600.ms, delay: 200.ms),
              
              const SizedBox(height: 40),
              
              // Character selection
              Expanded(
                child: AnimatedBuilder(
                  animation: _characterController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 50 * (1 - _characterController.value)),
                      child: Opacity(
                        opacity: _characterController.value,
                        child: _buildCharacterSelection(),
                      ),
                    );
                  },
                ),
              ),
              
              // Confirm button
              Padding(
                padding: const EdgeInsets.all(30),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _selectedCharacter != null && !_isConfirming
                        ? _confirmSelection
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedCharacter != null 
                          ? Colors.orange 
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    child: _isConfirming
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Start Adventure',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ).animate()
                .fadeIn(duration: 800.ms, delay: 600.ms)
                .slideY(begin: 50, duration: 600.ms, delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _characters.map((character) {
          final isSelected = _selectedCharacter == character.id;
          final index = _characters.indexOf(character);
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: GestureDetector(
              onTap: () => _selectCharacter(character.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.orange.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.orange 
                        : Colors.white.withValues(alpha: 0.3),
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    // Character sprite
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Image.asset(
                        character.assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              character.id == 'male' ? Icons.person : Icons.person_4,
                              size: 40,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(width: 20),
                    
                    // Character info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            character.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            character.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Selection indicator
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? Colors.orange : Colors.white.withValues(alpha: 0.5),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ).animate()
              .fadeIn(
                duration: 600.ms,
                delay: Duration(milliseconds: 200 + (index * 100)),
              )
              .slideX(
                begin: 100,
                duration: 600.ms,
                delay: Duration(milliseconds: 200 + (index * 100)),
              ),
          );
        }).toList(),
      ),
    );
  }
}

class CharacterOption {
  final String id;
  final String name;
  final String assetPath;
  final String description;

  const CharacterOption({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.description,
  });
}