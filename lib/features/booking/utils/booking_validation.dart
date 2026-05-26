import 'package:flutter/material.dart';

import '../models/facility_slot_capacity.dart';
import '../models/facility_slot_occurrence.dart';
import '../models/facility_slot_reservation.dart';
import '../models/facility_slot_template.dart';

const facilityStatusAvailable = 'available';
const facilityStatusUnavailable = 'unavailable';
const allowedFacilityStatuses = [
  facilityStatusAvailable,
  facilityStatusUnavailable,
];

const bookingStatusPending = 'pending';
const bookingStatusApproved = 'approved';
const bookingStatusCancelled = 'cancelled';
const bookingCapacityFullMessage = 'Capacity is full for this slot.';
const bookingSaveDeniedMessage =
    'Could not save booking. Please refresh slots and try again.';

const slotTemplateStatusActive = 'active';
const slotTemplateStatusInactive = 'inactive';
const allowedSlotTemplateStatuses = [
  slotTemplateStatusActive,
  slotTemplateStatusInactive,
];

const slotModeDate = 'date';
const slotModeDaily = 'daily';
const slotModeWeekdays = 'weekdays';
const slotModeWeekly = 'weekly';
const allowedSlotModes = [
  slotModeDate,
  slotModeDaily,
  slotModeWeekdays,
  slotModeWeekly,
];

String bookingDocumentId({required String slotOccurrenceId}) {
  return slotOccurrenceId.trim();
}

String bookingDateKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';
}

String bookingTimeKey(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}'
      '${value.minute.toString().padLeft(2, '0')}';
}

DateTime bookingDateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime combineBookingDateAndTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String? validateFacilityDraft({
  required String name,
  required String type,
  required String location,
  required String capacity,
}) {
  if (name.trim().isEmpty) {
    return 'Facility name is required';
  }

  if (type.trim().isEmpty) {
    return 'Facility type is required';
  }

  if (location.trim().isEmpty) {
    return 'Location is required';
  }

  final parsedCapacity = int.tryParse(capacity.trim());
  if (parsedCapacity == null || parsedCapacity <= 0) {
    return 'Capacity must be greater than 0';
  }

  return null;
}

String? validateBookingDraft({
  required String facilityId,
  required FacilitySlotOccurrence? slot,
}) {
  if (facilityId.trim().isEmpty) {
    return 'Choose a facility';
  }

  if (slot == null) {
    return 'Choose a time slot';
  }

  return null;
}

String? validateSlotTemplateDraft({
  required String facilityId,
  required String slotMode,
  required DateTime? slotDate,
  required int? weekday,
  required int startMinutes,
  required int endMinutes,
}) {
  if (facilityId.trim().isEmpty) {
    return 'Choose a facility';
  }

  if (!allowedSlotModes.contains(slotMode)) {
    return 'Choose a valid slot mode';
  }

  if (slotMode == slotModeDate && slotDate == null) {
    return 'Choose a slot date';
  }

  if (slotMode == slotModeWeekly &&
      (weekday == null ||
          weekday < DateTime.monday ||
          weekday > DateTime.sunday)) {
    return 'Choose a valid weekday';
  }

  if (startMinutes < 0 || startMinutes >= 1440) {
    return 'Choose a valid start time';
  }

  if (endMinutes <= startMinutes || endMinutes > 1440) {
    return 'End time must be after start time';
  }

  return null;
}

List<FacilitySlotOccurrence> generateAvailableSlotOccurrences({
  required List<FacilitySlotTemplate> templates,
  required List<FacilitySlotReservation> reservations,
  List<FacilitySlotCapacity> capacities = const <FacilitySlotCapacity>[],
  int facilityCapacity = 1,
  DateTime? from,
  int days = 14,
}) {
  final now = from ?? DateTime.now();
  final startDate = bookingDateOnly(now);
  final heldCounts = slotHeldCounts(
    reservations: reservations,
    capacities: capacities,
  );
  final occurrences = <FacilitySlotOccurrence>[];

  for (var offset = 0; offset < days; offset++) {
    final date = startDate.add(Duration(days: offset));
    for (final template in templates) {
      if (template.status != slotTemplateStatusActive ||
          !_templateOccursOnDate(template, date)) {
        continue;
      }

      final occurrence = FacilitySlotOccurrence.fromTemplate(
        template: template,
        date: date,
      );
      if (occurrence.startTime.isBefore(now) ||
          (heldCounts[occurrence.slotOccurrenceId] ?? 0) >= facilityCapacity) {
        continue;
      }

      occurrences.add(occurrence);
    }
  }

  occurrences.sort((a, b) => a.startTime.compareTo(b.startTime));
  return occurrences;
}

