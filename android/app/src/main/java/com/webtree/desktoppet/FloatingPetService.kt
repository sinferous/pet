package com.webtree.desktoppet

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.util.Log
import android.webkit.ConsoleMessage
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.app.NotificationCompat
import kotlin.math.hypot

class FloatingPetService : Service() {

    companion object {
        private const val CHANNEL_ID = "LunaCompanionChannel"
        private const val NOTIFICATION_ID = 1001
        private const val UPDATE_INTERVAL_MS = 2000L // 2 seconds app check

        @Volatile
        var instance: FloatingPetService? = null
    }

    private lateinit var windowManager: WindowManager
    private lateinit var params: WindowManager.LayoutParams
    private lateinit var webView: CustomWebView
    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastAppPackage: String? = null
    private var currentScrollingApp: String? = null
    private var continuousScrollTimeMs = 0L
    private val scrollingApps = setOf("Instagram", "YouTube", "Facebook", "Twitter/X", "TikTok", "Reddit", "Browser")

    private val appCheckRunnable = object : Runnable {
        override fun run() {
            checkActiveApp()
            mainHandler.postDelayed(this, UPDATE_INTERVAL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.service_notification_title))
            .setContentText(getString(R.string.service_notification_desc))
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        startForeground(NOTIFICATION_ID, notification)

        setupFloatingWebView()
        mainHandler.post(appCheckRunnable)
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun setupFloatingWebView() {
        val density = resources.displayMetrics.density
        val petWidth = (200 * density).toInt()
        val petHeight = (220 * density).toInt()

        params = WindowManager.LayoutParams(
            petWidth,
            petHeight,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (-36 * density).toInt()
            y = (60 * density).toInt()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(true)
        }

        webView = CustomWebView(this).apply {
            setBackgroundColor(Color.TRANSPARENT)
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = true
            settings.allowContentAccess = true
            @Suppress("DEPRECATION")
            settings.allowFileAccessFromFileURLs = true
            @Suppress("DEPRECATION")
            settings.allowUniversalAccessFromFileURLs = true
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            
            webChromeClient = object : WebChromeClient() {
                override fun onConsoleMessage(consoleMessage: ConsoleMessage?): Boolean {
                    consoleMessage?.let {
                        Log.d("LunaWebViewConsole", "${it.message()} -- From line ${it.lineNumber()} of ${it.sourceId()}")
                    }
                    return true
                }
            }

            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    // Set default screen dimensions in JS once page is loaded
                    val width = (resources.displayMetrics.widthPixels / density).toInt()
                    val height = (resources.displayMetrics.heightPixels / density).toInt()
                    webView.evaluateJavascript(
                        "if (window.onInitScreen) window.onInitScreen($width, $height, $x, $y)",
                        null
                    )
                }
            }
            
            addJavascriptInterface(AndroidInterface(), "Android")
            loadUrl("file:///android_asset/index.html")
        }

