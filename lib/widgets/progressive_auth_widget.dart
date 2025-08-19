import 'package:flutter/material.dart';
import 'package:babblelon/services/progressive_auth_service.dart';
import 'package:babblelon/services/auth_service_interface.dart';
import 'package:babblelon/screens/authentication_screen.dart';
import 'package:babblelon/widgets/account_linking_widget.dart';

/// Widget that guides users through progressive authentication steps
/// Shows current progress and suggests next steps to enhance security
class ProgressiveAuthWidget extends StatefulWidget {
  final bool showDetailedSteps;
  final Function(AuthStep)? onStepTapped;
  final Function(AuthLevel)? onLevelChanged;

  const ProgressiveAuthWidget({
    super.key,
    this.showDetailedSteps = true,
    this.onStepTapped,
    this.onLevelChanged,
  });

  @override
  State<ProgressiveAuthWidget> createState() => _ProgressiveAuthWidgetState();
}

class _ProgressiveAuthWidgetState extends State<ProgressiveAuthWidget> {
  late ProgressiveAuthService _progressiveAuth;
  final AuthServiceInterface _authService = AuthServiceFactory.getInstance();

  @override
  void initState() {
    super.initState();
    _progressiveAuth = ProgressiveAuthService();
    _progressiveAuth.addListener(_onAuthProgressChanged);
  }

  @override
  void dispose() {
    _progressiveAuth.removeListener(_onAuthProgressChanged);
    _progressiveAuth.dispose();
    super.dispose();
  }

  void _onAuthProgressChanged() {
    if (mounted) {
      setState(() {});
      widget.onLevelChanged?.call(_progressiveAuth.currentLevel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildProgressIndicator(),
        const SizedBox(height: 24),
        if (widget.showDetailedSteps) ...[
          _buildStepsSection(),
          const SizedBox(height: 24),
        ],
        _buildFeatureAccess(),
        const SizedBox(height: 16),
        _buildNextStepCard(),
      ],
    );
  }

