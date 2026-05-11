import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../shared/layouts/auth_layout.dart';
import '../../../shared/widgets/utm_primary_button.dart';
import '../../../shared/widgets/utm_text_field.dart';
import '../services/auth_service.dart';
import '../utils/auth_form_helpers.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
      _isSuccess = false;
    });

    try {
      await _authService.sendPasswordReset(_emailController.text);

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _message = 'Password reset email sent. Please check your inbox.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSuccess = false;
          _message = _resetErrorMessage(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _resetErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'user-not-found':
          return 'No account was found for that email address.';
        case 'too-many-requests':
          return 'Too many reset attempts. Please wait before trying again.';
        case 'network-request-failed':
          return 'Check your internet connection and try again.';
        default:
          return error.message ??
              'Could not send reset email. Please try again.';
      }
    }

    return 'Could not send reset email. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;

    return AuthLayout(
      title: 'Reset password',
      subtitle:
          'Enter your account email and Firebase will send a secure reset link.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UtmTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              validator: validateResetEmail,
            ),
            if (message != null) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              Text(
                message,
                style: TextStyle(
                  color: _isSuccess
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.spacingLarge),
            UtmPrimaryButton(
              label: 'Send reset email',
              icon: Icons.lock_reset_rounded,
              isLoading: _isLoading,
              onPressed: _sendResetEmail,
            ),
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text('Back to sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
