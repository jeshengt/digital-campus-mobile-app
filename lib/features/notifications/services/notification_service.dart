import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/errors/app_exception.dart';
import '../models/app_notification.dart';

abstract class NotificationService {
  Stream<List<AppNotification>> watchCurrentUserNotifications();

  Stream<int> watchUnreadCount();

  Future<void> markAsRead(AppNotification notification);
}

class FirebaseNotificationService implements NotificationService {
  FirebaseNotificationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(FirebaseCollections.notifications);

  @override
  Stream<List<AppNotification>> watchCurrentUserNotifications() {
    return _firebaseAuth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(const <AppNotification>[]);
      }

      return _notifications
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .map(_notificationsFromSnapshot);
    });
  }

  @override
  Stream<int> watchUnreadCount() {
    return watchCurrentUserNotifications().map((notifications) {
      return notifications.where((notification) => !notification.isRead).length;
    });
  }

  @override
  Future<void> markAsRead(AppNotification notification) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AppException('You must be signed in to read notifications.');
    }

    if (notification.userId != user.uid) {
      throw const AppException('You can only update your own notifications.');
    }

    if (notification.isRead) {
      return;
    }

    await _notifications.doc(notification.notificationId).update({
      'isRead': true,
    });
  }

  static List<AppNotification> _notificationsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final notifications = snapshot.docs
        .map((doc) => AppNotification.fromMap(doc.data(), documentId: doc.id))
        .toList();
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }
}
