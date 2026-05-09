import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../shared/widgets/utm_primary_button.dart';
import '../../../shared/widgets/utm_text_field.dart';
import '../../auth/services/auth_service.dart';
import '../utils/profile_form_helpers.dart';

class PasswordChangeSheet extends StatefulWidget {
  const PasswordChangeSheet({super.key, required this.authService});

  final AuthService authService;

  @override
  State<PasswordChangeSheet> createState() => _PasswordChangeSheetState();
}

class _PasswordChangeSheetState extends State<PasswordChangeSheet> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final validationMessage = validatePasswordChange(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (validationMessage != null) {
      setState(() => _errorMessage = validationMessage);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.changePasswordWithCurrentPassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _friendlyPasswordError(error));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimensions.spacingLarge,
          right: AppDimensions.spacingLarge,
          top: AppDimensions.spacingLarge,
          bottom:
              MediaQuery.viewInsetsOf(context).bottom +
              AppDimensions.spacingLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Change password',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              'Enter your current password before setting a new one.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
            UtmTextField(
              controller: _currentPasswordController,
              label: 'Current password',
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            UtmTextField(
              controller: _newPasswordController,
              label: 'New password',
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            UtmTextField(
              controller: _confirmPasswordController,
              label: 'Confirm new password',
              obscureText: true,
              textInputAction: TextInputAction.done,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppDimensions.spacingLarge),
            UtmPrimaryButton(
              label: 'Update password',
              icon: Icons.lock_reset_rounded,
              isLoading: _isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyPasswordError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'The current password is incorrect.';
      case 'weak-password':
        return 'Choose a stronger new password.';
      case 'requires-recent-login':
        return 'Please sign in again before changing your password.';
      case 'no-current-user':
        return 'Please sign in again before changing your password.';
      case 'missing-email':
        return 'This account does not have an email address available.';
      default:
        return error.message ?? 'Could not update password. Please try again.';
    }
  }
}
