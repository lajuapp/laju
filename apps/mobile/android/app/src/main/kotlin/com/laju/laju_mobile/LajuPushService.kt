package com.laju.laju_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class LajuPushService : Service() {

    companion object {
        const val CHANNEL_CALLS = "laju_calls"
        const val CHANNEL_MESSAGES = "laju_messages"
        const val CHANNEL_BACKGROUND = "laju_sync"
        const val NOTIFICATION_ID_CALL = 9999
        const val NOTIFICATION_ID_SYNC = 9001

        const val ACTION_START = "com.laju.START_PUSH_SERVICE"
        const val ACTION_STOP = "com.laju.STOP_PUSH_SERVICE"
        const val ACTION_DECLINE = "com.laju.DECLINE_CALL"
        const val ACTION_RESTART = "com.laju.RESTART_PUSH_SERVICE"
        const val ACTION_WATCHDOG = "com.laju.PUSH_WATCHDOG"

        const val PREFS_NAME = "laju_push_prefs"
        const val KEY_BASE_URL = "base_url"
        const val KEY_TOKEN = "auth_token"
        const val KEY_LAST_EVENT_TS = "last_event_ts"
        const val KEY_NOTIFIED_IDS = "notified_ids"

        fun startService(context: Context, baseUrl: String, token: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val edit = prefs.edit()
                .putString(KEY_BASE_URL, baseUrl)
                .putString(KEY_TOKEN, token)
            if (!prefs.contains(KEY_LAST_EVENT_TS)) {
                edit.putLong(KEY_LAST_EVENT_TS, System.currentTimeMillis() - 15 * 60 * 1000L)
            }
            edit.apply()

            val intent = Intent(context, LajuPushService::class.java).apply {
                action = ACTION_START
                putExtra(KEY_BASE_URL, baseUrl)
                putExtra(KEY_TOKEN, token)
            }
            try {
                // Prefer standard silent background service - zero persistent notification in status bar / drawer!
                context.startService(intent)
            } catch (e: Exception) {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    }
                } catch (e2: Exception) {
                    e2.printStackTrace()
                }
            }

            // Arm 3-minute exact watchdog
            scheduleWatchdog(context)
        }

        fun stopService(context: Context) {
            cancelWatchdog(context)
            val intent = Intent(context, LajuPushService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.stopService(intent)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        fun scheduleWatchdog(context: Context) {
            try {
                val am = context.getSystemService(Context.ALARM_SERVICE) as? android.app.AlarmManager ?: return
                val intent = Intent(context, LajuPushReceiver::class.java).apply {
                    action = ACTION_WATCHDOG
                }
                val pi = PendingIntent.getBroadcast(
                    context,
                    2001,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val intervalMs = 3 * 60 * 1000L // 3 minutes
                val triggerAt = System.currentTimeMillis() + intervalMs

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        am.setExactAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, triggerAt, pi)
                    } catch (_: SecurityException) {
                        am.setAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, triggerAt, pi)
                    }
                } else {
                    am.set(android.app.AlarmManager.RTC_WAKEUP, triggerAt, pi)
                }
            } catch (_: Exception) {}
        }

        fun cancelWatchdog(context: Context) {
            try {
                val am = context.getSystemService(Context.ALARM_SERVICE) as? android.app.AlarmManager ?: return
                val intent = Intent(context, LajuPushReceiver::class.java).apply {
                    action = ACTION_WATCHDOG
                }
                val pi = PendingIntent.getBroadcast(
                    context,
                    2001,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                am.cancel(pi)
            } catch (_: Exception) {}
        }
    }

    @Volatile private var isRunning = false
    @Volatile private var currentToken = ""
    @Volatile private var currentBaseUrl = ""
    @Volatile private var lastStreamActivityMs = 0L
    @Volatile private var activeConnection: HttpURLConnection? = null
    private var streamThread: Thread? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var callWakeLock: PowerManager.WakeLock? = null
    private var streamWakeLock: PowerManager.WakeLock? = null
    private val notifiedEventIds = java.util.Collections.synchronizedSet( LinkedHashSet<String>() )

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannels()
        registerNetworkCallback()
        loadNotifiedIds()
    }

    private fun loadNotifiedIds() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val saved = prefs.getStringSet(KEY_NOTIFIED_IDS, null)
            if (saved != null) {
                notifiedEventIds.addAll(saved)
            }
        } catch (_: Exception) {}
    }

    private fun markEventNotified(eventId: String): Boolean {
        if (eventId.isEmpty()) return true
        synchronized(notifiedEventIds) {
            if (notifiedEventIds.contains(eventId)) {
                return false
            }
            notifiedEventIds.add(eventId)
            while (notifiedEventIds.size > 150) {
                val first = notifiedEventIds.iterator().next()
                notifiedEventIds.remove(first)
            }
            try {
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putStringSet(KEY_NOTIFIED_IDS, HashSet(notifiedEventIds)).apply()
            } catch (_: Exception) {}
            return true
        }
    }

    private fun acquireStreamWakeLock(timeoutMs: Long = 10000L) {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
            if (streamWakeLock == null) {
                streamWakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "laju:push_stream_wake"
                ).apply {
                    setReferenceCounted(false)
                }
            }
            streamWakeLock?.acquire(timeoutMs)
        } catch (_: Exception) {}
    }

    private fun releaseStreamWakeLock() {
        try {
            if (streamWakeLock?.isHeld == true) {
                streamWakeLock?.release()
            }
        } catch (_: Exception) {}
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action

        if (action == ACTION_DECLINE) {
            val callId = intent.getStringExtra("call_id") ?: ""
            val callerName = intent.getStringExtra("caller_name") ?: "Panggilan"
            releaseCallWakeLock()
            if (callId.isNotEmpty()) {
                declineCallInBackground(callId)
            }
            try {
                val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(NOTIFICATION_ID_CALL)
                nm.cancel(9999)
            } catch (_: Exception) {}

            MainActivity.instance?.let { activity ->
                activity.dispatchCallAction(callId, "decline", callerName = callerName)
            }
            return START_NOT_STICKY
        }

        if (action == ACTION_STOP) {
            releaseCallWakeLock()
            releaseStreamWakeLock()
            stopStream()
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
            } catch (_: Exception) {}
            stopSelf()
            return START_NOT_STICKY
        }

        // Satisfy startForeground contract if started via startForegroundService, then immediately dismiss
        // This ensures ZERO persistent notifications exist in status bar or drawer while idle
        dismissForegroundSyncNotification()

        // Always re-arm the 3-minute watchdog on every service start/wakeup
        scheduleWatchdog(applicationContext)

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isAuthenticated = flutterPrefs.getBoolean("flutter.laju_is_authenticated", true)
        if (!isAuthenticated) {
            stopStream()
            stopSelf()
            return START_NOT_STICKY
        }

        val baseUrl = intent?.getStringExtra(KEY_BASE_URL) ?: prefs.getString(KEY_BASE_URL, "") ?: ""
        val flutterToken = flutterPrefs.getString("flutter.laju_auth_token", "") ?: ""
        val intentToken = intent?.getStringExtra(KEY_TOKEN) ?: ""
        val savedToken = prefs.getString(KEY_TOKEN, "") ?: ""
        val token = when {
            intentToken.isNotEmpty() -> intentToken
            flutterToken.isNotEmpty() -> flutterToken
            else -> savedToken
        }

        if (baseUrl.isNotEmpty() && token.isNotEmpty()) {
            prefs.edit().putString(KEY_BASE_URL, baseUrl).putString(KEY_TOKEN, token).apply()
            startPushStream(baseUrl, token)
        }

        return START_STICKY
    }

    private fun dismissForegroundSyncNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            val syncChannel = NotificationChannel(
                CHANNEL_BACKGROUND,
                "Layanan Latar Belakang LAJU",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Layanan latar belakang senyap"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }
            nm.createNotificationChannel(syncChannel)

            val emptyNotif = NotificationCompat.Builder(this, CHANNEL_BACKGROUND)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("")
                .setContentText("")
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .setSilent(true)
                .build()

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        NOTIFICATION_ID_SYNC,
                        emptyNotif,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                    )
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIFICATION_ID_SYNC,
                        emptyNotif,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                    )
                } else {
                    startForeground(NOTIFICATION_ID_SYNC, emptyNotif)
                }

                // Immediately remove from notification bar & drawer - 100% clean like WhatsApp
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                nm.cancel(NOTIFICATION_ID_SYNC)
            } catch (_: Exception) {}
        }
    }

    private fun isConnectedToWifi(): Boolean {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = cm.activeNetwork ?: return false
            val caps = cm.getNetworkCapabilities(network) ?: return false
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
        } else {
            @Suppress("DEPRECATION")
            val info = cm.activeNetworkInfo
            @Suppress("DEPRECATION")
            info != null && info.type == ConnectivityManager.TYPE_WIFI
        }
    }

    private fun registerNetworkCallback() {
        if (networkCallback != null) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    // Fast instant network reconnection on handover (Wi-Fi <-> Cellular)
                    restartStreamImmediately()
                }

                override fun onLost(network: Network) {
                    interruptCurrentConnection()
                }
            }
            try {
                cm.registerDefaultNetworkCallback(networkCallback!!)
            } catch (_: Exception) {}
        }
    }

    private fun unregisterNetworkCallback() {
        networkCallback?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                try {
                    cm?.unregisterNetworkCallback(it)
                } catch (_: Exception) {}
            }
        }
        networkCallback = null
    }

    private fun interruptCurrentConnection() {
        try {
            activeConnection?.disconnect()
        } catch (_: Exception) {}
    }

    private fun restartStreamImmediately() {
        if (!isRunning) {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val bUrl = prefs.getString(KEY_BASE_URL, "") ?: ""
            val tok = resolveLatestToken(prefs.getString(KEY_TOKEN, "") ?: "")
            if (bUrl.isNotEmpty() && tok.isNotEmpty()) {
                startPushStream(bUrl, tok)
            }
            return
        }
        lastStreamActivityMs = 0L
        interruptCurrentConnection()
    }

    private fun resolveLatestToken(fallback: String): String {
        return try {
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val flutterTok = flutterPrefs.getString("flutter.laju_auth_token", "") ?: ""
            if (flutterTok.isNotEmpty()) flutterTok else fallback
        } catch (_: Exception) {
            fallback
        }
    }

    private fun tryRefreshTokenInBackground(rawBase: String, oldToken: String): String? {
        var conn: HttpURLConnection? = null
        return try {
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isAuthenticated = flutterPrefs.getBoolean("flutter.laju_is_authenticated", true)
            if (!isAuthenticated) return null

            val latestFlutterTok = flutterPrefs.getString("flutter.laju_auth_token", "") ?: ""
            if (latestFlutterTok.isNotEmpty() && latestFlutterTok != oldToken) {
                getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .edit()
                    .putString(KEY_TOKEN, latestFlutterTok)
                    .apply()
                return latestFlutterTok
            }

            val deviceUuid = flutterPrefs.getString("flutter.laju_local_device_uuid", "") ?: ""
            if (deviceUuid.isEmpty()) return null

            val url = URL("$rawBase/auth/refresh-device")
            conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Authorization", "Bearer $oldToken")
                setRequestProperty("Content-Type", "application/json")
                connectTimeout = 10000
                readTimeout = 10000
                doOutput = true
                doInput = true
            }
            val bodyJson = JSONObject().apply {
                put("deviceUuid", deviceUuid)
                put("deviceName", "Mobile Device")
            }.toString()
            conn.outputStream.use { os ->
                os.write(bodyJson.toByteArray(Charsets.UTF_8))
                os.flush()
            }

            if (conn.responseCode in 200..201) {
                val respStr = BufferedReader(InputStreamReader(conn.inputStream)).use { it.readText() }
                val respObj = JSONObject(respStr)
                val dataObj = respObj.optJSONObject("data") ?: respObj
                val newTok = dataObj.optString("accessToken", dataObj.optString("token", ""))
                if (newTok.isNotEmpty()) {
                    getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        .edit()
                        .putString(KEY_TOKEN, newTok)
                        .apply()
                    flutterPrefs.edit().putString("flutter.laju_auth_token", newTok).apply()
                    return newTok
                }
            }
            null
        } catch (_: Exception) {
            null
        } finally {
            try { conn?.disconnect() } catch (_: Exception) {}
        }
    }

    private fun ensureNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

            // Calls Channel
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            val callAttrs = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .build()

            val callChannel = NotificationChannel(
                CHANNEL_CALLS,
                "Panggilan Masuk LAJU",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi panggilan suara dan video masuk"
                setSound(ringtoneUri, callAttrs)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 800, 400, 800, 400, 800)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(callChannel)

            // Messages Channel
            val msgUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val msgAttrs = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_INSTANT)
                .build()

            val msgChannel = NotificationChannel(
                CHANNEL_MESSAGES,
                "Pesan Masuk LAJU",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi pesan baru terenkripsi"
                setSound(msgUri, msgAttrs)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 150, 250)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(msgChannel)
        }
    }

    private fun startPushStream(baseUrl: String, token: String) {
        val effectiveToken = resolveLatestToken(token)
        val now = System.currentTimeMillis()
        val isStreamHealthy = isRunning &&
            streamThread?.isAlive == true &&
            (now - lastStreamActivityMs) < 75_000L &&
            effectiveToken == currentToken &&
            baseUrl == currentBaseUrl

        if (isStreamHealthy) return

        stopStream()
        isRunning = true
        currentToken = effectiveToken
        currentBaseUrl = baseUrl
        lastStreamActivityMs = now

        streamThread = thread(start = true, isDaemon = true) {
            var retryDelay = 3000L

            while (isRunning) {
                var conn: HttpURLConnection? = null
                var reader: BufferedReader? = null

                try {
                    acquireStreamWakeLock(12000L)
                    currentToken = resolveLatestToken(currentToken)

                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val sinceTs = prefs.getLong(KEY_LAST_EVENT_TS, System.currentTimeMillis() - 15 * 60 * 1000L)

                    val cleanBase = if (baseUrl.endsWith("/")) baseUrl.substring(0, baseUrl.length - 1) else baseUrl
                    val rawBase = if (cleanBase.endsWith("/api/v1")) cleanBase.substring(0, cleanBase.length - 7) else cleanBase
                    val streamUrl = "$rawBase/devices/push-stream?since=$sinceTs"
                    val url = URL(streamUrl)

                    // Server sends heartbeat every 25s; 65s read timeout detects dead/half-open NAT sockets fast
                    conn = (url.openConnection() as HttpURLConnection).apply {
                        requestMethod = "GET"
                        setRequestProperty("Authorization", "Bearer $currentToken")
                        setRequestProperty("Accept", "text/event-stream")
                        setRequestProperty("Cache-Control", "no-cache")
                        connectTimeout = 15000
                        readTimeout = 65000
                        doInput = true
                    }
                    activeConnection = conn

                    val code = conn.responseCode
                    if (code == 200) {
                        retryDelay = 3000L // Reset backoff
                        lastStreamActivityMs = System.currentTimeMillis()
                        reader = BufferedReader(InputStreamReader(conn.inputStream))

                        var line: String? = null
                        // Blocking readLine on kernel socket wait: 0.0% CPU utilization
                        while (isRunning && reader.readLine().also { line = it } != null) {
                            lastStreamActivityMs = System.currentTimeMillis()
                            val l = line?.trim() ?: continue
                            if (l.startsWith("data:")) {
                                acquireStreamWakeLock(10000L)
                                val dataStr = l.substring(5).trim()
                                handlePushEvent(dataStr)
                            }
                        }
                    } else if (code == 401) {
                        // Attempt background token refresh before giving up
                        val refreshed = tryRefreshTokenInBackground(rawBase, currentToken)
                        if (!refreshed.isNullOrEmpty()) {
                            currentToken = refreshed
                            retryDelay = 1000L
                        } else {
                            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            val stillAuth = flutterPrefs.getBoolean("flutter.laju_is_authenticated", true)
                            if (!stillAuth) {
                                isRunning = false
                                break
                            }
                            retryDelay = 30000L
                        }
                    }
                } catch (_: Exception) {
                    // Normal network timeout / transition handover
                } finally {
                    try { reader?.close() } catch (_: Exception) {}
                    try { conn?.disconnect() } catch (_: Exception) {}
                    activeConnection = null
                    releaseStreamWakeLock()
                }

                if (isRunning) {
                    try {
                        Thread.sleep(retryDelay)
                        retryDelay = (retryDelay * 1.5).toLong().coerceAtMost(30000L)
                    } catch (_: Exception) {}
                }
            }
        }
    }

    private fun stopStream() {
        isRunning = false
        interruptCurrentConnection()
        try {
            streamThread?.interrupt()
        } catch (_: Exception) {}
        streamThread = null
    }

    private fun updateLastEventTimestamp(eventTs: Long = 0L) {
        try {
            val now = System.currentTimeMillis()
            val ts = if (eventTs > 0L && eventTs <= now + 60000L) eventTs else now
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val prev = prefs.getLong(KEY_LAST_EVENT_TS, 0L)
            if (ts >= prev) {
                prefs.edit().putLong(KEY_LAST_EVENT_TS, ts).apply()
            }
        } catch (_: Exception) {}
    }

    private fun handlePushEvent(jsonStr: String) {
        try {
            val obj = JSONObject(jsonStr)
            val type = obj.optString("type", "")
            val eventTs = obj.optLong("timestamp", System.currentTimeMillis())

            if (type != "CONNECTED") {
                updateLastEventTimestamp(eventTs)
            }

            when (type) {
                "CALL_INCOMING" -> {
                    val callId = obj.optString("callId", "")
                    val callerName = obj.optString("initiatorName", "Kontak")
                    val isVideo = obj.optBoolean("isVideo", false)

                    if (callId.isNotEmpty() && !markEventNotified("call_in_$callId")) {
                        return
                    }

                    // Acquire WakeLock with a STRICT 10-second hard safety timeout to turn on the screen
                    try {
                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        releaseCallWakeLock()
                        callWakeLock = pm?.newWakeLock(
                            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                            "laju:incoming_call_wake"
                        )?.apply {
                            setReferenceCounted(false)
                            acquire(10000L)
                        }
                    } catch (_: Exception) {}

                    if (!MainActivity.isAppInForeground) {
                        showIncomingCallNotification(callId, callerName, isVideo)
                    }
                }
                "CALL_MISSED" -> {
                    val callId = obj.optString("callId", "")
                    val convId = obj.optString("conversationId", callId)
                    val callerName = obj.optString("initiatorName", "Kontak")
                    val isVideo = obj.optBoolean("isVideo", false)

                    releaseCallWakeLock()
                    try {
                        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                        nm.cancel(NOTIFICATION_ID_CALL)
                    } catch (_: Exception) {}

                    if (callId.isNotEmpty() && !markEventNotified("call_missed_$callId")) {
                        return
                    }

                    if (!MainActivity.isAppInForeground) {
                        val preview = if (isVideo) "📹 Panggilan video tak terjawab" else "📞 Panggilan suara tak terjawab"
                        showMessageNotification(convId.ifEmpty { "missed_$callId" }, callerName, preview)
                    }
                }
                "NEW_MESSAGE" -> {
                    val isSilent = obj.optBoolean("isSilent", false)
                    if (isSilent) return

                    val msgObj = obj.optJSONObject("message")
                    val senderUserId = msgObj?.optString("senderUserId", "") ?: ""
                    val msgId = obj.optString("messageId", msgObj?.optString("id", "") ?: "")

                    val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val currentUserId = flutterPrefs.getString("flutter.laju_user_id", "") 
                        ?: getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).getString("current_user_id", "") ?: ""

                    if (currentUserId.isNotEmpty() && senderUserId == currentUserId) {
                        // Silent sync: sender must NOT get a notification banner for their own outgoing messages!
                        return
                    }

                    if (msgId.isNotEmpty() && !markEventNotified("msg_$msgId")) {
                        return
                    }

                    val convId = obj.optString("conversationId", "")
                    val senderName = obj.optString("senderName", "Pesan Baru")
                    val preview = obj.optString("preview", "Pesan baru terenkripsi")
                    showMessageNotification(convId, senderName, preview)
                    MainActivity.instance?.dispatchPushMessage(convId, senderName, preview)
                }
                "MESSAGE_SYNC" -> {
                    val convId = obj.optString("conversationId", "")
                    val senderName = obj.optString("senderName", "")
                    val preview = obj.optString("preview", "")
                    MainActivity.instance?.dispatchPushMessage(convId, senderName, preview)
                }
                "CALL_ENDED", "CALL_REJECTED" -> {
                    releaseCallWakeLock()
                    val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                    nm.cancel(NOTIFICATION_ID_CALL)
                    MainActivity.instance?.disableShowWhenLocked()
                }
                "SYSTEM_ANNOUNCEMENT" -> {
                    val title = obj.optString("title", "Pengumuman Resmi")
                    val content = obj.optString("content", "")
                    showAnnouncementNotification(title, content)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun releaseCallWakeLock() {
        try {
            if (callWakeLock?.isHeld == true) {
                callWakeLock?.release()
            }
        } catch (_: Exception) {}
        callWakeLock = null
    }

    private fun showIncomingCallNotification(callId: String, callerName: String, isVideo: Boolean) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        // Fullscreen & Content Intent (Opens Incoming Call UI without auto-answering)
        val incomingCallIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("laju_type", "call")
            putExtra("laju_id", callId)
            putExtra("laju_caller_name", callerName)
            putExtra("laju_is_video", isVideo)
            putExtra("laju_action", "incoming_call")
        }
        val incomingCallPendingIntent = PendingIntent.getActivity(
            this,
            100,
            incomingCallIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Answer intent (ONLY triggered when user explicitly taps "Jawab" button on notification)
        val answerIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("laju_type", "call")
            putExtra("laju_id", callId)
            putExtra("laju_caller_name", callerName)
            putExtra("laju_is_video", isVideo)
            putExtra("laju_action", "answer")
        }
        val answerPendingIntent = PendingIntent.getActivity(
            this,
            101,
            answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Decline intent (Triggered when user taps "Tolak" button on notification)
        val declineIntent = Intent(this, LajuPushService::class.java).apply {
            action = ACTION_DECLINE
            putExtra("call_id", callId)
            putExtra("caller_name", callerName)
        }
        val declinePendingIntent = PendingIntent.getService(
            this,
            102,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = callerName
        val content = if (isVideo) "Panggilan video masuk..." else "Panggilan suara masuk..."

        val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

        val builder = NotificationCompat.Builder(this, CHANNEL_CALLS)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(content)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setSound(ringtoneUri)
            .setVibrate(longArrayOf(0, 800, 400, 800, 400, 800))
            .setFullScreenIntent(incomingCallPendingIntent, true)
            .setContentIntent(incomingCallPendingIntent)
            .setAutoCancel(true)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_call, "Jawab", answerPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Tolak", declinePendingIntent)

        nm.notify(NOTIFICATION_ID_CALL, builder.build())
    }

    private fun showMessageNotification(conversationId: String, senderName: String, preview: String) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("laju_type", "chat")
            putExtra("laju_id", conversationId)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            conversationId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val msgUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        val builder = NotificationCompat.Builder(this, CHANNEL_MESSAGES)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(senderName)
            .setContentText(preview)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setSound(msgUri)
            .setVibrate(longArrayOf(0, 250, 150, 250))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        nm.notify(conversationId.hashCode(), builder.build())
    }

    private fun showAnnouncementNotification(title: String, content: String) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("laju_type", "announcement")
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        val builder = NotificationCompat.Builder(this, CHANNEL_MESSAGES)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("📢 $title")
            .setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setSound(soundUri)
            .setVibrate(longArrayOf(0, 300, 200, 300))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        val notifId = (System.currentTimeMillis() % 100000).toInt() + 1000
        nm.notify(notifId, builder.build())
    }

    private fun declineCallInBackground(callId: String) {
        thread {
            try {
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val baseUrl = prefs.getString(KEY_BASE_URL, "") ?: ""
                val token = prefs.getString(KEY_TOKEN, "") ?: ""
                if (baseUrl.isNotEmpty() && token.isNotEmpty()) {
                    val cleanBase = if (baseUrl.endsWith("/")) baseUrl.substring(0, baseUrl.length - 1) else baseUrl
                    val url = URL("$cleanBase/calls/$callId/reject")
                    val conn = (url.openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        setRequestProperty("Authorization", "Bearer $token")
                        connectTimeout = 5000
                        readTimeout = 5000
                    }
                    conn.responseCode
                    conn.disconnect()
                }
            } catch (_: Exception) {}
        }
    }

    private fun scheduleImmediateRestart() {
        try {
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isAuthenticated = flutterPrefs.getBoolean("flutter.laju_is_authenticated", true)
            if (!isAuthenticated) return

            scheduleWatchdog(applicationContext)

            val restartIntent = Intent(applicationContext, LajuPushReceiver::class.java).apply {
                action = ACTION_RESTART
            }
            val restartPendingIntent = PendingIntent.getBroadcast(
                applicationContext,
                1001,
                restartIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as? android.app.AlarmManager
            val triggerAt = System.currentTimeMillis() + 2000L
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    alarmManager?.setExactAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, triggerAt, restartPendingIntent)
                } catch (_: SecurityException) {
                    alarmManager?.setAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, triggerAt, restartPendingIntent)
                }
            } else {
                alarmManager?.set(android.app.AlarmManager.RTC_WAKEUP, triggerAt, restartPendingIntent)
            }
        } catch (_: Exception) {}
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        scheduleImmediateRestart()
    }

    override fun onDestroy() {
        releaseCallWakeLock()
        releaseStreamWakeLock()
        unregisterNetworkCallback()
        stopStream()
        scheduleImmediateRestart()
        super.onDestroy()
    }
}
