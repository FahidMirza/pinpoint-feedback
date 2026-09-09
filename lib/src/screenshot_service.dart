import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

/// Captures the wrapped app as a compressed JPEG.
///
/// Works by rendering the [RepaintBoundary] that wraps the host app, so the
/// Pinpoint UI itself (button, markers, sheet) never appears in the capture.
///
/// Known limitation: platform views — Google Maps, WebViews, camera previews,
/// video players — are composited by the OS outside Flutter's layer tree and
/// come out blank. Everything Flutter draws itself captures correctly.
class ScreenshotService {
  const ScreenshotService._();

  static Future<Uint8List?> capture({
    required GlobalKey boundaryKey,
    double pixelRatio = 1.5,
    int quality = 75,
    bool useIsolate = true,
  }) async {
    final object = boundaryKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;

    ui.Image? image;
    try {
      image = await object.toImage(pixelRatio: pixelRatio);
      final width = image.width;
      final height = image.height;

      // rawRgba avoids a PNG encode/decode round trip before re-compressing.
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;

      final request = _EncodeRequest(
        pixels: data.buffer.asUint8List(),
        width: width,
        height: height,
        quality: quality,
      );

      return useIsolate
          ? await compute(_encodeJpeg, request)
          : _encodeJpeg(request);
    } catch (e, s) {
      debugPrint('[Pinpoint] screenshot capture failed: $e\n$s');
      return null;
    } finally {
      image?.dispose();
    }
  }
}

class _EncodeRequest {
  const _EncodeRequest({
    required this.pixels,
    required this.width,
    required this.height,
    required this.quality,
  });

  final Uint8List pixels;
  final int width;
  final int height;
  final int quality;
}

/// Runs off the UI isolate — JPEG encoding a full screen would otherwise jank.
Uint8List _encodeJpeg(_EncodeRequest req) {
  final image = img.Image.fromBytes(
    width: req.width,
    height: req.height,
    bytes: req.pixels.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: req.quality);
}
