import 'package:flutter/material.dart';
import '../../services/tutorial_service.dart';
import '../../services/tutorial_sequence_service.dart';
import '../../theme/modern_design_system.dart' as modern;

class TutorialPopup extends StatefulWidget {
  final TutorialStep step;
  final bool isLastStep;
  final VoidCallback? onSkipEntireTutorial;
  final VoidCallback onNext;
  final String? tutorialId; // New: ID for completion tracking
  final VoidCallback? onSkipSingle; // New: Skip just this tutorial

  const TutorialPopup({
    super.key,
    required this.step,
    required this.isLastStep,
    this.onSkipEntireTutorial,
    required this.onNext,
    this.tutorialId,
    this.onSkipSingle,
  });

  @override
  State<TutorialPopup> createState() => _TutorialPopupState();
}

class _TutorialPopupState extends State<TutorialPopup> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late PageController _pageController;
  int _currentPage = 0;
  
  // Get all slides (main content as first slide + additional slides)
  List<TutorialSlide> get _allSlides {
    final mainSlide = TutorialSlide(
      title: widget.step.title,
      content: widget.step.content,
      visualElements: widget.step.visualElements,
      headerIcon: widget.step.headerIcon,
    );
    
    if (widget.step.slides != null && widget.step.slides!.isNotEmpty) {
      return [mainSlide, ...widget.step.slides!];
    }
    return [mainSlide];
  }
  
  bool get _isMultiSlide => _allSlides.length > 1;
  bool get _isLastSlide => _currentPage == _allSlides.length - 1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: _buildGlassmorphicCard(context),
      ),
    );
  }

  Widget _buildGlassmorphicCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: modern.ModernDesignSystem.surfaceGradient,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: modern.ModernDesignSystem.primaryAccent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isMultiSlide)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemCount: _allSlides.length,
                  itemBuilder: (context, index) {
                    final slide = _allSlides[index];
                    return _buildSlideContent(slide);
                  },
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: _buildSlideContent(_allSlides[0]),
                ),
              ),
            if (_isMultiSlide) ...[
              const SizedBox(height: 16),
              _buildPageIndicators(),
            ],
            const SizedBox(height: 24),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSlideContent(TutorialSlide slide) {
    if (_isMultiSlide) {
      // For multi-slide: use scrollable layout to prevent overflow
      return SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildHeader(slide.title),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                slide.content,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: modern.ModernDesignSystem.textPrimary,
                  fontSize: 15, // Slightly smaller font to save space
                  height: 1.4, // Reduced line height to save space
                ),
              ),
            ),
            if (slide.visualElements != null && slide.visualElements!.isNotEmpty) ...[
              const SizedBox(height: 16), // Reduced spacing
              _buildVisualElements(slide.visualElements!),
            ],
            const SizedBox(height: 16), // Bottom padding for scrolling
          ],
        ),
      );
    } else {
      // For single slide: keep original compact layout
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(slide.title),
          const SizedBox(height: 16),
          Text(
            slide.content,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: modern.ModernDesignSystem.textPrimary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          if (slide.visualElements != null && slide.visualElements!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildVisualElements(slide.visualElements!),
          ],
        ],
      );
    }
  }
  
  Widget _buildVisualElements(List<TutorialVisual> elements) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16.0,
      runSpacing: 8.0,
      children: elements.map((element) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (element.type == 'icon')
              Icon(
                element.data as IconData,
                color: modern.ModernDesignSystem.textSecondary,
                size: element.size ?? 28,
              ),
            if (element.label != null) ...[
              const SizedBox(height: 4),
              Text(
                element.label!,
                style: TextStyle(
                  color: modern.ModernDesignSystem.textTertiary,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      }).toList(),
    );
  }
  
  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _allSlides.length,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? Colors.white
                : Colors.white.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: const DecorationImage(
              image: AssetImage('assets/images/player/capybara_face.png'),
              fit: BoxFit.cover,
            ),
             border: Border.all(color: modern.ModernDesignSystem.borderPrimary, width: 2)
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
              textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black54,
                offset: Offset(2.0, 2.0),
              ),
            ]
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main action buttons row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Skip options (show based on availability)
            if (widget.onSkipSingle != null || widget.onSkipEntireTutorial != null)
              _buildSkipButton()
            else
              const SizedBox(width: 88),
            
            // Main action button
            ElevatedButton(
              onPressed: () async {
                if (_isMultiSlide && !_isLastSlide) {
                  // Navigate to next slide
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                  );
                } else {
                  // Complete tutorial and track completion
                  if (widget.tutorialId != null) {
                    final sequenceService = TutorialSequenceService();
                    await sequenceService.completeTutorial(widget.tutorialId!, 'viewed');
                  }
                  
                  widget.onNext();
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: Text(
                _isMultiSlide && _isLastSlide 
                    ? 'Got it!' 
                    : (!_isMultiSlide && widget.isLastStep) 
                        ? 'Got it!' 
                        : 'Continue'
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSkipButton() {
    // If both skip options are available, show a dropdown/menu
    if (widget.onSkipSingle != null && widget.onSkipEntireTutorial != null) {
      return PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'skip_single' && widget.tutorialId != null) {
            final sequenceService = TutorialSequenceService();
            await sequenceService.skipTutorial(widget.tutorialId!);
            widget.onSkipSingle!();
          } else if (value == 'skip_all') {
            widget.onSkipEntireTutorial!();
          }
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'skip_single',
            child: Text(
              'Skip this step',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.8)),
            ),
          ),
          PopupMenuItem(
            value: 'skip_all',
            child: Text(
              'Skip all tutorials',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.8)),
            ),
          ),
        ],
        child: TextButton(
          onPressed: null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Skip',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
            ],
          ),
        ),
      );
    } 
    // If only single skip is available
    else if (widget.onSkipSingle != null) {
      return TextButton(
        onPressed: () async {
          if (widget.tutorialId != null) {
            final sequenceService = TutorialSequenceService();
            await sequenceService.skipTutorial(widget.tutorialId!);
          }
          widget.onSkipSingle!();
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Text(
          'Skip',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
      );
    }
    // If only entire tutorial skip is available
    else {
      return TextButton(
        onPressed: () {
          widget.onSkipEntireTutorial!();
          Navigator.of(context).pop();
        },
        child: Text(
          'Skip Tutorial',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
      );
    }
  }
}
