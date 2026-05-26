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
      subtitle: 'Route status and careful live location broadcasting.',
      cards: [
        UtmInfoCard(
          icon: Icons.radio_button_checked_rounded,
          title: 'Broadcast status',
          statusLabel: 'Live',
          description: 'Toggle your assigned bus location sharing.',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.driverBusBroadcast),
        ),
        const UtmInfoCard(
          icon: Icons.speed_rounded,
          title: 'Route telemetry',
          statusLabel: 'Live',
          description:
              'Speed, heading, and assigned route details belong here.',
        ),
      ],
    );
  }
}
