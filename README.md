<div align="center">
  <img src="assets/images/utmgologonobg.png" alt="UTM Go logo" width="160">

  # UTM Go

  **A digital campus companion for Universiti Teknologi Malaysia**

  Flutter application for Android and Web

  [Open Web App](https://utmgooo.web.app) · [Download Android APK](https://drive.google.com/drive/folders/1jMqnA0l7Oc93-4vQ--axDXp2Q7FAF0nB?usp=sharing)
</div>

> [!NOTE]
> UTM Go is an independent student project created for Universiti Teknologi Malaysia campus workflows. It is not an official UTM application or service.

## Overview

UTM Go brings common campus services into one role-based application for students, lecturers, bus drivers, facility staff, and administrators. It combines attendance management, facility booking, live bus tracking, profile management, notifications, and operational dashboards.

The application currently targets **Android** and **Flutter Web**.

## Features

| Role | Available capabilities |
| --- | --- |
| **Student** | Scan attendance QR codes, complete optional location validation, review attendance history, browse and request facility slots, track campus buses, manage bookings, and receive booking notifications. |
| **Lecturer** | Create attendance sessions, generate and share QR posters, configure optional time and location validation, monitor live attendance lists, export local PDF reports, and track campus buses. |
| **Bus Driver** | View assigned routes and broadcast the latest bus location, speed, heading, and status. |
| **Staff** | Review booking requests, approve or cancel requests, and manage facility availability slots. |
| **Admin** | View system analytics, manage facilities, create and edit bus routes, and assign drivers to routes. |

Shared account features include registration, sign-in, email verification, password reset, profile management, password changes, and role-based navigation.

## Download

Use UTM Go directly in a browser:

**[Open UTM Go Web App](https://utmgooo.web.app)**

The latest shared Android APK is available from the project Google Drive folder:

**[Download UTM Go for Android](https://drive.google.com/drive/folders/1jMqnA0l7Oc93-4vQ--axDXp2Q7FAF0nB?usp=sharing)**

Android may ask for permission to install an APK obtained outside the Play Store.

## Technology

- Flutter 3.41.8 and Dart 3.11.5
- Firebase Authentication
- Cloud Firestore with role-based Security Rules
- OpenStreetMap through `flutter_map`
- Device location and QR scanning
- Local PDF generation and sharing
- Firebase Hosting configuration for Flutter Web

## Project Structure

```text
lib/
  app/          # Application setup, routing, and themes
  core/         # Shared constants and utilities
  features/     # Role dashboards and feature modules
  models/       # Shared application models
  services/     # Shared Firebase and device services
  shared/       # Reusable layouts and widgets

docs/           # Firebase setup and data model guidance
test/           # Focused module and widget tests
firestore.rules # Firestore role and data access rules
```

Feature modules are organized under `lib/features/`, including authentication, profile management, attendance, facility booking, bus tracking, notifications, analytics, and role dashboards.

## Getting Started

### Prerequisites

- Flutter 3.41.8
- Dart 3.11.5
- Android Studio or another Flutter-compatible IDE
- An authorized Firebase configuration for the project

### Install Dependencies

```bash
git clone https://github.com/jeshengt/digital-campus-mobile-app.git
cd digital-campus-mobile-app
flutter pub get
```

### Configure Firebase

Real Firebase credentials are intentionally not committed to this repository. You need an authorized local Firebase configuration before the app can connect to Firebase.

For Android:

1. Copy `android/app/google-services.json.template` to `android/app/google-services.json`.
2. Replace the placeholder API key with an authorized restricted Android Firebase API key.
3. Keep `android/app/google-services.json` untracked.

For Flutter Web, provide an authorized restricted web Firebase API key at runtime:

```bash
flutter run -d chrome --dart-define=UTMGO_FIREBASE_WEB_API_KEY=your_web_key
```

See [Firebase Local Setup](docs/firebase_local_setup.md) for the complete configuration guidance.

### Run the App

Android:

```bash
flutter run
```

Flutter Web:

```bash
flutter run -d chrome --dart-define=UTMGO_FIREBASE_WEB_API_KEY=your_web_key
```

### Build

Android APK:

```bash
flutter build apk
```

Flutter Web:

```bash
flutter build web --dart-define=UTMGO_FIREBASE_WEB_API_KEY=your_web_key
```

## Quality Checks

```bash
flutter analyze
flutter test
```

## Documentation

- [Firebase Local Setup](docs/firebase_local_setup.md)
- [Firebase Data Model Plan](docs/firebase_data_model_plan.md)

## Roadmap

- Admin user management
- Admin role and permission management
- Expanded notification and in-app status workflows
- Additional campus reports and analytics
- Further deployment and release automation

## Project Status

UTM Go is under active development and is maintained by the project owner. The repository is not currently accepting external contributions.