Map<String, int> slotHeldCounts({
  required List<FacilitySlotReservation> reservations,
  required List<FacilitySlotCapacity> capacities,
}) {
  final counts = <String, int>{
    for (final capacity in capacities)
      capacity.slotOccurrenceId: capacity.activeCount,
  };
  final reservationCounts = <String, int>{};

  for (final reservation in reservations) {
    if (reservation.status != bookingStatusPending &&
        reservation.status != bookingStatusApproved) {
      continue;
    }

    final slotOccurrenceId = reservation.slotOccurrenceId;
    reservationCounts[slotOccurrenceId] =
        (reservationCounts[slotOccurrenceId] ?? 0) + 1;
  }

  for (final entry in reservationCounts.entries) {
    final counterCount = counts[entry.key] ?? 0;
    if (entry.value > counterCount) {
      counts[entry.key] = entry.value;
    }
  }

  return counts;
}

FacilitySlotCapacity nextCapacityForSubmit({
  required FacilitySlotCapacity? current,
  required FacilitySlotOccurrence slot,
  required int facilityCapacity,
  required DateTime now,
}) {
  final pendingCount = (current?.pendingCount ?? 0) + 1;
  final approvedCount = current?.approvedCount ?? 0;
  final activeCount = (current?.activeCount ?? 0) + 1;
  if (activeCount > facilityCapacity) {
    throw StateError('capacity-full');
  }

  return FacilitySlotCapacity(
    slotOccurrenceId: slot.slotOccurrenceId,
    facilityId: slot.facilityId,
    requestedDate: bookingDateOnly(slot.requestedDate),
    startTime: slot.startTime,
    endTime: slot.endTime,
    pendingCount: pendingCount,
    approvedCount: approvedCount,
    activeCount: activeCount,
    createdAt: current?.createdAt ?? now,
    updatedAt: now,
  );
}

FacilitySlotCapacity nextCapacityForApproval({
  required FacilitySlotCapacity current,
  required int facilityCapacity,
  required DateTime now,
}) {
  if (current.approvedCount >= facilityCapacity) {
    throw StateError('capacity-full');
  }

  final pendingCount = (current.pendingCount - 1).clamp(0, facilityCapacity);
  final approvedCount = current.approvedCount + 1;

  return current.copyWith(
    pendingCount: pendingCount,
    approvedCount: approvedCount,
    activeCount: current.activeCount,
    updatedAt: now,
  );
}

FacilitySlotCapacity nextCapacityForCancellation({
  required FacilitySlotCapacity current,
  required String previousStatus,
  required DateTime now,
}) {
  final pendingDelta = previousStatus == bookingStatusPending ? 1 : 0;
  final approvedDelta = previousStatus == bookingStatusApproved ? 1 : 0;
  final pendingCount = (current.pendingCount - pendingDelta).clamp(
    0,
    current.pendingCount,
  );
  final approvedCount = (current.approvedCount - approvedDelta).clamp(
    0,
    current.approvedCount,
  );
  final activeCount = (current.activeCount - 1).clamp(0, current.activeCount);

  return current.copyWith(
    pendingCount: pendingCount,
    approvedCount: approvedCount,
    activeCount: activeCount,
    updatedAt: now,
  );
}

bool _templateOccursOnDate(FacilitySlotTemplate template, DateTime date) {
  final mode = allowedSlotModes.contains(template.slotMode)
      ? template.slotMode
      : slotModeWeekly;

  if (mode == slotModeDaily) {
    return true;
  }

  if (mode == slotModeWeekdays) {
    return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
  }

  if (mode == slotModeDate) {
    final slotDate = template.slotDate;
    return slotDate != null && bookingDateOnly(slotDate) == date;
  }

  return template.weekday == date.weekday;
}

String formatBookingDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

String formatBookingTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatBookingTimeRange(DateTime startTime, DateTime endTime) {
  return '${formatBookingTime(startTime)} - ${formatBookingTime(endTime)}';
}

String formatSlotMinutes(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String slotModeLabel(String slotMode) {
  return switch (slotMode) {
    slotModeDate => 'One date',
    slotModeDaily => 'Every day',
    slotModeWeekdays => 'Weekdays',
    slotModeWeekly => 'Weekly',
    _ => 'Weekly',
  };
}

String slotTemplateScheduleLabel(FacilitySlotTemplate template) {
  final mode = allowedSlotModes.contains(template.slotMode)
      ? template.slotMode
      : slotModeWeekly;

  if (mode == slotModeDate) {
    final slotDate = template.slotDate;
    return slotDate == null ? 'One date' : formatBookingDate(slotDate);
  }

  if (mode == slotModeDaily) {
    return 'Every day';
  }

  if (mode == slotModeWeekdays) {
    return 'Weekdays';
  }

  return weekdayLabel(template.weekday ?? 0);
}

String weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    DateTime.sunday => 'Sunday',
    _ => 'Unknown',
  };
}
