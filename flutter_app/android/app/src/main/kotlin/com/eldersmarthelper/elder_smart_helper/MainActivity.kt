package com.eldersmarthelper.elder_smart_helper

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {

    private val CAPTURE_CHANNEL = "com.eldersmarthelper/screen_capture"
    private val OVERLAY_CHANNEL = "com.eldersmarthelper/guide_overlay"
    private val FRAME_EVENT_CHANNEL = "com.eldersmarthelper/screen_frames"

    private var frameEventSink: EventChannel.EventSink? = null
    private var pendingMethodResult: MethodChannel.Result? = null

    companion object {
        private const val REQUEST_MEDIA_PROJECTION = 1001
        private const val REQUEST_OVERLAY_PERMISSION = 1002
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 屏幕录制 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAPTURE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startCapture" -> {
                        pendingMethodResult?.success(false)
                        pendingMethodResult = result
                        requestScreenCapture()
                    }
                    "stopCapture" -> {
                        stopScreenCapture()
                        result.success(true)
                    }
                    "isCapturing" -> {
                        result.success(ScreenCaptureService.isActive())
                    }
                    else -> result.notImplemented()
                }
            }

        // 悬浮窗 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasOverlayPermission" -> {
                        result.success(hasOverlayPermission())
                    }
                    "requestOverlayPermission" -> {
                        requestOverlayPermission()
                        result.success(true)
                    }
                    "showGuideOverlay" -> {
                        val marksJson = call.argument<String>("marks") ?: "[]"
                        showGuideOverlay(marksJson)
                        result.success(true)
                    }
                    "hideGuideOverlay" -> {
                        hideGuideOverlay()
                        result.success(true)
                    }
                    "setConfirmCallback" -> {
                        GuideOverlayService.confirmCallback = {
                            runOnUiThread {
                                MethodChannel(
                                    flutterEngine.dartExecutor.binaryMessenger,
                                    OVERLAY_CHANNEL
                                ).invokeMethod("onGuideConfirmed", null)
                            }
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // 屏幕帧 EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FRAME_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    frameEventSink = events
                    ScreenCaptureService.frameCallback = { jpegBytes, width, height ->
                        val base64 = android.util.Base64.encodeToString(
                            jpegBytes, android.util.Base64.NO_WRAP
                        )
                        runOnUiThread {
                            frameEventSink?.success(mapOf(
                                "image" to base64,
                                "width" to width,
                                "height" to height
                            ))
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    frameEventSink = null
                    ScreenCaptureService.frameCallback = null
                }
            })
    }

    private fun requestScreenCapture() {
        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        @Suppress("DEPRECATION")
        startActivityForResult(projectionManager.createScreenCaptureIntent(), REQUEST_MEDIA_PROJECTION)
    }

    private fun stopScreenCapture() {
        val intent = Intent(this, ScreenCaptureService::class.java).apply {
            action = ScreenCaptureService.ACTION_STOP
        }
        startService(intent)
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else true
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            @Suppress("DEPRECATION")
            startActivityForResult(intent, REQUEST_OVERLAY_PERMISSION)
        }
    }

    private fun showGuideOverlay(marksJson: String) {
        val intent = Intent(this, GuideOverlayService::class.java).apply {
            action = GuideOverlayService.ACTION_SHOW
            putExtra(GuideOverlayService.EXTRA_MARKS, marksJson)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun hideGuideOverlay() {
        val intent = Intent(this, GuideOverlayService::class.java).apply {
            action = GuideOverlayService.ACTION_HIDE
        }
        startService(intent)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_MEDIA_PROJECTION) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                // 启动前台录屏服务
                val serviceIntent = Intent(this, ScreenCaptureService::class.java).apply {
                    action = ScreenCaptureService.ACTION_START
                    putExtra(ScreenCaptureService.EXTRA_RESULT_CODE, resultCode)
                    putExtra(ScreenCaptureService.EXTRA_RESULT_DATA, data)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
                pendingMethodResult?.success(true)
            } else {
                pendingMethodResult?.success(false)
            }
            pendingMethodResult = null
        }
    }
}
