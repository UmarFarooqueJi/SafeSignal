/*
 * SafeSignal Mobile Security Suite
 * Module: Persistent Background Protection Service
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
 * Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
 *
 * START_STICKY foreground service keeping SMS & Call Shield active
 * even when the main app is not in the foreground.
 */
package com.safesignal.safesignal

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class SafeSignalService : Service() {

    companion object {
        private const val CHANNEL_ID = "safesignal_persistent_service"
        private const val NOTIFICATION_ID = 1930
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            val pendingIntent = if (launchIntent != null) {
                PendingIntent.getActivity(
                    this, 0, launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            } else null

            val builder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("🛡️ SafeSignal is Active")
                .setContentText("Live SMS & Call Shield is protecting you.")
                .setSmallIcon(android.R.drawable.ic_secure) // fallback icon
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)

            if (pendingIntent != null) {
                builder.setContentIntent(pendingIntent)
            }

            val notification: Notification = builder.build()

            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Return START_STICKY to ensure the service restarts if killed by the OS
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        // We don't provide binding
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "SafeSignal Live Protection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps SafeSignal active in the background for real-time protection"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }
}
