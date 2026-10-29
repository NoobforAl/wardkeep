package dev.omnitun.app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import dev.omnitun.mobile.Mobile
import org.json.JSONArray
import org.json.JSONObject
import java.net.InetAddress
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Holds the Android VPN interface for the Go core. The core asks for a TUN via
 * [CorePlatform.openTun]; this service starts in the foreground, builds the
 * interface and hands the fd back. It stops itself when the core reports the
 * tunnel stopped, when the user taps Disconnect, or when the OS revokes the VPN.
 *
 * Its ongoing notification: "Connecting… · profile" with Disconnect; "Connected · profile"
 * with the speed, Reconnect and Disconnect. When the connection fails it closes the VPN
 * interface as on a stop and leaves a "Connection lost · reason" notification with
 * Reconnect and Open app; a stop the user asked for leaves nothing.
 */
class OmnitunVpnService : VpnService() {

    private var tun: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_DISCONNECT -> {
                Thread { Mobile.stopTunnel() }.start()
                return START_NOT_STICKY
            }
            ACTION_RECONNECT -> {
                // Started with startForegroundService (the notification's Reconnect): foreground first.
                lastText = ""
                startForegroundCompat(buildNotification(getString(R.string.vpn_connecting)))
                instance = this
                ready.countDown()
                cancelConnectionLost(this)
                if (prepare(this) != null) {
                    // The VPN permission was taken away since the notification was posted. Android does not
                    // let a service started from a notification open an activity, so the new notification's
                    // Reconnect opens the app, which asks for it.
                    stopVpn()
                    showConnectionLost(this, "")
                    return START_NOT_STICKY
                }
                Thread { reconnect() }.start()
            }
            SERVICE_INTERFACE -> {
                // Started by Android itself: "Always-on VPN" (at boot, or after this app was
                // killed). No UI is running, so reconnect with the last connect request.
                startForegroundCompat(buildNotification(getString(R.string.vpn_connecting)))
                instance = this
                ready.countDown()
                Thread { reconnectSaved() }.start()
            }
            else -> {
                startForegroundCompat(buildNotification(getString(R.string.vpn_connecting)))
                instance = this
                ready.countDown()
            }
        }
        // Never restart on our own: a VPN must only run while the core asks for it.
        return START_NOT_STICKY
    }

    /** Always-on VPN: starts the core and the tunnel from the request the app saved when it last connected. */
    private fun reconnectSaved() {
        val request = lastConnect(this)
        if (request == null) {
            // Nothing to connect to. With "Block connections without VPN" on, Android keeps
            // traffic blocked until the user connects from the app once.
            Log.w(TAG, "always-on VPN: no saved connection, open the app and connect once")
            stopVpn()
            return
        }
        try {
            CorePlatform.start(this)
            Mobile.startTunnelFromJSON(request)
            Log.i(TAG, "always-on VPN: reconnecting")
        } catch (e: Exception) {
            Log.w(TAG, "always-on VPN failed: ${e.message}")
            Mobile.stopTunnel()
            stopVpn()
        }
    }

    /** Reconnect: connects again with the saved request, replacing whatever the core is doing. */
    private fun reconnect() {
        val request = lastConnect(this)
        if (request == null) {
            stopVpn()
            return
        }
        try {
            CorePlatform.start(this)
            Mobile.restartTunnelFromJSON(request)
        } catch (e: Exception) {
            Log.w(TAG, "reconnect failed: ${e.message}")
            // A failure of the connection itself was reported as an "error" state, which already said
            // "Connection lost" with its reason; anything else (the core did not start) is said here.
            if (!connectionLostShown(this)) {
                stopVpn()
                showConnectionLost(this, "")
            }
        }
    }

    /** Builds the VPN interface from the core's tun config JSON and returns its fd. */
    fun openTun(json: String): Int {
        val cfg = JSONObject(json)
        val builder = Builder().setSession(getString(R.string.app_name))
        val mtu = cfg.optInt("mtu", 0)
        if (mtu > 0) builder.setMtu(mtu)

        cfg.strings("inet4_address").forEach { builder.addAddress(it.addr(), it.bits()) }
        cfg.strings("inet6_address").forEach { builder.addAddress(it.addr(), it.bits()) }

        if (cfg.optBoolean("auto_route", true)) {
            val v4 = cfg.strings("inet4_route_range").ifEmpty { listOf("0.0.0.0/0") }
            val v6 = cfg.strings("inet6_route_range").ifEmpty { listOf("::/0") }
            (v4 + v6).forEach { builder.addRoute(it.addr(), it.bits()) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                (cfg.strings("inet4_route_exclude") + cfg.strings("inet6_route_exclude")).forEach {
                    builder.excludeRoute(android.net.IpPrefix(InetAddress.getByName(it.addr()), it.bits()))
                }
            }
        }
        cfg.strings("dns_servers").forEach { builder.addDnsServer(it) }

        val include = cfg.strings("include_package")
        val exclude = cfg.strings("exclude_package")
        if (include.isNotEmpty()) {
            include.forEach { runCatching { builder.addAllowedApplication(it) } }
        } else {
            exclude.forEach { runCatching { builder.addDisallowedApplication(it) } }
            // Engines whose sockets can't be protected one by one keep the
            // whole app out of the VPN instead.
            if (cfg.optBoolean("exclude_self")) runCatching { builder.addDisallowedApplication(packageName) }
        }

        cfg.optJSONObject("http_proxy")?.let { proxy ->
            builder.setHttpProxy(
                ProxyInfo.buildDirectProxy(
                    proxy.getString("server"),
                    proxy.getInt("port"),
                    proxy.optJSONArray("bypass_domain").toList(),
                ),
            )
        }
        builder.setMetered(false)

        val pfd = builder.establish() ?: throw IllegalStateException("VPN permission not granted")
        tun?.close()
        tun = pfd
        cancelConnectionLost(this)
        updateNotification(getString(R.string.vpn_connected))
        return pfd.fd
    }

    private var lastText = ""

    /** Shows the profile and live speed; called about once a second while connected. */
    fun updateStatus(status: String, profile: String, upBps: Long, downBps: Long) {
        val title = when (status) {
            "connected" -> getString(R.string.vpn_connected)
            else -> getString(R.string.vpn_connecting)
        } + if (profile.isNotEmpty()) " · $profile" else ""
        val text = if (status == "connected") "↓ ${speed(downBps)}   ↑ ${speed(upBps)}" else ""
        val key = "$title|$text"
        if (key == lastText) return
        lastText = key
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification(title, text, connected = status == "connected"))
    }

    private fun speed(bps: Long): String = when {
        bps >= 1 shl 20 -> "%.1f MB/s".format(bps / 1048576.0)
        bps >= 1 shl 10 -> "${bps shr 10} KB/s"
        else -> "$bps B/s"
    }

    /**
     * The connection failed (the core's "error" state): the VPN interface closes as on a stop, so nothing
     * runs half-open, and a notification says the connection was lost and why ([error], scrubbed of
     * addresses by the core, or else [code]), with Reconnect.
     */
    fun connectionLost(error: String, code: String) {
        stopVpn()
        showConnectionLost(this, shortReason(error, code))
    }

    /** Called when the core reports the tunnel stopped. */
    fun stopVpn() {
        tun?.close()
        tun = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /** The user swiped the app away from Recents. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        if (stopOnClose(this)) {
            Log.i(TAG, "app task removed, stopping VPN")
            Thread { Mobile.stopTunnel() }.start()
            stopVpn()
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onRevoke() {
        // Another VPN took over or the user revoked us in system settings.
        Log.i(TAG, "VPN revoked by the system")
        Thread { Mobile.stopTunnel() }.start()
        stopVpn()
    }

    override fun onDestroy() {
        tun?.close()
        tun = null
        if (instance === this) {
            instance = null
            ready = CountDownLatch(1)
        }
        super.onDestroy()
    }

    private fun startForegroundCompat(n: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
    }

    private fun updateNotification(title: String) {
        lastText = "" // the next status update shows the profile and speed again
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, buildNotification(title, connected = true))
    }

    /** The ongoing notification; a [connected] one also offers Reconnect. */
    private fun buildNotification(title: String, text: String = "", connected: Boolean = false): Notification {
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, getString(R.string.vpn_channel), NotificationManager.IMPORTANCE_LOW),
            )
        }
        val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), flags)
        val disconnect = PendingIntent.getService(
            this, 1, Intent(this, OmnitunVpnService::class.java).setAction(ACTION_DISCONNECT), flags,
        )
        val builder = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_vpn_key)
            .setContentTitle(title)
            .setContentText(text.ifEmpty { getString(R.string.app_name) })
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
        if (connected) {
            builder.addAction(Notification.Action.Builder(null, getString(R.string.vpn_reconnect), reconnectIntent(this)).build())
        }
        return builder
            .addAction(Notification.Action.Builder(null, getString(R.string.vpn_disconnect), disconnect).build())
            .build()
    }

    companion object {
        private const val TAG = "OmnitunVpn"
        private const val CHANNEL = "vpn"
        private const val NOTIFICATION_ID = 1
        private const val ACTION_DISCONNECT = "dev.omnitun.app.DISCONNECT"
        private const val ACTION_RECONNECT = "dev.omnitun.app.RECONNECT"

        /** The "Connection lost" notification: not ongoing, on the "errors" channel, next to the service's own. */
        private const val LOST_NOTIFICATION_ID = 2
        private const val ERRORS_CHANNEL = "errors"

        /** The longest reason "Connection lost · reason" shows. */
        private const val MAX_REASON = 100

        private const val PREFS = "omnitun"
        private const val KEY_STOP_ON_CLOSE = "stop_on_close"
        private const val KEY_LAST_CONNECT = "last_connect"

        @Volatile
        var instance: OmnitunVpnService? = null
            private set

        /** "Stop VPN when app is closed", mirrored from the Flutter settings. */
        fun stopOnClose(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_STOP_ON_CLOSE, true)

        fun setStopOnClose(context: Context, value: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_STOP_ON_CLOSE, value).apply()
        }

        /** The core's "start" request of the last connection (what always-on VPN reconnects with). */
        fun lastConnect(context: Context): String? =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_LAST_CONNECT, null)

        fun saveLastConnect(context: Context, request: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY_LAST_CONNECT, request).apply()
        }

        @Volatile
        private var ready = CountDownLatch(1)

        /**
         * The app's own system notifications of connection failures (MainActivity's "show" with
         * connection = true) still on screen. "Connection lost" says the same, so posting it removes them,
         * and while it is shown they are not posted: one notification per failure. Guarded by itself.
         */
        private val connectionAlerts = mutableSetOf<Int>()

        /** The "errors" channel (failures the user should hear about), created on first use. */
        fun errorsChannel(context: Context): String {
            val nm = context.getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(ERRORS_CHANNEL) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(ERRORS_CHANNEL, context.getString(R.string.errors_channel), NotificationManager.IMPORTANCE_DEFAULT),
                )
            }
            return ERRORS_CHANNEL
        }

        /** Whether the app may post notifications (Android 13 asks the user). */
        fun canNotify(context: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

        fun connectionLostShown(context: Context): Boolean =
            context.getSystemService(NotificationManager::class.java).activeNotifications.any { it.id == LOST_NOTIFICATION_ID }

        /**
         * Posts one of the app's notifications of a connection failure unless "Connection lost" already tells
         * it; [post] posts it and returns its id. Returns whether it was posted.
         */
        fun postConnectionAlert(context: Context, post: () -> Int): Boolean = synchronized(connectionAlerts) {
            if (connectionLostShown(context)) return false
            connectionAlerts += post()
            true
        }

        /** "Connection lost · reason" with Reconnect and Open app; tapping it opens the app. */
        fun showConnectionLost(context: Context, reason: String) {
            if (!canNotify(context)) return
            val nm = context.getSystemService(NotificationManager::class.java)
            val title = context.getString(R.string.vpn_connection_lost) + if (reason.isNotEmpty()) " · $reason" else ""
            val open = openAppIntent(context)
            val notification = Notification.Builder(context, errorsChannel(context))
                .setSmallIcon(R.drawable.ic_vpn_key)
                .setContentTitle(title)
                .setContentText(context.getString(R.string.app_name))
                .setContentIntent(open)
                .setAutoCancel(true)
                .addAction(Notification.Action.Builder(null, context.getString(R.string.vpn_reconnect), reconnectIntent(context)).build())
                .addAction(Notification.Action.Builder(null, context.getString(R.string.vpn_open_app), open).build())
                .build()
            synchronized(connectionAlerts) {
                nm.notify(LOST_NOTIFICATION_ID, notification)
                connectionAlerts.forEach { nm.cancel(it) }
                connectionAlerts.clear()
            }
        }

        fun cancelConnectionLost(context: Context) {
            context.getSystemService(NotificationManager::class.java).cancel(LOST_NOTIFICATION_ID)
        }

        private fun openAppIntent(context: Context): PendingIntent = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        /**
         * Reconnect: the service connects again with the saved request. Without the VPN permission (revoked
         * since) it opens the app instead, which asks for it when the user connects.
         */
        private fun reconnectIntent(context: Context): PendingIntent =
            if (prepare(context) != null) {
                openAppIntent(context)
            } else {
                PendingIntent.getForegroundService(
                    context, 2, Intent(context, OmnitunVpnService::class.java).setAction(ACTION_RECONNECT),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
            }

        /** The short reason "Connection lost" gives: the core's sentence, else its code; never long. */
        fun shortReason(error: String, code: String): String {
            val text = error.trim().ifEmpty { code.trim() }
            val short = if (text.length > MAX_REASON) text.take(MAX_REASON - 1).trimEnd() + "…" else text
            return short.replaceFirstChar { it.uppercase() }
        }

        /** Starts the service in the foreground and waits until it is ready. */
        fun startAndAwait(context: Context, timeoutSeconds: Long = 10): OmnitunVpnService {
            instance?.let { return it }
            context.startForegroundService(Intent(context, OmnitunVpnService::class.java))
            if (!ready.await(timeoutSeconds, TimeUnit.SECONDS)) {
                throw IllegalStateException("VPN service did not start")
            }
            return instance ?: throw IllegalStateException("VPN service did not start")
        }
    }
}

private fun JSONObject.strings(key: String): List<String> = optJSONArray(key).toList()

private fun JSONArray?.toList(): List<String> =
    if (this == null) emptyList() else List(length()) { getString(it) }

private fun String.addr(): String = substringBefore('/')

private fun String.bits(): Int = substringAfter('/').toInt()
