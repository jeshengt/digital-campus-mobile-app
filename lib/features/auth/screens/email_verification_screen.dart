import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../features/profile/services/user_profile_service.dart';
import '../../../shared/layouts/auth_layout.dart';
import '../../../shared/widgets/utm_primary_button.dart';
import '../services/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _authService = AuthService();
  final _profileService = UserProfileService();

  bool _isLoading = false;
  String? _message;

  Future<void> _resendVerification() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await _authService.sendEmailVerification();
      if (mounted) {
        setState(() => _message = 'Verification email sent.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _continueAfterVerification() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await _authService.reloadCurrentUser();
      final user = _authService.currentUser;

      if (user == null) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.signIn,
            (_) => false,
          );
        }
        return;
      }

      if (!user.emailVerified) {
        if (mounted) {
          setState(
            () => _message = 'Please verify your email before continuing.',
          );
        }
        return;
      }

      await user.getIdToken(true);
      await _profileService.syncEmailVerified(
        uid: user.uid,
        emailVerified: true,
      );

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.roleGateway,
          (_) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Verify your email',
      subtitle:
          'Check your inbox and confirm your UTM Go account before opening role-based services.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UtmPrimaryButton(
            label: 'I verified my email',
            icon: Icons.verified_outlined,
            isLoading: _isLoading,
            onPressed: _continueAfterVerification,
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          TextButton(
            onPressed: _isLoading ? null : _resendVerification,
            child: const Text('Resend verification email'),
          ),
          TextButton(
            onPressed: _isLoading
                ? null
                : () async {
                    await _authService.logout();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.signIn,
                        (_) => false,
                      );
                    }
                  },
            child: const Text('Sign out'),
          ),
          if (_message != null) ...[
            const SizedBox(height: AppDimensions.spacingMedium),
            Text(_message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
