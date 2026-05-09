import 'package:flutter_test/flutter_test.dart';
import 'package:utmgo/app/routes/app_routes.dart';
import 'package:utmgo/app/routes/role_router.dart';
import 'package:utmgo/models/user_role.dart';

void main() {
  group('UserRole', () {
    test('parses known values', () {
      expect(UserRole.fromValue('student'), UserRole.student);
      expect(UserRole.fromValue('lecturer'), UserRole.lecturer);
      expect(UserRole.fromValue('driver'), UserRole.driver);
      expect(UserRole.fromValue('staff'), UserRole.staff);
      expect(UserRole.fromValue('admin'), UserRole.admin);
    });

    test('defaults unknown values to student', () {
      expect(UserRole.fromValue(null), UserRole.student);
      expect(UserRole.fromValue('unknown'), UserRole.student);
    });
  });

  group('RoleRouter', () {
    test('maps roles to dashboard routes', () {
      expect(
        RoleRouter.dashboardRouteFor(UserRole.student),
        AppRoutes.studentDashboard,
      );
      expect(
        RoleRouter.dashboardRouteFor(UserRole.lecturer),
        AppRoutes.lecturerDashboard,
      );
      expect(
        RoleRouter.dashboardRouteFor(UserRole.driver),
        AppRoutes.driverDashboard,
      );
      expect(
        RoleRouter.dashboardRouteFor(UserRole.staff),
        AppRoutes.staffDashboard,
      );
      expect(
        RoleRouter.dashboardRouteFor(UserRole.admin),
        AppRoutes.adminDashboard,
      );
    });
  });
}
