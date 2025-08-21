import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/models/local_storage_models.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart' as cartoon;
import 'package:babblelon/providers/player_data_providers.dart';
import 'package:babblelon/services/auth_service_interface.dart';

/// Universal stats bar component - overflow-proof inline design
/// Displays stats horizontally without cards to prevent overflow issues
class UniversalStatsRow extends ConsumerWidget {
  const UniversalStatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current authenticated user ID
    final authService = AuthServiceFactory.getInstance();
    final currentUserId = authService.currentUserId;
    
    // If no authenticated user, show placeholder stats
    if (currentUserId == null) {
      return _buildInlineStats(null);
    }
    
    // Use the playerProfileProvider with the authenticated user ID
    final profileAsyncValue = ref.watch(playerProfileProvider(currentUserId));
    
    return profileAsyncValue.when(
      data: (profile) => _buildInlineStats(profile),
      loading: () => _buildInlineStats(null, isLoading: true),
      error: (error, stackTrace) => _buildInlineStats(null),
    );
  }
  
  /// Build inline stats bar - overflow-proof design
  Widget _buildInlineStats(PlayerProfile? profile, {bool isLoading = false}) {
    final level = isLoading ? '...' : (profile?.playerLevel.toString() ?? '0');
    final xp = isLoading ? '...' : (profile?.experiencePoints.toString() ?? '0');
    final gold = isLoading ? '...' : (profile?.gold.toString() ?? '0');
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cartoon.CartoonDesignSystem.softPeach.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(
          color: cartoon.CartoonDesignSystem.textMuted.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInlineStatItem(
            icon: Icons.star,
            value: level,
            color: cartoon.CartoonDesignSystem.sunshineYellow,
          ),
          _buildInlineStatItem(
            icon: Icons.psychology,
            value: xp,
            color: cartoon.CartoonDesignSystem.skyBlue,
          ),
          _buildInlineStatItem(
            icon: Icons.monetization_on,
            value: gold,
            color: cartoon.CartoonDesignSystem.warmOrange,
          ),
        ],
      ),
    );
  }
  
  /// Build individual stat item - guaranteed no overflow
  Widget _buildInlineStatItem({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

