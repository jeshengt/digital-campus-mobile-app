import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/routes/role_router.dart';
import '../../../features/profile/models/app_user.dart';
import '../../../features/profile/services/user_profile_service.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/route_redirect.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../services/auth_service.dart';

class RoleGatewayScreen extends StatelessWidget {
  const RoleGatewayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return const RouteRedirect(routeName: AppRoutes.signIn);
    }

    return FutureBuilder<AppUser?>(
      future: UserProfileService().getProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const UtmBackgroundScaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return UtmBackgroundScaffold(
            appBar: const UtmTopAppBar(title: 'Profile needed'),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No profile document was found for this account. Please contact an admin or register again.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return RouteRedirect(
          routeName: RoleRouter.dashboardRouteFor(profile.role),
        );
      },
    );
  }
}
