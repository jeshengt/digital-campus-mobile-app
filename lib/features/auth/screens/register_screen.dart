import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/user_role.dart';
import '../../../shared/layouts/auth_layout.dart';
import '../../../shared/widgets/utm_primary_button.dart';
import '../../../shared/widgets/utm_text_field.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _registrationRoles = [
    UserRole.student,
    UserRole.lecturer,
    UserRole.driver,
    UserRole.staff,
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  UserRole _selectedRole = UserRole.student;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        role: _selectedRole,
      );

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.emailVerification,
          (_) => false,
        );
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
    return AuthLayout(
      title: 'Create your account',
      subtitle:
          'Smart campus experience starts here.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UtmTextField(
              controller: _nameController,
              label: 'Full name',
              icon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            UtmTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            UtmTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            DropdownButtonFormField<UserRole>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
              items: _registrationRoles
                  .map(
                    (role) =>
                        DropdownMenuItem(value: role, child: Text(role.label)),
                  )
                  .toList(),
              onChanged: _isLoading
                  ? null
                  : (role) {
                      if (role != null) {
                        setState(() => _selectedRole = role);
                      }
                    },
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
              label: 'Register',
              icon: Icons.person_add_alt_rounded,
              isLoading: _isLoading,
              onPressed: _submit,
            ),
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text('I already have an account'),
            ),
          ],
        ),
      ),
    );
  }
}
