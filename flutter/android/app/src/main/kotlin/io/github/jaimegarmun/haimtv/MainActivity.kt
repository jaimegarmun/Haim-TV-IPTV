package io.github.jaimegarmun.haimtv

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "io.github.jaimegarmun.haimtv/exoplayer",
            ExoPlayerViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (ExoPlayerView.active?.dispatchDpad(event) == true) {
            return true
        }
        return super.dispatchKeyEvent(event)
    }
}
