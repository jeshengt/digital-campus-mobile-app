# Firebase Data Model Plan

This Phase 1 plan keeps Firebase usage compatible with the Spark Plan. The app uses Firebase Authentication for accounts and Cloud Firestore for app data. It does not use Cloud Functions, Firebase Storage, Google Maps SDK, paid APIs, or paid packages.

## Initial Collections

- `users`: user profile documents keyed by Firebase Auth UID.
- `attendanceSessions`: lecturer-owned attendance session metadata.
- `attendanceRecords`: student attendance records linked to sessions.
- `facilities`: bookable campus facility records.
- `bookings`: student booking requests and staff review state.
- `buses`: route and assigned driver information.
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

`attendanceRecords/{sessionId_studentId}` stores one student record per session with course code, student name, scan time, `locationValidated`, optional submitted latitude and longitude, optional calculated distance, status, and remarks as a shared audit copy. `attendanceSessions/{sessionId}/records/{sessionId_studentId}` stores a session-scoped copy, `users/{lecturerUid}/lecturerAttendance/{sessionId}/records/{sessionId_studentId}` stores the lecturer-owned list copy, and `users/{studentUid}/attendanceHistory/{sessionId_studentId}` stores the student-owned personal history copy. Location validation is performed in the Flutter app only when the session requires it; Security Rules restrict record ownership, active session state, duplicate document IDs, and allowed fields.

## Security Rules Reminder

Security Rules must be added before real Firestore data is used. Rules must enforce authenticated access, profile ownership, role-based permissions, admin-only role management, lecturer ownership of attendance sessions, student ownership of attendance records and bookings, staff booking review permissions, and driver-only bus location updates.
