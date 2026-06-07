import 'package:cloud_firestore/cloud_firestore.dart';

const notificationTypeFacilityBookingStatus = 'facilityBookingStatus';

class AppNotification {
  const AppNotification({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.bookingId,
    required this.facilityId,
    required this.facilityName,
    required this.status,
    required this.isRead,
    required this.createdAt,
  });

  final String notificationId;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String bookingId;
  final String facilityId;
  final String facilityName;
  final String status;
  final bool isRead;
  final DateTime createdAt;

  AppNotification copyWith({
    String? notificationId,
    String? userId,
    String? title,
    String? message,
    String? type,
    String? bookingId,
    String? facilityId,
    String? facilityName,
    String? status,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      bookingId: bookingId ?? this.bookingId,
      facilityId: facilityId ?? this.facilityId,
      facilityName: facilityName ?? this.facilityName,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AppNotification.fromMap(
    Map<String, dynamic> data, {
    String? documentId,
  }) {
    return AppNotification(
      notificationId: data['notificationId'] as String? ?? documentId ?? '',
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      type: data['type'] as String? ?? '',
      bookingId: data['bookingId'] as String? ?? '',
      facilityId: data['facilityId'] as String? ?? '',
      facilityName: data['facilityName'] as String? ?? '',
      status: data['status'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      createdAt:
          _readDate(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'bookingId': bookingId,
      'facilityId': facilityId,
      'facilityName': facilityName,
      'status': status,
      'isRead': isRead,
      'createdAt': createdAt,
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
