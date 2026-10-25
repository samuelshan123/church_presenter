package com.example.church_presenter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var externalDisplay: ExternalDisplayController? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        externalDisplay = ExternalDisplayController(
            this,
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "church_presenter/external_display",
            ),
        ).also { it.start() }
    }

    override fun onDestroy() {
        externalDisplay?.stop()
        externalDisplay = null
        super.onDestroy()
    }
}
