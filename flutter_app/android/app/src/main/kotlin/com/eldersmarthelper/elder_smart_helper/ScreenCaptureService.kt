package com.eldersmarthelper.elder_smart_helper

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.view.WindowManager
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class ScreenCaptureService : Service() {

    companion object {
        const val CHANNEL_ID = "screen_capture"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_RESULT_DATA = "result_data"

        var frameCallback: ((ByteArray, Int, Int) -> Unit)? = null
        private val isCapturing = AtomicBoolean(false)

        fun isActive(): Boolean = isCapturing.get()
    }

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var captureThread: Thread? = null
    private var screenWidth = 720
    private var screenHeight = 1280
    private var screenDpi = 320

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getRealMetrics(metrics)
        screenWidth = (metrics.widthPixels * 0.5).toInt()  // 50% 缩放减小传输量
        screenHeight = (metrics.heightPixels * 0.5).toInt()
        screenDpi = (metrics.densityDpi * 0.5).toInt()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
                val resultData = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(EXTRA_RESULT_DATA)
                }
                if (resultData != null) {
                    startForeground(NOTIFICATION_ID, createNotification())
                    startCapture(resultCode, resultData)
                }
            }
            ACTION_STOP -> {
                stopCapture()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun startCapture(resultCode: Int, resultData: Intent) {
        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = projectionManager.getMediaProjection(resultCode, resultData)

        val reader = ImageReader.newInstance(screenWidth, screenHeight, PixelFormat.RGBA_8888, 2)
        imageReader = reader

        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "ScreenCapture",
            screenWidth, screenHeight, screenDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            reader.surface, null, null
        )

        isCapturing.set(true)

        captureThread = Thread {
            while (isCapturing.get()) {
                try {
                    val image = imageReader?.acquireLatestImage()
                    if (image != null) {
                        val planes = image.planes
                        val buffer = planes[0].buffer
                        val pixelStride = planes[0].pixelStride
                        val rowStride = planes[0].rowStride
                        val rowPadding = rowStride - pixelStride * screenWidth
                        val bmp = Bitmap.createBitmap(
                            screenWidth + rowPadding / pixelStride,
                            screenHeight,
                            Bitmap.Config.ARGB_8888
                        )
                        bmp.copyPixelsFromBuffer(buffer)
                        // 裁剪到实际宽度
                        val cropped = Bitmap.createBitmap(bmp, 0, 0, screenWidth, screenHeight)
                        bmp.recycle()
                        image.close()

                        val baos = ByteArrayOutputStream()
                        cropped.compress(Bitmap.CompressFormat.JPEG, 50, baos)
                        cropped.recycle()

                        frameCallback?.invoke(baos.toByteArray(), screenWidth, screenHeight)
                    }
                    Thread.sleep(2000) // 每2秒截一帧
                } catch (e: InterruptedException) {
                    break
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
        captureThread?.start()
    }

    private fun stopCapture() {
        isCapturing.set(false)
        captureThread?.interrupt()
        captureThread = null
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        mediaProjection?.stop()
        mediaProjection = null
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "屏幕录制",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "远程协助屏幕共享"
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun createNotification(): Notification {
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("远程协助")
            .setContentText("正在共享屏幕...")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .build()
    }

    override fun onDestroy() {
        stopCapture()
        super.onDestroy()
    }
}
