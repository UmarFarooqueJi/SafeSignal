/*
 * SafeSignal Mobile Security Suite
 * Module: Real-time SMS Smishing & OTP Theft Detection Receiver
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
 * Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
 *
 * Proprietary BroadcastReceiver: India-specific SMS scam pattern detection,
 * TRAI DLT header analysis, OTP theft, APK dropper detection, digital arrest.
 */
package com.safesignal.safesignal

import android.graphics.PixelFormat
import android.os.Looper
import android.os.Handler
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import android.graphics.Color
import android.provider.Settings


import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.provider.Telephony
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.util.Locale
import java.util.regex.Pattern

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private var overlayView: View? = null
        private var windowManager: WindowManager? = null
        private const val CHANNEL_ID = "safesignal_sms_alerts"
        private const val NOTIFICATION_ID_BASE = 2002
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREFS_KEY = "flutter.sms_inbox"
        private const val MAX_STORED = 200
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (msg in messages) {
                val body = msg.messageBody ?: continue
                val sender = msg.originatingAddress ?: "Unknown"
                val analysis = analyzeSms(body, sender)
                
                // ── Save to SharedPreferences for Flutter to read ──────────
                saveSmsToInbox(context, sender, body, analysis)
                
                // ── Show notification & overlay only on suspicious messages ───
                if (analysis.isSuspicious) {
                    showScamNotification(context, sender, body, analysis)
                    showPremiumOverlay(context, sender, analysis)
                }
                // Harmless messages do not spam the user with notifications
            }
        } catch (e: Exception) {
            // fail silently
        }
    }

    // ─── Save SMS to Flutter SharedPreferences ────────────────────────────────
    private fun saveSmsToInbox(
        context: Context, sender: String, body: String, analysis: SmsAnalysis
    ) {
        try {
            val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existing = prefs.getString(PREFS_KEY, "[]")
            val arr = JSONArray(existing)

            val sanitizedBody = sanitizeSmsBody(body)
            val record = JSONObject().apply {
                put("sender", sender)
                put("body", sanitizedBody)
                put("verdict", analysis.verdict)
                put("confidence", analysis.confidence)
                put("reason", analysis.reason)
                put("receivedAt", Instant.now().toString())
            }

            // Insert at beginning (newest first)
            val newArr = JSONArray()
            newArr.put(record)
            for (i in 0 until minOf(arr.length(), MAX_STORED - 1)) {
                newArr.put(arr.get(i))
            }

            prefs.edit().putString(PREFS_KEY, newArr.toString()).apply()
        } catch (e: Exception) {
            // fail silently — never crash on SMS storage failure
        }
    }

    private fun sanitizeSmsBody(body: String): String {
        // Redact OTP / 2FA numeric verification codes to prevent credential leakage in stored inbox logs
        val otpPattern = Regex("""(?i)\b(?:otp|code|verification|passcode|one-time|pin|v-code)\b[:\s\-—]+([0-9]{4,8})\b""")
        var sanitized = otpPattern.replace(body) { matchResult ->
            val full = matchResult.value
            val code = matchResult.groupValues[1]
            full.replace(code, "[REDACTED-OTP]")
        }
        if (body.contains("otp", ignoreCase = true) || body.contains("verification code", ignoreCase = true)) {
            val standaloneDigits = Regex("""\b\d{4,8}\b""")
            sanitized = standaloneDigits.replace(sanitized, "[REDACTED-OTP]")
        }
        return sanitized
    }

    private fun showSafeNotification(
        context: Context, sender: String, body: String, analysis: SmsAnalysis
    ) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SafeSignal SMS Scam Shield",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Real-time SMS scam detection alerts"
            }
            nm.createNotificationChannel(channel)
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.presence_online)
            .setContentTitle("SMS Audit — $sender")
            .setContentText("No known scam indicators detected.")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle("SafeSignal: No Scam Indicators Detected")
                    .bigText(
                        "From: $sender\n\n" +
                        "Message: \"${body.take(200)}${if (body.length > 200) "..." else ""}\"\n\n" +
                        "Verdict: No suspicious links or known scam patterns detected in local analysis."
                    )
                    .setSummaryText("SafeSignal Shield")
            )
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setColor(android.graphics.Color.BLUE)
            .build()

        nm.notify(NOTIFICATION_ID_BASE + sender.hashCode(), notification)
    }

    // ─── Analysis Result ─────────────────────────────────────────────────────
    private data class SmsAnalysis(
        val isSuspicious: Boolean,
        val verdict: String,        // "SCAM" | "CAUTION" | "SAFE"
        val confidence: Int,        // 0-100
        val reason: String,
        val category: String        // human-readable category
    )

    // ─── Core Analysis Engine ─────────────────────────────────────────────────
    private fun analyzeSms(body: String, sender: String): SmsAnalysis {
        val lower = body.lowercase(Locale.getDefault())
        var score = 0
        val detectedReasons = mutableListOf<String>()

        // ── TIER 1: High-confidence fraud patterns (each +35 score) ──────────
        val tier1 = mapOf(
            "digital arrest" to "Digital Arrest scam",
            "arrested" to "Arrest threat",
            "cbi officer" to "Fake CBI officer",
            "narcotics" to "Fake narcotics case",
            "police custody" to "Fake police custody threat",
            "court warrant" to "Fake court warrant",
            "money laundering" to "Money laundering scam",
            "cyber crime notice" to "Fake cybercrime notice",
            "ed notice" to "Fake ED notice",
            "income tax notice" to "Fake IT notice",
            "kbc lottery" to "KBC lottery scam",
            "won lucky draw" to "Lucky draw fraud",
            "won prize" to "Prize scam",
            "claim your reward" to "Reward scam",
            "electricity cut" to "Electricity bill scam",
            "bijli katne" to "Bijli katne scam",
            "aadhaar blocked" to "Aadhaar block scam",
            "sim card blocked" to "SIM block scam",
            "kyc expire" to "KYC expiry scam",
            "update pan card" to "PAN card scam",
            "account suspend" to "Account suspension scam",
            "part time job" to "Fake job fraud",
            "telegram like job" to "Telegram like-job scam",
            "earn from home" to "Work-from-home fraud",
            "daily salary" to "Daily salary scam",
            "transfer success rs" to "Fake transaction alert",
            "unknown transaction" to "Fake transaction alert",
            "otp share" to "OTP phishing",
            "share otp" to "OTP phishing"
        )

        for ((keyword, reason) in tier1) {
            if (lower.contains(keyword)) {
                score += 35
                detectedReasons.add(reason)
            }
        }

        // ── TIER 2: Medium-confidence indicators (each +20 score) ─────────
        val tier2 = listOf(
            "click here", "tap here", "click link", "click now",
            "verify account", "verify your", "update account",
            "account blocked", "card blocked", "bank account block",
            "crore", "lakh prize", "won rs", "gift rs",
            "immediate action", "last chance", "expires today",
            "debit card", "credit card fraud", "upi fraud",
            "refund amount", "cashback credited"
        )
        for (kw in tier2) {
            if (lower.contains(kw)) {
                score += 20
                detectedReasons.add("Urgency/pressure tactic: '$kw'")
                break
            }
        }

        // ── TIER 3: Suspicious links + urgency combo (+30 score) ──────────
        val hasLink = lower.contains("http") || lower.contains("www.")
            || lower.contains(".apk") || lower.contains("bit.ly")
            || lower.contains("tinyurl") || lower.contains(".ru/")
            || lower.contains(".xyz/") || lower.contains(".tk/")
        val urgentWords = listOf("urgent", "immediately", "block", "verify", "claim", "last date", "expire", "today only")
        val hasUrgency = urgentWords.any { lower.contains(it) }

        if (hasLink && hasUrgency) {
            score += 30
            detectedReasons.add("Suspicious link with urgent call-to-action")
        } else if (hasLink && lower.contains(".apk")) {
            score += 40
            detectedReasons.add("APK download link — highly dangerous!")
        }

        // ── TIER 4: Sender number analysis & TRAI DLT Header ─────────────
        val cleanSender = sender.replace(Regex("[\\s\\-()]+"), "")
        val traiHeaderPattern = Regex("^[A-Za-z]{2}-?[A-Za-z0-9]{6}$")
        val isTraiSender = traiHeaderPattern.matches(cleanSender)
        val indianMobilePattern = Regex("^(\\+91|91)?[6-9]\\d{9}$")
        val claimsBank = Regex("(?i)(sbi|hdfc|icici|axis|kotak|pnb|bob|bank|paytm|phonepe|netbanking)").containsMatchIn(lower)

        if (cleanSender.startsWith("+") && !cleanSender.startsWith("+91")) {
            score += 25
            detectedReasons.add("International sender ($cleanSender)")
        } else if (indianMobilePattern.matches(cleanSender) && claimsBank) {
            score += 50
            detectedReasons.add("Bank notification sent from personal 10-digit mobile number")
        }

        // ── SAFE INDICATORS (Authentic Banking / Transaction Notifications) ───
        val hasMaliciousLink = lower.contains(".apk") || lower.contains("bit.ly") ||
                lower.contains("tinyurl") || lower.contains(".xyz") || lower.contains(".tk")
        val hasOtpTheft = lower.contains("share otp") || lower.contains("otp share") || lower.contains("send otp")

        val bankTxIndicators = listOf(
            "debited by rs", "debited for rs", "debited from", "credited to", "credited with",
            "your transaction of", "upi ref no", "upi/cr/", "upi/dr/", "neft transfer",
            "imps transfer", "avl bal", "available balance", "a/c ending", "acct ending",
            "do not share otp with anyone", "never share otp", "otp is"
        )
        val isBankTx = bankTxIndicators.any { lower.contains(it) }

        if (isTraiSender && isBankTx && !hasMaliciousLink && !hasOtpTheft) {
            // Official TRAI commercial/banking message with verified transactional structure
            score = 0
            detectedReasons.clear()
        } else if (isBankTx && !hasMaliciousLink && !hasOtpTheft) {
            score = (score * 0.25).toInt()
        }

        // ── Verdict ───────────────────────────────────────────────────────
        val reasonText = detectedReasons.take(2).joinToString("; ")
        return when {
            score >= 60 -> SmsAnalysis(
                true, "SCAM", score.coerceAtMost(99),
                if (reasonText.isNotEmpty()) reasonText else "Multiple scam indicators detected",
                "Scam SMS Detected"
            )
            score in 35..59 -> SmsAnalysis(
                true, "CAUTION", score,
                detectedReasons.firstOrNull() ?: "Suspicious content found",
                "Suspicious SMS"
            )
            else -> SmsAnalysis(
                false, "SAFE", maxOf(5, 100 - score),
                if (isBankTx) "Verified banking transactional alert" else "No scam patterns found",
                "Safe Message"
            )
        }
    }

    // ─── Notification Builder ─────────────────────────────────────────────────
    private fun showScamNotification(
        context: Context, sender: String, body: String, analysis: SmsAnalysis
    ) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SafeSignal SMS Scam Shield",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Real-time SMS scam detection alerts"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 350, 150, 350)
                enableLights(true)
                lightColor = android.graphics.Color.RED
            }
            nm.createNotificationChannel(channel)
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val emoji = when (analysis.verdict) {
            "SCAM" -> "\uD83D\uDD34"
            "CAUTION" -> "⚠\uFE0F"
            else -> "\uD83D\uDD35"
        }

        val confidenceStr = "${analysis.confidence}% confidence"
        val safetyTip = when (analysis.verdict) {
            "SCAM" -> "Kisi bhi link pe click mat karein aur na hi OTP/bank details share karein. 1930 pe call karein."
            else -> "Is message ke sath sawdhan rahein. Koi bhi link ya attachment pe click karne se pehle verify karein."
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setContentTitle("$emoji ${analysis.category} — $sender")
            .setContentText(analysis.reason)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle("$emoji SafeSignal: ${analysis.verdict} SMS ($confidenceStr)")
                    .bigText(
                        "From: $sender\n\n" +
                        "Message: \"${body.take(200)}${if (body.length > 200) "..." else ""}\"\n\n" +
                        "⚠\uFE0F Reason: ${analysis.reason}\n\n" +
                        "\uD83D\uDEA8 $safetyTip"
                    )
                    .setSummaryText("SafeSignal Scam Shield")
            )
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setVibrate(longArrayOf(0, 350, 150, 350))
            .setColor(if (analysis.verdict == "SCAM") android.graphics.Color.RED else android.graphics.Color.parseColor("#FF6F00"))
            .build()

        nm.notify(NOTIFICATION_ID_BASE + sender.hashCode(), notification)
    }

    private fun showPremiumOverlay(context: Context, sender: String, analysis: SmsAnalysis) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
            return
        }

        Handler(Looper.getMainLooper()).post {
            try {
                dismissOverlay()

                val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                windowManager = wm

                // Base Container
                val container = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding(48, 48, 48, 48)
                    
                    val bgDrawable = android.graphics.drawable.GradientDrawable().apply {
                        shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                        cornerRadius = 48f
                        colors = intArrayOf(Color.parseColor("#1E2128"), Color.parseColor("#121418"))
                        setStroke(2, Color.parseColor("#44FFFFFF"))
                    }
                    background = bgDrawable
                    elevation = 30f
                }

                // Brand header
                val brandRow = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                }
                val brandIcon = TextView(context).apply {
                    text = "🛡️"
                    textSize = 18f
                    setPadding(0, 0, 16, 0)
                }
                val brandText = TextView(context).apply {
                    text = "SafeSignal AI Shield"
                    setTextColor(Color.parseColor("#4CAF50"))
                    textSize = 15f
                    setTypeface(null, android.graphics.Typeface.BOLD)
                }
                brandRow.addView(brandIcon)
                brandRow.addView(brandText)

                val divider = View(context).apply {
                    val params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 2)
                    params.setMargins(0, 24, 0, 24)
                    layoutParams = params
                    setBackgroundColor(Color.parseColor("#2A2E35"))
                }

                val incomingLabel = TextView(context).apply {
                    text = "DANGEROUS SMS DETECTED"
                    setTextColor(Color.parseColor("#FF5252"))
                    textSize = 11f
                    setTypeface(null, android.graphics.Typeface.BOLD)
                    letterSpacing = 0.05f
                }

                val senderText = TextView(context).apply {
                    text = sender
                    setTextColor(Color.WHITE)
                    textSize = 24f
                    setTypeface(null, android.graphics.Typeface.BOLD)
                    setPadding(0, 8, 0, 0)
                }

                val badgeContainer = LinearLayout(context).apply {
                    setPadding(0, 32, 0, 16)
                    gravity = Gravity.LEFT
                }
                
                val bgColor = if(analysis.verdict == "SCAM") Color.parseColor("#C62828") else Color.parseColor("#E65100")
                val emoji = if(analysis.verdict == "SCAM") "🔴" else "⚠️"
                
                val verdictBadge = TextView(context).apply {
                    text = "$emoji  ${analysis.verdict} (${analysis.confidence}%)"
                    setTextColor(Color.WHITE)
                    textSize = 15f
                    setTypeface(null, android.graphics.Typeface.BOLD)
                    setPadding(40, 20, 40, 20)
                    
                    val badgeBg = android.graphics.drawable.GradientDrawable().apply {
                        shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                        cornerRadius = 100f
                        setColor(bgColor)
                        setStroke(2, Color.parseColor("#50FFFFFF"))
                    }
                    background = badgeBg
                }
                badgeContainer.addView(verdictBadge)

                val reasonText = TextView(context).apply {
                    text = analysis.reason
                    setTextColor(Color.parseColor("#CCD6F6"))
                    textSize = 14f
                    setPadding(0, 8, 0, 0)
                    setLineSpacing(4f, 1f)
                }

                container.addView(brandRow)
                container.addView(divider)
                container.addView(incomingLabel)
                container.addView(senderText)
                container.addView(badgeContainer)
                container.addView(reasonText)

                val wrapper = LinearLayout(context).apply {
                    setPadding(40, 80, 40, 40)
                    addView(container, LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ))
                }

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    else
                        @Suppress("DEPRECATION")
                        WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.TOP
                    y = 50
                }

                wm.addView(wrapper, params)
                overlayView = wrapper

                Handler(Looper.getMainLooper()).postDelayed({ dismissOverlay() }, 15000)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun dismissOverlay() {
        try {
            overlayView?.let { view ->
                windowManager?.removeView(view)
                overlayView = null
            }
        } catch (e: Exception) {}
    }
}
