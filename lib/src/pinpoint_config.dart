/// Backend configuration for the Pinpoint SDK.
///
/// The defaults point at the production Pinpoint project, so an app only ever
/// needs to supply its own `apiKey`. Override [supabaseUrl] / [supabaseAnonKey]
/// to point a build at a staging project.
///
/// The anon key is safe to ship inside an app: it grants no table access on its
/// own. Reads are blocked by row level security, and the only write path is the
/// `submit_feedback` function, which requires a valid per-app `apiKey`.
class PinpointConfig {
  const PinpointConfig({
    this.supabaseUrl = _defaultUrl,
    this.supabaseAnonKey = _defaultAnonKey,
    this.bucket = 'screenshots',
    this.pixelRatio = 1.5,
    this.jpegQuality = 75,
    this.requestTimeout = const Duration(seconds: 30),
    this.useIsolateForEncoding = true,
  });

  static const _defaultUrl = 'https://qvzkiglgnqyeqlpvjntf.supabase.co';
  static const _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2emtpZ2xnbnF5ZXFscHZqbnRmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg4NzY2MTYsImV4cCI6MjEwNDQ1MjYxNn0.giVk4k1COBVRgwQyK659ykLtN_xRNmVixYmrS9MSwh4';

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Storage bucket screenshots are uploaded to.
  final String bucket;

  /// Capture resolution. 1.5 keeps text readable at roughly a quarter the bytes
  /// of a full 3.0 device-pixel capture.
  final double pixelRatio;

  /// JPEG quality, 0-100. 75 is the sweet spot for screenshots.
  final int jpegQuality;

  final Duration requestTimeout;

  /// Encode the JPEG on a background isolate so the UI does not jank.
  ///
  /// Leave this on in real apps. Set false under `flutter_test`, where a
  /// `compute` call never completes and would hang the test.
  final bool useIsolateForEncoding;
}
