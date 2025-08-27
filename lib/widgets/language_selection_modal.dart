import 'package:flutter/material.dart';
import 'package:babblelon/theme/modern_design_system.dart' as modern;

/// Language data model for language selection
class LanguageData {
  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final bool isAvailable;

  const LanguageData({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.isAvailable,
  });
}

/// Reusable language selection modal
class LanguageSelectionModal extends StatefulWidget {
  final String? initialLanguage;
  final Function(String languageCode) onLanguageSelected;

  const LanguageSelectionModal({
    super.key,
    this.initialLanguage,
    required this.onLanguageSelected,
  });

  @override
  State<LanguageSelectionModal> createState() => _LanguageSelectionModalState();
}

class _LanguageSelectionModalState extends State<LanguageSelectionModal> {
  String? _selectedLanguage;

  final List<LanguageData> _languages = [
    const LanguageData(
      code: 'chinese',
      name: 'Chinese',
      nativeName: '中文',
      flag: '🇨🇳',
      isAvailable: false,
    ),
    const LanguageData(
      code: 'japanese',
      name: 'Japanese',
      nativeName: '日本語',
      flag: '🇯🇵',
      isAvailable: false,
    ),
    const LanguageData(
      code: 'korean',
      name: 'Korean',
      nativeName: '한국어',
      flag: '🇰🇷',
      isAvailable: false,
    ),
    const LanguageData(
      code: 'thai',
      name: 'Thai',
      nativeName: 'ไทย',
      flag: '🇹🇭',
      isAvailable: true,
    ),
    const LanguageData(
      code: 'vietnamese',
      name: 'Vietnamese',
      nativeName: 'Tiếng Việt',
      flag: '🇻🇳',
      isAvailable: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: modern.ModernDesignSystem.primarySurface,
      title: Row(
        children: [
          const Icon(
            Icons.language_outlined,
            color: modern.ModernDesignSystem.forestGreen,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: const Text(
              'Choose Learning Language',
              style: TextStyle(color: modern.ModernDesignSystem.textPrimary),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select the language you want to learn:',
              style: TextStyle(
                fontSize: 14,
                color: modern.ModernDesignSystem.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            
            // Language list
            Column(
              children: _languages.map((language) {
                final isSelected = _selectedLanguage == language.code;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: GestureDetector(
                    onTap: language.isAvailable 
                      ? () => setState(() => _selectedLanguage = language.code)
                      : () => _showComingSoonMessage(language.name),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected 
                          ? modern.ModernDesignSystem.forestGreen.withValues(alpha: 0.15)
                          : language.isAvailable
                            ? modern.ModernDesignSystem.primarySurface
                            : modern.ModernDesignSystem.primarySurfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(modern.ModernDesignSystem.radiusMedium),
                        border: Border.all(
                          color: isSelected 
                            ? modern.ModernDesignSystem.forestGreen
                            : language.isAvailable
                              ? modern.ModernDesignSystem.borderPrimary.withValues(alpha: 0.3)
                              : modern.ModernDesignSystem.borderPrimary.withValues(alpha: 0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            language.flag,
                            style: TextStyle(
                              fontSize: 24,
                              color: language.isAvailable ? null : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  language.name,
                                  style: modern.ModernDesignSystem.bodyMedium.copyWith(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: language.isAvailable
                                      ? (isSelected ? modern.ModernDesignSystem.forestGreen : modern.ModernDesignSystem.textPrimary)
                                      : modern.ModernDesignSystem.textTertiary,
                                  ),
                                ),
                                Text(
                                  language.nativeName,
                                  style: modern.ModernDesignSystem.bodySmall.copyWith(
                                    color: language.isAvailable
                                      ? modern.ModernDesignSystem.textSecondary
                                      : modern.ModernDesignSystem.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!language.isAvailable)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: modern.ModernDesignSystem.warmOrange,
                                borderRadius: BorderRadius.circular(modern.ModernDesignSystem.radiusSmall),
                              ),
                              child: Text(
                                'Coming Soon',
                                style: modern.ModernDesignSystem.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          else if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: modern.ModernDesignSystem.forestGreen,
                              size: 20,
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
          child: const Text(
            'Cancel',
            style: TextStyle(color: modern.ModernDesignSystem.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _selectedLanguage != null 
            ? () {
                widget.onLanguageSelected(_selectedLanguage!);
                Navigator.of(context).pop();
              }
            : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: modern.ModernDesignSystem.forestGreen,
            foregroundColor: Colors.white,
          ),
          child: const Text('Select'),
        ),
      ],
    );
  }

  void _showComingSoonMessage(String languageName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$languageName learning is coming soon!',
          style: const TextStyle(color: modern.ModernDesignSystem.textPrimary),
        ),
        backgroundColor: modern.ModernDesignSystem.primarySurface,
        action: SnackBarAction(
          label: 'OK',
          textColor: modern.ModernDesignSystem.warmOrange,
          onPressed: () {},
        ),
      ),
    );
  }
}