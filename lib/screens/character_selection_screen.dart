import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/character_models.dart';
import '../theme/modern_design_system.dart';

/// Simplified character selection screen - only 2 characters, no customization
class CharacterSelectionScreen extends ConsumerStatefulWidget {
  final bool isOnboarding;
  final Function(GameCharacter, Map<String, dynamic>)? onCharacterSelected;
  
  const CharacterSelectionScreen({
    super.key,
    this.isOnboarding = true,
    this.onCharacterSelected,
  });

  @override
  ConsumerState<CharacterSelectionScreen> createState() => _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends ConsumerState<CharacterSelectionScreen> 
    with SingleTickerProviderStateMixin {
  GameCharacter? selectedCharacter;
  late AnimationController _animationController;
  late Animation<double> _bounceAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _selectCharacter(GameCharacter character) {
    setState(() {
      selectedCharacter = character;
    });
  }
  
  void _confirmSelection() {
    if (selectedCharacter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a character')),
      );
      return;
    }
    
    if (widget.onCharacterSelected != null) {
      // Pass empty customization since we removed that feature
      widget.onCharacterSelected!(selectedCharacter!, {});
    } else {
      Navigator.pop(context, {
        'character': selectedCharacter,
        'customization': {},
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernDesignSystem.skyBlue,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Choose Your Character',
                    style: ModernDesignSystem.displayMedium.copyWith(
                      color: Colors.white,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select your avatar for the adventure',
                    style: ModernDesignSystem.bodyLarge.copyWith(
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Character selection - simplified to 2 characters
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Character grid - 2 characters side by side
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: CharacterDatabase.availableCharacters.map((character) {
                          final isSelected = selectedCharacter?.id == character.id;
                          
                          return ScaleTransition(
                            scale: _bounceAnimation,
                            child: GestureDetector(
                              onTap: () => _selectCharacter(character),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 140,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                    ? ModernDesignSystem.skyBlue.withValues(alpha: 0.1)
                                    : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: isSelected 
                                      ? ModernDesignSystem.skyBlue
                                      : Colors.grey[300]!,
                                    width: isSelected ? 3 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Character sprite
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                          ? ModernDesignSystem.lavenderPurple.withValues(alpha: 0.2)
                                          : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(
                                          character.spriteSheetPath,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) {
                                            // Fallback to icon if sprite fails to load
                                            return Icon(
                                              character.id == 'male_tourist' 
                                                ? Icons.person 
                                                : Icons.person_outline,
                                              size: 40,
                                              color: isSelected 
                                                ? ModernDesignSystem.skyBlue
                                                : ModernDesignSystem.textOnLightSecondary,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      character.name,
                                      style: ModernDesignSystem.labelLarge.copyWith(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: ModernDesignSystem.textOnLight,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      character.description,
                                      style: ModernDesignSystem.bodySmall.copyWith(
                                        fontSize: 11,
                                        color: ModernDesignSystem.textOnLightSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      // Selected character indicator
                      if (selectedCharacter != null) ...[
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: ModernDesignSystem.skyBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: ModernDesignSystem.skyBlue,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Selected: ${selectedCharacter!.displayName}',
                            style: ModernDesignSystem.bodyMedium.copyWith(
                              color: ModernDesignSystem.skyBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (!widget.isOnboarding) ...[
                    Expanded(
                      child: ModernButton(
                        text: 'Cancel',
                        onPressed: () => Navigator.pop(context),
                        style: ModernButtonStyle.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ModernButton(
                      text: widget.isOnboarding ? 'Continue' : 'Confirm',
                      onPressed: selectedCharacter != null ? _confirmSelection : null,
                      style: selectedCharacter != null 
                        ? ModernButtonStyle.primary
                        : ModernButtonStyle.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}