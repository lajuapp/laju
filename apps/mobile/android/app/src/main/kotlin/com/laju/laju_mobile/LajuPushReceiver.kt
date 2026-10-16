package com.laju.laju_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class LajuPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action == LajuPushService.ACTION_RESTART ||
            action == LajuPushService.ACTION_WATCHDOG ||
            action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == Intent.ACTION_USER_PRESENT ||
            action == Intent.ACTION_POWER_CONNECTED ||
            action == "android.net.conn.CONNECTIVITY_CHANGE"
        ) {
            val prefs = context.getSharedPreferences(LajuPushService.PREFS_NAME, Context.MODE_PRIVATE)
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            val isAuthenticated = flutterPrefs.getBoolean("flutter.laju_is_authenticated", true)
            if (!isAuthenticated) {
                return
            }

            val baseUrl = prefs.getString(LajuPushService.KEY_BASE_URL, "") ?: ""
            val flutterToken = flutterPrefs.getString("flutter.laju_auth_token", "") ?: ""
            val savedToken = prefs.getString(LajuPushService.KEY_TOKEN, "") ?: ""
            val token = if (flutterToken.isNotEmpty()) flutterToken else savedToken

            if (baseUrl.isNotEmpty() && token.isNotEmpty()) {
                LajuPushService.startService(context, baseUrl, token)
            }

            // Always keep the periodic watchdog alive across reboots and intervals
            LajuPushService.scheduleWatchdog(context)
        }
    }
}
