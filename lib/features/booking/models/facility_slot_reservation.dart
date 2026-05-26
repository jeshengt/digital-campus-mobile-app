import 'package:cloud_firestore/cloud_firestore.dart';

class FacilitySlotReservation {
  const FacilitySlotReservation({
    required this.slotOccurrenceId,
    required this.facilityId,
    required this.templateId,
    required this.bookingId,
    required this.studentId,
    required this.requestedDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String slotOccurrenceId;
  final String facilityId;
  final String templateId;
  final String bookingId;
  final String studentId;
  final DateTime requestedDate;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  FacilitySlotReservation copyWith({
    String? slotOccurrenceId,
    String? facilityId,
    String? templateId,
    String? bookingId,
    String? studentId,
    DateTime? requestedDate,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FacilitySlotReservation(
      slotOccurrenceId: slotOccurrenceId ?? this.slotOccurrenceId,
      facilityId: facilityId ?? this.facilityId,
      templateId: templateId ?? this.templateId,
      bookingId: bookingId ?? this.bookingId,
      studentId: studentId ?? this.studentId,
      requestedDate: requestedDate ?? this.requestedDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FacilitySlotReservation.fromMap(
    Map<String, dynamic> data, {
    String? documentId,
  }) {
    return FacilitySlotReservation(
      slotOccurrenceId: data['slotOccurrenceId'] as String? ?? documentId ?? '',
      facilityId: data['facilityId'] as String? ?? '',
      templateId: data['templateId'] as String? ?? '',
      bookingId: data['bookingId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      requestedDate:
          _readDate(data['requestedDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      startTime:
          _readDate(data['startTime']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endTime:
          _readDate(data['endTime']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      status: data['status'] as String? ?? 'pending',
      createdAt:
          _readDate(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _readDate(data['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slotOccurrenceId': slotOccurrenceId,
      'facilityId': facilityId,
      'templateId': templateId,
      'bookingId': bookingId,
      'studentId': studentId,
      'requestedDate': requestedDate,
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
