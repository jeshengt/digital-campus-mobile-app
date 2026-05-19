import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../shared/layouts/role_dashboard_layout.dart';
import '../../../shared/widgets/utm_info_card.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboardLayout(
      title: 'Student Dashboard',
      subtitle: 'Attendance, bookings, buses, and campus updates for students.',
      cards: [
        UtmInfoCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Attendance scanning',
          statusLabel: 'Ready',
          description: 'Scan a lecturer QR and validate your class location.',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.studentScanAttendance),
        ),
        UtmInfoCard(
          icon: Icons.fact_check_outlined,
          title: 'Attendance history',
          statusLabel: 'Mine',
          description: 'View your own validated class attendance records.',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.studentAttendanceHistory),
        ),
        const UtmInfoCard(
          icon: Icons.event_available_outlined,
          title: 'Facility booking',
          statusLabel: 'Planned',
          description: 'Students will create and track booking requests here.',
        ),
        const UtmInfoCard(
          icon: Icons.directions_bus_filled_outlined,
          title: 'Live bus tracking',
          statusLabel: 'OSM',
          description:
              'OpenStreetMap-based bus viewing will connect here later.',
        ),
      ],
    );
  }
}
