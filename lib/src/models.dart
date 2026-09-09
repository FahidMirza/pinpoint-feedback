import 'package:flutter/foundation.dart';

/// A point the reporter tapped to flag a problem.
///
/// Coordinates are stored as fractions of the screen (0.0-1.0) rather than
/// pixels, so the dashboard can overlay them on the screenshot at any size.
@immutable
class PinpointMarker {
  const PinpointMarker({
    required this.x,
    required this.y,
    required this.label,
  });

  /// Horizontal position, 0.0 (left edge) to 1.0 (right edge).
  final double x;

  /// Vertical position, 0.0 (top edge) to 1.0 (bottom edge).
  final double y;

  /// 1-based number shown inside the marker.
  final int label;

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'label': label};
}
