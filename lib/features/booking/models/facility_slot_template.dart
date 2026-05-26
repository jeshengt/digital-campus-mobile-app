import 'package:cloud_firestore/cloud_firestore.dart';

class FacilitySlotTemplate {
  const FacilitySlotTemplate({
    required this.templateId,
    required this.facilityId,
    required this.slotMode,
    this.slotDate,
    this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String templateId;
  final String facilityId;
  final String slotMode;
  final DateTime? slotDate;
  final int? weekday;
  final int startMinutes;
  final int endMinutes;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  FacilitySlotTemplate copyWith({
    String? templateId,
    String? facilityId,
    String? slotMode,
    DateTime? slotDate,
    int? weekday,
    int? startMinutes,
    int? endMinutes,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FacilitySlotTemplate(
      templateId: templateId ?? this.templateId,
      facilityId: facilityId ?? this.facilityId,
      slotMode: slotMode ?? this.slotMode,
      slotDate: slotDate ?? this.slotDate,
      weekday: weekday ?? this.weekday,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FacilitySlotTemplate.fromMap(
    Map<String, dynamic> data, {
    String? documentId,
  }) {
    final parsedWeekday = (data['weekday'] as num?)?.toInt();
    final parsedSlotMode = data['slotMode'] as String?;
    return FacilitySlotTemplate(
      templateId: data['templateId'] as String? ?? documentId ?? '',
      facilityId: data['facilityId'] as String? ?? '',
      slotMode: parsedSlotMode ?? (parsedWeekday == null ? 'daily' : 'weekly'),
      slotDate: _readDate(data['slotDate']),
      weekday: parsedWeekday,
      startMinutes: (data['startMinutes'] as num?)?.toInt() ?? 0,
      endMinutes: (data['endMinutes'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'inactive',
      createdBy: data['createdBy'] as String? ?? '',
      createdAt:
          _readDate(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _readDate(data['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'templateId': templateId,
      'facilityId': facilityId,
      'slotMode': slotMode,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'status': status,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };

    if (slotDate != null) {
      data['slotDate'] = slotDate;
    }

    if (weekday != null) {
      data['weekday'] = weekday;
    }

    return data;
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
