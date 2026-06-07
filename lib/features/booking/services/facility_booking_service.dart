import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/errors/app_exception.dart';
import '../../profile/services/user_profile_service.dart';
import '../models/facility.dart';
import '../models/facility_booking.dart';
import '../models/facility_slot_capacity.dart';
import '../models/facility_slot_occurrence.dart';
import '../models/facility_slot_reservation.dart';
import '../models/facility_slot_template.dart';
import '../utils/booking_validation.dart';
import '../../notifications/utils/facility_booking_notification_builder.dart';

abstract class FacilityBookingService {
  Stream<List<Facility>> watchAvailableFacilities();

  Stream<List<Facility>> watchFacilities();

  Stream<List<FacilityBooking>> watchCurrentStudentBookings();

  Stream<List<FacilityBooking>> watchBookingRequests();

  Stream<List<FacilitySlotTemplate>> watchSlotTemplatesForFacility(
    String facilityId,
  );

  Stream<List<FacilitySlotTemplate>> watchAvailableSlotTemplatesForFacility(
    String facilityId,
  );

  Stream<List<FacilitySlotReservation>> watchReservationsForFacility(
    String facilityId,
  );

  Stream<List<FacilitySlotCapacity>> watchSlotCapacitiesForFacility(
    String facilityId,
  );

  Future<Facility> createFacility(Facility facility);

  Future<void> updateFacility(Facility facility);

  Future<void> deleteFacility(String facilityId);

  Future<FacilitySlotTemplate> createSlotTemplate(
    FacilitySlotTemplate template,
  );

  Future<void> updateSlotTemplate(FacilitySlotTemplate template);

  Future<void> deleteSlotTemplate(FacilitySlotTemplate template);

  Future<FacilityBooking> submitBooking({
    required Facility facility,
    required FacilitySlotOccurrence slot,
  });

  Future<void> cancelStudentBooking(FacilityBooking booking);

  Future<void> approveBooking(FacilityBooking booking);

  Future<void> cancelBookingAsStaff(FacilityBooking booking);
}

class FirebaseFacilityBookingService implements FacilityBookingService {
  FirebaseFacilityBookingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    UserProfileService? profileService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _profileService = profileService ?? UserProfileService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final UserProfileService _profileService;

  CollectionReference<Map<String, dynamic>> get _facilities =>
      _firestore.collection(FirebaseCollections.facilities);

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection(FirebaseCollections.bookings);

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(FirebaseCollections.notifications);

  CollectionReference<Map<String, dynamic>> get _reservations =>
      _firestore.collection('facilitySlotReservations');

  CollectionReference<Map<String, dynamic>> get _slotCapacities =>
      _firestore.collection('facilitySlotCapacity');

  CollectionReference<Map<String, dynamic>> _slotTemplates(String facilityId) {
    return _facilities.doc(facilityId).collection('slotTemplates');
  }

  CollectionReference<Map<String, dynamic>> _studentBookings(String uid) {
    return _firestore
        .collection(FirebaseCollections.users)
        .doc(uid)
        .collection('facilityBookings');
  }

  DocumentReference<Map<String, dynamic>> _slotCapacityDoc(
    String slotOccurrenceId,
  ) {
    return _slotCapacities.doc(slotOccurrenceId);
  }

  @override
  Stream<List<Facility>> watchAvailableFacilities() {
    return _facilities
        .where('status', isEqualTo: facilityStatusAvailable)
        .snapshots()
        .map(_facilitiesFromSnapshot);
  }

  @override
  Stream<List<Facility>> watchFacilities() {
    return _facilities.snapshots().map(_facilitiesFromSnapshot);
  }

  @override
  Stream<List<FacilityBooking>> watchCurrentStudentBookings() {
    final student = _requireCurrentUser();

    return _studentBookings(student.uid).snapshots().map(_bookingsFromSnapshot);
  }

