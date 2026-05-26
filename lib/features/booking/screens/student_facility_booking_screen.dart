import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/facility.dart';
import '../models/facility_booking.dart';
import '../models/facility_slot_capacity.dart';
import '../models/facility_slot_occurrence.dart';
import '../models/facility_slot_reservation.dart';
import '../models/facility_slot_template.dart';
import '../services/facility_booking_service.dart';
import '../utils/booking_validation.dart';

class StudentFacilityBookingScreen extends StatefulWidget {
  const StudentFacilityBookingScreen({
    super.key,
    FacilityBookingService? facilityBookingService,
  }) : _facilityBookingService = facilityBookingService;

  final FacilityBookingService? _facilityBookingService;

  @override
  State<StudentFacilityBookingScreen> createState() =>
      _StudentFacilityBookingScreenState();
}

class _StudentFacilityBookingScreenState
    extends State<StudentFacilityBookingScreen> {
  late final FacilityBookingService _facilityBookingService;

  @override
  void initState() {
    super.initState();
    _facilityBookingService =
        widget._facilityBookingService ?? FirebaseFacilityBookingService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Facility booking')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: StreamBuilder<List<Facility>>(
              stream: _facilityBookingService.watchAvailableFacilities(),
              builder: (context, facilitySnapshot) {
                if (facilitySnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (facilitySnapshot.hasError) {
                  return _BookingMessageState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load facilities',
                    message: facilitySnapshot.error.toString(),
                  );
                }

                final facilities = facilitySnapshot.data ?? const <Facility>[];

                return StreamBuilder<List<FacilityBooking>>(
                  stream: _facilityBookingService.watchCurrentStudentBookings(),
                  builder: (context, bookingSnapshot) {
                    if (bookingSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !bookingSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (bookingSnapshot.hasError) {
                      return _BookingMessageState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load bookings',
                        message: bookingSnapshot.error.toString(),
                      );
                    }

                    final bookings =
                        bookingSnapshot.data ?? const <FacilityBooking>[];

                    return ListView(
                      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                      children: [
                        _StudentBookingHeader(
                          facilityCount: facilities.length,
                          bookingCount: bookings.length,
                        ),
                        const SizedBox(height: AppDimensions.spacingLarge),
                        Text(
                          'Facilities',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppDimensions.spacingMedium),
                        if (facilities.isEmpty)
                          const _BookingMessageCard(
                            icon: Icons.meeting_room_outlined,
                            title: 'No facilities yet',
                            message:
                                'Available facilities will appear after an admin adds them.',
                          )
                        else
                          for (final facility in facilities)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppDimensions.spacingMedium,
                              ),
                              child: _FacilityTile(
                                facility: facility,
                                onBook: () => _showBookingSheet(facility),
                              ),
                            ),
                        const SizedBox(height: AppDimensions.spacingLarge),
                        Text(
                          'My bookings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppDimensions.spacingMedium),
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBookingSheet(Facility facility) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BookingFormSheet(
        facility: facility,
        facilityBookingService: _facilityBookingService,
      ),
    );

    if (saved == true) {
      _showSnack('Booking request submitted.');
    }
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

class _BookingFormSheet extends StatefulWidget {
  const _BookingFormSheet({
    required this.facility,
    required this.facilityBookingService,
  });

  final Facility facility;
  final FacilityBookingService facilityBookingService;

  @override
  State<_BookingFormSheet> createState() => _BookingFormSheetState();
}

class _BookingFormSheetState extends State<_BookingFormSheet> {
  FacilitySlotOccurrence? _selectedSlot;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimensions.spacingLarge,
          right: AppDimensions.spacingLarge,
          top: AppDimensions.spacingMedium,
          bottom:
              MediaQuery.viewInsetsOf(context).bottom +
              AppDimensions.spacingLarge,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Book ${widget.facility.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              Text(
                '${widget.facility.location} - Capacity ${widget.facility.capacity}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              Text(
                'Choose an available slot',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              _SlotPicker(
                facility: widget.facility,
                facilityBookingService: widget.facilityBookingService,
                selectedSlot: _selectedSlot,
                onSelected: (slot) {
                  setState(() {
                    _selectedSlot = slot;
                    _errorMessage = null;
                  });
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppDimensions.spacingMedium),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: AppDimensions.spacingLarge),
              ElevatedButton.icon(
                key: const Key('submitBookingButton'),
                onPressed: _isSaving ? null : _submit,
                icon: const Icon(Icons.event_available_outlined),
                label: Text(_isSaving ? 'Submitting...' : 'Submit booking'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final validationError = validateBookingDraft(
      facilityId: widget.facility.facilityId,
      slot: _selectedSlot,
    );

    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.facilityBookingService.submitBooking(
        facility: widget.facility,
        slot: _selectedSlot!,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = error.toString();
        });
      }
    }
  }
}

class _SlotPicker extends StatelessWidget {
  const _SlotPicker({
    required this.facility,
    required this.facilityBookingService,
    required this.selectedSlot,
    required this.onSelected,
  });

  final Facility facility;
  final FacilityBookingService facilityBookingService;
  final FacilitySlotOccurrence? selectedSlot;
  final ValueChanged<FacilitySlotOccurrence> onSelected;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FacilitySlotTemplate>>(
      stream: facilityBookingService.watchAvailableSlotTemplatesForFacility(
        facility.facilityId,
      ),
      builder: (context, templateSnapshot) {
        if (templateSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (templateSnapshot.hasError) {
          return _BookingMessageCard(
            icon: Icons.error_outline_rounded,
            title: 'Could not load slots',
            message: templateSnapshot.error.toString(),
          );
        }

        return StreamBuilder<List<FacilitySlotReservation>>(
          stream: facilityBookingService.watchReservationsForFacility(
            facility.facilityId,
          ),
          builder: (context, reservationSnapshot) {
            if (reservationSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !reservationSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (reservationSnapshot.hasError) {
              return _BookingMessageCard(
                icon: Icons.error_outline_rounded,
                title: 'Could not load reservations',
                message: reservationSnapshot.error.toString(),
              );
            }

            return StreamBuilder<List<FacilitySlotCapacity>>(
              stream: facilityBookingService.watchSlotCapacitiesForFacility(
                facility.facilityId,
              ),
              builder: (context, capacitySnapshot) {
                if (capacitySnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !capacitySnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (capacitySnapshot.hasError) {
                  return _BookingMessageCard(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load capacity',
                    message: capacitySnapshot.error.toString(),
                  );
                }

                final occurrences = generateAvailableSlotOccurrences(
                  templates:
                      templateSnapshot.data ?? const <FacilitySlotTemplate>[],
                  reservations:
                      reservationSnapshot.data ??
                      const <FacilitySlotReservation>[],
                  capacities:
                      capacitySnapshot.data ?? const <FacilitySlotCapacity>[],
                  facilityCapacity: facility.capacity,
                );

                if (occurrences.isEmpty) {
                  return const _BookingMessageCard(
                    icon: Icons.event_busy_outlined,
                    title: 'No slots available',
                    message: 'Staff-provided time slots will appear here.',
                  );
                }

                return DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMedium,
                    ),
                  ),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < occurrences.length;
                        index++
                      ) ...[
                        ListTile(
                          key: Key(
                            'slotOption_${occurrences[index].slotOccurrenceId}',
                          ),
                          onTap: () => onSelected(occurrences[index]),
                          leading:
                              selectedSlot?.slotOccurrenceId ==
                                  occurrences[index].slotOccurrenceId
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.utmMaroon,
                                )
                              : const Icon(Icons.circle_outlined),
                          title: Text(
                            formatBookingDate(occurrences[index].requestedDate),
                          ),
                          subtitle: Text(
                            formatBookingTimeRange(
                              occurrences[index].startTime,
                              occurrences[index].endTime,
                            ),
                          ),
                        ),
                        if (index != occurrences.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StudentBookingHeader extends StatelessWidget {
  const _StudentBookingHeader({
    required this.facilityCount,
    required this.bookingCount,
  });

  final int facilityCount;
  final int bookingCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.utmMaroon,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: const Icon(
                Icons.meeting_room_outlined,
                color: AppColors.utmGoldTint,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campus facilities',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingTiny),
                  Text(
                    '$facilityCount available - $bookingCount request${bookingCount == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.utmGoldTint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacilityTile extends StatelessWidget {
  const _FacilityTile({required this.facility, required this.onBook});

  final Facility facility;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppDimensions.spacingMedium),
        leading: const CircleAvatar(
          backgroundColor: AppColors.utmMaroonTint,
          foregroundColor: AppColors.utmMaroon,
          child: Icon(Icons.meeting_room_outlined),
        ),
        title: Text(facility.name),
        subtitle: Text(
          '${facility.type} - ${facility.location} - Capacity ${facility.capacity}',
        ),
        trailing: FilledButton(
          key: Key('bookFacility_${facility.facilityId}'),
          onPressed: onBook,
          child: const Text('Book'),
        ),
      ),
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
    final color = switch (status) {
      bookingStatusApproved => AppColors.success,
      bookingStatusCancelled => AppColors.textTertiary,
      _ => AppColors.warning,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: AppColors.utmMaroon),
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
