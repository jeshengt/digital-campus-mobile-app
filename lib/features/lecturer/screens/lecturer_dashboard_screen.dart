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
      subtitle: 'Attendance sessions, live lists, and local report exports.',
      cards: [
        UtmInfoCard(
          icon: Icons.qr_code_2_rounded,
          title: 'Generate attendance QR',
          statusLabel: 'Secure',
          description: 'Create a time-bound QR with classroom geofence checks.',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.lecturerCreateAttendance),
        ),
        UtmInfoCard(
          icon: Icons.list_alt_rounded,
          title: 'Attendance lists',
          statusLabel: 'Live',
          description: 'Review students who scanned and passed validation.',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.lecturerAttendanceList),
        ),
        const UtmInfoCard(
          icon: Icons.picture_as_pdf_outlined,
          title: 'Local PDF export',
          statusLabel: 'Local',
          description: 'Reports will be generated on device, not by a backend.',
        ),
      ],
    );
  }
}
