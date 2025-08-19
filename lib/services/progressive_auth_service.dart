import 'package:flutter/foundation.dart';
import 'package:babblelon/services/authentication_service.dart';
import 'package:babblelon/services/auth_service_interface.dart';

/// Progressive authentication flow that gradually increases security requirements
/// based on user actions and feature access needs
class ProgressiveAuthService extends ChangeNotifier {
  final AuthServiceInterface _authService;
  final AuthenticationService _platformService;

  ProgressiveAuthService()
      : _authService = AuthServiceFactory.getInstance(),
        _platformService = AuthenticationService() {
    _listenToAuthChanges();
  }

  // Authentication levels for progressive security
  AuthLevel _currentLevel = AuthLevel.none;
  List<String> _completedSteps = [];
  Map<String, dynamic> _userCapabilities = {};

  AuthLevel get currentLevel => _currentLevel;
  List<String> get completedSteps => List.from(_completedSteps);
  Map<String, dynamic> get userCapabilities => Map.from(_userCapabilities);

  void _listenToAuthChanges() {
    _authService.authStateChanges.listen((authState) {
      _updateAuthenticationLevel(authState);
    });
  }

  /// Check if user has sufficient authentication level for a feature
  bool canAccess(AuthRequirement requirement) {
    switch (requirement) {
      case AuthRequirement.none:
        return true;
      case AuthRequirement.basic:
        return _currentLevel.index >= AuthLevel.basicAuth.index;
      case AuthRequirement.verified:
        return _currentLevel.index >= AuthLevel.verifiedAuth.index;
      case AuthRequirement.multiProvider:
        return _currentLevel.index >= AuthLevel.multiProviderAuth.index;
      case AuthRequirement.premium:
        return _currentLevel.index >= AuthLevel.premiumAuth.index;
    }
  }

  /// Get next authentication step for the user
  AuthStep? getNextStep() {
    if (!_authService.isAuthenticated) {
      return AuthStep(
        id: 'initial_auth',
        title: 'Sign In',
        description: 'Choose your preferred sign-in method',
        type: AuthStepType.initialAuth,
        level: AuthLevel.basicAuth,
        isRequired: true,
      );
    }

    if (!_authService.isEmailVerified && _platformService.getPlatformConfig().requireEmailVerification) {
      return AuthStep(
        id: 'email_verification',
        title: 'Verify Email',
        description: 'Verify your email address for security',
        type: AuthStepType.emailVerification,
        level: AuthLevel.verifiedAuth,
        isRequired: true,
      );
    }

    // Check if user should link additional providers for better security
    return _getOptionalSecurityStep();
  }

  /// Get all available authentication steps
  List<AuthStep> getAllSteps() {
    final steps = <AuthStep>[];

    // Initial authentication
    steps.add(AuthStep(
      id: 'initial_auth',
      title: 'Sign In',
      description: 'Create account or sign in',
      type: AuthStepType.initialAuth,
      level: AuthLevel.basicAuth,
      isRequired: true,
      isCompleted: _authService.isAuthenticated,
    ));

    // Email verification
    if (_platformService.getPlatformConfig().requireEmailVerification) {
      steps.add(AuthStep(
        id: 'email_verification',
        title: 'Verify Email',
        description: 'Verify your email address',
        type: AuthStepType.emailVerification,
        level: AuthLevel.verifiedAuth,
        isRequired: true,
        isCompleted: _authService.isEmailVerified,
      ));
    }

    // Multi-provider linking
    steps.add(AuthStep(
      id: 'multi_provider',
      title: 'Link Additional Methods',
      description: 'Add more sign-in methods for security',
      type: AuthStepType.providerLinking,
      level: AuthLevel.multiProviderAuth,
      isRequired: false,
      isCompleted: _completedSteps.contains('multi_provider'),
    ));

    // Profile completion
    steps.add(AuthStep(
      id: 'profile_completion',
      title: 'Complete Profile',
      description: 'Add display name and preferences',
      type: AuthStepType.profileCompletion,
      level: AuthLevel.verifiedAuth,
      isRequired: false,
      isCompleted: _completedSteps.contains('profile_completion'),
    ));

    return steps;
  }

  /// Mark an authentication step as completed
  Future<void> completeStep(String stepId, {Map<String, dynamic>? data}) async {
    if (!_completedSteps.contains(stepId)) {
      _completedSteps.add(stepId);
      
      // Update capabilities based on completed step
      await _updateCapabilities(stepId, data);
      
      // Re-evaluate authentication level
      await _evaluateAuthenticationLevel();
      
      notifyListeners();
    }
  }

  /// Get authentication progress as percentage
  double getProgress() {
    final allSteps = getAllSteps();
    final requiredSteps = allSteps.where((step) => step.isRequired).toList();
    final completedRequired = requiredSteps.where((step) => step.isCompleted).length;
    
    if (requiredSteps.isEmpty) return 1.0;
    return completedRequired / requiredSteps.length;
  }

  /// Get feature access summary
  Map<String, bool> getFeatureAccess() {
    return {
      'basic_gameplay': canAccess(AuthRequirement.basic),
      'cloud_saves': canAccess(AuthRequirement.verified),
      'social_features': canAccess(AuthRequirement.verified),
      'premium_content': canAccess(AuthRequirement.premium),
      'advanced_analytics': canAccess(AuthRequirement.multiProvider),
      'account_recovery': canAccess(AuthRequirement.multiProvider),
    };
  }

