import '../../../models/user_role.dart';
import '../../attendance/models/attendance_record.dart';
import '../../attendance/models/attendance_session.dart';
import '../../booking/models/facility.dart';
import '../../booking/models/facility_booking.dart';
import '../../booking/utils/booking_validation.dart';
import '../../bus_tracking/models/bus_location.dart';
import '../../bus_tracking/models/campus_bus.dart';
import '../../profile/models/app_user.dart';

class SystemAnalyticsSnapshot {
  const SystemAnalyticsSnapshot({
    required this.generatedAt,
    required this.totalUsers,
    required this.roleCounts,
    required this.verifiedUsers,
    required this.unverifiedUsers,
    required this.totalAttendanceSessions,
    required this.activeAttendanceSessions,
    required this.closedAttendanceSessions,
    required this.totalAttendanceRecords,
    required this.locationValidatedAttendanceRecords,
    required this.totalFacilities,
    required this.availableFacilities,
    required this.unavailableFacilities,
    required this.totalBookings,
    required this.pendingBookings,
    required this.approvedBookings,
    required this.cancelledBookings,
    required this.totalBusRoutes,
    required this.activeBusRoutes,
    required this.inactiveBusRoutes,
    required this.assignedBusRoutes,
    required this.unassignedBusRoutes,
    required this.liveBusBroadcasts,
    required this.staleBusBroadcasts,
  });

  final DateTime generatedAt;
  final int totalUsers;
  final Map<UserRole, int> roleCounts;
  final int verifiedUsers;
  final int unverifiedUsers;
  final int totalAttendanceSessions;
  final int activeAttendanceSessions;
  final int closedAttendanceSessions;
  final int totalAttendanceRecords;
  final int locationValidatedAttendanceRecords;
  final int totalFacilities;
  final int availableFacilities;
  final int unavailableFacilities;
  final int totalBookings;
  final int pendingBookings;
  final int approvedBookings;
  final int cancelledBookings;
  final int totalBusRoutes;
  final int activeBusRoutes;
  final int inactiveBusRoutes;
  final int assignedBusRoutes;
  final int unassignedBusRoutes;
  final int liveBusBroadcasts;
  final int staleBusBroadcasts;

  bool get isEmpty {
    return totalUsers == 0 &&
        totalAttendanceSessions == 0 &&
        totalAttendanceRecords == 0 &&
        totalFacilities == 0 &&
        totalBookings == 0 &&
        totalBusRoutes == 0 &&
        liveBusBroadcasts == 0 &&
        staleBusBroadcasts == 0;
  }

  int roleCount(UserRole role) {
    return roleCounts[role] ?? 0;
  }
}

SystemAnalyticsSnapshot buildSystemAnalyticsSnapshot({
  required List<AppUser> users,
  required List<AttendanceSession> attendanceSessions,
  required List<AttendanceRecord> attendanceRecords,
  required List<Facility> facilities,
  required List<FacilityBooking> bookings,
  required List<CampusBus> buses,
  required List<BusLocation> busLocations,
  required DateTime now,
  Duration liveBroadcastWindow = const Duration(seconds: 30),
}) {
  final roleCounts = <UserRole, int>{
    for (final role in UserRole.values) role: 0,
  };
  for (final user in users) {
    roleCounts[user.role] = (roleCounts[user.role] ?? 0) + 1;
  }

  final activeAttendanceSessions = attendanceSessions.where((session) {
    return session.status == 'active' &&
        (session.expiryTime == null || session.expiryTime!.isAfter(now));
  }).length;
  final liveBusBroadcasts = busLocations.where((location) {
    return location.isBroadcasting &&
        now.difference(location.updatedAt) <= liveBroadcastWindow;
  }).length;
  final staleBusBroadcasts = busLocations.where((location) {
    return location.isBroadcasting &&
        now.difference(location.updatedAt) > liveBroadcastWindow;
  }).length;

  return SystemAnalyticsSnapshot(
    generatedAt: now,
    totalUsers: users.length,
    roleCounts: Map.unmodifiable(roleCounts),
    verifiedUsers: users.where((user) => user.emailVerified).length,
    unverifiedUsers: users.where((user) => !user.emailVerified).length,
    totalAttendanceSessions: attendanceSessions.length,
    activeAttendanceSessions: activeAttendanceSessions,
    closedAttendanceSessions: attendanceSessions
        .where((session) => session.status == 'closed')
        .length,
    totalAttendanceRecords: attendanceRecords.length,
    locationValidatedAttendanceRecords: attendanceRecords
        .where((record) => record.locationValidated)
        .length,
    totalFacilities: facilities.length,
    availableFacilities: facilities
        .where((facility) => facility.status == facilityStatusAvailable)
        .length,
    unavailableFacilities: facilities
        .where((facility) => facility.status == facilityStatusUnavailable)
        .length,
    totalBookings: bookings.length,
    pendingBookings: bookings
        .where((booking) => booking.status == bookingStatusPending)
        .length,
    approvedBookings: bookings
        .where((booking) => booking.status == bookingStatusApproved)
        .length,
    cancelledBookings: bookings
        .where((booking) => booking.status == bookingStatusCancelled)
        .length,
    totalBusRoutes: buses.length,
    activeBusRoutes: buses.where((bus) => bus.status == 'active').length,
    inactiveBusRoutes: buses.where((bus) => bus.status == 'inactive').length,
    assignedBusRoutes: buses.where((bus) => bus.driverIds.isNotEmpty).length,
    unassignedBusRoutes: buses.where((bus) => bus.driverIds.isEmpty).length,
    liveBusBroadcasts: liveBusBroadcasts,
    staleBusBroadcasts: staleBusBroadcasts,
  );
}
