import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../shared/layouts/role_dashboard_layout.dart';
import '../../../shared/widgets/utm_info_card.dart';

class LecturerDashboardScreen extends StatelessWidget {
  const LecturerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboardLayout(
      title: 'Lecturer Dashboard',
      subtitle: 'Attendance sessions and live class lists.',
      cards: [
        UtmInfoCard(
          icon: Icons.qr_code_2_rounded,
          title: 'Generate Attendance QR',
          description:
              'Create a QR code with a time limit and classroom location check.',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.lecturerCreateAttendance),
        ),
        UtmInfoCard(
          icon: Icons.list_alt_rounded,
          title: 'Attendance Lists',
          description: 'View students who scanned and passed validation.',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.lecturerAttendanceList),
        ),
        UtmInfoCard(
          icon: Icons.directions_bus_filled_outlined,
          title: 'Track Buses',
          description: 'View live locations for campus buses.',
          onTap: () => Navigator.pushNamed(context, AppRoutes.busTrackingMap),
        ),
      ],
    );
  }
}
