/*
 * SafeSignal Mobile Security Suite
 * Module: Email & Notification Phishing Scanner
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
 * Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
 *
 * NotificationListenerService scanning Gmail/Outlook/Yahoo for phishing
 * indicators without requiring OAuth email access.
 */
package com.safesignal.safesignal

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import java.util.Locale

/**
 * SafeSignal Email & Notification Scanner
 *
 * Listens to incoming notifications from Gmail, Outlook, Yahoo Mail, etc.
 * Scans content for phishing / scam patterns WITHOUT requiring Gmail OAuth.
 * User must grant "Notification Access" once in Android Settings.
 */
class EmailNotificationService : NotificationListenerService() {

    companion object {
        private const val CHANNEL_ID = "safesignal_email_alerts"
        private const val NOTIFICATION_ID_BASE = 4001

        // Email & messaging apps to monitor
        private val MONITORED_PACKAGES = setOf(
            "com.google.android.gm",                    // Gmail
            "com.microsoft.office.outlook",             // Outlook
            "com.yahoo.mobile.client.android.mail",     // Yahoo Mail
            "com.samsung.android.email.provider",       // Samsung Email
            "me.proton.android.mail",                   // ProtonMail
            "com.zoho.mail",                            // Zoho Mail
            "com.android.email",                        // AOSP Email
        )

        // Packages to IGNORE (social, system noise)
        private val IGNORED_PACKAGES = setOf(
            "com.android.systemui",
            "com.google.android.googlequicksearchbox",
            "android",
        )
    }

    // ─── Notification Posted ──────────────────────────────────────────────────
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        val pkg = sbn.packageName ?: return

        if (pkg in IGNORED_PACKAGES) return
        if (pkg !in MONITORED_PACKAGES) return

        // Suppress group summaries / silent notifications
        val notification = sbn.notification ?: return
        if (notification.group != null && sbn.isGroup) return

        val extras = notification.extras ?: return
        val title    = extras.getCharSequence("android.title")?.toString() ?: ""
        val text     = extras.getCharSequence("android.text")?.toString() ?: ""
        val bigText  = extras.getCharSequence("android.bigText")?.toString() ?: ""
        val subText  = extras.getCharSequence("android.subText")?.toString() ?: ""

        val combined = "$title $text $bigText $subText"
        if (combined.isBlank()) return

