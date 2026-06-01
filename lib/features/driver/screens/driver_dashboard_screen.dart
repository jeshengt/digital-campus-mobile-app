import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../shared/layouts/role_dashboard_layout.dart';
import '../../../shared/widgets/utm_info_card.dart';

class DriverDashboardScreen extends StatelessWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboardLayout(
      title: 'Bus Driver Console',
      subtitle: 'Careful live location broadcasting for assigned routes.',
      cards: [
        UtmInfoCard(
          icon: Icons.location_searching_rounded,
          title: 'Broadcast Bus Location',
          description: 'Manage location broadcasting for your assigned bus.',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.driverBusBroadcast),
        ),
      ],
    );
  }
}
