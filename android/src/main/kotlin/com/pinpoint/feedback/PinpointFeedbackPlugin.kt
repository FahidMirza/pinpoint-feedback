package com.pinpoint.feedback

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Reports the host app's identity so feedback maps to the right app without
 * anyone pasting an API key.
 *
 * Written as our own channel rather than depending on package_info_plus or
 * device_info_plus: those would be version constraints on every client app that
 * embeds this SDK, and a conflict there would break their build.
 */
class PinpointFeedbackPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "pinpoint_feedback")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method != "getAppInfo") {
      result.notImplemented()
      return
    }

    try {
      val pm = context.packageManager
      val packageName = context.packageName
      val info = pm.getPackageInfo(packageName, 0)

      @Suppress("DEPRECATION")
      val buildNumber =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode.toString()
        else info.versionCode.toString()

      val label = try {
        pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
      } catch (e: PackageManager.NameNotFoundException) {
        null
      }

      result.success(
        mapOf(
          "packageId" to packageName,
          "appName" to label,
          "version" to info.versionName,
          "buildNumber" to buildNumber,
          "deviceModel" to "${Build.MANUFACTURER} ${Build.MODEL}",
          "osVersion" to "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"
        )
      )
    } catch (e: Exception) {
      // Never fail the caller: missing context only means a thinner report.
      result.success(emptyMap<String, String>())
    }
  }
}
