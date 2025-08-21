import 'package:flutter/material.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart' as cartoon;

/// Character data model for character selection
class CharacterData {
  final String id;
  final String name;
  final String assetPath;
  final String description;

  const CharacterData({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.description,
  });
}

/// Reusable character selection modal
class CharacterSelectionModal extends StatefulWidget {
  final String? initialCharacter;
  final Function(String characterId) onCharacterSelected;

  const CharacterSelectionModal({
    super.key,
    this.initialCharacter,
    required this.onCharacterSelected,
  });

  @override
  State<CharacterSelectionModal> createState() => _CharacterSelectionModalState();
}

class _CharacterSelectionModalState extends State<CharacterSelectionModal> {
  String? _selectedCharacter;

  final List<CharacterData> _characters = [
    const CharacterData(
      id: 'male',
      name: 'Male Tourist',
      assetPath: 'assets/images/player/sprite_male_tourist.png',
      description: 'Ready for adventure!',
    ),
    const CharacterData(
      id: 'female',
      name: 'Female Tourist',
      assetPath: 'assets/images/player/sprite_female_tourist.png',
      description: 'Excited to explore!',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCharacter = widget.initialCharacter;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.person_outline,
            color: cartoon.CartoonDesignSystem.lavenderPurple,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text('Choose Character'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select your character to represent you in Thai adventures:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            
            // Character grid - 2 characters side by side
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _characters.map((character) {
                final isSelected = _selectedCharacter == character.id;
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedCharacter = character.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 120,
                    height: 150,
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? cartoon.CartoonDesignSystem.lavenderPurple.withValues(alpha: 0.1)
                        : Colors.grey[50],
                      borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
                      border: Border.all(
                        color: isSelected 
                          ? cartoon.CartoonDesignSystem.lavenderPurple
                          : cartoon.CartoonDesignSystem.textMuted.withValues(alpha: 0.3),
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: cartoon.CartoonDesignSystem.lavenderPurple.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Character sprite
                          Expanded(
                            child: Image.asset(
                              character.assetPath,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  character.id == 'male' ? Icons.person : Icons.person_4,
                                  size: 48,
                                  color: isSelected 
                                      ? cartoon.CartoonDesignSystem.lavenderPurple
                                      : cartoon.CartoonDesignSystem.textSecondary,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            character.name,
                            style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected 
                                  ? cartoon.CartoonDesignSystem.lavenderPurple
                                  : cartoon.CartoonDesignSystem.textPrimary,
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: cartoon.CartoonDesignSystem.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _selectedCharacter != null 
            ? () {
                widget.onCharacterSelected(_selectedCharacter!);
                Navigator.of(context).pop();
              }
            : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: cartoon.CartoonDesignSystem.lavenderPurple,
            foregroundColor: Colors.white,
          ),
          child: const Text('Select'),
        ),
      ],
    );
  }
}