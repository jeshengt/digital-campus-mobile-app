import 'facility_slot_template.dart';

class FacilitySlotOccurrence {
  const FacilitySlotOccurrence({
    required this.slotOccurrenceId,
    required this.templateId,
    required this.facilityId,
    required this.requestedDate,
    required this.startTime,
    required this.endTime,
  });

  final String slotOccurrenceId;
  final String templateId;
  final String facilityId;
  final DateTime requestedDate;
  final DateTime startTime;
  final DateTime endTime;

  factory FacilitySlotOccurrence.fromTemplate({
    required FacilitySlotTemplate template,
    required DateTime date,
  }) {
    final requestedDate = DateTime(date.year, date.month, date.day);
    final startTime = requestedDate.add(
      Duration(minutes: template.startMinutes),
    );
    final endTime = requestedDate.add(Duration(minutes: template.endMinutes));
    return FacilitySlotOccurrence(
      slotOccurrenceId: slotOccurrenceIdFor(
        facilityId: template.facilityId,
        templateId: template.templateId,
        requestedDate: requestedDate,
        startTime: startTime,
        endTime: endTime,
      ),
      templateId: template.templateId,
      facilityId: template.facilityId,
      requestedDate: requestedDate,
      startTime: startTime,
      endTime: endTime,
    );
  }
}

String slotOccurrenceIdFor({
  required String facilityId,
  required String templateId,
  required DateTime requestedDate,
  required DateTime startTime,
  required DateTime endTime,
}) {
  return [
    facilityId.trim(),
    templateId.trim(),
    _dateKey(requestedDate),
    _timeKey(startTime),
    _timeKey(endTime),
  ].join('_');
}

String bookingIdForStudentSlot({
  required String studentId,
  required String slotOccurrenceId,
}) {
  return '${studentId.trim()}_${slotOccurrenceId.trim()}';
}

String _dateKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';
}

String _timeKey(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}'
      '${value.minute.toString().padLeft(2, '0')}';
}
