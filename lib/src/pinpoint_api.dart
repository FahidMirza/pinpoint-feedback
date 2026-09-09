import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_info.dart';
import 'models.dart';
import 'pinpoint_config.dart';

/// Thrown when a submission cannot be delivered. The message is safe to show.
class PinpointException implements Exception {
  PinpointException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to Supabase over plain REST.
///
/// Deliberately does not use `supabase_flutter`: a client app that already
/// depends on it at a different version would otherwise fail to resolve.
class PinpointApi {
  PinpointApi(this.config, {http.Client? client})
      : _http = client ?? http.Client();

  final PinpointConfig config;
  final http.Client _http;

  Map<String, String> get _headers => {
        'apikey': config.supabaseAnonKey,
        'Authorization': 'Bearer ${config.supabaseAnonKey}',
      };

  /// Uploads the screenshot then records the feedback row.
  ///
  /// A failed upload does not abort the submission — the note and markers are
  /// still worth keeping, so the row is written with a null image.
  Future<void> submit({
    String? apiKey,
    required PinpointAppInfo info,
    required String? note,
    required List<PinpointMarker> markers,
    required Uint8List? screenshot,
    String? screenName,
    String? appVersion,
    String? buildNumber,
    String? reporterEmail,
  }) async {
    final hasKey = apiKey != null && apiKey.trim().isNotEmpty;

    if (!hasKey && (info.packageId == null || info.packageId!.isEmpty)) {
      throw PinpointException(
        'Pinpoint could not identify this app. Pass an apiKey on platforms '
        'without a package id, such as web.',
      );
    }

    String? imagePath;

    if (screenshot != null) {
      try {
        // Screenshots are stored under <app_id>/, so the app has to be
        // resolved (and, for a new package, created) before uploading.
        final appId = hasKey
            ? await _resolveByKey(apiKey)
            : await _resolveByPackage(info.packageId!, info.appName);
        imagePath = await _uploadScreenshot(appId: appId, bytes: screenshot);
      } catch (e) {
        debugPrint('[Pinpoint] screenshot upload failed, submitting without it: $e');
      }
    }

    await _rpc('submit_feedback_v2', {
      'p_package_id': info.packageId,
      'p_api_key': hasKey ? apiKey : null,
      'p_app_name': info.appName,
      'p_note': note,
      'p_image_url': imagePath,
      'p_markers': markers.map((m) => m.toJson()).toList(),
      'p_screen_name': screenName,
      'p_app_version': appVersion ?? info.version,
      'p_build_number': buildNumber ?? info.buildNumber,
      'p_device_model': info.deviceModel,
      'p_os_version': info.osVersion,
      'p_reporter_email': reporterEmail,
    });
  }

  Future<String> _resolveByKey(String? apiKey) async {
    final body = await _rpc('pinpoint_resolve_app', {'p_api_key': apiKey});
    return _asId(body, 'Could not resolve app for this API key.');
  }

  Future<String> _resolveByPackage(String packageId, String? appName) async {
    final body = await _rpc('pinpoint_resolve_package', {
      'p_package_id': packageId,
      'p_app_name': appName,
    });
    return _asId(body, 'Could not resolve app for package $packageId.');
  }

  String _asId(String body, String message) {
    final id = jsonDecode(body);
    if (id is! String || id.isEmpty) throw PinpointException(message);
    return id;
  }

  /// Returns the stored object path. The bucket is private, so the dashboard
  /// turns this path into a short-lived signed URL when displaying it.
  Future<String> _uploadScreenshot({
    required String appId,
    required Uint8List bytes,
  }) async {
    final name = '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}.jpg';
    final path = '$appId/$name';
    final uri = Uri.parse('${config.supabaseUrl}/storage/v1/object/${config.bucket}/$path');

    final res = await _http
        .post(uri, headers: {..._headers, 'Content-Type': 'image/jpeg'}, body: bytes)
        .timeout(config.requestTimeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PinpointException('Upload failed (${res.statusCode}): ${res.body}');
    }
    return path;
  }

  Future<String> _rpc(String fn, Map<String, dynamic> params) async {
    final uri = Uri.parse('${config.supabaseUrl}/rest/v1/rpc/$fn');
    late final http.Response res;
    try {
      res = await _http
          .post(uri,
              headers: {..._headers, 'Content-Type': 'application/json'},
              body: jsonEncode(params))
          .timeout(config.requestTimeout);
    } catch (e) {
      throw PinpointException('Network error. Check your connection and try again.');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (res.statusCode == 401 || res.statusCode == 403 || res.body.contains('Invalid api key')) {
        throw PinpointException('This app\'s Pinpoint API key is not valid.');
      }
      throw PinpointException('Could not send feedback (${res.statusCode}).');
    }
    return res.body;
  }

  String _randomSuffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  void dispose() => _http.close();
}