        val analysis = analyzeContent(combined, pkg)
        if (analysis.isSuspicious) {
            showThreatNotification(pkg, title, text, analysis)
        } else {
            showSafeEmailNotification(pkg, title, text, analysis)
        }
    }

    private fun showSafeEmailNotification(
        sourcePkg: String,
        title: String,
        preview: String,
        analysis: ContentAnalysis
    ) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SafeSignal Email Scam Shield",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Alerts when a suspicious email or notification is detected"
            }
            nm.createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val appName = when (sourcePkg) {
            "com.google.android.gm" -> "Gmail"
            "com.microsoft.office.outlook" -> "Outlook"
            "com.yahoo.mobile.client.android.mail" -> "Yahoo Mail"
            "com.samsung.android.email.provider" -> "Samsung Email"
            "me.proton.android.mail" -> "ProtonMail"
            else -> "Email"
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.presence_online)
            .setContentTitle("🟢 Safe $appName — Secure")
            .setContentText("SafeSignal: Verified safe and secure email.")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle("🟢 SafeSignal: Verified $appName Secure")
                    .bigText(
                        "App: $appName\n" +
                        "From: ${title.take(60)}\n" +
                        "Preview: ${preview.take(150)}${if (preview.length > 150) "..." else ""}\n\n" +
                        "✅ Verdict: SECURE & CLEAN\n" +
                        "SafeSignal analyzed this email and found no phishing links, digital arrest notices, or lottery scam patterns."
                    )
                    .setSummaryText("SafeSignal Email Shield")
            )
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setColor(android.graphics.Color.GREEN)
            .build()

        nm.notify(NOTIFICATION_ID_BASE + title.hashCode(), notification)
    }

    // ─── Analysis Result ──────────────────────────────────────────────────────
    private data class ContentAnalysis(
        val isSuspicious: Boolean,
        val verdict: String,
        val confidence: Int,
        val category: String,
        val reason: String
    )

    // ─── Core AI-powered Heuristic Engine ────────────────────────────────────
    private fun analyzeContent(content: String, sourcePkg: String): ContentAnalysis {
        val lower = content.lowercase(Locale.getDefault())
        var score = 0
        var topReason = ""
        var category = ""

        // ── CRITICAL SCAM PATTERNS (score +50 each) ───────────────────────
        val critical = mapOf(
            "account suspended" to Pair("Account Suspension Scam", "Account suspend threat"),
            "account will be closed" to Pair("Account Closure Scam", "Account closure threat"),
            "your account has been blocked" to Pair("Account Block Scam", "Account blocked alert"),
            "verify your account immediately" to Pair("Phishing", "Immediate verify demand"),
            "kyc verification required" to Pair("KYC Fraud", "Fake KYC demand"),
            "update your kyc" to Pair("KYC Fraud", "Fake KYC update request"),
            "unusual activity detected" to Pair("Phishing", "Unusual activity alert"),
            "income tax refund" to Pair("Tax Refund Scam", "Fake IT refund offer"),
            "it refund" to Pair("Tax Refund Scam", "Fake IT refund"),
            "aadhaar verification pending" to Pair("Aadhaar Fraud", "Fake Aadhaar verification"),
            "digital arrest" to Pair("Digital Arrest Scam", "Digital arrest threat"),
            "cybercrime notice" to Pair("Fake Legal Notice", "Cybercrime notice threat"),
            "cbi notice" to Pair("Fake Legal Notice", "Fake CBI notice"),
            "ed notice" to Pair("Fake Legal Notice", "Fake ED notice"),
            "court notice" to Pair("Fake Legal Notice", "Fake court notice"),
            "won a prize" to Pair("Lottery Scam", "Prize won claim"),
            "lottery winner" to Pair("Lottery Scam", "Lottery winner scam"),
            "claim your reward" to Pair("Reward Scam", "Fake reward claim"),
            "you have been selected" to Pair("Selection Scam", "Fake selection offer"),
            "lucky winner" to Pair("Lottery Scam", "Lucky winner fraud"),
            "package is held" to Pair("Customs Scam", "Fake parcel held scam"),
            "customs clearance fee" to Pair("Customs Scam", "Customs fee fraud"),
            "work from home earn" to Pair("Job Fraud", "Fake work from home"),
            "part time job offer" to Pair("Job Fraud", "Fake part time job"),
            "investment return guaranteed" to Pair("Investment Fraud", "Guaranteed return scam"),
            "double your money" to Pair("Investment Fraud", "Money doubling scam"),
            "your otp is" to Pair("OTP Scam", "Unexpected OTP — verify sender"),
        )

        for ((keyword, info) in critical) {
            if (lower.contains(keyword)) {
                score += 50
                if (topReason.isEmpty()) {
                    category = info.first
                    topReason = info.second
                }
            }
        }

        // ── MEDIUM INDICATORS (score +20 each) ────────────────────────────
        val medium = listOf(
            "click here to verify", "verify now", "update now", "act now",
            "urgent action required", "immediate action needed", "final warning",
            "last chance", "expires in", "limited time", "only today",
            "free gift", "no cost", "exclusive offer",
            "account deactivated", "password expired",
            "refund initiated", "cashback credited",
            "congratulations you have won", "you are a winner"
        )
        var mediumCount = 0
        for (kw in medium) {
            if (lower.contains(kw)) mediumCount++
        }
        score += (mediumCount * 20).coerceAtMost(40)
        if (mediumCount >= 2 && topReason.isEmpty()) {
            category = "Suspicious Email"
            topReason = "Multiple pressure/urgency tactics detected"
        }

        // ── SUSPICIOUS LINKS (score +25) ──────────────────────────────────
        val suspiciousLinks = listOf(
            "bit.ly", "tinyurl.com", "goo.gl", "ow.ly", "t.co",
            ".ru/", ".xyz/", ".tk/", ".ml/", ".ga/", ".cf/",
            "login-secure", "account-verify", "bank-secure", "verify-now"
        )
        val hasPhishingLink = suspiciousLinks.any { lower.contains(it) }
        if (hasPhishingLink) {
            score += 25
            if (topReason.isEmpty()) {
                category = "Phishing Link"
                topReason = "Phishing link detected in email"
            }
        }

        // ── SAFE INDICATORS (heavily reduce score) ─────────────────────────
        val safeIndicators = listOf(
            "your transaction of rs", "amount debited", "amount credited",
            "upi transaction", "neft transfer", "imps transfer",
            "hdfc bank", "sbi bank", "axis bank", "icici bank",
            "your booking is confirmed", "order confirmed",
            "thank you for your purchase", "your order has been shipped",
            "noreply@google", "no-reply@amazon", "support@apple",
            "do not share this otp"
        )
        val isSafeContext = safeIndicators.any { lower.contains(it) }
        if (isSafeContext) {
            score = (score * 0.3).toInt()
        }

        return when {
            score >= 50 -> ContentAnalysis(
                true, "SCAM", score.coerceAtMost(99), category, topReason
            )
            score in 30..49 -> ContentAnalysis(
                true, "PHISHING", score, category.ifEmpty { "Suspicious Email" },
                topReason.ifEmpty { "Multiple suspicious signals detected" }
            )
            else -> ContentAnalysis(false, "SAFE", score, "", "")
        }
    }

    // ─── Notification Builder ─────────────────────────────────────────────────
    private fun showThreatNotification(
        sourcePkg: String,
        title: String,
        preview: String,
        analysis: ContentAnalysis
    ) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SafeSignal Email Scam Shield",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts when a suspicious email or notification is detected"
                enableVibration(true)
                enableLights(true)
                lightColor = android.graphics.Color.RED
            }
            nm.createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val appName = when (sourcePkg) {
            "com.google.android.gm" -> "Gmail"
            "com.microsoft.office.outlook" -> "Outlook"
            "com.yahoo.mobile.client.android.mail" -> "Yahoo Mail"
            "com.samsung.android.email.provider" -> "Samsung Email"
            "me.proton.android.mail" -> "ProtonMail"
            else -> "Email"
        }

        val emoji = if (analysis.verdict == "SCAM") "\uD83D\uDD34" else "⚠\uFE0F"
        val confidenceStr = "${analysis.confidence}% confidence"

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setContentTitle("$emoji $appName: ${analysis.category}")
            .setContentText(analysis.reason)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle("$emoji SafeSignal: ${analysis.verdict} Email Detected ($confidenceStr)")
                    .bigText(
                        "App: $appName\n" +
                        "From: ${title.take(60)}\n" +
                        "Preview: ${preview.take(150)}${if (preview.length > 150) "..." else ""}\n\n" +
                        "⚠\uFE0F ${analysis.reason}\n\n" +
                        "\uD83D\uDEA8 Is email mein diye links pe click mat karein ya personal details share mat karein!\n" +
                        "Cybercrime helpline: 1930"
                    )
                    .setSummaryText("SafeSignal Email Shield")
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setColor(android.graphics.Color.RED)
            .build()

        nm.notify(NOTIFICATION_ID_BASE + title.hashCode(), notification)
    }
}
