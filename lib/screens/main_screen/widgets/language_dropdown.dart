import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LanguageDropdown extends StatefulWidget {
  final Function(String) onLanguageSelected;
  final bool isRotating;

  const LanguageDropdown({
    super.key,
    required this.onLanguageSelected,
    required this.isRotating,
  });

  @override
  State<LanguageDropdown> createState() => _LanguageDropdownState();
}

class _LanguageDropdownState extends State<LanguageDropdown> {
  bool _isExpanded = false;

  // Static language data - no need to recreate on each build
  static const List<Map<String, dynamic>> _languages = [
    {'name': 'Thai', 'flag': '🇹🇭', 'enabled': true, 'code': 'thai'},
    {'name': 'Japanese', 'flag': '🇯🇵', 'enabled': false, 'code': 'japanese'},
    {'name': 'Chinese', 'flag': '🇨🇳', 'enabled': false, 'code': 'chinese'},
    {'name': 'Korean', 'flag': '🇰🇷', 'enabled': false, 'code': 'korean'},
    {'name': 'Vietnamese', 'flag': '🇻🇳', 'enabled': false, 'code': 'vietnamese'},
    {'name': 'Indonesian', 'flag': '🇮🇩', 'enabled': false, 'code': 'indonesian'},
  ];

  // Pre-calculate decorations for better performance
  static final BoxDecoration _dropdownDecoration = BoxDecoration(
    color: Colors.white.withOpacity(0.35),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Colors.white.withOpacity(0.4),
      width: 1,
    ),
  );

  static final BoxDecoration _itemBorderDecoration = BoxDecoration(
    border: Border(
      bottom: BorderSide(
        color: Colors.white.withOpacity(0.05),
        width: 1,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main dropdown button
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3), // Increased opacity for better visibility
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4), // Increased border opacity
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.language,
                    color: Colors.white.withAlpha(179),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select Language',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withAlpha(179),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Dropdown items
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _isExpanded ? 250 : 0, // Fixed height for scrollable area
            child: _isExpanded
                ? Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.35), // Increased opacity for expanded dropdown
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4), // Increased border opacity
                            width: 1,
                          ),
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: _languages.length,
                          itemBuilder: (context, index) {
                            final language = _languages[index];
                            return RepaintBoundary(
                              child: _LanguageItem(
                                language: language,
                                onTap: language['enabled'] as bool
                                    ? () {
                                        setState(() {
                                          _isExpanded = false;
                                        });
                                        widget.onLanguageSelected(language['code'] as String);
                                      }
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 800.ms, delay: 600.ms)
      .slideY(begin: 20, duration: 600.ms, delay: 600.ms);
  }
}

// Optimized language item widget for better performance
class _LanguageItem extends StatelessWidget {
  final Map<String, dynamic> language;
  final VoidCallback? onTap;

  const _LanguageItem({
    required this.language,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = language['enabled'] as bool;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              language['flag'] as String,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                language['name'] as String,
                style: TextStyle(
                  fontSize: 14,
                  color: isEnabled
                      ? Colors.white
                      : Colors.white.withOpacity(0.4),
                ),
              ),
            ),
            if (!isEnabled)
              Text(
                'Coming soon...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.3),
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}