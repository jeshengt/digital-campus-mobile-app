import '../../models/user_role.dart';
import 'app_routes.dart';

class RoleRouter {
  const RoleRouter._();

  static String dashboardRouteFor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return AppRoutes.studentDashboard;
      case UserRole.lecturer:
        return AppRoutes.lecturerDashboard;
      case UserRole.driver:
        return AppRoutes.driverDashboard;
      case UserRole.staff:
        return AppRoutes.staffDashboard;
      case UserRole.admin:
        return AppRoutes.adminDashboard;
    }
  }
}
