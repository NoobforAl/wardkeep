package dev.omnitun.app

import android.Manifest
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.net.VpnManager
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction
import java.util.concurrent.Executors

/**
 * Bridges Flutter to the core over the "omnitun/core" channel:
 *  - start: launch the in-process core, returns {"addr","token"} for the control protocol
 *  - prepareVpn: show the system VPN consent dialog if needed, returns true when granted
 *  - requestNotifications: ask for POST_NOTIFICATIONS (Android 13+)
 *
 * and the "omnitun/notify" channel: a failure nothing handled (docs/logging.md §5) as a system notification
 * ("show" {title, body, conn, connection}); tapping it opens the app's log page for that connection ("openLogs"
 * to Flutter while it runs, "takeOpenLogs" from Flutter when the tap started the app). A failure of the
 * connection (connection = true) is left out while the VPN service's "Connection lost" tells it.
 */
class MainActivity : FlutterActivity() {

    private val io = Executors.newSingleThreadExecutor()
    private var pendingVpn: MethodChannel.Result? = null

    /** A link or config file another app sent us, until Flutter has taken it (see "omnitun/incoming"). */
    private var incoming: String? = null

    /** Why that file could not be read ("empty", "too_large", "not_text", "denied", "missing", "unreadable"). */
    private var incomingError: String? = null
    private var incomingChannel: MethodChannel? = null

    private class IncomingFailure(val code: String) : Exception(code)

