import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:babblelon/services/supabase_service.dart';
import 'package:babblelon/services/auth_service_interface.dart';

/// Profile completion state data class
class ProfileCompletionState {
  final bool isCompleted;
  final bool hasLocalProfile;
  final bool hasRemoteProfile;
  final String? userId;
  final DateTime? lastChecked;

  const ProfileCompletionState({
    required this.isCompleted,
    required this.hasLocalProfile,
    required this.hasRemoteProfile,
    this.userId,
    this.lastChecked,
  });

  ProfileCompletionState copyWith({
    bool? isCompleted,
    bool? hasLocalProfile,
    bool? hasRemoteProfile,
    String? userId,
    DateTime? lastChecked,
  }) {
    return ProfileCompletionState(
      isCompleted: isCompleted ?? this.isCompleted,
      hasLocalProfile: hasLocalProfile ?? this.hasLocalProfile,
      hasRemoteProfile: hasRemoteProfile ?? this.hasRemoteProfile,
      userId: userId ?? this.userId,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }

  @override
  String toString() {
    return 'ProfileCompletionState(isCompleted: $isCompleted, hasLocal: $hasLocalProfile, hasRemote: $hasRemoteProfile, userId: $userId)';
  }
}

/// Provider that checks profile completion state
final profileCompletionProvider = FutureProvider.autoDispose<ProfileCompletionState>((ref) async {
  return await _checkProfileCompletion();
});

/// Provider for refreshing profile completion state
final profileRefreshProvider = Provider<void Function()>((ref) {
  return () {
    debugPrint('🔄 ProfileProvider: Refreshing profile completion state');
    ref.invalidate(profileCompletionProvider);
  };
});

/// Check profile completion from both local and remote sources
Future<ProfileCompletionState> _checkProfileCompletion() async {
  try {
      // Get current user ID
      final authService = AuthServiceFactory.getInstance();
      final userId = authService.currentUserId;
      
      debugPrint('🔍 ProfileCompletionWatcher: Checking for user: $userId');
      
      if (userId == null) {
        debugPrint('❌ ProfileCompletionWatcher: No user ID');
        return const ProfileCompletionState(
          isCompleted: false,
          hasLocalProfile: false,
          hasRemoteProfile: false,
        );
      }

      // Check local Isar database
      final isarService = IsarService();
      final localProfile = await isarService.getPlayerProfile(userId);
      final hasLocalProfile = localProfile != null;
      final isLocalComplete = localProfile?.onboardingCompleted == true;
      
      debugPrint('🔍 ProfileCompletionWatcher: Local profile found: $hasLocalProfile');
      debugPrint('🔍 ProfileCompletionWatcher: Local completed: $isLocalComplete');

      // If local profile is complete, return immediately
      if (isLocalComplete) {
        return ProfileCompletionState(
          isCompleted: true,
          hasLocalProfile: true,
          hasRemoteProfile: true, // Assume remote exists if local is complete
          userId: userId,
          lastChecked: DateTime.now(),
        );
      }

      // Check remote Supabase database
      bool hasRemoteProfile = false;
      bool isRemoteComplete = false;
      
      try {
        final supabaseService = SupabaseService();
        final remoteProfile = await supabaseService.getPlayerProfile();
        hasRemoteProfile = remoteProfile != null;
        isRemoteComplete = remoteProfile?.onboardingCompleted == true;
        
        debugPrint('🔍 ProfileCompletionWatcher: Remote profile found: $hasRemoteProfile');
        debugPrint('🔍 ProfileCompletionWatcher: Remote completed: $isRemoteComplete');
      } catch (e) {
        debugPrint('💥 ProfileCompletionWatcher: Error checking remote profile: $e');
        // Continue with local-only check
      }

      final finalCompleted = isLocalComplete || isRemoteComplete;
      debugPrint('🔍 ProfileCompletionWatcher: Final completion status: $finalCompleted');

      return ProfileCompletionState(
        isCompleted: finalCompleted,
        hasLocalProfile: hasLocalProfile,
        hasRemoteProfile: hasRemoteProfile,
        userId: userId,
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      debugPrint('💥 ProfileCompletionWatcher: Error during profile check: $e');
      return const ProfileCompletionState(
        isCompleted: false,
        hasLocalProfile: false,
        hasRemoteProfile: false,
      );
  }
}