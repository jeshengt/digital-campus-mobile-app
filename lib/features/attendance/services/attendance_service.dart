import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/errors/app_exception.dart';
import '../../../features/profile/services/user_profile_service.dart';
import '../models/attendance_record.dart';
import '../models/attendance_session.dart';
import '../utils/attendance_helpers.dart';

abstract class AttendanceService {
  Future<AttendanceSession> createSession({
    required String courseCode,
    required bool requiresLocation,
    double? latitude,
    double? longitude,
    double? geofenceRadius,
    int? durationMinutes,
  });

  Stream<List<AttendanceSession>> watchLecturerSessions();

  Future<AttendanceSession?> findActiveSessionByQrCode(String qrCodeValue);

  Future<void> closeSession(String sessionId);

  Stream<List<AttendanceRecord>> watchRecordsForSession(String sessionId);

  Stream<List<AttendanceRecord>> watchCurrentStudentRecords();

  Future<AttendanceRecord> submitAttendance({
    required AttendanceSession session,
    double? latitude,
    double? longitude,
    double? distanceMeters,
  });
}

class FirebaseAttendanceService implements AttendanceService {
  FirebaseAttendanceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    UserProfileService? profileService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _profileService = profileService ?? UserProfileService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final UserProfileService _profileService;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection(FirebaseCollections.attendanceSessions);

  CollectionReference<Map<String, dynamic>> get _records =>
      _firestore.collection(FirebaseCollections.attendanceRecords);

  CollectionReference<Map<String, dynamic>> _studentHistory(String uid) {
    return _firestore
        .collection(FirebaseCollections.users)
        .doc(uid)
        .collection('attendanceHistory');
  }

  CollectionReference<Map<String, dynamic>> _lecturerSessionRecords({
    required String lecturerId,
    required String sessionId,
  }) {
    return _firestore
        .collection(FirebaseCollections.users)
        .doc(lecturerId)
        .collection('lecturerAttendance')
        .doc(sessionId)
        .collection('records');
  }

  CollectionReference<Map<String, dynamic>> _sessionRecords(String sessionId) {
    return _sessions.doc(sessionId).collection('records');
  }

  @override
  Future<AttendanceSession> createSession({
    required String courseCode,
    required bool requiresLocation,
    double? latitude,
    double? longitude,
    double? geofenceRadius,
    int? durationMinutes,
  }) async {
    final lecturer = _requireCurrentUser();
    final now = DateTime.now();
    final doc = _sessions.doc();
    final session = AttendanceSession(
      sessionId: doc.id,
      lecturerId: lecturer.uid,
      courseCode: courseCode.trim().toUpperCase(),
      requiresLocation: requiresLocation,
      latitude: requiresLocation ? latitude : null,
      longitude: requiresLocation ? longitude : null,
      geofenceRadius: requiresLocation ? geofenceRadius : null,
      qrCodeValue: generateAttendanceQrToken(sessionId: doc.id, now: now),
      startTime: now,
      expiryTime: durationMinutes == null
          ? null
          : now.add(Duration(minutes: durationMinutes)),
      status: attendanceStatusActive,
      createdAt: now,
    );

    await doc.set(session.toMap());
    return session;
  }

  @override
  Future<void> closeSession(String sessionId) async {
    _requireCurrentUser();
    await _sessions.doc(sessionId).update({'status': attendanceStatusClosed});
  }

  @override
  Stream<List<AttendanceSession>> watchLecturerSessions() {
    final lecturer = _requireCurrentUser();

    return _sessions
        .where('lecturerId', isEqualTo: lecturer.uid)
        .snapshots()
        .map((snapshot) {
          final sessions = snapshot.docs
              .map((doc) => AttendanceSession.fromMap(doc.data()))
              .toList();
          sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return sessions;
        });
  }

  @override
  Future<AttendanceSession?> findActiveSessionByQrCode(
    String qrCodeValue,
  ) async {
    final normalizedQr = normalizeQrCodeValue(qrCodeValue);
    if (normalizedQr.isEmpty) {
      return null;
    }

    final sessionId = sessionIdFromAttendanceQr(normalizedQr);
    if (sessionId == null) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _sessions.doc(sessionId).get();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return null;
      }

      rethrow;
    }

    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }

    final session = AttendanceSession.fromMap(data);
    if (session.qrCodeValue != normalizedQr) {
      return null;
    }

    if (!isSessionActive(
      status: session.status,
      expiryTime: session.expiryTime,
    )) {
      return null;
    }

    return session;
  }

  @override
  Stream<List<AttendanceRecord>> watchRecordsForSession(String sessionId) {
    final lecturer = _requireCurrentUser();

    return _lecturerSessionRecords(
      lecturerId: lecturer.uid,
      sessionId: sessionId,
    ).snapshots().map((snapshot) {
      final records = snapshot.docs
          .map((doc) => AttendanceRecord.fromMap(doc.data()))
          .toList();
      records.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      return records;
    });
  }

  @override
  Stream<List<AttendanceRecord>> watchCurrentStudentRecords() {
    final student = _requireCurrentUser();

    return _studentHistory(student.uid).snapshots().map((snapshot) {
      final records = snapshot.docs
          .map((doc) => AttendanceRecord.fromMap(doc.data()))
          .toList();
      records.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      return records;
    });
  }

  @override
  Future<AttendanceRecord> submitAttendance({
    required AttendanceSession session,
    double? latitude,
    double? longitude,
    double? distanceMeters,
  }) async {
    final student = _requireCurrentUser();

    if (!isSessionActive(
      status: session.status,
      expiryTime: session.expiryTime,
    )) {
      throw const AppException('This attendance session has expired.');
    }

    if (session.requiresLocation) {
      final radius = session.geofenceRadius;
      if (latitude == null ||
          longitude == null ||
          distanceMeters == null ||
          radius == null) {
        throw const AppException('Location validation is required.');
      }

      if (!isInsideGeofence(
        distanceMeters: distanceMeters,
        radiusMeters: radius,
      )) {
        throw AppException(
          'You are ${distanceMeters.toStringAsFixed(0)}m away from the session location.',
        );
      }
    }

    final recordId = attendanceRecordId(
      sessionId: session.sessionId,
      studentId: student.uid,
    );
    final recordDoc = _records.doc(recordId);
    final sessionRecordDoc = _sessionRecords(session.sessionId).doc(recordId);
    final lecturerRecordDoc = _lecturerSessionRecords(
      lecturerId: session.lecturerId,
      sessionId: session.sessionId,
    ).doc(recordId);
    final historyDoc = _studentHistory(student.uid).doc(recordId);

    final profile = await _profileService.getProfile(student.uid);
    final record = AttendanceRecord(
      recordId: recordId,
      sessionId: session.sessionId,
      courseCode: session.courseCode,
      studentId: student.uid,
      studentName: profile?.name ?? student.displayName ?? 'Student',
      scannedAt: DateTime.now(),
      locationValidated: session.requiresLocation,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters,
      status: attendanceRecordStatusPresent,
      remarks: session.requiresLocation
          ? 'Validated by QR and location'
          : 'Validated by QR',
    );

    try {
      final batch = _firestore.batch();
      final recordData = record.toMap();
      batch.set(recordDoc, recordData);
      batch.set(sessionRecordDoc, recordData);
      batch.set(lecturerRecordDoc, recordData);
      batch.set(historyDoc, recordData);
      await batch.commit();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const AppException(
          'Attendance could not be saved. You may have already submitted it.',
        );
      }

      rethrow;
    }

    return record;
  }

  User _requireCurrentUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AppException('You must be signed in to use attendance.');
    }

    return user;
  }
}
