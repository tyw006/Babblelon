import 'package:flutter/material.dart';
import '../../services/tutorial_service.dart';

class TutorialPopup extends StatefulWidget {
  final TutorialStep step;
  final bool isLastStep;
  final VoidCallback? onSkipEntireTutorial;
  final VoidCallback onNext;

  const TutorialPopup({
    super.key,
    required this.step,
    required this.isLastStep,
    this.onSkipEntireTutorial,
    required this.onNext,
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
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
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
            _buildSlideContent(_allSlides[0]),
          if (_isMultiSlide) ...[
            const SizedBox(height: 16),
            _buildPageIndicators(),
          ],
          const SizedBox(height: 24),
          _buildNavigationButtons(),
        ],
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
                  color: Colors.white.withOpacity(1.0),
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
              color: Colors.white.withOpacity(1.0),
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
                color: Colors.white.withOpacity(0.9),
                size: element.size ?? 28,
              ),
            if (element.label != null) ...[
              const SizedBox(height: 4),
              Text(
                element.label!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
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
             border: Border.all(color: Colors.white.withOpacity(0.5), width: 2)
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
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        if (widget.onSkipEntireTutorial != null)
            TextButton(
              onPressed: () {
                widget.onSkipEntireTutorial!();
                Navigator.of(context).pop();
            },
            child: Text(
              'Skip Tutorial',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            )
          else
          const SizedBox(width: 88),
        ElevatedButton(
          onPressed: () {
            if (_isMultiSlide && !_isLastSlide) {
              // Navigate to next slide
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
              );
            } else {
              // Complete tutorial
              widget.onNext();
              Navigator.of(context).pop();
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
    );
  }
}
