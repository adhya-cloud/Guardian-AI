package com.guardian.safety

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.ContactsContract
import android.telephony.SmsManager
import android.view.WindowManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * Platform features used by the Guardian app that have no reliable Flutter
 * plugin: direct SMS with sent-confirmation, the system contact picker,
 * direct calls, torch, a synthesized siren and the fake-call ringtone.
 */
class NativeBridge(
    private val activity: Activity,
    private val location: LocationBridge,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "guardian/native"
        const val REQUEST_PICK_CONTACT = 4101
        private const val SMS_TIMEOUT_MS = 60_000L
    }

    private val main = Handler(Looper.getMainLooper())
    private val requestCodes = AtomicInteger(1000)
    private var pendingPick: MethodChannel.Result? = null

    private var siren: AudioTrack? = null
    private var savedAlarmVolume: Int? = null
    private var ringtone: Ringtone? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "capabilities" -> result.success(capabilities())
                "smsRestricted" -> result.success(smsRestricted())
                "sendSms" -> sendSms(call.argument<String>("phone")!!, call.argument<String>("message")!!, result)
                "pickContact" -> pickContact(result)
                "call" -> result.success(placeCall(call.argument<String>("number")!!, call.argument<Boolean>("direct") ?: false))
                "batteryLevel" -> result.success(batteryLevel())
                "setTorch" -> result.success(setTorch(call.argument<Boolean>("on") ?: false))
                "startSiren" -> { startSiren(); result.success(null) }
                "stopSiren" -> { stopSiren(); result.success(null) }
                "startRingtone" -> { startRingtone(); result.success(null) }
                "stopRingtone" -> { stopRingtone(); result.success(null) }
                "keepScreenOn" -> { keepScreenOn(call.argument<Boolean>("on") ?: false); result.success(null) }
                "locationEnabled" -> result.success(location.isEnabled())
                "openLocationSettings" -> { location.openSettings(); result.success(true) }
                "currentLocation" -> location.current((call.argument<Int>("timeoutMs") ?: 15000).toLong(), result)
                "lastKnownLocation" -> location.lastKnown(result)
                "startTracking" -> result.success(
                    location.startTracking(
                        call.argument<Boolean>("background") ?: false,
                        call.argument<String>("title") ?: "",
                        call.argument<String>("text") ?: "",
                    )
                )
                "stopTracking" -> { location.stopTracking(); result.success(null) }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("NATIVE_ERROR", e.message, null)
        }
    }

    fun dispose() {
        stopSiren()
        stopRingtone()
    }

    private fun granted(permission: String) =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun declares(permission: String): Boolean = try {
        val info = activity.packageManager.getPackageInfo(activity.packageName, PackageManager.GET_PERMISSIONS)
        info.requestedPermissions?.contains(permission) == true
    } catch (e: Exception) {
        false
    }

    /**
     * True when Android's "restricted settings" (enhanced confirmation) block
     * SEND_SMS. Since Android 15 this applies to apps installed from a file
     * (browser, WhatsApp, file manager): every request is denied with an
     * "App was denied access to SMS" message until the user taps "Allow
     * restricted settings" in App info. Store and USB (adb) installs are not
     * affected.
     */
    private fun smsRestricted(): Boolean {
        if (Build.VERSION.SDK_INT < 35) return false
        if (!declares(Manifest.permission.SEND_SMS) || granted(Manifest.permission.SEND_SMS)) return false
        return try {
            val source = activity.packageManager.getInstallSourceInfo(activity.packageName).packageSource
            // USB (adb) installs report PACKAGE_SOURCE_OTHER and are not restricted.
            source == PackageInstaller.PACKAGE_SOURCE_LOCAL_FILE ||
                source == PackageInstaller.PACKAGE_SOURCE_DOWNLOADED_FILE
        } catch (e: Exception) {
            false
        }
    }

    private fun capabilities(): Map<String, Boolean> {
        val pm = activity.packageManager
        // Some devices only declare the older, broader telephony feature.
        val telephony = pm.hasSystemFeature(PackageManager.FEATURE_TELEPHONY) ||
            (Build.VERSION.SDK_INT >= 33 && pm.hasSystemFeature(PackageManager.FEATURE_TELEPHONY_MESSAGING))
        return mapOf(
            // The lite edition removes these permissions from its manifest.
            "sms" to (telephony && declares(Manifest.permission.SEND_SMS)),
            "call" to declares(Manifest.permission.CALL_PHONE),
            "torch" to (torchCameraId() != null),
        )
    }

    // ── SMS ────────────────────────────────────────────────────────────────

    private fun sendSms(phone: String, message: String, result: MethodChannel.Result) {
        if (!granted(Manifest.permission.SEND_SMS)) {
            result.success(mapOf("status" to "failed", "error" to "permission_denied"))
            return
        }
        val sms: SmsManager = if (Build.VERSION.SDK_INT >= 31) {
            activity.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION") SmsManager.getDefault()
        }
        // Application context: the receiver must outlive Activity recreation.
        val app = activity.applicationContext
        val parts = sms.divideMessage(message)
        val action = "${app.packageName}.SMS_SENT.${requestCodes.incrementAndGet()}"
        var remaining = parts.size
        var failure: String? = null
        var finished = false

        lateinit var receiver: BroadcastReceiver
        val finish = { status: String, error: String? ->
            if (!finished) {
                finished = true
                runCatching { app.unregisterReceiver(receiver) }
                result.success(if (error == null) mapOf("status" to status) else mapOf("status" to status, "error" to error))
            }
        }
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (resultCode != Activity.RESULT_OK && failure == null) failure = smsError(resultCode)
                remaining -= 1
                if (remaining <= 0) {
                    val f = failure
                    if (f == null) finish("sent", null) else finish("failed", f)
                }
            }
        }
        val filter = IntentFilter(action)
        if (Build.VERSION.SDK_INT >= 33) {
            app.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag") app.registerReceiver(receiver, filter)
        }

        val sentIntents = ArrayList<PendingIntent>()
        repeat(parts.size) {
            val intent = Intent(action).setPackage(app.packageName)
            sentIntents.add(
                PendingIntent.getBroadcast(
                    app, requestCodes.incrementAndGet(), intent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_ONE_SHOT
                )
            )
        }
        try {
            sms.sendMultipartTextMessage(phone, null, parts, sentIntents, null)
        } catch (e: Exception) {
            finish("failed", e.message ?: "send_error")
            return
        }
        main.postDelayed({ finish("failed", "timeout") }, SMS_TIMEOUT_MS)
    }

    private fun smsError(code: Int) = when (code) {
        SmsManager.RESULT_ERROR_NO_SERVICE -> "no_service"
        SmsManager.RESULT_ERROR_RADIO_OFF -> "radio_off"
        SmsManager.RESULT_ERROR_NULL_PDU -> "null_pdu"
        SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "generic_failure"
        else -> "error_$code"
    }

    // ── Contacts ───────────────────────────────────────────────────────────

    private fun pickContact(result: MethodChannel.Result) {
        pendingPick?.success(null)
        pendingPick = result
        val intent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
        activity.startActivityForResult(intent, REQUEST_PICK_CONTACT)
    }

    /** Returns true when the result belonged to the contact picker. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_CONTACT) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
        )
        activity.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                result.success(mapOf("name" to (cursor.getString(0) ?: ""), "phone" to (cursor.getString(1) ?: "")))
                return true
            }
        }
        result.success(null)
        return true
    }

    // ── Calls ──────────────────────────────────────────────────────────────

    private fun placeCall(number: String, direct: Boolean): Boolean {
        val uri = Uri.parse("tel:" + Uri.encode(number))
        val action = if (direct && granted(Manifest.permission.CALL_PHONE)) Intent.ACTION_CALL else Intent.ACTION_DIAL
        return try {
            activity.startActivity(Intent(action, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: Exception) {
            false
        }
    }

    // ── Device state ───────────────────────────────────────────────────────

    private fun batteryLevel(): Int? {
        val bm = activity.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        return if (level in 0..100) level else null
    }

    private fun keepScreenOn(on: Boolean) {
        if (on) activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        else activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun torchCameraId(): String? {
        val cm = activity.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        return try {
            cm.cameraIdList.firstOrNull { id ->
                cm.getCameraCharacteristics(id).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun setTorch(on: Boolean): Boolean {
        val id = torchCameraId() ?: return false
        val cm = activity.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        return try {
            cm.setTorchMode(id, on)
            true
        } catch (e: Exception) {
            false
        }
    }

    // ── Siren ──────────────────────────────────────────────────────────────

    /** A loud rising/falling siren on the alarm stream, synthesized in memory. */
    private fun startSiren() {
        if (siren != null) return
        val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        savedAlarmVolume = audio.getStreamVolume(AudioManager.STREAM_ALARM)
        audio.setStreamVolume(AudioManager.STREAM_ALARM, audio.getStreamMaxVolume(AudioManager.STREAM_ALARM), 0)

        val rate = 44100
        val period = 1.6 // seconds per up-and-down sweep
        val samples = (rate * period).toInt()
        val pcm = ShortArray(samples)
        var phase = 0.0
        for (i in 0 until samples) {
            val t = i.toDouble() / rate
            val freq = 700.0 + 800.0 * (0.5 - 0.5 * cos(2 * PI * t / period))
            phase += 2 * PI * freq / rate
            pcm[i] = (sin(phase) * 0.95 * Short.MAX_VALUE).toInt().toShort()
        }
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(rate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(samples * 2)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()
        track.write(pcm, 0, samples)
        track.setLoopPoints(0, samples, -1)
        track.play()
        siren = track
    }

    private fun stopSiren() {
        siren?.let {
            runCatching { it.stop() }
            it.release()
        }
        siren = null
        savedAlarmVolume?.let { volume ->
            val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audio.setStreamVolume(AudioManager.STREAM_ALARM, volume, 0)
        }
        savedAlarmVolume = null
    }

    // ── Fake call ringtone ─────────────────────────────────────────────────

    private fun vibrator(): Vibrator = if (Build.VERSION.SDK_INT >= 31) {
        (activity.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
    } else {
        @Suppress("DEPRECATION") activity.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }

    private fun startRingtone() {
        stopRingtone()
        val uri = RingtoneManager.getActualDefaultRingtoneUri(activity, RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        ringtone = RingtoneManager.getRingtone(activity, uri)?.also { tone ->
            if (Build.VERSION.SDK_INT >= 28) tone.isLooping = true
            tone.play()
        }
        vibrator().vibrate(VibrationEffect.createWaveform(longArrayOf(0, 900, 700), 0))
    }

    private fun stopRingtone() {
        ringtone?.stop()
        ringtone = null
        runCatching { vibrator().cancel() }
    }
}
