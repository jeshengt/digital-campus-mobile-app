import 'package:cloud_firestore/cloud_firestore.dart';

class FacilitySlotCapacity {
  const FacilitySlotCapacity({
    required this.slotOccurrenceId,
    required this.facilityId,
    required this.requestedDate,
    required this.startTime,
    required this.endTime,
    required this.pendingCount,
    required this.approvedCount,
    required this.activeCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String slotOccurrenceId;
  final String facilityId;
  final DateTime requestedDate;
  final DateTime startTime;
  final DateTime endTime;
  final int pendingCount;
  final int approvedCount;
  final int activeCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  FacilitySlotCapacity copyWith({
    String? slotOccurrenceId,
    String? facilityId,
    DateTime? requestedDate,
    DateTime? startTime,
    DateTime? endTime,
    int? pendingCount,
    int? approvedCount,
    int? activeCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FacilitySlotCapacity(
      slotOccurrenceId: slotOccurrenceId ?? this.slotOccurrenceId,
      facilityId: facilityId ?? this.facilityId,
      requestedDate: requestedDate ?? this.requestedDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      pendingCount: pendingCount ?? this.pendingCount,
      approvedCount: approvedCount ?? this.approvedCount,
      activeCount: activeCount ?? this.activeCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FacilitySlotCapacity.fromMap(
    Map<String, dynamic> data, {
    String? documentId,
  }) {
    return FacilitySlotCapacity(
      slotOccurrenceId: data['slotOccurrenceId'] as String? ?? documentId ?? '',
      facilityId: data['facilityId'] as String? ?? '',
      requestedDate:
          _readDate(data['requestedDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      startTime:
          _readDate(data['startTime']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endTime:
          _readDate(data['endTime']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      pendingCount: (data['pendingCount'] as num?)?.toInt() ?? 0,
      approvedCount: (data['approvedCount'] as num?)?.toInt() ?? 0,
      activeCount: (data['activeCount'] as num?)?.toInt() ?? 0,
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
      'requestedDate': requestedDate,
      'startTime': startTime,
      'endTime': endTime,
      'pendingCount': pendingCount,
      'approvedCount': approvedCount,
      'activeCount': activeCount,
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
