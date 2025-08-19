import 'package:flutter/material.dart';
import 'package:babblelon/services/authentication_service.dart';
import 'package:babblelon/services/auth_service_interface.dart';
import 'package:babblelon/widgets/auth_button.dart';

/// Comprehensive authentication screen that handles all authentication flows
/// including OAuth, email/password, and platform-specific authentication
class AuthenticationScreen extends StatefulWidget {
  final bool requireEmailVerification;
  final Function(AuthResult)? onAuthSuccess;
  final Function(String)? onAuthError;

  const AuthenticationScreen({
    super.key,
    this.requireEmailVerification = true,
    this.onAuthSuccess,
    this.onAuthError,
  });

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final AuthServiceInterface _authService = AuthServiceFactory.getInstance();
  final AuthenticationService _platformService = AuthenticationService();
  
  bool _isLoading = false;
  String? _loadingProvider;
  bool _isSignUpMode = false;
  bool _showEmailForm = false;
  
  // Email form controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authService.authStateChanges.listen((authState) {
      if (authState == AuthState.authenticated) {
        _handleAuthSuccess();
      }
    });
  }

  void _handleAuthSuccess() {
    if (_authService.isAuthenticated) {
      final result = AuthResult.success(
        userId: _authService.currentUserId!,
        email: _authService.currentUserEmail,
        isEmailVerified: _authService.isEmailVerified,
      );
      
      widget.onAuthSuccess?.call(result);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              _buildHeader(),
              const SizedBox(height: 40),
              _buildMainContent(),
              const SizedBox(height: 32),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // App logo or icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.language,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'BabbleOn',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Learn Thai through adventure',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    if (_showEmailForm) {
      return _buildEmailAuthForm();
    } else {
      return _buildProviderAuthSection();
    }
  }

  Widget _buildProviderAuthSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose your sign-in method',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        AuthProviderList(
          onProviderSelected: _handleProviderSelection,
          isLoading: _isLoading,
          loadingProvider: _loadingProvider,
        ),
      ],
    );
  }

  Widget _buildEmailAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _showEmailForm = false;
                  });
                },
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              Text(
                _isSignUpMode ? 'Create Account' : 'Sign In',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildEmailField(),
          const SizedBox(height: 16),
          _buildPasswordField(),
          if (_isSignUpMode) ...[
            const SizedBox(height: 16),
            _buildConfirmPasswordField(),
          ],
          const SizedBox(height: 24),
          _buildEmailActionButton(),
          const SizedBox(height: 16),
          _buildToggleAuthModeButton(),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Email',
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.orange),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Password',
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.orange),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (_isSignUpMode && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Confirm Password',
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.orange),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please confirm your password';
        }
        if (value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildEmailActionButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleEmailAuth,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              _isSignUpMode ? 'Create Account' : 'Sign In',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
    );
  }

  Widget _buildToggleAuthModeButton() {
    return TextButton(
      onPressed: _isLoading ? null : () {
        setState(() {
          _isSignUpMode = !_isSignUpMode;
          _formKey.currentState?.reset();
        });
      },
      child: Text(
        _isSignUpMode 
            ? 'Already have an account? Sign In' 
            : 'Don\'t have an account? Sign Up',
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'By continuing, you agree to our Terms of Service and Privacy Policy',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white60,
          ),
        ),
        if (widget.requireEmailVerification) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Email verification required for full access',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleProviderSelection(AuthProvider provider) async {
    if (provider == AuthProvider.email) {
      setState(() {
        _showEmailForm = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingProvider = provider.toString().split('.').last;
    });

    try {
      final result = await _authService.signInWithProvider(provider);
      
      if (result.success) {
        if (widget.onAuthSuccess != null) {
          widget.onAuthSuccess!(result);
        }
      } else {
        _showError(result.error ?? 'Authentication failed');
      }
    } catch (e) {
      _showError('Authentication error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingProvider = null;
        });
      }
    }
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      AuthResult result;
      
      if (_isSignUpMode) {
        result = await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        result = await _authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (result.success) {
        if (widget.requireEmailVerification && !result.isEmailVerified) {
          _showEmailVerificationDialog();
        } else if (widget.onAuthSuccess != null) {
          widget.onAuthSuccess!(result);
        }
      } else {
        _showError(result.error ?? 'Authentication failed');
      }
    } catch (e) {
      _showError('Authentication error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showEmailVerificationDialog() {
    final TextEditingController codeController = TextEditingController();
    bool isVerifying = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a3e),
          title: const Text(
            'Verify Your Email',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'We\'ve sent a verification link to your email. You can:',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                const Text(
                  '1. Click the link in your email, OR',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const Text(
                  '2. Copy the code from the email URL and paste it here:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Verification Code',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: 'Paste code from email URL',
                    hintStyle: TextStyle(color: Colors.white30),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The code is in the URL after "code="',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
                if (isVerifying)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: isVerifying ? null : () async {
                final code = codeController.text.trim();
                if (code.isEmpty) {
                  _showError('Please enter the verification code');
                  return;
                }
                
                setDialogState(() {
                  isVerifying = true;
                });
                
                try {
                  final result = await _authService.verifyEmail(code);
                  
                  if (!mounted) return;
                  
                  if (result.success) {
                    Navigator.of(context).pop();
                    _showSuccess('Email verified successfully!');
                    widget.onAuthSuccess?.call(result);
                  } else {
                    _showError(result.error ?? 'Verification failed');
                    setDialogState(() {
                      isVerifying = false;
                    });
                  }
                } catch (e) {
                  _showError('Verification error: $e');
                  setDialogState(() {
                    isVerifying = false;
                  });
                }
              },
              child: const Text('Verify', style: TextStyle(color: Colors.orange)),
            ),
            TextButton(
              onPressed: isVerifying ? null : () async {
                setDialogState(() {
                  isVerifying = true;
                });
                
                try {
                  final success = await _authService.sendEmailVerification();
                  if (success) {
                    _showSuccess('Verification email resent!');
                  } else {
                    _showError('Failed to resend email');
                  }
                } finally {
                  setDialogState(() {
                    isVerifying = false;
                  });
                }
              },
              child: const Text('Resend Email', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
    
    widget.onAuthError?.call(message);
  }

  
  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

/// Authentication status widget that shows current user state
class AuthStatusWidget extends StatelessWidget {
  final AuthServiceInterface authService;

  const AuthStatusWidget({
    super.key,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final authState = snapshot.data ?? AuthState.unauthenticated;
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getStatusColor(authState).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _getStatusColor(authState)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(authState),
                color: _getStatusColor(authState),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _getStatusText(authState),
                style: TextStyle(
                  color: _getStatusColor(authState),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(AuthState state) {
    switch (state) {
      case AuthState.authenticated:
        return Colors.green;
      case AuthState.unauthenticated:
        return Colors.red;
      case AuthState.loading:
        return Colors.orange;
      case AuthState.error:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(AuthState state) {
    switch (state) {
      case AuthState.authenticated:
        return Icons.check_circle;
      case AuthState.unauthenticated:
        return Icons.cancel;
      case AuthState.loading:
        return Icons.hourglass_empty;
      case AuthState.error:
        return Icons.error;
    }
  }

  String _getStatusText(AuthState state) {
    switch (state) {
      case AuthState.authenticated:
        return 'Authenticated';
      case AuthState.unauthenticated:
        return 'Not Authenticated';
      case AuthState.loading:
        return 'Loading...';
      case AuthState.error:
        return 'Error';
    }
  }
}