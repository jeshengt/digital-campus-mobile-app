# Firebase Data Model Plan

This Phase 1 plan keeps Firebase usage compatible with the Spark Plan. The app uses Firebase Authentication for accounts and Cloud Firestore for app data. It does not use Cloud Functions, Firebase Storage, Google Maps SDK, paid APIs, or paid packages.

Firebase API keys are local/runtime configuration, not tracked source. The Android `google-services.json` file stays ignored and is read by the native Android Firebase setup, while Flutter Web receives its API key through the `--dart-define` value described in `docs/firebase_local_setup.md`.

## Initial Collections

- `users`: user profile documents keyed by Firebase Auth UID.
- `attendanceSessions`: lecturer-owned attendance session metadata.
- `attendanceRecords`: student attendance records linked to sessions.
- `facilities`: bookable campus facility records.
- `bookings`: student booking requests and staff review state.
- `buses`: route information with optional assigned drivers.
- `busLocations`: live bus location state, updated carefully to limit writes.
- `notifications`: in-app status updates and read state.

## Phase 1 Profile Shape

`users/{uid}` starts with these fields:

- `uid`
- `name`
- `email`
- `role`
- `matricNumber`
- `staffId`
- `emailVerified`
- `createdAt`
- `updatedAt`

Users may later edit safe profile fields only: `name`, `matricNumber`, and `staffId`. Users must not edit `uid`, `email`, `role`, `emailVerified`, or permission fields from the app UI.

## Attendance Module Shape

`attendanceSessions/{sessionId}` stores lecturer-owned QR sessions with course code, QR token, start time, optional expiry time, status, created time, and optional geofence data. `requiresLocation` controls whether latitude, longitude, and geofence radius must be present. QR tokens include the session document ID plus a random token segment so students can perform a secure direct session read instead of a broad token lookup query.

`attendanceRecords/{sessionId_studentId}` stores one student record per session with course code, student name, student email, scan time, `locationValidated`, optional submitted latitude and longitude, optional calculated distance, status, and remarks as a shared audit copy. `attendanceSessions/{sessionId}/records/{sessionId_studentId}` stores a session-scoped copy, `users/{lecturerUid}/lecturerAttendance/{sessionId}/records/{sessionId_studentId}` stores the lecturer-owned list copy, and `users/{studentUid}/attendanceHistory/{sessionId_studentId}` stores the student-owned personal history copy. Location validation is performed in the Flutter app only when the session requires it; Security Rules restrict record ownership, active session state, duplicate document IDs, and allowed fields.

## Bus Tracking Module Shape

`buses/{busId}` stores admin-managed route metadata including route name, optional assigned driver UIDs in `driverIds`, status, optional start/end names, and required `routePoints` latitude/longitude geometry for drawing a local route line on OpenStreetMap. Admins create and edit route details separately from driver assignment; the route form saves mapped route data, while the Assign Drivers action changes or clears one or more assigned drivers. `busLocations/{busId}` stores the latest driver broadcast for one bus with the currently broadcasting driver UID, latitude, longitude, speed, heading, broadcast state, and update time. Any driver listed in the route’s `driverIds` can view the route map, preview their current GPS position, and broadcast that bus at a modest interval from the Flutter app. Students and lecturers read live locations, can preview their own current GPS position locally on the map without writing it to Firebase, and the app estimates ETA locally from straight-line distance to the final route point without Cloud Functions, Google Maps, or paid routing APIs.

## Facility Booking Module Shape

`facilities/{facilityId}` stores admin-managed bookable campus facilities with name, type, location, capacity, availability status, created time, and updated time. Signed-in students read available facilities for browsing, while admins can create, edit, and delete facility records from the app.

`facilities/{facilityId}/slotTemplates/{templateId}` stores staff-managed booking slots with slot mode (`date`, `daily`, `weekdays`, or `weekly`), optional exact slot date, optional weekday, start minutes, end minutes, status, creator UID, created time, and updated time. Students do not manually choose start or end times; the app generates the next 14 days of available slot occurrences locally from active templates. Existing weekly templates without `slotMode` are treated as weekly templates by the app.

`bookings/{bookingId}` stores the shared staff-review copy of each student facility request with slot occurrence ID, facility metadata, template ID, student identity, requested date, start and end timestamps, review status, optional reviewer UID, optional review time, created time, and updated time. `users/{studentUid}/facilityBookings/{bookingId}` stores the student-owned copy used by the student booking screen so students can stream their own requests through a directly authorized owner path. Booking IDs are deterministic per student and slot (`studentId_slotOccurrenceId`), so one student cannot submit the same slot twice while different students can request seats in the same facility slot.

`facilitySlotReservations/{bookingId}` stores the active per-booking reservation for a submitted slot, including the shared `slotOccurrenceId`. `facilitySlotCapacity/{slotOccurrenceId}` stores the per-slot counter with pending, approved, and active counts. The app writes shared booking, student-owned booking, reservation, and capacity counter updates in a Firestore transaction. Pending and approved requests both hold capacity; student pending cancellation and staff cancellation release capacity, while staff approval moves one held seat from pending to approved.

## Security Rules Reminder

Security Rules must be added before real Firestore data is used. Rules must enforce authenticated access, profile ownership, role-based permissions, admin-only role management, lecturer ownership of attendance sessions, student ownership of attendance records and bookings, staff booking review permissions, and driver-only bus location updates.
