import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/route_redirect.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const UtmBackgroundScaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const RouteRedirect(routeName: AppRoutes.signIn);
        }

        if (!user.emailVerified) {
          return const RouteRedirect(routeName: AppRoutes.emailVerification);
        }

        return const RouteRedirect(routeName: AppRoutes.roleGateway);
      },
    );
  }
}
