# Firebase Local Setup

Real Firebase API keys must not be committed to Git. Keep local config files and runtime keys on your machine only.

## Android

1. Copy `android/app/google-services.json.template` to `android/app/google-services.json`.
2. Replace `REPLACE_WITH_RESTRICTED_ANDROID_FIREBASE_API_KEY` with the restricted Android Firebase API key from Firebase Console.
3. Keep `android/app/google-services.json` ignored by Git.
4. Build Android normally. Android Firebase initialization reads the ignored local `google-services.json` through the Google Services Gradle plugin:

```powershell
flutter run
flutter build apk
```

## Flutter Web

Pass the restricted web Firebase API key at build or run time:

```powershell
flutter run -d chrome --dart-define=UTMGO_FIREBASE_WEB_API_KEY=your_web_key
flutter build web --dart-define=UTMGO_FIREBASE_WEB_API_KEY=your_web_key
```

## Key Safety

- Rotate or delete any key that was ever pushed to GitHub.
- Restrict Android keys to package `com.example.utmgo` plus the correct SHA certificate fingerprints.
- Restrict web keys to Firebase Hosting domains and approved local development origins.
- If GitHub secret scanning reports a key, remove it from the current tree and from Git history before pushing again.
