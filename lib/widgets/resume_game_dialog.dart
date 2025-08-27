import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/models/local_storage_models.dart';
import 'package:babblelon/services/game_save_service.dart';
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/theme/modern_design_system.dart' as modern;

/// Dialog that appears when a level has existing save data
/// Offers players the choice to resume from last save or start fresh
class ResumeGameDialog extends ConsumerStatefulWidget {
  final String levelId;
  final GameSaveState saveData;
  final VoidCallback onResume;
  final VoidCallback onStartNew;

  const ResumeGameDialog({
    super.key,
    required this.levelId,
    required this.saveData,
    required this.onResume,
    required this.onStartNew,
  });

  @override
  ConsumerState<ResumeGameDialog> createState() => _ResumeGameDialogState();
}

class _ResumeGameDialogState extends ConsumerState<ResumeGameDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatTimeSince(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      // Simple date formatting without intl dependency
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[timestamp.month - 1]} ${timestamp.day}, ${timestamp.year}';
    }
  }

  String _getGameTypeDisplayName() {
    switch (widget.saveData.gameType) {
      case 'babblelon_game':
        return 'Exploration';
      case 'boss_fight':
        return 'Boss Battle';
      default:
        return widget.saveData.gameType;
    }
  }

  IconData _getGameTypeIcon() {
    switch (widget.saveData.gameType) {
      case 'babblelon_game':
        return Icons.explore;
      case 'boss_fight':
        return Icons.sports_kabaddi;
      default:
        return Icons.gamepad;
    }
  }

  Color _getProgressColor() {
    final progress = widget.saveData.progressPercentage;
    if (progress < 25) return Colors.red;
    if (progress < 50) return Colors.orange;
    if (progress < 75) return Colors.yellow;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: isSmallScreen ? screenSize.height * 0.9 : 600,
                ),
                decoration: BoxDecoration(
                  gradient: modern.ModernDesignSystem.surfaceGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: modern.ModernDesignSystem.primaryAccent.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(
                            Icons.save_alt_rounded,
                            color: modern.ModernDesignSystem.primaryAccent,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Continue Your Adventure?',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: modern.ModernDesignSystem.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Save Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.deepPurple.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Game Type and Time
                            Row(
                              children: [
                                Icon(
                                  _getGameTypeIcon(),
                                  color: modern.ModernDesignSystem.secondaryAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getGameTypeDisplayName(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: modern.ModernDesignSystem.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatTimeSince(widget.saveData.timestamp),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: modern.ModernDesignSystem.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Progress Bar
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Progress',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: modern.ModernDesignSystem.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      '${widget.saveData.progressPercentage.toInt()}%',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _getProgressColor(),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: widget.saveData.progressPercentage / 100,
                                  backgroundColor: Colors.grey.withValues(alpha: 0.3),
                                  valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
                                  borderRadius: BorderRadius.circular(8),
                                  minHeight: 8,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Simplified display without potentially inaccurate metrics
                            if (widget.saveData.gameType == 'boss_fight') ...[
                              Row(
                                children: [
                                  _StatChip(
                                    icon: Icons.favorite,
                                    label: 'HP: ${widget.saveData.playerHealth}',
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Action Buttons
                      if (!_isDeleting) ...[
                        // Resume Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              debugPrint('🎮 ResumeGameDialog: Resume button pressed');
                              ref.playButtonSound();
                              debugPrint('🎮 ResumeGameDialog: Calling onResume callback');
                              widget.onResume();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: modern.ModernDesignSystem.primaryAccent,
                              foregroundColor: modern.ModernDesignSystem.textOnColor,
                              elevation: 8,
                              shadowColor: modern.ModernDesignSystem.primaryAccent.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_arrow_rounded, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Resume Game',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Start New Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _showStartNewConfirmation,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: modern.ModernDesignSystem.textPrimary,
                              side: BorderSide(color: modern.ModernDesignSystem.borderPrimary, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.refresh_rounded, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Start New Game',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Deleting state
                        const SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Center(
                            child: CircularProgressIndicator(color: Colors.deepPurple),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showStartNewConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Start New Game?',
          style: const TextStyle(
            color: modern.ModernDesignSystem.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently delete your saved progress. Are you sure?',
          style: const TextStyle(color: modern.ModernDesignSystem.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.playButtonSound();
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: const TextStyle(color: modern.ModernDesignSystem.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              debugPrint('🎮 ResumeGameDialog: Delete & Start New button pressed');
              ref.playButtonSound();
              final navigator = Navigator.of(context);
              navigator.pop(); // Close confirmation dialog only
              
              setState(() {
                _isDeleting = true;
              });

              // Delete all saves for this level (exploration + all boss fights)
              try {
                final saveService = GameSaveService();
                await saveService.deleteAllLevelSaves(widget.levelId);
                debugPrint('🗑️ ResumeGameDialog: Deleted all saves for ${widget.levelId}');
              } catch (e) {
                debugPrint('❌ ResumeGameDialog: Failed to delete save: $e');
              }

              if (mounted) {
                debugPrint('🎮 ResumeGameDialog: Calling onStartNew callback');
                widget.onStartNew(); // This will pop the resume dialog with false
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Delete & Start New',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: modern.ModernDesignSystem.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}