    /** The connection whose log a tapped error notification asked for, until Flutter has taken it. */
    private var openLogs: String? = null
    private var notifyChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        removeOldIkev2Profile()
        // Only a fresh start: after a rotation the same intent would import the file again.
        if (savedInstanceState == null) {
            takeIncoming(intent)
            if (intent?.action == ACTION_SHOW_LOGS) openLogs = intent.getStringExtra(EXTRA_CONN) ?: ""
        }
    }

    /**
     * Versions with IKEv2 registered a VPN profile with Android's own IKEv2 client. IKEv2 is gone, so the
     * profile is deleted once (Android 11+), or it would stay in the system's VPN settings.
     */
    private fun removeOldIkev2Profile() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val prefs = getSharedPreferences(CLEANUP_PREFS, MODE_PRIVATE)
        if (prefs.getBoolean(KEY_IKEV2_PROFILE_REMOVED, false)) return
        runCatching { getSystemService(VpnManager::class.java)?.deleteProvisionedVpnProfile() }
        prefs.edit().putBoolean(KEY_IKEV2_PROFILE_REMOVED, true).apply()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ACTION_SHOW_LOGS) {
            notifyChannel?.invokeMethod("openLogs", intent.getStringExtra(EXTRA_CONN) ?: "")
            return
        }
        takeIncoming(intent)
    }

    /**
     * A failure as a notification on the "errors" channel; one per connection, a newer one replaces it. A failure
     * of the [connection] is not posted while the VPN service's "Connection lost" says it (and that one removes
     * it when it comes later).
     */
    private fun showError(title: String, body: String, conn: String, connection: Boolean) {
        if (!OmnitunVpnService.canNotify(this)) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = OmnitunVpnService.errorsChannel(this)
        val notificationId = ERROR_NOTIFICATION_BASE + (conn.hashCode() and 0xffff)
        val open = PendingIntent.getActivity(
            this,
            notificationId,
            Intent(this, MainActivity::class.java)
                .setAction(ACTION_SHOW_LOGS)
                .putExtra(EXTRA_CONN, conn)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = Notification.Builder(this, channel)
            .setSmallIcon(R.drawable.ic_vpn_key)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        if (connection) {
            OmnitunVpnService.postConnectionAlert(this) { notificationId.also { manager.notify(it, notification) } }
        } else {
            manager.notify(notificationId, notification)
        }
    }

    private fun takeIncoming(intent: Intent?) {
        incomingError = null
        incoming = try {
            incomingText(intent) ?: return
        } catch (e: IncomingFailure) {
            incomingError = e.code // the app tells the user why, instead of doing nothing
            null
        }
        incomingChannel?.invokeMethod("incoming", null) // the app is running: tell it now; else it asks at start
    }

    /** The text a VIEW or SEND intent carries: the link itself, or the contents of the file (up to 8 MB). */
    private fun incomingText(intent: Intent?): String? {
        intent ?: return null
        return when (intent.action) {
            Intent.ACTION_VIEW -> {
                val uri = intent.data ?: return null
                if (uri.scheme == "content" || uri.scheme == "file") readText(uri) else uri.toString()
            }
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                val stream: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
                stream?.let { readText(it) } ?: intent.getStringExtra(Intent.EXTRA_TEXT)
            }
            else -> null
        }
    }

    /** The text of a file, or an [IncomingFailure] saying why it cannot be used. */
    private fun readText(uri: Uri): String {
        val bytes = try {
            val input = contentResolver.openInputStream(uri) ?: throw IncomingFailure("unreadable")
            input.use { stream ->
                val out = ByteArrayOutputStream()
                val buf = ByteArray(8192)
                while (true) {
                    val n = stream.read(buf)
                    if (n < 0) break
                    out.write(buf, 0, n)
                    if (out.size() > MAX_INCOMING) throw IncomingFailure("too_large") // not a config file
                }
                out.toByteArray()
            }
        } catch (e: IncomingFailure) {
            throw e
        } catch (e: SecurityException) {
            throw IncomingFailure("denied")
        } catch (e: java.io.FileNotFoundException) {
            // Android reports a file it will not open for us the same way as one that is not there; the
            // text of the exception tells them apart ("open failed: EACCES (Permission denied)").
            val why = e.message.orEmpty()
            throw IncomingFailure(if (why.contains("EACCES") || why.contains("EPERM") || why.contains("Permission denied")) "denied" else "missing")
        } catch (e: java.io.IOException) {
            throw IncomingFailure("unreadable")
        }
        return decodeText(bytes)
    }

    /** UTF-8 (with or without a byte order mark) or UTF-16 with one; binary data or another encoding is "not_text". */
    private fun decodeText(bytes: ByteArray): String {
        if (bytes.isEmpty()) throw IncomingFailure("empty")
        val bom16 = bytes.size >= 2 &&
            ((bytes[0] == 0xFF.toByte() && bytes[1] == 0xFE.toByte()) || (bytes[0] == 0xFE.toByte() && bytes[1] == 0xFF.toByte()))
        val text = if (bom16) {
            String(bytes, Charsets.UTF_16) // honours the mark and drops it
        } else {
            if (bytes.take(4096).contains(0)) throw IncomingFailure("not_text")
            try {
                Charsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(bytes)).toString()
            } catch (e: CharacterCodingException) {
                throw IncomingFailure("not_text")
            }
        }.removePrefix("﻿")
        if (text.isBlank()) throw IncomingFailure("empty")
        return text
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        incomingChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "omnitun/incoming").also { ch ->
            ch.setMethodCallHandler { call, result ->
                if (call.method == "take") {
                    result.success(mapOf("text" to incoming, "error" to incomingError))
                    incoming = null
                    incomingError = null
                } else {
                    result.notImplemented()
                }
            }
        }
        notifyChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "omnitun/notify").also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        runCatching {
                            showError(
                                call.argument<String>("title") ?: getString(R.string.app_name),
                                call.argument<String>("body") ?: "",
                                call.argument<String>("conn") ?: "",
                                call.argument<Boolean>("connection") ?: false,
                            )
                        }
                        result.success(null)
                    }
                    "takeOpenLogs" -> {
                        result.success(openLogs)
                        openLogs = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "omnitun/core").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> io.execute {
                    val res = runCatching { CorePlatform.start(this) }
                    runOnUiThread {
                        res.fold({ result.success(it) }, { result.error("START_FAILED", it.message, null) })
                    }
                }
                "prepareVpn" -> {
                    val intent = VpnService.prepare(this)
                    if (intent == null) {
                        result.success(true)
                    } else {
                        pendingVpn?.success(false)
                        pendingVpn = result
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, REQUEST_VPN)
                    }
                }
                "listApps" -> io.execute {
                    // [{package, label, system}] for the split-tunneling picker.
                    val res = runCatching {
                        val pm = packageManager
                        pm.getInstalledApplications(0)
                            .filter { it.packageName != packageName }
                            .map {
                                mapOf(
                                    "package" to it.packageName,
                                    "label" to pm.getApplicationLabel(it).toString(),
                                    // Preinstalled apps with a launcher icon (Chrome, YouTube…) are
                                    // ordinary apps to the user; only hide background system packages.
                                    "system" to ((it.flags and ApplicationInfo.FLAG_SYSTEM) != 0 &&
                                        pm.getLaunchIntentForPackage(it.packageName) == null),
                                )
                            }
                    }
                    runOnUiThread {
                        res.fold({ result.success(it) }, { result.error("LIST_APPS_FAILED", it.message, null) })
                    }
                }
                "appIcon" -> io.execute {
                    val pkg = call.arguments as String
                    val png = runCatching { iconPng(pkg) }.getOrNull()
                    runOnUiThread { result.success(png) }
                }
                "setStopOnClose" -> {
                    OmnitunVpnService.setStopOnClose(this, call.arguments as? Boolean ?: true)
                    result.success(null)
                }
                "saveLastConnect" -> {
                    OmnitunVpnService.saveLastConnect(this, call.arguments as String)
                    result.success(null)
                }
                "openVpnSettings" -> {
                    // Where "Always-on VPN" and "Block connections without VPN" are switched on.
                    val opened = runCatching { startActivity(Intent(Settings.ACTION_VPN_SETTINGS)) }.isSuccess
                    result.success(opened)
                }
                "requestNotifications" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_VPN) {
            pendingVpn?.success(resultCode == RESULT_OK)
            pendingVpn = null
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    /** The app's launcher icon as a 96 px PNG. */
    private fun iconPng(pkg: String): ByteArray {
        val drawable = packageManager.getApplicationIcon(pkg)
        val size = 96
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        return ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteArray()
        }
    }

    companion object {
        private const val REQUEST_VPN = 1001
        private const val CLEANUP_PREFS = "cleanup"
        private const val KEY_IKEV2_PROFILE_REMOVED = "ikev2_profile_removed"
        private const val REQUEST_NOTIFICATIONS = 1002
        private const val ERROR_NOTIFICATION_BASE = 0x10000 // above the VPN service's own (1)
        private const val ACTION_SHOW_LOGS = "dev.omnitun.app.SHOW_LOGS"
        private const val EXTRA_CONN = "conn"
        private const val MAX_INCOMING = 8 * 1024 * 1024 // as much as the core imports (importer.MaxTextSize)
    }
}
