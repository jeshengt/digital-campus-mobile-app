import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utmgo/app/theme/app_theme.dart';
import 'package:utmgo/features/bus_tracking/models/campus_bus.dart';
import 'package:utmgo/features/bus_tracking/widgets/bus_status_card.dart';
import 'package:utmgo/features/profile/models/app_user.dart';
import 'package:utmgo/features/profile/widgets/profile_action_tile.dart';
import 'package:utmgo/features/profile/widgets/profile_header_card.dart';
import 'package:utmgo/features/student/screens/student_dashboard_screen.dart';
import 'package:utmgo/models/user_role.dart';
import 'package:utmgo/shared/layouts/auth_layout.dart';
import 'package:utmgo/shared/widgets/utm_feature_header.dart';
import 'package:utmgo/shared/widgets/utm_info_card.dart';
import 'package:utmgo/shared/widgets/utm_primary_button.dart';
import 'package:utmgo/shared/widgets/utm_text_field.dart';

void main() {
  testWidgets('shared Liquid Glass surfaces render in light and dark themes', (
    tester,
  ) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(mode),
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const _SharedDesignSmokeSurface(),
        ),
      );

      expect(find.text('Campus today'), findsOneWidget);
      expect(find.text('Student Dashboard'), findsOneWidget);
      expect(find.text('Aina Rahman'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Green Line'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Green Line'), findsOneWidget);
    }
  });

  testWidgets('auth layout follows the system dark theme', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: AuthLayout(
          title: 'Welcome',
          subtitle: 'Your campus experience continues here.',
          child: Column(
            children: [
              UtmTextField(
                controller: TextEditingController(),
                label: 'Email',
                icon: Icons.mail_outline_rounded,
              ),
              const SizedBox(height: 12),
              UtmPrimaryButton(
                label: 'Sign in',
                icon: Icons.login_rounded,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('student dashboard uses the scan-first glass layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const StudentDashboardScreen(),
      ),
    );

    expect(find.byTooltip('Profile'), findsOneWidget);
    expect(find.text('Student workspace'), findsNothing);
    expect(find.text('Ready for campus'), findsNothing);
    expect(find.text('Scan Attendance QR'), findsOneWidget);
    expect(
      find.text('Scan the QR code to record your attendance.'),
      findsOneWidget,
    );
    expect(find.text('Book a Facility'), findsOneWidget);
    expect(find.text('Classes'), findsNothing);
  });
}

class _SharedDesignSmokeSurface extends StatelessWidget {
  const _SharedDesignSmokeSurface();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const UtmFeatureHeader(
            icon: Icons.school_outlined,
            title: 'Campus today',
            subtitle: 'Booking, attendance, and buses are ready.',
          ),
          const SizedBox(height: 16),
          const UtmInfoCard(
            icon: Icons.event_available_outlined,
            title: 'Student Dashboard',
            statusLabel: 'Ready',
            description: 'Apple-inspired role card surface.',
          ),
          const SizedBox(height: 16),
          const ProfileHeaderCard(
            profile: AppUser(
              uid: 'student-1',
              name: 'Aina Rahman',
              email: 'aina@example.com',
              role: UserRole.student,
            ),
          ),
          ProfileActionTile(
            icon: Icons.person_outline_rounded,
            label: 'Edit Profile',
            onTap: () {},
          ),
          const SizedBox(height: 16),
          const BusStatusCard(
            bus: CampusBus(
              busId: 'green',
              routeName: 'Green Line',
              status: 'active',
            ),
            location: null,
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 420, child: StudentDashboardScreen()),
        ],
      ),
    );
  }
}
