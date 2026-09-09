import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app_info.dart';
import 'feedback_sheet.dart';
import 'models.dart';
import 'pinpoint_api.dart';
import 'pinpoint_config.dart';
import 'screenshot_service.dart';

/// Tracks the current route name so feedback records which screen it came from.
///
/// Optional. Add to your app to get screen names in the dashboard:
/// ```dart
/// MaterialApp(navigatorObservers: [PinpointRouteObserver()], ...)
/// ```
class PinpointRouteObserver extends NavigatorObserver {
  static String? currentRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRoute = route.settings.name ?? currentRoute;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRoute = previousRoute?.settings.name ?? currentRoute;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    currentRoute = newRoute?.settings.name ?? currentRoute;
  }
}

enum _Phase { idle, marking, composing }

/// Wrap your app to add in-app feedback.
///
/// ```dart
/// runApp(Pinpoint(apiKey: 'your-app-key', child: MyApp()));
/// ```
///
/// Adds a floating button over the whole app. Tapping it lets the reporter mark
/// problem spots, write a note, and send both along with a screenshot and
/// device context.
class Pinpoint extends StatefulWidget {
  const Pinpoint({
    super.key,
    this.apiKey,
    required this.child,
    this.enabled = true,
    this.userEmail,
    this.appVersion,
    this.buildNumber,
    this.alignment = Alignment.bottomRight,
    this.config = const PinpointConfig(),
  });

  /// Optional. Feedback is normally routed by the app's package id, which the
  /// SDK reads for itself — so nothing needs configuring. Set a key only to
  /// pin this build to a specific app (separate staging and production, say),
  /// or on web, where there is no package id.
  final String? apiKey;

  /// Your app.
  final Widget child;

  /// Set false to compile the button out — e.g. `enabled: !kReleaseMode`.
  final bool enabled;

  /// Tags feedback with who reported it.
  final String? userEmail;

  /// Read from the platform automatically. Set these only to override.
  final String? appVersion;
  final String? buildNumber;

  /// Where the floating button sits.
  final Alignment alignment;

  final PinpointConfig config;

  @override
  State<Pinpoint> createState() => _PinpointState();
}

class _PinpointState extends State<Pinpoint> {
  final GlobalKey _boundaryKey = GlobalKey();
  late final PinpointApi _api = PinpointApi(widget.config);

  PinpointAppInfo _info = const PinpointAppInfo();
  _Phase _phase = _Phase.idle;
  final List<PinpointMarker> _markers = [];
  Uint8List? _screenshot;
  bool _capturing = false;
  String? _toast;

  @override
  void initState() {
    super.initState();
    // Package id, version and device details in one native call, read once.
    PinpointAppInfo.load().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  void _startMarking() {
    setState(() {
      _phase = _Phase.marking;
      _markers.clear();
      _screenshot = null;
    });
  }

  void _cancel() {
    setState(() {
      _phase = _Phase.idle;
      _markers.clear();
      _screenshot = null;
    });
  }

  void _addMarker(Offset position, Size size) {
    if (size.width == 0 || size.height == 0) return;
    setState(() {
      _markers.add(PinpointMarker(
        x: (position.dx / size.width).clamp(0.0, 1.0),
        y: (position.dy / size.height).clamp(0.0, 1.0),
        label: _markers.length + 1,
      ));
    });
  }

  void _removeMarker(int index) {
    setState(() {
      _markers.removeAt(index);
      // Renumber so labels stay 1..n and match the dashboard.
      for (var i = 0; i < _markers.length; i++) {
        _markers[i] = PinpointMarker(x: _markers[i].x, y: _markers[i].y, label: i + 1);
      }
    });
  }

  /// Captures before the sheet appears, so the note UI is never in the image.
  Future<void> _toCompose() async {
    setState(() => _capturing = true);
    final shot = await ScreenshotService.capture(
      boundaryKey: _boundaryKey,
      pixelRatio: widget.config.pixelRatio,
      quality: widget.config.jpegQuality,
      useIsolate: widget.config.useIsolateForEncoding,
    );
    if (!mounted) return;
    setState(() {
      _screenshot = shot;
      _capturing = false;
      _phase = _Phase.composing;
    });
  }

  Future<String?> _submit(String note) async {
    try {
      await _api.submit(
        apiKey: widget.apiKey,
        info: _info,
        note: note,
        markers: List.of(_markers),
        screenshot: _screenshot,
        screenName: PinpointRouteObserver.currentRoute,
        appVersion: widget.appVersion,
        buildNumber: widget.buildNumber,
        reporterEmail: widget.userEmail,
      );
    } on PinpointException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }

    if (!mounted) return null;
    _cancel();
    _showToast('Feedback sent. Thank you!');
    return null;
  }

  void _showToast(String message) {
    setState(() => _toast = message);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _toast == message) setState(() => _toast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // Only this subtree is captured — Pinpoint's own UI stays out of it.
          RepaintBoundary(key: _boundaryKey, child: widget.child),

          // Pinpoint sits above the host's MaterialApp, so nothing below
          // provides Material, Directionality or Localizations. TextField hard
          // requires MaterialLocalizations, so supply them here rather than
          // assuming the app has an ancestor that does.
          Localizations(
            locale: const Locale('en', 'US'),
            delegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                children: [
                  if (_phase == _Phase.marking) ..._buildMarkingLayer(),
                  if (_phase == _Phase.idle) _buildButton(),
                  // The sheet's TextField needs an Overlay ancestor for its
                  // selection handles, which MaterialApp would normally supply.
                  // The sheet lives inside the entry so its own setState still
                  // drives rebuilds normally.
                  if (_phase == _Phase.composing)
                    Positioned.fill(
                      child: Overlay(
                        initialEntries: [
                          OverlayEntry(
                            builder: (_) => FeedbackSheet(
                              markerCount: _markers.length,
                              hasScreenshot: _screenshot != null,
                              onSubmit: _submit,
                              onCancel: _cancel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_capturing)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black26,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  if (_toast != null) _buildToast(_toast!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMarkingLayer() {
    return [
      Positioned.fill(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _addMarker(d.localPosition, size),
              child: Stack(
                children: [
                  // Faint wash so it is obvious the app is in feedback mode.
                  const Positioned.fill(child: ColoredBox(color: Color(0x14000000))),
                  for (var i = 0; i < _markers.length; i++)
                    Positioned(
                      left: _markers[i].x * size.width - 14,
                      top: _markers[i].y * size.height - 14,
                      child: GestureDetector(
                        onTap: () => _removeMarker(i),
                        child: _MarkerDot(label: _markers[i].label),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      _buildHintBar(),
    ];
  }

  Widget _buildHintBar() {
    return Positioned(
      left: 12,
      right: 12,
      top: MediaQuery.of(context).padding.top + 12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _markers.isEmpty
                    ? 'Tap the problem areas'
                    : '${_markers.length} marked · tap a dot to remove',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _cancel,
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            FilledButton(
              onPressed: _toCompose,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0A84FF),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton() {
    final padding = MediaQuery.of(context).padding;
    return Positioned(
      right: widget.alignment.x > 0 ? 16 : null,
      left: widget.alignment.x < 0 ? 16 : null,
      bottom: widget.alignment.y > 0 ? padding.bottom + 24 : null,
      top: widget.alignment.y < 0 ? padding.top + 24 : null,
      child: GestureDetector(
        onTap: _startMarking,
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFF0A84FF),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildToast(String message) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.of(context).padding.bottom + 40,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _MarkerDot extends StatelessWidget {
  const _MarkerDot({required this.label});
  final int label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
      ),
      child: Text(
        '$label',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
