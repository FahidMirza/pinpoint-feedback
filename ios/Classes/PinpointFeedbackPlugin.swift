import Flutter
import UIKit

/// Reports the host app's identity so feedback maps to the right app without
/// anyone pasting an API key.
///
/// Written as our own channel rather than depending on package_info_plus or
/// device_info_plus: those would be version constraints on every client app
/// that embeds this SDK, and a conflict there would break their build.
public class PinpointFeedbackPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "pinpoint_feedback",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(PinpointFeedbackPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "getAppInfo" else {
      result(FlutterMethodNotImplemented)
      return
    }

    let info = Bundle.main.infoDictionary

    result([
      "packageId": Bundle.main.bundleIdentifier as Any,
      "appName": (info?["CFBundleDisplayName"] ?? info?["CFBundleName"]) as Any,
      "version": info?["CFBundleShortVersionString"] as Any,
      "buildNumber": info?["CFBundleVersion"] as Any,
      "deviceModel": PinpointFeedbackPlugin.deviceModel() as Any,
      "osVersion": "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    ])
  }

  /// UIDevice.model only says "iPhone". The machine identifier ("iPhone16,1")
  /// is what actually tells you which device a layout broke on.
  private static func deviceModel() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machine = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(validatingUTF8: $0) }
    }
    return machine ?? UIDevice.current.model
  }
}
