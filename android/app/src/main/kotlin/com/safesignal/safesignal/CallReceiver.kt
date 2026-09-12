package com.safesignal.safesignal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telephony.TelephonyManager
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import android.provider.ContactsContract
import android.net.Uri
import android.Manifest
import android.content.pm.PackageManager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import androidx.core.app.NotificationCompat

/**
 * BroadcastReceiver that listens for incoming calls and shows
 * a SafeSignal overlay popup analyzing whether the caller is likely a scam.
 */
class CallReceiver : BroadcastReceiver() {

    companion object {
        private const val CALL_CHANNEL_ID = "safesignal_call_alerts"
        private const val CALL_NOTIFICATION_ID = 3003

        // Known scam prefixes in India
        private val SCAM_PREFIXES = setOf(
            "140", "141", "142", "143", "144", // Telemarketing prefixes
            "160"  // Service/TRAI commercial
        )

        // Known safe prefixes (banks, TRAI, etc.)
        private val BANK_PREFIXES = setOf(
            "1800", "1860", "1900" // Toll-free
        )

        // Scam number patterns
        private val SCAM_PATTERNS = listOf(
            Regex("^\\+?0?1[0-9]{9,10}$"), // US-like numbers
            Regex("^00[0-9]{10,}$"),         // International with 00
        )

        private var overlayView: View? = null
        private var windowManager: WindowManager? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val phoneNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: "Unknown"

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                // Incoming call — analyze and show high-priority alert + overlay
                val analysis = analyzeNumber(context, phoneNumber)
                showCallNotification(context, phoneNumber, analysis)
                showOverlay(context, phoneNumber, analysis)
            }
            TelephonyManager.EXTRA_STATE_IDLE,
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                // Call ended or picked up — dismiss overlay and clear notification
                dismissOverlay()
                dismissCallNotification(context)
            }
        }
    }

    private data class CallAnalysis(
        val verdict: String,        // "SAFE", "SCAM", "CAUTION"
        val confidence: Int,         // 0-100
        val reason: String,
        val emoji: String,
        val bgColor: Int,
        val textColor: Int,
        val displayName: String? = null // To hold real person name
    )
    
    private fun getContactName(context: Context, phoneNumber: String): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (context.checkSelfPermission(Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
                return null
            }
        }
        
        try {
            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI, 
                Uri.encode(phoneNumber)
            )
            val projection = arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME)
            context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    return cursor.getString(0)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }

    private fun analyzeNumber(context: Context, number: String): CallAnalysis {
        val clean = number.replace(Regex("[\\s\\-()]+"), "")
        
        val contactName = getContactName(context, clean)
        if (contactName != null) {
            return CallAnalysis(
                verdict = "SAFE",
                confidence = 100,
                reason = "Real person — Saved in your contacts",
                emoji = "✅",
                bgColor = Color.parseColor("#1B5E20"),
                textColor = Color.WHITE,
                displayName = contactName
            )
        }

        // Check if number is empty / private / withheld
        if (clean.isEmpty() || clean == "Unknown" || clean == "-1") {
            return CallAnalysis(
                verdict = "CAUTION",
                confidence = 60,
                reason = "Private / Hidden number — caller ne apna number chhupaaya hai",
                emoji = "⚠️",
                bgColor = Color.parseColor("#F57F17"),
                textColor = Color.WHITE
            )
        }

        // Check known scam prefixes (India)
        for (prefix in SCAM_PREFIXES) {
            if (clean.startsWith(prefix)) {
                return CallAnalysis(
                    verdict = "SCAM",
                    confidence = 85,
                    reason = "Telemarketing / Promotional prefix $prefix — likely spam call",
                    emoji = "🔴",
                    bgColor = Color.parseColor("#C62828"),
                    textColor = Color.WHITE
                )
            }
        }

        // Toll-free / bank numbers
        for (prefix in BANK_PREFIXES) {
            if (clean.startsWith(prefix)) {
                return CallAnalysis(
                    verdict = "SAFE",
                    confidence = 80,
                    reason = "Toll-free number — likely bank ya company helpline",
                    emoji = "✅",
                    bgColor = Color.parseColor("#1B5E20"),
                    textColor = Color.WHITE
                )
            }
        }

        // Short numbers (government, services)
        if (clean.length in 3..5) {
            return CallAnalysis(
                verdict = "SAFE",
                confidence = 75,
                reason = "Short service number — government ya emergency service",
                emoji = "✅",
                bgColor = Color.parseColor("#1B5E20"),
                textColor = Color.WHITE
            )
        }

        // International format
        if (clean.startsWith("+") && !clean.startsWith("+91")) {
            return CallAnalysis(
                verdict = "CAUTION",
                confidence = 70,
                reason = "International number (+${clean.take(4)}) — verify karein",
                emoji = "⚠️",
                bgColor = Color.parseColor("#E65100"),
                textColor = Color.WHITE
            )
        }

        // Pattern matching
        for (pattern in SCAM_PATTERNS) {
            if (pattern.containsMatchIn(clean)) {
                return CallAnalysis(
                    verdict = "SCAM",
                    confidence = 72,
                    reason = "Suspicious number pattern detected",
                    emoji = "🔴",
                    bgColor = Color.parseColor("#C62828"),
                    textColor = Color.WHITE
                )
            }
        }

        // Default — local Indian number
        return CallAnalysis(
            verdict = "UNKNOWN",
            confidence = 50,
            reason = "Local number — SafeSignal ke paas is number ki info nahi",
            emoji = "❓",
            bgColor = Color.parseColor("#1565C0"),
            textColor = Color.WHITE
        )
    }

    private fun showOverlay(context: Context, phoneNumber: String, analysis: CallAnalysis) {
        if (!canDrawOverlay(context)) return

        Handler(Looper.getMainLooper()).post {
            try {
                dismissOverlay() // clear any existing overlay

                val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                windowManager = wm

                // Base Container
                val container = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding(48, 48, 48, 48)
                    
                    // Premium Background with Gradient and Rounded Corners
                    val bgDrawable = android.graphics.drawable.GradientDrawable().apply {
                        shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                        cornerRadius = 48f
                        colors = intArrayOf(Color.parseColor("#1E2128"), Color.parseColor("#121418"))
                        setStroke(2, Color.parseColor("#33FFFFFF"))
                    }
                    background = bgDrawable
                    elevation = 30f
                }

                // Brand header (SafeSignal)
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

                // Divider Line
                val divider = View(context).apply {
                    val params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 2)
                    params.setMargins(0, 24, 0, 24)
                    layoutParams = params
                    setBackgroundColor(Color.parseColor("#2A2E35"))
                }

                // Incoming call label
                val incomingLabel = TextView(context).apply {
                    text = "INCOMING CALL ANALYSIS"
                    setTextColor(Color.parseColor("#8892B0"))
                    textSize = 11f
                    setTypeface(null, android.graphics.Typeface.BOLD)
                    letterSpacing = 0.05f
                }

                // Phone number or Contact Name
                val numberText = TextView(context).apply {
                    text = analysis.displayName ?: phoneNumber
                    setTextColor(Color.WHITE)
                    textSize = 28f
                    setTypeface(null, android.graphics.Typeface.BOLD)
                    setPadding(0, 8, 0, 0)
                }
                
                // If it's a known contact, also show the phone number small underneath
                var subNumberText: TextView? = null
                if (analysis.displayName != null) {
                    subNumberText = TextView(context).apply {
                        text = phoneNumber
                        setTextColor(Color.parseColor("#8892B0"))
                        textSize = 14f
                        setPadding(0, 4, 0, 8)
                    }
                }

                // Verdict badge container
                val badgeContainer = LinearLayout(context).apply {
                    setPadding(0, 32, 0, 16)
                    gravity = Gravity.LEFT
                }
                
                val verdictBadge = TextView(context).apply {
                    text = "${analysis.emoji}  ${analysis.verdict}"
                    setTextColor(analysis.textColor)
                    textSize = 16f
                    setTypeface(null, android.graphics.Typeface.BOLD)
                    setPadding(40, 20, 40, 20)
                    
                    val badgeBg = android.graphics.drawable.GradientDrawable().apply {
                        shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                        cornerRadius = 100f
                        setColor(analysis.bgColor)
                        setStroke(2, Color.parseColor("#50FFFFFF"))
                    }
                    background = badgeBg
                }
                badgeContainer.addView(verdictBadge)

                // Reason / Detail text
                val reasonText = TextView(context).apply {
                    text = analysis.reason
                    setTextColor(Color.parseColor("#CCD6F6"))
                    textSize = 14f
                    setPadding(0, 8, 0, 0)
                    setLineSpacing(4f, 1f)
                }
                
                // Confidence Bar (visual indicator)
                val confContainer = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    setPadding(0, 32, 0, 0)
                    gravity = Gravity.CENTER_VERTICAL
                }
                val confLabel = TextView(context).apply {
                    text = "AI Confidence: ${analysis.confidence}%"
                    setTextColor(Color.parseColor("#8892B0"))
                    textSize = 12f
                }
                confContainer.addView(confLabel)

                // Add views to main container
                container.addView(brandRow)
                container.addView(divider)
                container.addView(incomingLabel)
                container.addView(numberText)
                if (subNumberText != null) {
                    container.addView(subNumberText)
                }
                container.addView(badgeContainer)
                container.addView(reasonText)
                container.addView(confContainer)

                // Outer Wrapper for Margin
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

                // Auto-dismiss after 12 seconds
                Handler(Looper.getMainLooper()).postDelayed({ dismissOverlay() }, 12000)
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
        } catch (_: Exception) {}
    }

    private fun canDrawOverlay(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    private fun showCallNotification(context: Context, phoneNumber: String, analysis: CallAnalysis) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CALL_CHANNEL_ID,
                    "SafeSignal Live Call Shield",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Urgent incoming call scam analysis and warnings"
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 450, 250, 450)
                    enableLights(true)
                    lightColor = if (analysis.verdict == "SCAM") Color.RED else Color.BLUE
                }
                nm.createNotificationChannel(channel)
            }

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val displayName = analysis.displayName ?: phoneNumber
            val verdictTitle = when (analysis.verdict) {
                "SCAM" -> "🔴 CRITICAL: Potential Scam Call!"
                "CAUTION" -> "⚠️ CAUTION: Unverified Caller"
                "SAFE" -> "🟢 Safe Caller: $displayName"
                else -> "🛡️ SafeSignal Call Check: $displayName"
            }

            val alertColor = when (analysis.verdict) {
                "SCAM" -> Color.RED
                "CAUTION" -> Color.parseColor("#FF6F00")
                "SAFE" -> Color.parseColor("#00C853")
                else -> Color.parseColor("#2979FF")
            }

            val notification = NotificationCompat.Builder(context, CALL_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_warning)
                .setContentTitle(verdictTitle)
                .setContentText("${analysis.reason} (${analysis.confidence}% confidence)")
                .setStyle(
                    NotificationCompat.BigTextStyle()
                        .setBigContentTitle(verdictTitle)
                        .bigText("Caller: $displayName ($phoneNumber)\n\n" +
                                "Analysis: ${analysis.reason}\n\n" +
                                "Confidence Score: ${analysis.confidence}%\n\n" +
                                (if (analysis.verdict == "SCAM") "🚨 Security Warning: Never share OTP, UPI PIN, or bank passwords with unknown callers."
                                else "SafeSignal active background caller verification."))
                        .setSummaryText("Call Shield Active")
                )
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setVibrate(longArrayOf(0, 450, 250, 450))
                .setColor(alertColor)
                .build()

            nm.notify(CALL_NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun dismissCallNotification(context: Context) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(CALL_NOTIFICATION_ID)
        } catch (_: Exception) {}
    }
}
