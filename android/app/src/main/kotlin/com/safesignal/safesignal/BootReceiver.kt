/*
 * SafeSignal Mobile Security Suite
 * Module: Boot Persistence Receiver
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
 * Copyright (c) 2026 SafeSignal Technologies. All rights reserved.
 *
 * Restores SafeSignal live protection services after device reboot.
 */
package com.safesignal.safesignal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Receives BOOT_COMPLETED broadcast to restart background protection services
 * after the device reboots.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Note: SmsReceiver and EmailNotificationService are statically registered
            // in AndroidManifest.xml and will wake up on their respective events.
            
            // If we had a foreground service running continuously, we would start it here.
            // For example:
            /*
            val serviceIntent = Intent(context, PersistentProtectionService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            */
            
            // Currently, the broadcast receivers are sufficient since they are
            // triggered by system events (SMS_RECEIVED, PHONE_STATE, Notification).
        }
    }
}
