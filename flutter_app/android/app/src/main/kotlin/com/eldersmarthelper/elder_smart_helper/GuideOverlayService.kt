package com.eldersmarthelper.elder_smart_helper

import android.annotation.SuppressLint
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView

class GuideOverlayService : Service() {

    companion object {
        const val ACTION_SHOW = "ACTION_SHOW"
        const val ACTION_HIDE = "ACTION_HIDE"
        const val EXTRA_MARKS = "marks_json"

        var overlayVisible = false
        var confirmCallback: (() -> Unit)? = null
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> {
                val marksJson = intent.getStringExtra(EXTRA_MARKS) ?: "[]"
                showOverlay(marksJson)
            }
            ACTION_HIDE -> {
                hideOverlay()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun showOverlay(marksJson: String) {
        if (overlayVisible) return

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val container = FrameLayout(this)

        // 解析标记数据并添加视图
        val marks = parseMarks(marksJson)
        val dm = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager?.defaultDisplay?.getRealMetrics(dm)

        for (mark in marks) {
            val x = (mark.xRatio * dm.widthPixels).toInt()
            val y = (mark.yRatio * dm.heightPixels).toInt()

            // 脉冲圆圈视图
            val markView = object : View(this) {
                private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                }
                private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 3f
                    color = Color.WHITE
                }
                private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.WHITE
                    textSize = 36f
                    textAlign = Paint.Align.CENTER
                    isFakeBoldText = true
                }

                override fun onDraw(canvas: Canvas) {
                    val cx = width / 2f
                    val cy = height / 2f
                    val outerRadius = width / 2f
                    val innerRadius = outerRadius * 0.6f

                    // 半透明外圈
                    paint.color = Color.argb(60, 255, 0, 0)
                    canvas.drawCircle(cx, cy, outerRadius, paint)

                    // 实心内圈
                    paint.color = Color.RED
                    canvas.drawCircle(cx, cy, innerRadius, paint)

                    // 白色边框
                    canvas.drawCircle(cx, cy, innerRadius, borderPaint)

                    // 序号文字
                    val textY = cy - (textPaint.descent() + textPaint.ascent()) / 2
                    canvas.drawText(mark.order.toString(), cx, textY, textPaint)
                }
            }

            val markSize = (48 * dm.density).toInt()
            val params = FrameLayout.LayoutParams(markSize, markSize).apply {
                gravity = Gravity.TOP or Gravity.START
                leftMargin = x - markSize / 2
                topMargin = y - markSize / 2
            }
            container.addView(markView, params)
        }

        // 底部确认按钮
        val buttonTextView = TextView(this).apply {
            text = "✓ 我已完成"
            setTextColor(Color.WHITE)
            textSize = 18f
            setPadding(40, 20, 40, 20)
            setBackgroundColor(Color.argb(200, 76, 175, 80))
            setOnClickListener {
                confirmCallback?.invoke()
                hideOverlay()
                stopSelf()
            }
        }
        val buttonParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            bottomMargin = (100 * dm.density).toInt()
        }
        container.addView(buttonTextView, buttonParams)

        // 半透明全屏背景，点击关闭
        container.setOnClickListener {
            // 点击背景不做操作，只通过按钮关闭
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
            PixelFormat.TRANSLUCENT
        )

        windowManager?.addView(container, params)
        overlayView = container
        overlayVisible = true
    }

    private fun hideOverlay() {
        if (overlayView != null) {
            windowManager?.removeView(overlayView)
            overlayView = null
            overlayVisible = false
        }
    }

    private fun parseMarks(json: String): List<GuideMark> {
        val marks = mutableListOf<GuideMark>()
        try {
            val cleanJson = json.trim()
            if (cleanJson.startsWith("[")) {
                val items = cleanJson.removeSurrounding("[", "]").split("},{")
                for (item in items) {
                    val xMatch = Regex("\"x\"\\s*:\\s*([\\d.]+)").find(item)
                    val yMatch = Regex("\"y\"\\s*:\\s*([\\d.]+)").find(item)
                    val orderMatch = Regex("\"order\"\\s*:\\s*(\\d+)").find(item)
                    if (xMatch != null && yMatch != null) {
                        marks.add(GuideMark(
                            xRatio = xMatch.groupValues[1].toDouble(),
                            yRatio = yMatch.groupValues[1].toDouble(),
                            order = orderMatch?.groupValues?.get(1)?.toIntOrNull() ?: 1
                        ))
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return marks
    }

    override fun onDestroy() {
        hideOverlay()
        super.onDestroy()
    }

    data class GuideMark(val xRatio: Double, val yRatio: Double, val order: Int)
}
