# Adding Pinpoint to your Flutter app

Pinpoint puts a small feedback button in the app. Testers tap it, mark the spots
that look wrong, write a note, and it sends that along with a screenshot.

Setup is two lines. Nothing to sign up for and no key to configure.

---

## Step 1 — Add the dependency

In your app's `pubspec.yaml`:

```yaml
dependencies:
  pinpoint_feedback:
    git:
      url: https://github.com/FahidMirza/pinpoint-feedback.git
      ref: v0.2.0
```

Then:

```bash
flutter pub get
```

## Step 2 — Wrap your app

In `lib/main.dart`, wrap whatever you pass to `runApp`:

```dart
import 'package:flutter/material.dart';
import 'package:pinpoint_feedback/pinpoint_feedback.dart';

void main() {
  runApp(
    Pinpoint(child: MyApp()),   // <- your existing app, unchanged
  );
}
```

That is the whole integration. There is no key or ID to configure — the app
identifies itself by its package id.

## Step 3 — Run it

```bash
flutter run
```

A blue circle appears in the bottom-right. Tap it, tap a couple of spots on the
screen, write anything, and submit. It should say "Feedback sent."

---

## Optional

**Record which screen feedback came from.** Add the observer to your app:

```dart
MaterialApp(
  navigatorObservers: [PinpointRouteObserver()],
  ...
)
```

**Hide the button in production builds:**

```dart
Pinpoint(
  enabled: !kReleaseMode,
  child: MyApp(),
)
```

**Tag who reported it**, if users are signed in:

```dart
Pinpoint(
  userEmail: currentUser.email,
  child: MyApp(),
)
```

---

## What it sends

The note, the points that were tapped, a screenshot of that screen, and the app
version, build number, device model and OS. Nothing else — it cannot read
anything from your app or from the feedback system.

## Known limitations

- Google Maps, WebViews, camera previews and video players appear blank in
  screenshots. They are drawn by the operating system, outside the part Flutter
  can capture. Everything Flutter draws captures correctly.
- Sending needs a network connection. There is no offline queue yet, so a
  failed send asks the tester to retry.

## Troubleshooting

**`flutter pub get` succeeds but the button does not appear**
Check `enabled` is not false, and that `Pinpoint` wraps the widget passed to
`runApp` — not a widget inside `MaterialApp`.

**Build fails on iOS after adding the dependency**
The SDK includes native code, so CocoaPods needs to install it:

```bash
cd ios && pod install && cd ..
flutter clean && flutter run
```

**Nothing arrives in the dashboard**
Send us the package id — `applicationId` in `android/app/build.gradle`, or the
bundle identifier in Xcode. Feedback is routed by that, and the app registers
itself on the first send.