  /// Check what features would be unlocked by completing authentication
  Map<String, List<String>> getUpgradeIncentives() {
    final currentAccess = getFeatureAccess();
    final incentives = <String, List<String>>{};

    if (!canAccess(AuthRequirement.verified)) {
      incentives['Email Verification'] = [
        'Cloud save synchronization',
        'Cross-device progress',
        'Social features',
        'Leaderboards',
      ];
    }

    if (!canAccess(AuthRequirement.multiProvider)) {
      incentives['Additional Sign-in Methods'] = [
        'Enhanced account security',
        'Account recovery options',
        'Advanced analytics',
        'Priority support',
      ];
    }

    return incentives;
  }

  void _updateAuthenticationLevel(AuthState authState) {
    switch (authState) {
      case AuthState.unauthenticated:
        _currentLevel = AuthLevel.none;
        _completedSteps.clear();
        _userCapabilities.clear();
        break;
      case AuthState.authenticated:
        _evaluateAuthenticationLevel();
        break;
      case AuthState.loading:
        // Keep current level during loading
        break;
      case AuthState.error:
        // Handle auth errors gracefully
        break;
    }
    notifyListeners();
  }

  Future<void> _evaluateAuthenticationLevel() async {
    if (!_authService.isAuthenticated) {
      _currentLevel = AuthLevel.none;
      return;
    }

    // Basic authentication achieved
    _currentLevel = AuthLevel.basicAuth;

    // Check for email verification
    if (_authService.isEmailVerified) {
      _currentLevel = AuthLevel.verifiedAuth;
    }

    // Check for multiple providers
    try {
      final linkedProviders = await _authService.getLinkedProviders();
      if (linkedProviders.length >= 2) {
        _currentLevel = AuthLevel.multiProviderAuth;
      }
    } catch (e) {
      debugPrint('Error checking linked providers: $e');
    }

    // Premium level would be checked against subscription status
    // _currentLevel = AuthLevel.premiumAuth;
  }

  AuthStep? _getOptionalSecurityStep() {
    // Suggest linking additional providers if user only has one
    return AuthStep(
      id: 'security_upgrade',
      title: 'Enhance Security',
      description: 'Link additional sign-in methods',
      type: AuthStepType.securityUpgrade,
      level: AuthLevel.multiProviderAuth,
      isRequired: false,
    );
  }

  Future<void> _updateCapabilities(String stepId, Map<String, dynamic>? data) async {
    switch (stepId) {
      case 'initial_auth':
        _userCapabilities['can_save_progress'] = true;
        _userCapabilities['can_access_basic_features'] = true;
        break;
      case 'email_verification':
        _userCapabilities['can_sync_cloud'] = true;
        _userCapabilities['can_use_social_features'] = true;
        _userCapabilities['can_receive_notifications'] = true;
        break;
      case 'multi_provider':
        _userCapabilities['enhanced_security'] = true;
        _userCapabilities['account_recovery'] = true;
        _userCapabilities['priority_support'] = true;
        break;
      case 'profile_completion':
        _userCapabilities['personalized_experience'] = true;
        _userCapabilities['social_profile'] = true;
        break;
    }
  }
}

/// Authentication levels in progressive order
enum AuthLevel {
  none,           // No authentication
  basicAuth,      // Basic authentication (any provider)
  verifiedAuth,   // Email verified
  multiProviderAuth, // Multiple providers linked
  premiumAuth,    // Premium subscription + multi-provider
}

/// Feature access requirements
enum AuthRequirement {
  none,
  basic,
  verified,
  multiProvider,
  premium,
}

/// Authentication step types
enum AuthStepType {
  initialAuth,
  emailVerification,
  providerLinking,
  profileCompletion,
  securityUpgrade,
}

/// Individual authentication step
class AuthStep {
  final String id;
  final String title;
  final String description;
  final AuthStepType type;
  final AuthLevel level;
  final bool isRequired;
  final bool isCompleted;
  final Map<String, dynamic>? metadata;

  const AuthStep({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.level,
    required this.isRequired,
    this.isCompleted = false,
    this.metadata,
  });

  AuthStep copyWith({
    String? id,
    String? title,
    String? description,
    AuthStepType? type,
    AuthLevel? level,
    bool? isRequired,
    bool? isCompleted,
    Map<String, dynamic>? metadata,
  }) {
    return AuthStep(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      level: level ?? this.level,
      isRequired: isRequired ?? this.isRequired,
      isCompleted: isCompleted ?? this.isCompleted,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Progressive authentication flow widget helper
class ProgressiveAuthHelper {
  static String getStepStatusEmoji(AuthStep step) {
    if (step.isCompleted) return '✅';
    if (step.isRequired) return '🔴';
    return '🔵';
  }

  static String getLevelDescription(AuthLevel level) {
    switch (level) {
      case AuthLevel.none:
        return 'Not authenticated';
      case AuthLevel.basicAuth:
        return 'Basic access';
      case AuthLevel.verifiedAuth:
        return 'Verified account';
      case AuthLevel.multiProviderAuth:
        return 'Enhanced security';
      case AuthLevel.premiumAuth:
        return 'Premium member';
    }
  }

  static String getRequirementDescription(AuthRequirement requirement) {
    switch (requirement) {
      case AuthRequirement.none:
        return 'No authentication needed';
      case AuthRequirement.basic:
        return 'Sign in required';
      case AuthRequirement.verified:
        return 'Verified account required';
      case AuthRequirement.multiProvider:
        return 'Enhanced security required';
      case AuthRequirement.premium:
        return 'Premium membership required';
    }
  }
}