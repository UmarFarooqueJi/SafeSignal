/*
 * SafeSignal Mobile Security Suite
 * Module: Native Call Screening & Threat Interception Service
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
 * Copyright (c) 2026 SafeSignal Technologies. All rights reserved.
 *
 * Implements Android CallScreeningService (API 29+) to intercept incoming calls,
 * analyze phone metadata against TRAI 140/160 series telemarketing ranges,
 * international VoIP spoof prefixes (+92, +84, +234, etc.), and user blacklists.
 */
package com.safesignal.safesignal

import android.content.Context
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import androidx.annotation.RequiresApi
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@RequiresApi(Build.VERSION_CODES.Q)
class SafeSignalCallScreeningService : CallScreeningService() {

    override fun onScreenCall(callDetails: Call.Details) {
        val handle = callDetails.handle
        val rawNumber = handle?.schemeSpecificPart ?: ""
        val cleanNumber = rawNumber.replace("[^0-9+]".toRegex(), "")

        val prefs = getSharedPreferences("safesignal_call_shield", Context.MODE_PRIVATE)
        val blockTrai = prefs.getBoolean("block_trai", true)
        val blockInternational = prefs.getBoolean("block_international", true)

        var shouldBlock = false
        var reason = ""

        // 1. Check TRAI 140 and 160 series commercial/telemarketing blocks
        // Indian TRAI allocates 140xxxxxxx and 160xxxxxxx specifically to commercial telemarketers
        val digitsOnly = cleanNumber.replace("[^0-9]".toRegex(), "")
        val last10 = if (digitsOnly.length >= 10) digitsOnly.takeLast(10) else digitsOnly

        if (blockTrai) {
            if (last10.startsWith("140") || last10.startsWith("160")) {
                shouldBlock = true
                reason = "TRAI Telemarketer Prefix (${last10.take(3)} series)"
            }
        }

        // 2. Check international spoofing prefixes (+92, +84, +234, +4470, +93, +212, +252)
        if (!shouldBlock && blockInternational) {
            val highRiskPrefixes = listOf("+92", "+84", "+234", "+4470", "+93", "+212", "+252")
            for (prefix in highRiskPrefixes) {
                if (cleanNumber.startsWith(prefix)) {
                    shouldBlock = true
                    reason = "High-Risk International VoIP Spoof ($prefix)"
                    break
                }
            }
        }

        // 3. User custom blocklist
        if (!shouldBlock) {
            val blacklist = prefs.getStringSet("custom_blacklist", emptySet()) ?: emptySet()
            if (blacklist.contains(cleanNumber) || (last10.isNotEmpty() && blacklist.contains(last10))) {
                shouldBlock = true
                reason = "Custom Blocklist"
            }
        }

        if (shouldBlock) {
            // Log blocked call in persistent history
            logBlockedCall(cleanNumber, reason)

            val response = CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(true)
                .build()

            respondToCall(callDetails, response)
        } else {
            val response = CallResponse.Builder()
                .setDisallowCall(false)
                .setRejectCall(false)
                .setSkipCallLog(false)
                .setSkipNotification(false)
                .build()

            respondToCall(callDetails, response)
        }
    }

    private fun logBlockedCall(number: String, reason: String) {
        try {
            val prefs = getSharedPreferences("safesignal_call_shield", Context.MODE_PRIVATE)
            val existingJson = prefs.getString("blocked_calls_log", "[]") ?: "[]"
            val array = JSONArray(existingJson)

            val item = JSONObject().apply {
                put("number", if (number.isEmpty()) "Private / Unknown" else number)
                put("reason", reason)
                put("timestamp", System.currentTimeMillis())
                put("formattedTime", SimpleDateFormat("dd MMM, hh:mm a", Locale.getDefault()).format(Date()))
            }

            // Keep max 50 entries
            val newArray = JSONArray()
            newArray.put(item)
            for (i in 0 until Math.min(array.length(), 49)) {
                newArray.put(array.get(i))
            }

            prefs.edit().putString("blocked_calls_log", newArray.toString()).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
