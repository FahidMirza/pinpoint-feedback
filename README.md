# Pinpoint

In-app client feedback for Flutter. A floating button lets clients mark problem
spots on any screen, write a note, and send it with a screenshot and device
context — straight to your dashboard.

## Install

```yaml
dependencies:
  pinpoint_feedback:
    git:
      url: https://github.com/FahidMirza/pinpoint-feedback.git
      ref: v0.2.0
```

Pin a tag, not `main` — otherwise a client app silently picks up whatever was
pushed last.

## Use

```dart
import 'package:pinpoint_feedback/pinpoint_feedback.dart';

void main() {
  runApp(
    Pinpoint(child: MyApp()),
  );
}
```

That is the whole integration. There is no key to create or paste: the app
identifies itself by package id, and registers itself on its first submission.

## Options

```dart
Pinpoint(
  enabled: !kReleaseMode,         // hide the button in production builds
  userEmail: currentUser.email,    // tag who reported it
  alignment: Alignment.bottomLeft, // default: bottomRight
  apiKey: 'optional-key',          // pin this build to a specific app
  child: MyApp(),
)
```

### Screen names

Add the observer to record which screen feedback came from:

```dart
MaterialApp(
  navigatorObservers: [PinpointRouteObserver()],
  ...
)
```

Without it `screen_name` is null and everything else still works.

## What gets sent

| Field | Source |
|---|---|
| Note | Typed by the reporter |
| Markers | Tapped points, as fractions of screen size |
| Screenshot | JPEG q75 at 1.5× — typically 100–300 KB |
| Package id | Platform |
| Version, build | Platform |
| Device, OS | Platform |
| Screen name | `PinpointRouteObserver` |
| Reporter email | Passed in by you |

## How it works

`Pinpoint` wraps your app in a `RepaintBoundary` and stacks its own UI above it,
so the button, markers and note sheet never appear in the screenshot. The image
goes to a private bucket; the row goes to Postgres through a function that
resolves the package id to an app, creating it if it is new. The SDK can write
but never read.

## Dependencies

Only `http` and `image`, both pure Dart, plus a small Kotlin/Swift channel that
is part of this package. Nothing third-party and native, so this SDK cannot
create version conflicts in a client's app — which is why device details come
from our own channel rather than `device_info_plus`.

## Known limitations

- **Platform views capture blank.** Google Maps, WebViews, camera previews and
  video players are composited outside Flutter's layer tree. Everything Flutter
  draws itself captures correctly.
- **Flutter Web needs CanvasKit**, and has no package id — pass an `apiKey`
  there.
- **No offline queue.** A submission with no connection fails and asks the
  reporter to retry.
- **If the upload fails the note still sends**, without the image. A partial
  report beats a lost one.

## Releasing a version

```bash
# bump `version:` in pubspec.yaml and add a CHANGELOG entry first
git commit -am "Release 0.3.0"
git tag v0.3.0
git push && git push --tags
```

Consumers move when they change their `ref:` — never automatically.

## Try it

```bash
cd example
flutter run
```

Mark a few spots, submit, then look in the dashboard.
