import 'package:flutter/material.dart';
import 'package:babblelon/services/authentication_service.dart';
import 'package:babblelon/services/auth_service_interface.dart';
import 'package:babblelon/widgets/auth_button.dart';

/// Widget for managing linked authentication providers on the current account
/// Allows users to link/unlink multiple authentication methods for better security
class AccountLinkingWidget extends StatefulWidget {
  final Function(String)? onLinkSuccess;
  final Function(String)? onUnlinkSuccess;
  final Function(String)? onError;

  const AccountLinkingWidget({
    super.key,
    this.onLinkSuccess,
    this.onUnlinkSuccess,
    this.onError,
  });

  @override
  State<AccountLinkingWidget> createState() => _AccountLinkingWidgetState();
}

class _AccountLinkingWidgetState extends State<AccountLinkingWidget> {
  final AuthServiceInterface _authService = AuthServiceFactory.getInstance();
  final AuthenticationService _platformService = AuthenticationService();
  
  List<AuthProvider> _linkedProviders = [];
  List<AuthProvider> _availableProviders = [];
  bool _isLoading = false;
  String? _operationInProgress;

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    if (!_authService.isAuthenticated) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final linked = await _authService.getLinkedProviders();
      final available = _platformService.getAvailableProviders();

      setState(() {
        _linkedProviders = linked;
        _availableProviders = available;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load provider data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authService.isAuthenticated) {
      return const Center(
        child: Text(
          'Please authenticate first',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else ...[
          _buildLinkedProvidersSection(),
          const SizedBox(height: 24),
          _buildAvailableProvidersSection(),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Linking',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your authentication methods for better security and convenience.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildLinkedProvidersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.link, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(
              'Linked Providers (${_linkedProviders.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_linkedProviders.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No providers found. This may indicate an issue with your account setup.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          )
        else
          ...(_linkedProviders.map((provider) => _buildLinkedProviderCard(provider)).toList()),
      ],
    );
  }

  Widget _buildLinkedProviderCard(AuthProvider provider) {
    final isOperationInProgress = _operationInProgress == provider.toString();
    final canUnlink = _linkedProviders.length > 1; // Must keep at least one method
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          _buildProviderIcon(provider, Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _platformService.getProviderDisplayName(provider).replaceAll('Continue with ', ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Linked to your account',
                  style: TextStyle(
                    color: Colors.green.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (canUnlink)
            IconButton(
              onPressed: isOperationInProgress ? null : () => _unlinkProvider(provider),
              icon: isOperationInProgress
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link_off, color: Colors.red, size: 20),
              tooltip: 'Unlink provider',
            )
          else
            Tooltip(
              message: 'Cannot unlink last authentication method',
              child: Icon(
                Icons.lock,
                color: Colors.grey.withOpacity(0.5),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvailableProvidersSection() {
    final unlinkedProviders = _availableProviders
        .where((provider) => !_linkedProviders.contains(provider))
        .toList();

    if (unlinkedProviders.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_link, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Available to Link',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All available authentication methods are already linked!',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.add_link, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text(
              'Available to Link (${unlinkedProviders.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...unlinkedProviders.map((provider) => _buildAvailableProviderCard(provider)).toList(),
      ],
    );
  }

  Widget _buildAvailableProviderCard(AuthProvider provider) {
    final isOperationInProgress = _operationInProgress == provider.toString();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isOperationInProgress ? null : () => _linkProvider(provider),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                _buildProviderIcon(provider, Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _platformService.getProviderDisplayName(provider).replaceAll('Continue with ', ''),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Tap to link to your account',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOperationInProgress)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.add, color: Colors.blue, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderIcon(AuthProvider provider, Color color) {
    switch (provider) {
      case AuthProvider.apple:
        return Icon(Icons.apple, color: color, size: 24);
      case AuthProvider.google:
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Text(
              'G',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case AuthProvider.github:
        return Icon(Icons.code, color: color, size: 24);
      case AuthProvider.email:
        return Icon(Icons.email, color: color, size: 24);
    }
  }

  Future<void> _linkProvider(AuthProvider provider) async {
    setState(() {
      _operationInProgress = provider.toString();
    });

    try {
      final result = await _authService.linkProvider(provider);
      
      if (result.success) {
        widget.onLinkSuccess?.call(_platformService.getProviderDisplayName(provider));
        await _loadProviderData(); // Refresh the data
      } else {
        _showError(result.error ?? 'Failed to link provider');
      }
    } catch (e) {
      _showError('Error linking provider: $e');
    } finally {
      if (mounted) {
        setState(() {
          _operationInProgress = null;
        });
      }
    }
  }

  Future<void> _unlinkProvider(AuthProvider provider) async {
    // Show confirmation dialog for unlinking
    final confirmed = await _showUnlinkConfirmation(provider);
    if (!confirmed) return;

    setState(() {
      _operationInProgress = provider.toString();
    });

    try {
      final result = await _authService.unlinkProvider(provider);
      
      if (result.success) {
        widget.onUnlinkSuccess?.call(_platformService.getProviderDisplayName(provider));
        await _loadProviderData(); // Refresh the data
      } else {
        _showError(result.error ?? 'Failed to unlink provider');
      }
    } catch (e) {
      _showError('Error unlinking provider: $e');
    } finally {
      if (mounted) {
        setState(() {
          _operationInProgress = null;
        });
      }
    }
  }

  Future<bool> _showUnlinkConfirmation(AuthProvider provider) async {
    final providerName = _platformService.getProviderDisplayName(provider).replaceAll('Continue with ', '');
    
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title: const Text('Unlink Provider', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to unlink $providerName from your account? You will no longer be able to sign in using this method.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unlink', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
    
    widget.onError?.call(message);
  }
}

/// Simple account security overview widget
class AccountSecurityOverview extends StatelessWidget {
  final AuthServiceInterface authService;

  const AccountSecurityOverview({
    super.key,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AuthProvider>>(
      future: authService.getLinkedProviders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final linkedProviders = snapshot.data!;
        final securityLevel = _calculateSecurityLevel(linkedProviders);
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getSecurityColor(securityLevel).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _getSecurityColor(securityLevel)),
          ),
          child: Row(
            children: [
              Icon(
                _getSecurityIcon(securityLevel),
                color: _getSecurityColor(securityLevel),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Security: ${_getSecurityLabel(securityLevel)}',
                      style: TextStyle(
                        color: _getSecurityColor(securityLevel),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${linkedProviders.length} authentication method${linkedProviders.length != 1 ? 's' : ''} linked',
                      style: TextStyle(
                        color: _getSecurityColor(securityLevel).withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _calculateSecurityLevel(List<AuthProvider> providers) {
    if (providers.length >= 3) return 'Excellent';
    if (providers.length >= 2) return 'Good';
    if (providers.length == 1) return 'Basic';
    return 'Poor';
  }

  Color _getSecurityColor(String level) {
    switch (level) {
      case 'Excellent': return Colors.green;
      case 'Good': return Colors.blue;
      case 'Basic': return Colors.orange;
      case 'Poor': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getSecurityIcon(String level) {
    switch (level) {
      case 'Excellent': return Icons.security;
      case 'Good': return Icons.verified_user;
      case 'Basic': return Icons.shield;
      case 'Poor': return Icons.warning;
      default: return Icons.help;
    }
  }

  String _getSecurityLabel(String level) {
    return level;
  }
}