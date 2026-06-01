import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_feature_header.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../models/facility_booking.dart';
import '../services/facility_booking_service.dart';
import '../utils/booking_validation.dart';

class StaffBookingReviewScreen extends StatefulWidget {
  const StaffBookingReviewScreen({
    super.key,
    FacilityBookingService? facilityBookingService,
  }) : _facilityBookingService = facilityBookingService;

  final FacilityBookingService? _facilityBookingService;

  @override
  State<StaffBookingReviewScreen> createState() =>
      _StaffBookingReviewScreenState();
}

class _StaffBookingReviewScreenState extends State<StaffBookingReviewScreen> {
  late final FacilityBookingService _facilityBookingService;

  @override
  void initState() {
    super.initState();
    _facilityBookingService =
        widget._facilityBookingService ?? FirebaseFacilityBookingService();
  }

  @override
  Widget build(BuildContext context) {
    return UtmBackgroundScaffold(
      appBar: const UtmTopAppBar(title: 'Booking requests'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: StreamBuilder<List<FacilityBooking>>(
              stream: _facilityBookingService.watchBookingRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _StaffBookingMessageState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load requests',
                    message: snapshot.error.toString(),
                  );
                }

                final bookings = snapshot.data ?? const <FacilityBooking>[];
                if (bookings.isEmpty) {
                  return const _StaffBookingMessageState(
                    icon: Icons.fact_check_outlined,
                    title: 'No booking requests',
                    message: 'Student facility requests will appear here.',
                  );
                }

                final pendingCount = bookings
                    .where((booking) => booking.status == bookingStatusPending)
                    .length;

                return ListView(
                  padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                  children: [
                    _StaffBookingHeader(
                      totalCount: bookings.length,
                      pendingCount: pendingCount,
                    ),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    for (final booking in bookings)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppDimensions.spacingMedium,
                        ),
                        child: _StaffBookingTile(
                          booking: booking,
                          onApprove: booking.status == bookingStatusPending
                              ? () => _approveBooking(booking)
                              : null,
                          onCancel: booking.status != bookingStatusCancelled
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

  Future<void> _approveBooking(FacilityBooking booking) async {
    try {
      await _facilityBookingService.approveBooking(booking);
      _showSnack('Booking approved.');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<void> _cancelBooking(FacilityBooking booking) async {
    try {
      await _facilityBookingService.cancelBookingAsStaff(booking);
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

class _StaffBookingHeader extends StatelessWidget {
  const _StaffBookingHeader({
    required this.totalCount,
    required this.pendingCount,
  });

  final int totalCount;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return UtmFeatureHeader(
      icon: Icons.fact_check_outlined,
      title: 'Facility Bookings',
      subtitle: '$pendingCount Pending - $totalCount Total',
    );
  }
}

class _StaffBookingTile extends StatelessWidget {
  const _StaffBookingTile({
    required this.booking,
    required this.onApprove,
    required this.onCancel,
  });

  final FacilityBooking booking;
  final VoidCallback? onApprove;
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
                _StaffBookingStatusChip(status: booking.status),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              booking.studentName.isEmpty
                  ? booking.studentEmail
                  : '${booking.studentName} - ${booking.studentEmail}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spacingTiny),
            Text(
              '${formatBookingDate(booking.requestedDate)} - ${formatBookingTimeRange(booking.startTime, booking.endTime)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onApprove != null || onCancel != null) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              Wrap(
                spacing: AppDimensions.spacingSmall,
                runSpacing: AppDimensions.spacingSmall,
                alignment: WrapAlignment.end,
                children: [
                  if (onApprove != null)
                    FilledButton.icon(
                      key: Key('approveBooking_${booking.bookingId}'),
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Approve'),
                    ),
                  if (onCancel != null)
                    OutlinedButton.icon(
                      key: Key('cancelStaffBooking_${booking.bookingId}'),
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Decline'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StaffBookingStatusChip extends StatelessWidget {
  const _StaffBookingStatusChip({required this.status});

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

class _StaffBookingMessageState extends StatelessWidget {
  const _StaffBookingMessageState({
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Column(
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
        ),
      ),
    );
  }
}
