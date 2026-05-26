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
      subtitle: 'System oversight, users, facilities, roles, and permissions.',
      cards: [
        const UtmInfoCard(
          icon: Icons.admin_panel_settings_outlined,
          title: 'User management',
          statusLabel: 'Admin',
          description:
              'Admin-only role and permission management belongs here.',
        ),
        const UtmInfoCard(
          icon: Icons.analytics_outlined,
          title: 'System analytics',
          statusLabel: 'Spark',
          description:
              'Spark-plan-friendly overview data will be surfaced here.',
        ),
        UtmInfoCard(
          icon: Icons.meeting_room_outlined,
          title: 'Facility management',
          statusLabel: 'Facilities',
          description: 'Create and update bookable campus facilities.',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.adminFacilityManagement),
        ),
        UtmInfoCard(
          icon: Icons.directions_bus_filled_outlined,
          title: 'Bus management',
          statusLabel: 'Routes',
          description: 'Create bus routes and assign drivers to broadcast.',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.adminBusManagement),
        ),
        const UtmInfoCard(
          icon: Icons.security_outlined,
          title: 'Protected access',
          statusLabel: 'Rules',
          description: 'Security Rules must back every admin-only data path.',
        ),
      ],
    );
  }
}
