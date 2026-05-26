import 'package:cloud_firestore/cloud_firestore.dart';

class FacilityBooking {
  const FacilityBooking({
    required this.bookingId,
    required this.slotOccurrenceId,
    required this.facilityId,
    required this.templateId,
    required this.facilityName,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.requestedDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String bookingId;
  final String slotOccurrenceId;
  final String facilityId;
  final String templateId;
  final String facilityName;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final DateTime requestedDate;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  FacilityBooking copyWith({
    String? bookingId,
    String? slotOccurrenceId,
    String? facilityId,
    String? templateId,
    String? facilityName,
    String? studentId,
    String? studentName,
    String? studentEmail,
    DateTime? requestedDate,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FacilityBooking(
      bookingId: bookingId ?? this.bookingId,
      slotOccurrenceId: slotOccurrenceId ?? this.slotOccurrenceId,
      facilityId: facilityId ?? this.facilityId,
      templateId: templateId ?? this.templateId,
      facilityName: facilityName ?? this.facilityName,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      requestedDate: requestedDate ?? this.requestedDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FacilityBooking.fromMap(
    Map<String, dynamic> data, {
    String? documentId,
  }) {
    return FacilityBooking(
      bookingId: data['bookingId'] as String? ?? documentId ?? '',
      slotOccurrenceId:
          data['slotOccurrenceId'] as String? ??
          data['bookingId'] as String? ??
          documentId ??
          '',
      facilityId: data['facilityId'] as String? ?? '',
      templateId: data['templateId'] as String? ?? '',
      facilityName: data['facilityName'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      studentEmail: data['studentEmail'] as String? ?? '',
      requestedDate:
          _readDate(data['requestedDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      startTime:
          _readDate(data['startTime']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endTime:
          _readDate(data['endTime']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      status: data['status'] as String? ?? 'pending',
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: _readDate(data['reviewedAt']),
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
      'bookingId': bookingId,
      'slotOccurrenceId': slotOccurrenceId,
      'facilityId': facilityId,
      'templateId': templateId,
      'facilityName': facilityName,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'requestedDate': requestedDate,
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt,
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
