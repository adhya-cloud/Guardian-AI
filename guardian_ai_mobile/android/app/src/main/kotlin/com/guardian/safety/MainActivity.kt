package com.guardian.safety

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var bridge: NativeBridge? = null
    private var location: LocationBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val locationBridge = LocationBridge(this)
        val nativeBridge = NativeBridge(this, locationBridge)
        location = locationBridge
        bridge = nativeBridge
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, NativeBridge.CHANNEL).setMethodCallHandler(nativeBridge)
        EventChannel(messenger, LocationBridge.EVENTS).setStreamHandler(locationBridge)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (bridge?.onActivityResult(requestCode, resultCode, data) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        bridge?.dispose()
        bridge = null
        location?.dispose()
        location = null
        super.onDestroy()
    }
}
