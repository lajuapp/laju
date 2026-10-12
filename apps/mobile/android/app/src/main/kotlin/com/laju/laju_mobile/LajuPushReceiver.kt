package com.laju.laju_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class LajuPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action == "com.laju.RESTART_PUSH_SERVICE" ||
            action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            val prefs = context.getSharedPreferences(LajuPushService.PREFS_NAME, Context.MODE_PRIVATE)
            val baseUrl = prefs.getString(LajuPushService.KEY_BASE_URL, "") ?: ""
            val token = prefs.getString(LajuPushService.KEY_TOKEN, "") ?: ""

            if (baseUrl.isNotEmpty() && token.isNotEmpty()) {
                val serviceIntent = Intent(context, LajuPushService::class.java).apply {
                    this.action = LajuPushService.ACTION_START
                    putExtra(LajuPushService.KEY_BASE_URL, baseUrl)
                    putExtra(LajuPushService.KEY_TOKEN, token)
                }
                try {
                    context.startService(serviceIntent)
                } catch (_: Exception) {
                    try {
                        ContextCompat.startForegroundService(context, serviceIntent)
                    } catch (_: Exception) {}
                }
            }
        }
    }
}
