import 'package:flutter/material.dart';
import 'package:babblelon/services/authentication_service.dart';

/// Platform-aware authentication button that adapts its appearance and behavior
/// based on the authentication provider and current platform
class AuthButton extends StatelessWidget {
  final AuthProvider provider;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final double? height;

  const AuthButton({
    super.key,
    required this.provider,
    required this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthenticationService();
    final displayName = authService.getProviderDisplayName(provider);
    
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isDisabled || isLoading ? null : onPressed,
        style: _getButtonStyle(context),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _getTextColor(),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIcon(),
                  const SizedBox(width: 12),
                  Text(
                    displayName,
                    style: TextStyle(
                      color: _getTextColor(),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  ButtonStyle _getButtonStyle(BuildContext context) {
    switch (provider) {
      case AuthProvider.apple:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        );
      case AuthProvider.google:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.grey, width: 1),
          ),
          elevation: 2,
        );
      case AuthProvider.github:
        return ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF24292e),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        );
      case AuthProvider.email:
        return ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        );
    }
  }

  Color _getTextColor() {
    switch (provider) {
      case AuthProvider.apple:
      case AuthProvider.github:
      case AuthProvider.email:
        return Colors.white;
      case AuthProvider.google:
        return Colors.black87;
    }
  }

  Widget _buildIcon() {
    switch (provider) {
      case AuthProvider.apple:
        return const Icon(
          Icons.apple,
          size: 20,
          color: Colors.white,
        );
      case AuthProvider.google:
        // Using a simple colored circle as placeholder for Google icon
        return Container(
          width: 20,
          height: 20,
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
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case AuthProvider.github:
        return const Icon(
          Icons.code,
          size: 20,
          color: Colors.white,
        );
      case AuthProvider.email:
        return const Icon(
          Icons.email,
          size: 20,
          color: Colors.white,
        );
    }
  }
}

/// Authentication provider list widget that shows available providers
/// based on the current platform
class AuthProviderList extends StatelessWidget {
  final Function(AuthProvider) onProviderSelected;
  final bool isLoading;
  final String? loadingProvider;

  const AuthProviderList({
    super.key,
    required this.onProviderSelected,
    this.isLoading = false,
    this.loadingProvider,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthenticationService();
    final availableProviders = authService.getAvailableProviders();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...availableProviders.map((provider) {
          final providerName = provider.toString().split('.').last;
          final isProviderLoading = isLoading && loadingProvider == providerName;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AuthButton(
              provider: provider,
              isLoading: isProviderLoading,
              isDisabled: isLoading && !isProviderLoading,
              onPressed: () => onProviderSelected(provider),
            ),
          );
        }).toList(),
      ],
    );
  }
}