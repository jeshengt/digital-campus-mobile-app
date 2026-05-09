import 'package:flutter/material.dart';

import '../../../shared/layouts/role_dashboard_layout.dart';
import '../../../shared/widgets/utm_info_card.dart';

class StaffDashboardScreen extends StatelessWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleDashboardLayout(
      title: 'Staff Dashboard',
      subtitle: 'Facility booking review and operational campus workflows.',
      cards: [
        UtmInfoCard(
          icon: Icons.fact_check_outlined,
          title: 'Booking requests',
          statusLabel: 'Review',
          description:
              'Staff review, approve, or cancel assigned bookings here.',
        ),
        UtmInfoCard(
          icon: Icons.meeting_room_outlined,
          title: 'Facility status',
          statusLabel: 'Planned',
          description:
              'Facility management hooks are reserved for the next phase.',
        ),
      ],
    );
  }
}
