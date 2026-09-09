/// Pinpoint — in-app client feedback for Flutter.
///
/// Wrap your app once:
/// ```dart
/// runApp(Pinpoint(child: MyApp()));
/// ```
///
/// The app registers itself by package id on its first submission — there is
/// no key to create or paste.
library pinpoint_feedback;

export 'src/app_info.dart' show PinpointAppInfo;
export 'src/models.dart' show PinpointMarker;
export 'src/pinpoint.dart' show Pinpoint, PinpointRouteObserver;
export 'src/pinpoint_api.dart' show PinpointException;
export 'src/pinpoint_config.dart' show PinpointConfig;
