import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Identity of the host app, read from the platform.
///
/// The package id is what maps feedback to an app, so a developer adding the
/// SDK does not have to paste a key. Version and device details come along in
/// the same call, which is why the SDK no longer asks for them.
@immutable
class PinpointAppInfo {
  const PinpointAppInfo({
    this.packageId,
    this.appName,
    this.version,
    this.buildNumber,
    this.deviceModel,
    this.osVersion,
  });

  final String? packageId;
  final String? appName;
  final String? version;
  final String? buildNumber;
  final String? deviceModel;
  final String? osVersion;

  static const _channel = MethodChannel('pinpoint_feedback');

  static PinpointAppInfo? _cached;

  /// Reads once and caches — none of this changes while the app is running.
  ///
  /// Returns empty values rather than throwing where there is no native side
  /// (web, desktop): feedback without a package id is still worth sending, and
  /// an explicit apiKey covers those platforms.
  static Future<PinpointAppInfo> load() async {
    if (_cached != null) return _cached!;

    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('getAppInfo');
      _cached = PinpointAppInfo(
        packageId: raw?['packageId'] as String?,
        appName: raw?['appName'] as String?,
        version: raw?['version'] as String?,
        buildNumber: raw?['buildNumber'] as String?,
        deviceModel: raw?['deviceModel'] as String?,
        osVersion: raw?['osVersion'] as String?,
      );
    } on MissingPluginException {
      // Platform without a native implementation.
      _cached = const PinpointAppInfo();
    } catch (e) {
      debugPrint('[Pinpoint] could not read app info: $e');
      _cached = const PinpointAppInfo();
    }

    return _cached!;
  }
}
