# AirSense Mobile — Setup & Build Guide

This is the Flutter/Dart source code for the mobile version of AirSense.
It calls the SAME FastAPI backend you already have running in Colab —
nothing on the backend changes.

I could not compile or test this code myself (no Flutter SDK available in
my environment), so treat this as a strong first draft. Follow the steps
below carefully, and if you hit an error, paste it back and I'll fix it —
same as we did with the React app.

## Step 1 — Install Flutter (if you haven't already)

1. Go to https://docs.flutter.dev/get-started/install/windows
2. Download the Flutter SDK, unzip it somewhere like `C:\src\flutter`
3. Add `C:\src\flutter\bin` to your system PATH
4. Open a NEW PowerShell window and run:
   ```
   flutter doctor
   ```
   This checks your setup and tells you what's missing (usually Android
   Studio / Android SDK, if you don't have it — install that too, `flutter
   doctor` will link you to it).

## Step 2 — Create the actual Flutter project structure

I've only given you the `lib/` folder (the actual app code) and
`pubspec.yaml` (dependencies) — Flutter needs a full project scaffold
(android/, ios/ folders etc.) that only its own tool can generate correctly.

1. Copy this whole `airsense_mobile` folder to somewhere like `D:\`
2. Open a terminal INSIDE that folder:
   ```
   cd D:\airsense_mobile
   ```
3. Run:
   ```
   flutter create .
   ```
   This fills in the missing `android/`, `ios/`, and other platform
   folders around your existing `lib/` and `pubspec.yaml` — it will NOT
   overwrite the files I gave you.

## Step 3 — Add Android permissions

Open `ANDROID_PERMISSIONS.md` (included in this folder) and make the two
small edits it describes — this is required for internet access and
location detection to work at all.

## Step 4 — Install dependencies

```
flutter pub get
```

## Step 5 — Update the backend URL if needed

Open `lib/services/api_service.dart` and confirm this line matches your
current ngrok URL:
```dart
const String apiBase = "https://material-rhyme-friend.ngrok-free.dev";
```

## Step 6 — Run it (test on an emulator or your phone first)

Easiest first test — run in Chrome, just to check the logic works:
```
flutter run -d chrome
```

To test as an actual Android app, either:
- Connect your Android phone via USB (enable Developer Mode + USB
  debugging first), or
- Start an Android emulator from Android Studio

Then:
```
flutter run
```

## Step 7 — Build the actual APK

Once it runs correctly:
```
flutter build apk --release
```

The APK will be created at:
```
build\app\outputs\flutter-apk\app-release.apk
```

Copy that file to your phone (or share it) and install it directly —
that's your submittable APK.

## Common errors you might hit (and what they usually mean)

- **"Waiting for another flutter command to release the startup lock"**
  → close all terminals and try again, or restart your machine.
- **A specific package version conflict during `flutter pub get`**
  → paste the exact error, I'll adjust `pubspec.yaml`'s version numbers.
- **Location permission errors on the phone**
  → double check Step 3 was done correctly, and that you granted the
    permission when the phone prompted you.
- **Map tiles not loading**
  → same free OpenStreetMap tile server as the web app; if it fails,
    check your phone/emulator has internet access.
- **API calls failing**
  → confirm your Colab server is still running and the URL in
    `api_service.dart` is current.

## What to do once it's working — Git submission

Per your mentor's instructions, this goes on its own branch, not `main`:

```
git checkout -b mobile-app-m3
git add .
git commit -m "Add Flutter mobile app for M3"
git push origin mobile-app-m3
```

Then submit the branch link, not a main-branch link.
