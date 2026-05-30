# Firebase Local Setup

Real Firebase API keys must not be committed to Git. Keep local config files and runtime keys on your machine only.

## Android

1. Copy `android/app/google-services.json.template` to `android/app/google-services.json`.
2. Replace `REPLACE_WITH_RESTRICTED_ANDROID_FIREBASE_API_KEY` with the restricted Android Firebase API key from Firebase Console.
3. Keep `android/app/google-services.json` ignored by Git.

## Flutter Web

Pass the restricted web Firebase API key at build or run time:

```powershell
flutter run -d chrome --dart-define=UTMGO_FIREBASE_WEB_API_KEY=your_web_key
flutter build web --dart-define=UTMGO_FIREBASE_WEB_API_KEY=your_web_key
```

## Android Flutter Defines

The shared Dart Firebase options also read the Android key from a dart define:

```powershell
flutter run --dart-define=UTMGO_FIREBASE_ANDROID_API_KEY=your_android_key
flutter build apk --dart-define=UTMGO_FIREBASE_ANDROID_API_KEY=your_android_key
```

Use both defines when building a target that needs both Firebase option sets.

## Key Safety

- Rotate or delete any key that was ever pushed to GitHub.
- Restrict Android keys to package `com.example.utmgo` plus the correct SHA certificate fingerprints.
- Restrict web keys to Firebase Hosting domains and approved local development origins.
- If GitHub secret scanning reports a key, remove it from the current tree and from Git history before pushing again.
