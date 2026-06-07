import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_feature_header.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../models/facility_booking.dart';
import '../services/facility_booking_service.dart';
import '../utils/booking_validation.dart';

class StudentMyBookingsScreen extends StatefulWidget {
  const StudentMyBookingsScreen({
    super.key,
    FacilityBookingService? facilityBookingService,
  }) : _facilityBookingService = facilityBookingService;

  final FacilityBookingService? _facilityBookingService;

  @override
  State<StudentMyBookingsScreen> createState() =>
      _StudentMyBookingsScreenState();
}

class _StudentMyBookingsScreenState extends State<StudentMyBookingsScreen> {
  late final FacilityBookingService _facilityBookingService;
  late final Stream<List<FacilityBooking>> _studentBookingsStream;

  @override
  void initState() {
    super.initState();
    _facilityBookingService =
        widget._facilityBookingService ?? FirebaseFacilityBookingService();
    _studentBookingsStream = _facilityBookingService
        .watchCurrentStudentBookings();
  }

  @override
  Widget build(BuildContext context) {
    return UtmBackgroundScaffold(
      appBar: const UtmTopAppBar(title: 'My bookings'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: StreamBuilder<List<FacilityBooking>>(
              stream: _studentBookingsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _BookingMessageState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load bookings',
                    message: snapshot.error.toString(),
                  );
                }

                final bookings = snapshot.data ?? const <FacilityBooking>[];
                return ListView(
                  padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                  children: [
                    _StudentBookingsHeader(bookingCount: bookings.length),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    if (bookings.isEmpty)
                      const _BookingMessageCard(
                        icon: Icons.event_available_outlined,
                        title: 'No bookings yet',
                        message:
                            'Your facility booking requests will appear here.',
                      )
                    else
                      for (final booking in bookings)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppDimensions.spacingMedium,
                          ),
                          child: _StudentBookingTile(
                            booking: booking,
                            onCancel: booking.status == bookingStatusPending
                                ? () => _cancelBooking(booking)
                                : null,
                          ),
                        ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cancelBooking(FacilityBooking booking) async {
    try {
      await _facilityBookingService.cancelStudentBooking(booking);
      _showSnack('Booking cancelled.');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StudentBookingsHeader extends StatelessWidget {
  const _StudentBookingsHeader({required this.bookingCount});

  final int bookingCount;

  @override
  Widget build(BuildContext context) {
    return UtmFeatureHeader(
      icon: Icons.event_note_outlined,
      title: 'My facility bookings',
      subtitle: '$bookingCount request${bookingCount == 1 ? '' : 's'}',
    );
  }
}

class _StudentBookingTile extends StatelessWidget {
  const _StudentBookingTile({required this.booking, required this.onCancel});

  final FacilityBooking booking;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.facilityName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _BookingStatusChip(status: booking.status),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              '${formatBookingDate(booking.requestedDate)} - ${formatBookingTimeRange(booking.startTime, booking.endTime)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onCancel != null) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  key: Key('cancelStudentBooking_${booking.bookingId}'),
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingStatusChip extends StatelessWidget {
  const _BookingStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final color = switch (status) {
      bookingStatusApproved => colors.success,
      bookingStatusCancelled => colors.textTertiary,
      _ => colors.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSmall,
        vertical: AppDimensions.spacingTiny,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: color, fontSize: 11),
      ),
    );
  }
}

class _BookingMessageState extends StatelessWidget {
  const _BookingMessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: _BookingMessageContent(
          icon: icon,
          title: title,
          message: message,
        ),
      ),
    );
  }
}

class _BookingMessageCard extends StatelessWidget {
  const _BookingMessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: _BookingMessageContent(
          icon: icon,
          title: title,
          message: message,
        ),
      ),
    );
  }
}

class _BookingMessageContent extends StatelessWidget {
  const _BookingMessageContent({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: colors.brandMaroon),
        const SizedBox(height: AppDimensions.spacingMedium),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppDimensions.spacingSmall),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