  Widget _buildHeader() {
    final level = _progressiveAuth.currentLevel;
    final progress = _progressiveAuth.getProgress();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getLevelIcon(level),
              color: _getLevelColor(level),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Security',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ProgressiveAuthHelper.getLevelDescription(level),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _getLevelColor(level),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getLevelColor(level).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getLevelColor(level)),
              ),
              child: Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: _getLevelColor(level),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final progress = _progressiveAuth.getProgress();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Setup Progress',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white70,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}% Complete',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation(_getLevelColor(_progressiveAuth.currentLevel)),
        ),
      ],
    );
  }

  Widget _buildStepsSection() {
    final steps = _progressiveAuth.getAllSteps();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Authentication Steps',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...steps.map((step) => _buildStepCard(step)).toList(),
      ],
    );
  }

  Widget _buildStepCard(AuthStep step) {
    final isCompleted = step.isCompleted;
    final isRequired = step.isRequired;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleStepTap(step),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCompleted 
                  ? Colors.green.withOpacity(0.1)
                  : (isRequired ? Colors.orange.withOpacity(0.1) : Colors.white.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCompleted 
                    ? Colors.green.withOpacity(0.3)
                    : (isRequired ? Colors.orange.withOpacity(0.3) : Colors.white.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted 
                        ? Colors.green
                        : (isRequired ? Colors.orange : Colors.grey),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : _getStepTypeIcon(step.type),
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              step.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          if (isRequired && !isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Required',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        step.description,
                        style: TextStyle(
                          color: isCompleted ? Colors.green.withOpacity(0.8) : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isCompleted)
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureAccess() {
    final featureAccess = _progressiveAuth.getFeatureAccess();
    final accessibleFeatures = featureAccess.entries.where((e) => e.value).map((e) => e.key).toList();
    final lockedFeatures = featureAccess.entries.where((e) => !e.value).map((e) => e.key).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Feature Access',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (accessibleFeatures.isNotEmpty) ...[
          _buildFeatureGroup('Available Features', accessibleFeatures, Colors.green, true),
          if (lockedFeatures.isNotEmpty) const SizedBox(height: 12),
        ],
        if (lockedFeatures.isNotEmpty)
          _buildFeatureGroup('Locked Features', lockedFeatures, Colors.red, false),
      ],
    );
  }

  Widget _buildFeatureGroup(String title, List<String> features, Color color, bool isAccessible) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAccessible ? Icons.check_circle : Icons.lock,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: features.map((feature) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatFeatureName(feature),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepCard() {
    final nextStep = _progressiveAuth.getNextStep();
    if (nextStep == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_user, color: Colors.green, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Set!',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Your account security is fully configured.',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.arrow_forward, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Next Step',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            nextStep.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            nextStep.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _handleStepTap(nextStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Complete ${nextStep.title}'),
            ),
          ),
        ],
      ),
    );
  }

  void _handleStepTap(AuthStep step) {
    widget.onStepTapped?.call(step);
    
    switch (step.type) {
      case AuthStepType.initialAuth:
        _showAuthenticationScreen();
        break;
      case AuthStepType.emailVerification:
        _handleEmailVerification();
        break;
      case AuthStepType.providerLinking:
      case AuthStepType.securityUpgrade:
        _showProviderLinking();
        break;
      case AuthStepType.profileCompletion:
        _handleProfileCompletion();
        break;
    }
  }

  void _showAuthenticationScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AuthenticationScreen(
          onAuthSuccess: (result) {
            Navigator.of(context).pop();
            _progressiveAuth.completeStep('initial_auth', data: {
              'provider': 'unknown', // Would be passed from auth result
              'timestamp': DateTime.now().toIso8601String(),
            });
          },
        ),
      ),
    );
  }

  void _handleEmailVerification() async {
    try {
      final success = await _authService.sendEmailVerification();
      if (success) {
        _showSnackBar('Verification email sent! Check your inbox.', Colors.blue);
      } else {
        _showSnackBar('Failed to send verification email', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  void _showProviderLinking() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2a2a3e),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.7,
        child: AccountLinkingWidget(
          onLinkSuccess: (provider) {
            Navigator.of(context).pop();
            _progressiveAuth.completeStep('multi_provider');
            _showSnackBar('Successfully linked $provider', Colors.green);
          },
        ),
      ),
    );
  }

  void _handleProfileCompletion() {
    // Would show profile completion dialog/screen
    _showSnackBar('Profile completion coming soon!', Colors.blue);
    // For now, just mark as completed
    _progressiveAuth.completeStep('profile_completion');
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getLevelColor(AuthLevel level) {
    switch (level) {
      case AuthLevel.none:
        return Colors.grey;
      case AuthLevel.basicAuth:
        return Colors.orange;
      case AuthLevel.verifiedAuth:
        return Colors.blue;
      case AuthLevel.multiProviderAuth:
        return Colors.green;
      case AuthLevel.premiumAuth:
        return Colors.purple;
    }
  }

  IconData _getLevelIcon(AuthLevel level) {
    switch (level) {
      case AuthLevel.none:
        return Icons.person_outline;
      case AuthLevel.basicAuth:
        return Icons.person;
      case AuthLevel.verifiedAuth:
        return Icons.verified_user;
      case AuthLevel.multiProviderAuth:
        return Icons.security;
      case AuthLevel.premiumAuth:
        return Icons.diamond;
    }
  }

  IconData _getStepTypeIcon(AuthStepType type) {
    switch (type) {
      case AuthStepType.initialAuth:
        return Icons.login;
      case AuthStepType.emailVerification:
        return Icons.email;
      case AuthStepType.providerLinking:
        return Icons.link;
      case AuthStepType.profileCompletion:
        return Icons.person;
      case AuthStepType.securityUpgrade:
        return Icons.security;
    }
  }

  String _formatFeatureName(String feature) {
    return feature
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

/// Compact version of progressive auth widget for smaller spaces
class CompactProgressiveAuthWidget extends StatelessWidget {
  final ProgressiveAuthService progressiveAuth;
  final VoidCallback? onTap;

  const CompactProgressiveAuthWidget({
    super.key,
    required this.progressiveAuth,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progressiveAuth,
      builder: (context, child) {
        final level = progressiveAuth.currentLevel;
        final progress = progressiveAuth.getProgress();
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    _getLevelIcon(level),
                    color: _getLevelColor(level),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Security',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _getLevelColor(level),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation(_getLevelColor(level)),
                          minHeight: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getLevelColor(AuthLevel level) {
    switch (level) {
      case AuthLevel.none: return Colors.grey;
      case AuthLevel.basicAuth: return Colors.orange;
      case AuthLevel.verifiedAuth: return Colors.blue;
      case AuthLevel.multiProviderAuth: return Colors.green;
      case AuthLevel.premiumAuth: return Colors.purple;
    }
  }

  IconData _getLevelIcon(AuthLevel level) {
    switch (level) {
      case AuthLevel.none: return Icons.person_outline;
      case AuthLevel.basicAuth: return Icons.person;
      case AuthLevel.verifiedAuth: return Icons.verified_user;
      case AuthLevel.multiProviderAuth: return Icons.security;
      case AuthLevel.premiumAuth: return Icons.diamond;
    }
  }
}