package com.guardian.safety

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * Location via the platform LocationManager (fused provider where available,
 * plus GPS and network).
 *
 * Every LocationManager call runs on a dedicated background thread.  Location
 * binder calls can stall for a long time on some devices; running them on the
 * main thread would freeze the app (and every other platform call, including
 * SMS sending) at the worst possible moment.
 */
class LocationBridge(context: Context) : EventChannel.StreamHandler {

    companion object {
        const val EVENTS = "guardian/location"
    }

    private val app = context.applicationContext
    private val lm = app.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val thread = HandlerThread("guardian-location").apply { start() }
    private val bg = Handler(thread.looper)
    private val main = Handler(Looper.getMainLooper())

    private var sink: EventChannel.EventSink? = null
    private var listener: LocationListener? = null

    // ── EventChannel ───────────────────────────────────────────────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    // ── Queries ────────────────────────────────────────────────────────────

    fun hasPermission(): Boolean =
        app.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            app.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    fun isEnabled(): Boolean = try {
        if (Build.VERSION.SDK_INT >= 28) lm.isLocationEnabled
        else lm.isProviderEnabled(LocationManager.GPS_PROVIDER) || lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    } catch (e: Exception) {
        false
    }

    fun openSettings() {
        app.startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun providers(): List<String> {
        val enabled = try { lm.getProviders(true) } catch (e: Exception) { emptyList<String>() }
        val result = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= 31 && enabled.contains(LocationManager.FUSED_PROVIDER)) {
            result.add(LocationManager.FUSED_PROVIDER)
        }
        if (enabled.contains(LocationManager.GPS_PROVIDER)) result.add(LocationManager.GPS_PROVIDER)
        if (enabled.contains(LocationManager.NETWORK_PROVIDER)) result.add(LocationManager.NETWORK_PROVIDER)
        return result
    }

    private fun bestLastKnown(): Location? {
        if (!hasPermission()) return null
        return providers()
            .mapNotNull { p -> try { lm.getLastKnownLocation(p) } catch (e: SecurityException) { null } }
            .maxByOrNull { it.time }
    }

    private fun Location.toMap(): Map<String, Any> {
        val m = mutableMapOf<String, Any>("lat" to latitude, "lng" to longitude, "time" to time)
        if (hasAccuracy()) m["accuracy"] = accuracy.toDouble()
        if (hasSpeed()) m["speed"] = speed.toDouble()
        if (hasBearing()) m["heading"] = bearing.toDouble()
        return m
    }

    fun lastKnown(result: MethodChannel.Result) {
        bg.post {
            val loc = bestLastKnown()
            main.post { result.success(loc?.toMap()) }
        }
    }

    /** First fresh fix from any provider, or the best last-known one on timeout. */
    fun current(timeoutMs: Long, result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.success(null)
            return
        }
        bg.post {
            val done = AtomicBoolean(false)
            val cleanups = mutableListOf<() -> Unit>()
            fun finish(loc: Location?) {
                if (!done.compareAndSet(false, true)) return
                cleanups.forEach { runCatching { it() } }
                val answer = loc ?: bestLastKnown()
                main.post { result.success(answer?.toMap()) }
            }

            val provs = providers()
            if (provs.isEmpty()) {
                finish(null)
                return@post
            }
            if (Build.VERSION.SDK_INT >= 30) {
                val pending = AtomicInteger(provs.size)
                for (p in provs) {
                    val signal = CancellationSignal()
                    cleanups.add { signal.cancel() }
                    try {
                        lm.getCurrentLocation(p, signal, { r -> bg.post(r) }) { loc ->
                            if (loc != null) finish(loc)
                            else if (pending.decrementAndGet() == 0) finish(null)
                        }
                    } catch (e: Exception) {
                        if (pending.decrementAndGet() == 0) finish(null)
                    }
                }
            } else {
                val one = simpleListener { loc -> finish(loc) }
                cleanups.add { lm.removeUpdates(one) }
                for (p in provs) {
                    try {
                        @Suppress("DEPRECATION")
                        lm.requestLocationUpdates(p, 0L, 0f, one, thread.looper)
                    } catch (e: Exception) { /* provider unavailable */ }
                }
            }
            bg.postDelayed({ finish(null) }, timeoutMs)
        }
    }

    // ── Continuous tracking ────────────────────────────────────────────────

    fun startTracking(background: Boolean, title: String, text: String): Boolean {
        if (!hasPermission()) return false
        if (background) TrackingService.start(app, title, text) else TrackingService.stop(app)
        bg.post {
            removeListener()
            val l = simpleListener { loc ->
                val map = loc.toMap()
                main.post { sink?.success(map) }
            }
            for (p in providers()) {
                try {
                    lm.requestLocationUpdates(p, 5000L, 5f, l, thread.looper)
                } catch (e: Exception) { /* provider unavailable */ }
            }
            listener = l
        }
        return true
    }

    fun stopTracking() {
        TrackingService.stop(app)
        bg.post { removeListener() }
    }

    private fun removeListener() {
        listener?.let { runCatching { lm.removeUpdates(it) } }
        listener = null
    }

    fun dispose() {
        stopTracking()
        bg.post { thread.quitSafely() }
    }

    /** LocationListener with the pre-API-30 abstract methods implemented. */
    private fun simpleListener(onLocation: (Location) -> Unit) = object : LocationListener {
        override fun onLocationChanged(location: Location) = onLocation(location)
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
        @Deprecated("Deprecated in Java")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    }
}
