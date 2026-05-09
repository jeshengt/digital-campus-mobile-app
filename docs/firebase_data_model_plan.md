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

## Security Rules Reminder

Security Rules must be added before real Firestore data is used. Rules must enforce authenticated access, profile ownership, role-based permissions, admin-only role management, lecturer ownership of attendance sessions, student ownership of attendance records and bookings, staff booking review permissions, and driver-only bus location updates.