        webView.setParamsAndWindowManager(params, windowManager)
        windowManager.addView(webView, params)
    }

    private fun checkActiveApp() {
        val foregroundPackage = UsageTracker.getForegroundApp(applicationContext) ?: return
        val appFriendlyName = UsageTracker.getAppName(foregroundPackage)

        if (foregroundPackage != lastAppPackage) {
            lastAppPackage = foregroundPackage
            webView.post {
                webView.evaluateJavascript("if (window.onAppChanged) window.onAppChanged('$appFriendlyName')", null)
            }
        }

        if (scrollingApps.contains(appFriendlyName)) {
            if (currentScrollingApp == appFriendlyName) {
                continuousScrollTimeMs += UPDATE_INTERVAL_MS
            } else {
                currentScrollingApp = appFriendlyName
                continuousScrollTimeMs = 0L
            }
            webView.post {
                webView.evaluateJavascript(
                    "if (window.onScrollDurationUpdate) window.onScrollDurationUpdate('$currentScrollingApp', ${continuousScrollTimeMs / 1000})",
                    null
                )
            }
        } else {
            if (currentScrollingApp != null) {
                currentScrollingApp = null
                continuousScrollTimeMs = 0L
                webView.post {
                    webView.evaluateJavascript(
                        "if (window.onScrollDurationUpdate) window.onScrollDurationUpdate('', 0)",
                        null
                    )
                }
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Luna Mobile Companion Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }

    fun triggerState(stateName: String) {
        if (::webView.isInitialized) {
            webView.post {
                webView.evaluateJavascript("if (window.triggerState) window.triggerState('$stateName')", null)
            }
        }
    }

    fun simulateScroll(seconds: Int) {
        if (::webView.isInitialized) {
            webView.post {
                // First, send a reset to clear previous alert flags
                webView.evaluateJavascript("if (window.onScrollDurationUpdate) window.onScrollDurationUpdate('', 0)", null)
                // Wait 50ms, then trigger the new simulation duration
                webView.postDelayed({
                    webView.evaluateJavascript("if (window.onScrollDurationUpdate) window.onScrollDurationUpdate('Instagram', $seconds)", null)
                }, 50)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        mainHandler.removeCallbacks(appCheckRunnable)
        if (::webView.isInitialized) {
            windowManager.removeView(webView)
        }
    }

    // Inner class defining JS-to-Android interfaces
    inner class AndroidInterface {
        @JavascriptInterface
        fun getScreenWidth(): Int {
            val density = resources.displayMetrics.density
            return (resources.displayMetrics.widthPixels / density).toInt()
        }

        @JavascriptInterface
        fun getScreenHeight(): Int {
            val density = resources.displayMetrics.density
            return (resources.displayMetrics.heightPixels / density).toInt()
        }

        @JavascriptInterface
        fun setWindowBounds(x: Int, y: Int) {
            val density = resources.displayMetrics.density
            val safeY = if (y < 160) 160 else y
            mainHandler.post {
                params.x = ((x - 36) * density).toInt()
                params.y = ((safeY - 100) * density).toInt()
                if (webView.parent != null) {
                    windowManager.updateViewLayout(webView, params)
                }
            }
        }

        @JavascriptInterface
        fun triggerHapticFeedback() {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
            
            vibrator?.let {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    it.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    it.vibrate(50)
                }
            }
        }
    }

    // Custom WebView subclass to handle transparency passthrough and dragging in Kotlin
    class CustomWebView(context: Context) : WebView(context) {
        private var layoutParams: WindowManager.LayoutParams? = null
        private var windowManager: WindowManager? = null

        private var initialX = 0
        private var initialY = 0
        private var initialTouchX = 0f
        private var initialTouchY = 0f
        private var isDragging = false

        fun setParamsAndWindowManager(lp: WindowManager.LayoutParams, wm: WindowManager) {
            this.layoutParams = lp
            this.windowManager = wm
        }

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(event: MotionEvent): Boolean {
            val lp = layoutParams ?: return super.onTouchEvent(event)
            val wm = windowManager ?: return super.onTouchEvent(event)

            val x = event.x.toInt()
            val y = event.y.toInt()

            if (event.action == MotionEvent.ACTION_DOWN) {
                // Bounds safety check
                if (x < 0 || y < 0 || x >= width || y >= height) return false

                // Capture 1x1 pixel under touch and sample alpha to see if we hit the cat or transparent zone
                val bmp = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                canvas.translate(-x.toFloat(), -y.toFloat())
                draw(canvas)
                val pixel = bmp.getPixel(0, 0)
                val alpha = Color.alpha(pixel)
                bmp.recycle()

                // If transparent, let the touch pass through to background apps
                if (alpha < 10) return false

                // Record start coords for drag
                initialX = lp.x
                initialY = lp.y
                initialTouchX = event.rawX
                initialTouchY = event.rawY
                isDragging = false
                
                // Let the WebView process standard mouseDown internally
                super.onTouchEvent(event)
                return true
            }

            if (event.action == MotionEvent.ACTION_MOVE) {
                val dx = event.rawX - initialTouchX
                val dy = event.rawY - initialTouchY

                if (isDragging || hypot(dx, dy) > 10) {
                    isDragging = true
                    lp.x = initialX + dx.toInt()
                    lp.y = initialY + dy.toInt()
                    
                    // Clamp inside display boundaries
                    val metrics = resources.displayMetrics
                    val density = metrics.density
                    lp.x = lp.x.coerceIn(0, metrics.widthPixels - width)
                    val minYBoundary = (60 * density).toInt()
                    lp.y = lp.y.coerceIn(minYBoundary, metrics.heightPixels - height)
                    
                    wm.updateViewLayout(this, lp)
                }
                return true
            }

            if (event.action == MotionEvent.ACTION_UP) {
                super.onTouchEvent(event)
                if (isDragging) {
                    isDragging = false
                    val density = resources.displayMetrics.density
                    val logicalX = ((lp.x / density) + 36).toInt()
                    val logicalY = ((lp.y / density) + 100).toInt()
                    // Tell JS where the cat ended up
                    evaluateJavascript("if (window.onDragEnd) window.onDragEnd($logicalX, $logicalY)", null)
                }
                return true
            }

            return super.onTouchEvent(event)
        }
    }
}
