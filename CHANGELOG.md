# Changelog

## 0.2.0

- Apps identify themselves by package id — no API key to create or paste.
  The integration is now `Pinpoint(child: MyApp())`.
- Added a native channel (Android/iOS) reporting package id, version, build
  number, device model and OS. `appVersion` and `buildNumber` are now optional
  overrides rather than something the host app must supply.
- `apiKey` is optional. Pass one only to pin a build to a specific app, or on
  platforms with no package id (web).

## 0.1.0

- Floating button, tap-to-mark, screenshot capture, note and submit.
- Fixed: the note sheet crashed above `MaterialApp`, which provides the
  `MaterialLocalizations` and `Overlay` that `TextField` requires. Pinpoint now
  supplies both itself.
