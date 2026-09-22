package com.laju.laju_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
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

        const val PREFS_NAME = "laju_push_prefs"
        const val KEY_BASE_URL = "base_url"
        const val KEY_TOKEN = "auth_token"

        fun startService(context: Context, baseUrl: String, token: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(KEY_BASE_URL, baseUrl)
                .putString(KEY_TOKEN, token)
                .apply()

            val intent = Intent(context, LajuPushService::class.java).apply {
                action = ACTION_START
                putExtra(KEY_BASE_URL, baseUrl)
                putExtra(KEY_TOKEN, token)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, LajuPushService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.stopService(intent)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    @Volatile private var isRunning = false
    private var streamThread: Thread? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action

        if (action == ACTION_DECLINE) {
            val callId = intent.getStringExtra("call_id")
            if (callId != null) {
                declineCallInBackground(callId)
            }
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NOTIFICATION_ID_CALL)
            return START_NOT_STICKY
        }

        if (action == ACTION_STOP) {
            stopStream()
            stopSelf()
            return START_NOT_STICKY
        }

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val baseUrl = intent?.getStringExtra(KEY_BASE_URL) ?: prefs.getString(KEY_BASE_URL, "") ?: ""
        val token = intent?.getStringExtra(KEY_TOKEN) ?: prefs.getString(KEY_TOKEN, "") ?: ""

        if (baseUrl.isNotEmpty() && token.isNotEmpty()) {
            startForegroundSyncNotification()
            startPushStream(baseUrl, token)
        }

        return START_STICKY
    }

    private fun startForegroundSyncNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            val syncChannel = NotificationChannel(
                CHANNEL_BACKGROUND,
                "Laju Background Sync",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Sinkronisasi pesan dan panggilan terenkripsi"
                setShowBadge(false)
            }
            nm.createNotificationChannel(syncChannel)
        }

        val notif = NotificationCompat.Builder(this, CHANNEL_BACKGROUND)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Laju Secure Messenger")
            .setContentText("Layanan terenkripsi aktif di latar belakang")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .build()

        try {
            startForeground(NOTIFICATION_ID_SYNC, notif)
        } catch (e: Exception) {
            e.printStackTrace()
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
        if (isRunning) return
        isRunning = true

        streamThread = thread(start = true, isDaemon = true) {
            var retryDelay = 3000L

            while (isRunning) {
                var conn: HttpURLConnection? = null
                var reader: BufferedReader? = null

                try {
                    val cleanBase = if (baseUrl.endsWith("/")) baseUrl.substring(0, baseUrl.length - 1) else baseUrl
                    val streamUrl = "$cleanBase/api/v1/devices/push-stream"
                    val url = URL(streamUrl)

                    conn = (url.openConnection() as HttpURLConnection).apply {
                        requestMethod = "GET"
                        setRequestProperty("Authorization", "Bearer $token")
                        setRequestProperty("Accept", "text/event-stream")
                        connectTimeout = 15000
                        readTimeout = 60000
                        doInput = true
                    }

                    val code = conn.responseCode
                    if (code == 200) {
                        retryDelay = 3000L // Reset backoff
                        reader = BufferedReader(InputStreamReader(conn.inputStream))

                        var line: String?
                        while (isRunning && reader.readLine().also { line = it } != null) {
                            val l = line?.trim() ?: continue
                            if (l.startsWith("data:")) {
                                val dataStr = l.substring(5).trim()
                                handlePushEvent(dataStr)
                            }
                        }
                    } else if (code == 401) {
                        // Unauthorized - Stop retrying until re-authenticated
                        isRunning = false
                        break
                    }
                } catch (e: Exception) {
                    // Connection lost or network transition
                } finally {
                    try { reader?.close() } catch (_: Exception) {}
                    try { conn?.disconnect() } catch (_: Exception) {}
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
        try {
            streamThread?.interrupt()
        } catch (_: Exception) {}
        streamThread = null
    }

    private fun handlePushEvent(jsonStr: String) {
        try {
            val obj = JSONObject(jsonStr)
            val type = obj.optString("type", "")

            when (type) {
                "CALL_INCOMING" -> {
                    val callId = obj.optString("callId", "")
                    val callerName = obj.optString("initiatorName", "Kontak")
                    val isVideo = obj.optBoolean("isVideo", false)
                    showIncomingCallNotification(callId, callerName, isVideo)
                }
                "NEW_MESSAGE" -> {
                    val convId = obj.optString("conversationId", "")
                    val senderName = obj.optString("senderName", "Pesan Baru")
                    val preview = obj.optString("preview", "Pesan baru terenkripsi")
                    showMessageNotification(convId, senderName, preview)
                }
                "CALL_ENDED", "CALL_REJECTED" -> {
                    val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                    nm.cancel(NOTIFICATION_ID_CALL)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun showIncomingCallNotification(callId: String, callerName: String, isVideo: Boolean) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        // Answer intent
        val answerIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("laju_type", "call")
            putExtra("laju_id", callId)
            putExtra("laju_is_video", isVideo)
            putExtra("laju_action", "answer")
        }
        val answerPendingIntent = PendingIntent.getActivity(
            this,
            101,
            answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Decline intent
        val declineIntent = Intent(this, LajuPushService::class.java).apply {
            action = ACTION_DECLINE
            putExtra("call_id", callId)
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
            .setFullScreenIntent(answerPendingIntent, true)
            .setContentIntent(answerPendingIntent)
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

    private fun declineCallInBackground(callId: String) {
        thread {
            try {
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val baseUrl = prefs.getString(KEY_BASE_URL, "") ?: ""
                val token = prefs.getString(KEY_TOKEN, "") ?: ""
                if (baseUrl.isNotEmpty() && token.isNotEmpty()) {
                    val cleanBase = if (baseUrl.endsWith("/")) baseUrl.substring(0, baseUrl.length - 1) else baseUrl
                    val url = URL("$cleanBase/api/v1/calls/$callId/reject")
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

    override fun onDestroy() {
        stopStream()
        super.onDestroy()
    }
}