  @override
  Stream<List<FacilityBooking>> watchBookingRequests() {
    return _bookings.snapshots().map(_bookingsFromSnapshot);
  }

  @override
  Stream<List<FacilitySlotTemplate>> watchSlotTemplatesForFacility(
    String facilityId,
  ) {
    return _slotTemplates(facilityId).snapshots().map((snapshot) {
      return _slotTemplatesFromSnapshot(snapshot);
    });
  }

  @override
  Stream<List<FacilitySlotTemplate>> watchAvailableSlotTemplatesForFacility(
    String facilityId,
  ) {
    return _slotTemplates(facilityId)
        .where('status', isEqualTo: slotTemplateStatusActive)
        .snapshots()
        .map(_slotTemplatesFromSnapshot);
  }

  static List<FacilitySlotTemplate> _slotTemplatesFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final templates = snapshot.docs
        .map(
          (doc) => FacilitySlotTemplate.fromMap(doc.data(), documentId: doc.id),
        )
        .toList();
    templates.sort((a, b) {
      final modeCompare = a.slotMode.compareTo(b.slotMode);
      if (modeCompare != 0) {
        return modeCompare;
      }

      final dateCompare = (a.slotDate ?? DateTime(0)).compareTo(
        b.slotDate ?? DateTime(0),
      );
      if (dateCompare != 0) {
        return dateCompare;
      }

      final weekdayCompare = (a.weekday ?? 0).compareTo(b.weekday ?? 0);
      if (weekdayCompare != 0) {
        return weekdayCompare;
      }
      return a.startMinutes.compareTo(b.startMinutes);
    });
    return templates;
  }

  @override
  Stream<List<FacilitySlotReservation>> watchReservationsForFacility(
    String facilityId,
  ) {
    return _reservations
        .where('facilityId', isEqualTo: facilityId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => FacilitySlotReservation.fromMap(
                  doc.data(),
                  documentId: doc.id,
                ),
              )
              .toList();
        });
  }

  @override
  Stream<List<FacilitySlotCapacity>> watchSlotCapacitiesForFacility(
    String facilityId,
  ) {
    return _slotCapacities
        .where('facilityId', isEqualTo: facilityId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => FacilitySlotCapacity.fromMap(
                  doc.data(),
                  documentId: doc.id,
                ),
              )
              .toList();
        });
  }

  @override
  Future<Facility> createFacility(Facility facility) async {
    final doc = facility.facilityId.trim().isEmpty
        ? _facilities.doc()
        : _facilities.doc(facility.facilityId);
    final now = DateTime.now();
    final savedFacility = facility.copyWith(
      facilityId: doc.id,
      createdAt: now,
      updatedAt: now,
    );

    await doc.set(savedFacility.toMap());
    return savedFacility;
  }

  @override
  Future<void> updateFacility(Facility facility) async {
    await _facilities
        .doc(facility.facilityId)
        .set(facility.copyWith(updatedAt: DateTime.now()).toMap());
  }

  @override
  Future<void> deleteFacility(String facilityId) async {
    await _facilities.doc(facilityId).delete();
  }

  @override
  Future<FacilitySlotTemplate> createSlotTemplate(
    FacilitySlotTemplate template,
  ) async {
    final staff = _requireCurrentUser();
    final doc = template.templateId.trim().isEmpty
        ? _slotTemplates(template.facilityId).doc()
        : _slotTemplates(template.facilityId).doc(template.templateId);
    final now = DateTime.now();
    final savedTemplate = template.copyWith(
      templateId: doc.id,
      createdBy: staff.uid,
      createdAt: now,
      updatedAt: now,
    );

    await doc.set(savedTemplate.toMap());
    return savedTemplate;
  }

  @override
  Future<void> updateSlotTemplate(FacilitySlotTemplate template) async {
    await _slotTemplates(template.facilityId)
        .doc(template.templateId)
        .set(template.copyWith(updatedAt: DateTime.now()).toMap());
  }

  @override
  Future<void> deleteSlotTemplate(FacilitySlotTemplate template) async {
    await _slotTemplates(template.facilityId).doc(template.templateId).delete();
  }

  @override
  Future<FacilityBooking> submitBooking({
    required Facility facility,
    required FacilitySlotOccurrence slot,
  }) async {
    final student = _requireCurrentUser();
    final now = DateTime.now();
    final slotOccurrenceId = bookingDocumentId(
      slotOccurrenceId: slot.slotOccurrenceId,
    );
    final bookingId = bookingIdForStudentSlot(
      studentId: student.uid,
      slotOccurrenceId: slotOccurrenceId,
    );
    final profile = await _profileService.getProfile(student.uid);
    final booking = FacilityBooking(
      bookingId: bookingId,
      slotOccurrenceId: slot.slotOccurrenceId,
      facilityId: facility.facilityId,
      templateId: slot.templateId,
      facilityName: facility.name,
      studentId: student.uid,
      studentName: profile?.name ?? student.displayName ?? 'Student',
      studentEmail: student.email ?? profile?.email ?? '',
      requestedDate: bookingDateOnly(slot.requestedDate),
      startTime: slot.startTime,
      endTime: slot.endTime,
      status: bookingStatusPending,
      reviewedBy: null,
      reviewedAt: null,
      createdAt: now,
      updatedAt: now,
    );
    final reservation = FacilitySlotReservation(
      slotOccurrenceId: slot.slotOccurrenceId,
      facilityId: facility.facilityId,
      templateId: slot.templateId,
      bookingId: bookingId,
      studentId: student.uid,
      requestedDate: bookingDateOnly(slot.requestedDate),
      startTime: slot.startTime,
      endTime: slot.endTime,
      status: bookingStatusPending,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _firestore.runTransaction((transaction) async {
        final facilityDoc = _facilities.doc(facility.facilityId);
        final capacityDoc = _slotCapacityDoc(slot.slotOccurrenceId);
        final bookingDoc = _bookings.doc(bookingId);
        final legacyReservationDoc = _reservations.doc(slot.slotOccurrenceId);

        final facilitySnapshot = await transaction.get(facilityDoc);
        final capacitySnapshot = await transaction.get(capacityDoc);
        final bookingSnapshot = await transaction.get(bookingDoc);
        final legacyReservationSnapshot = bookingId == slot.slotOccurrenceId
            ? null
            : await transaction.get(legacyReservationDoc);

        if (bookingSnapshot.exists) {
          throw const AppException('You already submitted this slot request.');
        }

        final savedFacility = facilitySnapshot.exists
            ? Facility.fromMap(
                facilitySnapshot.data()!,
                documentId: facilitySnapshot.id,
              )
            : facility;
        final currentCapacity = _capacityFromSnapshot(
          capacitySnapshot,
          fallbackSlot: slot,
          legacyReservation: legacyReservationSnapshot,
        );
        final nextCapacity = nextCapacityForSubmit(
          current: currentCapacity,
          slot: slot,
          facilityCapacity: savedFacility.capacity,
          now: now,
        );
        final bookingData = booking.toMap();

        transaction.set(bookingDoc, bookingData);
        transaction.set(
          _studentBookings(student.uid).doc(bookingId),
          bookingData,
        );
        transaction.set(_reservations.doc(bookingId), reservation.toMap());
        transaction.set(capacityDoc, nextCapacity.toMap());
      });
    } on FirebaseException catch (error) {
      if (error.code == 'already-exists') {
        throw const AppException('You already submitted this slot request.');
      }

      if (error.code == 'permission-denied') {
        throw const AppException(bookingSaveDeniedMessage);
      }

      rethrow;
    } on StateError catch (error) {
      if (error.message == 'capacity-full') {
        throw const AppException(bookingCapacityFullMessage);
      }

      rethrow;
    }

    return booking;
  }

  @override
  Future<void> cancelStudentBooking(FacilityBooking booking) async {
    if (booking.status != bookingStatusPending) {
      throw const AppException('Only pending bookings can be cancelled.');
    }

    await _cancelBooking(booking);
  }

  @override
  Future<void> approveBooking(FacilityBooking booking) async {
    await _reviewBooking(booking: booking, status: bookingStatusApproved);
  }

  @override
  Future<void> cancelBookingAsStaff(FacilityBooking booking) async {
    await _reviewBooking(booking: booking, status: bookingStatusCancelled);
  }

  Future<void> _reviewBooking({
    required FacilityBooking booking,
    required String status,
  }) async {
    final reviewer = _requireCurrentUser();
    if (status == bookingStatusCancelled) {
      await _cancelBooking(booking, reviewerId: reviewer.uid);
      return;
    }

    final now = DateTime.now();
    final notificationDoc = _notifications.doc();
    final notification = buildFacilityBookingStatusNotification(
      notificationId: notificationDoc.id,
      booking: booking,
      status: status,
      createdAt: now,
    );

    try {
      await _firestore.runTransaction((transaction) async {
        final facilityDoc = _facilities.doc(booking.facilityId);
        final capacityDoc = _slotCapacityDoc(booking.slotOccurrenceId);
        final reservationDoc = _reservations.doc(booking.bookingId);

        final facilitySnapshot = await transaction.get(facilityDoc);
        final capacitySnapshot = await transaction.get(capacityDoc);
        final reservationSnapshot = await transaction.get(reservationDoc);

        final savedFacility = facilitySnapshot.exists
            ? Facility.fromMap(
                facilitySnapshot.data()!,
                documentId: facilitySnapshot.id,
              )
            : null;
        final currentCapacity = _capacityFromSnapshot(
          capacitySnapshot,
          fallbackBooking: booking,
          legacyReservation: reservationSnapshot,
        );
        if (savedFacility == null || currentCapacity == null) {
          throw const AppException('Could not verify facility capacity.');
        }

        final nextCapacity = nextCapacityForApproval(
          current: currentCapacity,
          facilityCapacity: savedFacility.capacity,
          now: now,
        );
        final updates = {
          'status': status,
          'reviewedBy': reviewer.uid,
          'reviewedAt': now,
          'updatedAt': now,
        };

        transaction.update(_bookings.doc(booking.bookingId), updates);
        transaction.update(
          _studentBookings(booking.studentId).doc(booking.bookingId),
          updates,
        );
        transaction.set(capacityDoc, nextCapacity.toMap());
        transaction.update(reservationDoc, {
          'status': status,
          'updatedAt': now,
        });
        transaction.set(notificationDoc, notification.toMap());
      });
    } on StateError catch (error) {
      if (error.message == 'capacity-full') {
        throw const AppException(bookingCapacityFullMessage);
      }

      rethrow;
    }
  }

  Future<void> _cancelBooking(
    FacilityBooking booking, {
    String? reviewerId,
  }) async {
    final now = DateTime.now();
    final notificationDoc = reviewerId == null ? null : _notifications.doc();
    final notification = notificationDoc == null
        ? null
        : buildFacilityBookingStatusNotification(
            notificationId: notificationDoc.id,
            booking: booking,
            status: bookingStatusCancelled,
            createdAt: now,
          );

    await _firestore.runTransaction((transaction) async {
      final capacityDoc = _slotCapacityDoc(booking.slotOccurrenceId);
      final reservationDoc = _reservations.doc(booking.bookingId);
      final legacyReservationDoc = _reservations.doc(booking.slotOccurrenceId);
      final capacitySnapshot = await transaction.get(capacityDoc);
      final reservationSnapshot = await transaction.get(reservationDoc);
      final legacyReservationSnapshot =
          booking.bookingId == booking.slotOccurrenceId
          ? null
          : await transaction.get(legacyReservationDoc);

      final currentCapacity = _capacityFromSnapshot(
        capacitySnapshot,
        fallbackBooking: booking,
        legacyReservation: reservationSnapshot.exists
            ? reservationSnapshot
            : legacyReservationSnapshot,
      );
      final updates = <String, Object>{
        'status': bookingStatusCancelled,
        'updatedAt': now,
      };
      if (reviewerId != null) {
        updates['reviewedBy'] = reviewerId;
        updates['reviewedAt'] = now;
      }

      transaction.update(_bookings.doc(booking.bookingId), updates);
      transaction.update(
        _studentBookings(booking.studentId).doc(booking.bookingId),
        updates,
      );
      if (currentCapacity != null) {
        final nextCapacity = nextCapacityForCancellation(
          current: currentCapacity,
          previousStatus: booking.status,
          now: now,
        );
        transaction.set(capacityDoc, nextCapacity.toMap());
      }
      if (reservationSnapshot.exists) {
        transaction.delete(reservationDoc);
      }
      if (legacyReservationSnapshot != null &&
          legacyReservationSnapshot.exists) {
        transaction.delete(legacyReservationDoc);
      }
      if (notificationDoc != null && notification != null) {
        transaction.set(notificationDoc, notification.toMap());
      }
    });
  }

  FacilitySlotCapacity? _capacityFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    FacilitySlotOccurrence? fallbackSlot,
    FacilityBooking? fallbackBooking,
    DocumentSnapshot<Map<String, dynamic>>? legacyReservation,
  }) {
    if (snapshot.exists) {
      return FacilitySlotCapacity.fromMap(
        snapshot.data()!,
        documentId: snapshot.id,
      );
    }

    final hasLegacyReservation = legacyReservation?.exists ?? false;
    if (!hasLegacyReservation &&
        fallbackSlot == null &&
        fallbackBooking == null) {
      return null;
    }

    final legacyStatus = hasLegacyReservation
        ? FacilitySlotReservation.fromMap(
            legacyReservation!.data()!,
            documentId: legacyReservation.id,
          ).status
        : null;
    final pendingCount = legacyStatus == bookingStatusPending ? 1 : 0;
    final approvedCount = legacyStatus == bookingStatusApproved ? 1 : 0;
    final activeCount = pendingCount + approvedCount;
    final now = DateTime.now();

    if (fallbackSlot != null) {
      return FacilitySlotCapacity(
        slotOccurrenceId: fallbackSlot.slotOccurrenceId,
        facilityId: fallbackSlot.facilityId,
        requestedDate: bookingDateOnly(fallbackSlot.requestedDate),
        startTime: fallbackSlot.startTime,
        endTime: fallbackSlot.endTime,
        pendingCount: pendingCount,
        approvedCount: approvedCount,
        activeCount: activeCount,
        createdAt: now,
        updatedAt: now,
      );
    }

    final booking = fallbackBooking!;
    return FacilitySlotCapacity(
      slotOccurrenceId: booking.slotOccurrenceId,
      facilityId: booking.facilityId,
      requestedDate: bookingDateOnly(booking.requestedDate),
      startTime: booking.startTime,
      endTime: booking.endTime,
      pendingCount: pendingCount,
      approvedCount: approvedCount,
      activeCount: activeCount,
      createdAt: now,
      updatedAt: now,
    );
  }

  User _requireCurrentUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AppException(
        'You must be signed in to use facility booking.',
      );
    }

    return user;
  }

  static List<Facility> _facilitiesFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final facilities = snapshot.docs
        .map((doc) => Facility.fromMap(doc.data(), documentId: doc.id))
        .toList();
    facilities.sort((a, b) => a.name.compareTo(b.name));
    return facilities;
  }

  static List<FacilityBooking> _bookingsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final bookings = snapshot.docs
        .map((doc) => FacilityBooking.fromMap(doc.data(), documentId: doc.id))
        .toList();
    bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bookings;
  }
}
