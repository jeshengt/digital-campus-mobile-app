import 'package:flutter/material.dart';

import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/attendance/screens/lecturer_attendance_list_screen.dart';
import '../../features/attendance/screens/lecturer_create_session_screen.dart';
import '../../features/attendance/screens/lecturer_session_qr_screen.dart';
import '../../features/attendance/screens/student_attendance_history_screen.dart';
import '../../features/attendance/screens/student_scan_attendance_screen.dart';
import '../../features/auth/screens/email_verification_screen.dart';
import '../../features/auth/screens/firebase_setup_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/role_gateway_screen.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/driver/screens/driver_dashboard_screen.dart';
import '../../features/lecturer/screens/lecturer_dashboard_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/staff/screens/staff_dashboard_screen.dart';
import '../../features/student/screens/student_dashboard_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const firebaseSetup = '/firebase-setup';
  static const splash = '/';
  static const signIn = '/sign-in';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const emailVerification = '/email-verification';
  static const roleGateway = '/role-gateway';
  static const profile = '/profile';
  static const studentDashboard = '/student';
  static const lecturerDashboard = '/lecturer';
  static const driverDashboard = '/driver';
  static const staffDashboard = '/staff';
  static const adminDashboard = '/admin';
  static const lecturerCreateAttendance = '/attendance/lecturer/create';
  static const lecturerAttendanceQr = '/attendance/lecturer/qr';
  static const lecturerAttendanceList = '/attendance/lecturer/list';
  static const studentScanAttendance = '/attendance/student/scan';
  static const studentAttendanceHistory = '/attendance/student/history';

  static Map<String, WidgetBuilder> routes({
    required bool isFirebaseReady,
    String? firebaseErrorMessage,
  }) {
    return {
      firebaseSetup: (_) =>
          FirebaseSetupScreen(errorMessage: firebaseErrorMessage),
      splash: (_) => isFirebaseReady
          ? const SplashScreen()
          : FirebaseSetupScreen(errorMessage: firebaseErrorMessage),
      signIn: (_) => const SignInScreen(),
      register: (_) => const RegisterScreen(),
      forgotPassword: (_) => const ForgotPasswordScreen(),
      emailVerification: (_) => const EmailVerificationScreen(),
      roleGateway: (_) => const RoleGatewayScreen(),
      profile: (_) => const ProfileScreen(),
      studentDashboard: (_) => const StudentDashboardScreen(),
      lecturerDashboard: (_) => const LecturerDashboardScreen(),
      driverDashboard: (_) => const DriverDashboardScreen(),
      staffDashboard: (_) => const StaffDashboardScreen(),
      adminDashboard: (_) => const AdminDashboardScreen(),
      lecturerCreateAttendance: (_) => const LecturerCreateSessionScreen(),
      lecturerAttendanceQr: (_) => const LecturerSessionQrScreen(),
      lecturerAttendanceList: (_) => const LecturerAttendanceListScreen(),
      studentScanAttendance: (_) => const StudentScanAttendanceScreen(),
      studentAttendanceHistory: (_) => const StudentAttendanceHistoryScreen(),
    };
  }
}
