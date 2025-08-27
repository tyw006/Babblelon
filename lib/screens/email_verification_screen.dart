import 'package:flutter/material.dart';
import 'package:babblelon/services/auth_service_interface.dart';
import 'package:babblelon/services/authentication_service.dart';

/// Screen shown to users who need to verify their email address
/// Blocks access to the app until email is confirmed
class EmailVerificationScreen extends StatefulWidget {
  final VoidCallback? onVerificationComplete;

  const EmailVerificationScreen({
    super.key,
    this.onVerificationComplete,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthServiceInterface _authService = AuthServiceFactory.getInstance();
  bool _isResending = false;
  bool _isChecking = false;
  DateTime? _lastResendTime;

  @override
  void initState() {
    super.initState();
    _startVerificationPolling();
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _authService.currentUserEmail ?? 'your email';

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeader(),
              const SizedBox(height: 40),
              _buildEmailInfo(userEmail),
              const SizedBox(height: 32),
              _buildVerificationStatus(),
              const SizedBox(height: 40),
              _buildResendButton(),
              const SizedBox(height: 24),
              _buildCheckButton(),
              const SizedBox(height: 40),
              _buildSignOutButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.mark_email_unread,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Verify Your Email',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We need to verify your email address to continue',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailInfo(String email) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.email, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Verification Email Sent',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ve sent a verification link to:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Click the link in your email to verify your account and continue to BabbleOn.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStatus() {
    return StreamBuilder<AuthState>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (_authService.isEmailVerified) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onVerificationComplete?.call();
          });
          
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email Verified!',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Redirecting to app...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green.withOpacity(0.8),
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
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Pending',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Check your email and click the verification link',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.withOpacity(0.8),
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

  Widget _buildResendButton() {
    final canResend = _lastResendTime == null || 
        DateTime.now().difference(_lastResendTime!).inSeconds >= 60;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canResend && !_isResending ? _resendVerificationEmail : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isResending
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                canResend ? 'Resend Verification Email' : 'Please wait 60 seconds',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  Widget _buildCheckButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isChecking ? null : _checkVerificationStatus,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white54),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isChecking
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              )
            : const Text(
                'I\'ve Verified My Email',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return TextButton(
      onPressed: _signOut,
      child: const Text(
        'Sign Out',
        style: TextStyle(
          color: Colors.white54,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Future<void> _resendVerificationEmail() async {
    setState(() {
      _isResending = true;
    });

    try {
      final success = await _authService.sendEmailVerification();
      if (success) {
        setState(() {
          _lastResendTime = DateTime.now();
        });
        _showSnackBar('Verification email sent!', Colors.green);
      } else {
        _showSnackBar('Failed to send verification email', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  Future<void> _checkVerificationStatus() async {
    setState(() {
      _isChecking = true;
    });

    try {
      // Refresh the user session to get updated verification status
      await _authService.refreshToken();
      
      if (_authService.isEmailVerified) {
        _showSnackBar('Email verified successfully!', Colors.green);
        widget.onVerificationComplete?.call();
      } else {
        _showSnackBar('Email not yet verified. Please check your email.', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Error checking verification status: $e', Colors.red);
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      _showSnackBar('Error signing out: $e', Colors.red);
    }
  }

  void _startVerificationPolling() {
    // Poll for verification status every 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && !_authService.isEmailVerified) {
        _authService.refreshToken().then((_) {
          if (_authService.isEmailVerified && mounted) {
            widget.onVerificationComplete?.call();
          } else if (mounted) {
            _startVerificationPolling();
          }
        });
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}