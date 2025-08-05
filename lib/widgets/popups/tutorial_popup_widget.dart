import 'package:flutter/material.dart';
import '../../services/tutorial_service.dart';

/// A popup widget for displaying tutorial steps with animations
class TutorialPopup extends StatefulWidget {
  final TutorialStep step;
  final bool isLastStep;
  final VoidCallback? onSkipEntireTutorial;

  const TutorialPopup({
    super.key,
    required this.step,
    required this.isLastStep,
    this.onSkipEntireTutorial,
  });

  @override
  State<TutorialPopup> createState() => _TutorialPopupState();
}

class _TutorialPopupState extends State<TutorialPopup> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _showContinueButton = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
    
    // Delay showing continue button for rich content (2 seconds)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showContinueButton = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildEnhancedAssetShowcase(List<TutorialVisual> visualElements) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.1),
            Colors.orange.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Enhanced title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, size: 18, color: Colors.orange[600]),
              const SizedBox(width: 6),
              Text(
                'Game Items',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
              Icon(Icons.star, size: 18, color: Colors.orange[600]),
            ],
          ),
          const SizedBox(height: 16),
          // Enhanced visual elements
          Wrap(
            spacing: 20,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: visualElements.map((element) => _buildEnhancedVisualElement(element)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedVisualElement(TutorialVisual element) {
    final isSpecialItem = element.label?.toLowerCase().contains('special') == true ||
                         element.label?.toLowerCase().contains('golden') == true;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,  // Increased from 50 to 80 for better visibility
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSpecialItem ? Colors.amber[400]! : Colors.grey[300]!,
              width: isSpecialItem ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSpecialItem 
                    ? Colors.amber.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: isSpecialItem ? 8 : 4,
                offset: const Offset(0, 2),
              ),
              // Additional golden glow for special items
              if (isSpecialItem)
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 0),
                ),
            ],
          ),
          child: Center(
            child: _buildVisualContent(element),
          ),
        ),
        if (element.label != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSpecialItem 
                  ? Colors.amber.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              element.label!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSpecialItem ? Colors.amber[800] : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVisualContent(TutorialVisual element) {
    const double defaultSize = 80; // Updated default size
    
    switch (element.type) {
      case 'icon':
        return Icon(
          element.data as IconData,
          size: (element.size ?? defaultSize) * 0.6,
          color: Colors.orange,
        );
      case 'image':
        return Image.asset(
          element.data as String,
          width: (element.size ?? defaultSize) * 0.75,
          height: (element.size ?? defaultSize) * 0.75,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.image_not_supported,
              size: (element.size ?? defaultSize) * 0.6,
              color: Colors.grey,
            );
          },
        );
      default:
        return Icon(
          Icons.help_outline,
          size: (element.size ?? defaultSize) * 0.6,
          color: Colors.grey,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.5 * _fadeAnimation.value),
          body: Center(
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                margin: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      spreadRadius: 5,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Content area - New vertical layout
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title with optional header icon
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (widget.step.headerIcon != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      widget.step.headerIcon!,
                                      size: 20,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Text(
                                    widget.step.title,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Compact Blabbybara avatar
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(50),
                                color: Colors.grey[100],
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: Image.asset(
                                  'assets/images/capybara/blabbybara_portrait.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.brown[100],
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Icon(
                                        Icons.pets,
                                        size: 40,
                                        color: Colors.brown[400],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Main content
                            Flexible(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    Text(
                                      widget.step.content,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.black54,
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    
                                    // Prominent game asset showcase
                                    if (widget.step.visualElements != null && widget.step.visualElements!.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      _buildEnhancedAssetShowcase(widget.step.visualElements!),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Enhanced button area with better touch targets
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Only show skip button for multi-step tutorials
                          if (!widget.step.isStandalone)
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                if (widget.onSkipEntireTutorial != null) {
                                  widget.onSkipEntireTutorial!();
                                }
                              },
                              style: TextButton.styleFrom(
                                minimumSize: const Size(88, 44), // Ensure minimum touch target
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              child: const Text(
                                'Skip Tutorial',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ),
                          // Show spacer if no skip button to maintain layout
                          if (widget.step.isStandalone)
                            const Spacer(),
                          AnimatedOpacity(
                            opacity: _showContinueButton ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: ElevatedButton(
                              onPressed: _showContinueButton ? () {
                                Navigator.of(context).pop();
                              } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(120, 48), // Better touch target
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                widget.isLastStep ? "Let's Start!" : "Continue",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}