package com.pimenta.ledor

import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val SCREEN_CHANNEL = "ledor/screen"

/// Extending AudioServiceActivity (instead of FlutterActivity) lets the
/// audio_service plugin observe `MEDIA_BUTTON` intents — headphone /
/// bluetooth play-pause buttons reach the Flutter handler this way. It's
/// also what unlocks pre-activity intent handling for the media session.
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // RSVP playback has no touch input, so the idle timeout would turn
        // the screen off mid-sentence. The flag is window-scoped: it stops
        // applying on its own once the activity leaves the foreground.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "keepOn") return@setMethodCallHandler result.notImplemented()
                if (call.arguments == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }
    }

    // audio_service caches the engine past this activity; drop the handler
    // so it doesn't keep a destroyed activity (and its window) alive.
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL)
            .setMethodCallHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
