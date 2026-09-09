# Changelog

## 0.3.0

Breaking: `Pinpoint` now takes a required `clientKey` and no longer accepts
`apiKey`.

- One key per client, not per app. Every app a client builds carries the same
  key, registers itself by package id on first submission, and arrives already
  attached to that client — no app to create and none to assign afterwards.
- An app that already belongs to a client is never reassigned by a submission,
  so a key cannot be used to claim someone else's package id.
- Apps registered before client keys existed are adopted the first time a build
  submits with one.

Upgrading from 0.2.0: replace `apiKey:` with `clientKey:` and use the key from
your client's row rather than a per-app key.

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
