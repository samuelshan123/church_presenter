package com.example.church_presenter

import android.annotation.SuppressLint
import android.app.Presentation
import android.content.Context
import android.graphics.Color
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.WindowManager
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.MethodChannel

/**
 * Second-screen output for HDMI / USB-C / wireless displays.
 *
 * When Android reports a presentation display, a [LivePresentation] shows the
 * built-in display page (`assets/presenter/web/index.html`) full-screen on it,
 * instead of mirroring the controller UI. Connect/disconnect events go to Dart
 * (`ExternalDisplayService`) over [channel].
 */
class ExternalDisplayController(
    private val context: Context,
    private val channel: MethodChannel,
) : DisplayManager.DisplayListener {

    private val displayManager =
        context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private var presentation: LivePresentation? = null

    fun start() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isConnected" -> result.success(presentation != null)
                else -> result.notImplemented()
            }
        }
        displayManager.registerDisplayListener(this, Handler(Looper.getMainLooper()))
        updatePresentation()
    }

    fun stop() {
        displayManager.unregisterDisplayListener(this)
        dismissPresentation()
        channel.setMethodCallHandler(null)
    }

    override fun onDisplayAdded(displayId: Int) = updatePresentation()

    override fun onDisplayRemoved(displayId: Int) = updatePresentation()

    override fun onDisplayChanged(displayId: Int) = updatePresentation()

    private fun updatePresentation() {
        val display = displayManager
            .getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
            .firstOrNull()

        if (presentation?.display?.displayId == display?.displayId) return

        dismissPresentation()
        if (display != null) {
            presentation = LivePresentation(context, display).also {
                try {
                    it.show()
                } catch (e: WindowManager.InvalidDisplayException) {
                    // The display disappeared while we were attaching to it.
                    presentation = null
                }
            }
        }
        channel.invokeMethod(if (presentation != null) "connected" else "disconnected", null)
    }

    private fun dismissPresentation() {
        presentation?.dismiss()
        presentation = null
    }
}

/**
 * Full-screen web view of the local display page. While the presenter server
 * isn't running it shows a waiting screen and retries, so plugging the TV in
 * before tapping "Start Presenter" just works.
 */
private class LivePresentation(context: Context, display: Display) :
    Presentation(context, display) {

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var webView: WebView
    private var showingWaitingScreen = false
    private val retry = Runnable { loadDisplayPage() }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        webView = WebView(context).apply {
            setBackgroundColor(Color.BLACK)
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.mediaPlaybackRequiresUserGesture = false
            isVerticalScrollBarEnabled = false
            isHorizontalScrollBarEnabled = false
            webViewClient = object : WebViewClient() {
                override fun onReceivedError(
                    view: WebView,
                    request: WebResourceRequest,
                    error: WebResourceError,
                ) {
                    if (request.isForMainFrame) handleLoadFailure()
                }

                override fun onPageFinished(view: WebView, url: String?) {
                    if (url?.startsWith(DISPLAY_URL) == true) showingWaitingScreen = false
                }
            }
        }
        setContentView(webView)
        loadDisplayPage()
    }

    override fun onStop() {
        handler.removeCallbacks(retry)
        webView.destroy()
        super.onStop()
    }

    private fun loadDisplayPage() {
        webView.loadUrl(DISPLAY_URL)
    }

    private fun handleLoadFailure() {
        if (!showingWaitingScreen) {
            showingWaitingScreen = true
            webView.loadDataWithBaseURL(null, WAITING_PAGE_HTML, "text/html", "utf-8", null)
        }
        handler.removeCallbacks(retry)
        handler.postDelayed(retry, RETRY_INTERVAL_MS)
    }

    private companion object {
        const val DISPLAY_URL = "http://127.0.0.1:8901/"
        const val RETRY_INTERVAL_MS = 2000L
        const val WAITING_PAGE_HTML = """<!DOCTYPE html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  html,body{margin:0;height:100%;background:#000;color:#fff;font-family:sans-serif;
    display:flex;align-items:center;justify-content:center;text-align:center}
  h1{font-size:5vw;font-weight:600;margin:0 0 1.5vw}
  p{font-size:2.4vw;color:#9a9a9a;margin:0}
</style></head>
<body><div><h1>Church Presenter</h1>
<p>Tap “Start Presenter” on your device to show slides here.</p></div></body></html>"""
    }
}
