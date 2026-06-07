import '../../booking/models/facility_booking.dart';
import '../../booking/utils/booking_validation.dart';
import '../models/app_notification.dart';

AppNotification buildFacilityBookingStatusNotification({
  required String notificationId,
  required FacilityBooking booking,
  required String status,
  required DateTime createdAt,
}) {
  return AppNotification(
    notificationId: notificationId,
    userId: booking.studentId,
    title: _facilityBookingStatusTitle(status),
    message: _facilityBookingStatusMessage(booking, status),
    type: notificationTypeFacilityBookingStatus,
    bookingId: booking.bookingId,
    facilityId: booking.facilityId,
    facilityName: booking.facilityName,
    status: status,
    isRead: false,
    createdAt: createdAt,
  );
}

String _facilityBookingStatusTitle(String status) {
  return switch (status) {
    bookingStatusApproved => 'Facility booking approved',
    bookingStatusCancelled => 'Facility booking cancelled',
    _ => 'Facility booking updated',
  };
}

String _facilityBookingStatusMessage(FacilityBooking booking, String status) {
  final statusLabel = switch (status) {
    bookingStatusApproved => 'approved',
    bookingStatusCancelled => 'cancelled',
    _ => 'updated',
  };

  return 'Your ${booking.facilityName} booking has been $statusLabel.';
}
