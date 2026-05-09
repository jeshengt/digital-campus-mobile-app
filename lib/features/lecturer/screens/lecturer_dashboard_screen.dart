import 'package:flutter/material.dart';

import '../../../shared/layouts/role_dashboard_layout.dart';
import '../../../shared/widgets/utm_info_card.dart';

class LecturerDashboardScreen extends StatelessWidget {
  const LecturerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleDashboardLayout(
      title: 'Lecturer Dashboard',
      subtitle: 'Attendance sessions, live lists, and local report exports.',
      cards: [
        UtmInfoCard(
          icon: Icons.qr_code_2_rounded,
          title: 'Generate attendance QR',
          statusLabel: 'Secure',
          description: 'Time-bound QR session setup will be added here.',
        ),
        UtmInfoCard(
          icon: Icons.location_on_outlined,
          title: 'Geofence settings',
          statusLabel: 'Planned',
          description: 'Session location radius planning is reserved here.',
        ),
        UtmInfoCard(
          icon: Icons.picture_as_pdf_outlined,
          title: 'Local PDF export',
          statusLabel: 'Local',
          description: 'Reports will be generated on device, not by a backend.',
        ),
      ],
    );
  }
}
