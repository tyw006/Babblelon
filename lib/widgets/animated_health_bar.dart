import 'package:flutter/material.dart';

class AnimatedHealthBar extends StatefulWidget {
  final int currentHealth;
  final int maxHealth;
  final String label;
  final Color primaryColor;
  final Color backgroundColor;
  final double width;
  final double height;

  const AnimatedHealthBar({
    super.key,
    required this.currentHealth,
    required this.maxHealth,
    required this.label,
    this.primaryColor = Colors.red,
    this.backgroundColor = Colors.grey,
    this.width = 120,
    this.height = 16,
  });

  @override
  State<AnimatedHealthBar> createState() => _AnimatedHealthBarState();
}

class _AnimatedHealthBarState extends State<AnimatedHealthBar>
    with TickerProviderStateMixin {
  late AnimationController _healthController;
  late AnimationController _damageController;
  late AnimationController _criticalController;
  late Animation<double> _healthAnimation;
  late Animation<double> _damageFlash;
  late Animation<double> _criticalPulse;
  
  int _previousHealth = 0;

  @override
  void initState() {
    super.initState();
    _previousHealth = widget.currentHealth;
    
    _healthController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _damageController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _criticalController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _healthAnimation = Tween<double>(
      begin: 0.0,
      end: widget.currentHealth / widget.maxHealth,
    ).animate(CurvedAnimation(
      parent: _healthController,
      curve: Curves.easeOutCubic,
    ));
    
    _damageFlash = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _damageController, curve: Curves.easeOut),
    );
    
    _criticalPulse = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _criticalController, curve: Curves.easeInOut),
    );
    
    _healthController.forward();
    
    // Start critical animation if health is low
    if (widget.currentHealth / widget.maxHealth <= 0.2) {
      _criticalController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedHealthBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.currentHealth != widget.currentHealth) {
      // Trigger damage flash if health decreased
      if (widget.currentHealth < _previousHealth) {
        _damageController.forward().then((_) => _damageController.reverse());
      }
      
      // Update health animation
      _healthAnimation = Tween<double>(
        begin: _healthAnimation.value,
        end: widget.currentHealth / widget.maxHealth,
      ).animate(CurvedAnimation(
        parent: _healthController,
        curve: Curves.easeOutCubic,
      ));
      
      _healthController.reset();
      _healthController.forward();
      
      // Handle critical health animation
      final healthPercent = widget.currentHealth / widget.maxHealth;
      if (healthPercent <= 0.2 && !_criticalController.isAnimating) {
        _criticalController.repeat(reverse: true);
      } else if (healthPercent > 0.2 && _criticalController.isAnimating) {
        _criticalController.stop();
        _criticalController.reset();
      }
      
      _previousHealth = widget.currentHealth;
    }
  }

  @override
  void dispose() {
    _healthController.dispose();
    _damageController.dispose();
    _criticalController.dispose();
    super.dispose();
  }

  // Dynamic font size calculation based on label length
  double _calculateFontSize(String label) {
    if (label.length <= 6) return 12.0;
    if (label.length <= 10) return 11.0;
    if (label.length <= 14) return 10.0;
    return 9.0; // For very long names
  }

  Color _getHealthColor(double healthPercent) {
    if (healthPercent > 0.6) return Colors.green.shade400;
    if (healthPercent > 0.3) return Colors.orange.shade400;
    return Colors.red.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final healthPercent = widget.currentHealth / widget.maxHealth;
    final dynamicColor = _getHealthColor(healthPercent);
    final fontSize = _calculateFontSize(widget.label);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with dynamic font size
        SizedBox(
          height: 16, // Fixed height to prevent layout shifts
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        
        const SizedBox(height: 2),
        
        // Health bar container
        AnimatedBuilder(
          animation: Listenable.merge([_healthAnimation, _damageFlash, _criticalPulse]),
          builder: (context, child) {
            return Transform.scale(
              scale: healthPercent <= 0.2 ? _criticalPulse.value : 1.0,
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  child: Stack(
                    children: [
                      // Background
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: widget.backgroundColor,
                      ),
                      
                      // Health bar with gradient
                      FractionallySizedBox(
                        widthFactor: _healthAnimation.value.clamp(0.0, 1.0),
                        child: Container(
                          height: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                dynamicColor,
                                dynamicColor.withOpacity(0.8),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),
                      ),
                      
                      // Damage flash overlay
                      if (_damageFlash.value > 0)
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.white.withOpacity(_damageFlash.value * 0.6),
                        ),
                      
                      // Shine effect
                      Positioned(
                        left: -20,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.0),
                                Colors.white.withOpacity(0.3),
                                Colors.white.withOpacity(0.0),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 2),
        
        // Health text
        Text(
          '${widget.currentHealth}/${widget.maxHealth}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
} 