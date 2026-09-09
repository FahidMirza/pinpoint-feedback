/// Pinpoint — in-app client feedback for Flutter.
///
/// Wrap your app once:
/// ```dart
/// runApp(Pinpoint(clientKey: 'your-client-key', child: MyApp()));
/// ```
///
/// One key per client covers all of their apps. Each app registers itself by
/// package id the first time feedback is sent.
library pinpoint_feedback;

export 'src/app_info.dart' show PinpointAppInfo;
export 'src/models.dart' show PinpointMarker;
export 'src/pinpoint.dart' show Pinpoint, PinpointRouteObserver;
export 'src/pinpoint_api.dart' show PinpointException;
export 'src/pinpoint_config.dart' show PinpointConfig;
