import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utmgo/app/routes/app_routes.dart';
import 'package:utmgo/app/theme/app_theme.dart';
import 'package:utmgo/features/auth/screens/forgot_password_screen.dart';
import 'package:utmgo/features/auth/screens/sign_in_screen.dart';
import 'package:utmgo/features/auth/utils/auth_form_helpers.dart';

void main() {
  group('AppRoutes auth flow', () {
    test('registers the forgot password route', () {
      final routes = AppRoutes.routes(isFirebaseReady: true);

      expect(routes.containsKey(AppRoutes.forgotPassword), isTrue);
      expect(AppRoutes.forgotPassword, '/forgot-password');
    });
  });

  group('auth screens', () {
    testWidgets('sign in screen opens forgot password screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.signIn: (_) => const SignInScreen(),
            AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
          },
          initialRoute: AppRoutes.signIn,
        ),
      );

      expect(find.text('Forgot password?'), findsOneWidget);

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset password'), findsOneWidget);
      expect(find.text('Send reset email'), findsOneWidget);
    });

    testWidgets('forgot password screen validates empty email', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const ForgotPasswordScreen()),
      );

      await tester.tap(find.text('Send reset email'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
    });
  });

  group('auth form helpers', () {
    test('validates reset email input', () {
      expect(validateResetEmail(null), 'Email is required');
      expect(validateResetEmail('   '), 'Email is required');
      expect(validateResetEmail('student'), 'Enter a valid email address');
      expect(validateResetEmail('student@utm.my'), isNull);
    });
  });
}
