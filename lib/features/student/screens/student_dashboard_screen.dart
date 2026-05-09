import 'package:flutter/material.dart';

import '../../../shared/layouts/role_dashboard_layout.dart';
import '../../../shared/widgets/utm_info_card.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleDashboardLayout(
      title: 'Student Dashboard',
      subtitle: 'Attendance, bookings, buses, and campus updates for students.',
      cards: [
        UtmInfoCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Attendance scanning',
          statusLabel: 'Phase 1',
          description:
              'QR and location validation foundation is reserved here.',
        ),
        UtmInfoCard(
          icon: Icons.event_available_outlined,
          title: 'Facility booking',
          statusLabel: 'Planned',
          description: 'Students will create and track booking requests here.',
        ),
        UtmInfoCard(
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
