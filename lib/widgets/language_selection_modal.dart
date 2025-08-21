import 'package:flutter/material.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart' as cartoon;

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
      title: Row(
        children: [
          Icon(
            Icons.language_outlined,
            color: cartoon.CartoonDesignSystem.forestGreen,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text('Choose Learning Language'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select the language you want to learn:',
              style: TextStyle(fontSize: 14),
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
                          ? cartoon.CartoonDesignSystem.forestGreen.withValues(alpha: 0.1)
                          : language.isAvailable
                            ? Colors.grey[50]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
                        border: Border.all(
                          color: isSelected 
                            ? cartoon.CartoonDesignSystem.forestGreen
                            : language.isAvailable
                              ? cartoon.CartoonDesignSystem.textMuted.withValues(alpha: 0.3)
                              : Colors.grey.shade300,
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
                                  style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: language.isAvailable
                                      ? (isSelected ? cartoon.CartoonDesignSystem.forestGreen : cartoon.CartoonDesignSystem.textPrimary)
                                      : Colors.grey.shade500,
                                  ),
                                ),
                                Text(
                                  language.nativeName,
                                  style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                                    color: language.isAvailable
                                      ? cartoon.CartoonDesignSystem.textSecondary
                                      : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!language.isAvailable)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cartoon.CartoonDesignSystem.warmOrange,
                                borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusSmall),
                              ),
                              child: Text(
                                'Coming Soon',
                                style: cartoon.CartoonDesignSystem.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          else if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: cartoon.CartoonDesignSystem.forestGreen,
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
          child: Text(
            'Cancel',
            style: TextStyle(color: cartoon.CartoonDesignSystem.textSecondary),
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
            backgroundColor: cartoon.CartoonDesignSystem.forestGreen,
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
        content: Text('$languageName learning is coming soon!'),
        backgroundColor: cartoon.CartoonDesignSystem.warmOrange,
      ),
    );
  }
}