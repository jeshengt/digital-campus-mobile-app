import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../shared/layouts/role_dashboard_layout.dart';
import '../../../shared/widgets/utm_info_card.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboardLayout(
      title: 'Admin Dashboard',
      subtitle: 'System oversight, facilities, and campus route operations.',
      cards: [
        UtmInfoCard(
          icon: Icons.analytics_outlined,
          title: 'Analytics',
          description: 'View system activity and insights.',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.adminSystemAnalytics),
        ),
        UtmInfoCard(
          icon: Icons.meeting_room_outlined,
          title: 'Facilities',
          description: 'Add and manage bookable campus facilities.',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.adminFacilityManagement),
        ),
        UtmInfoCard(
          icon: Icons.directions_bus_filled_outlined,
          title: 'Bus Routes',
          description: 'Manage routes and assign drivers.',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.adminBusManagement),
        ),
      ],
    );
  }
}
