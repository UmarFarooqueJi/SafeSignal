package com.safesignal.safesignal

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class LinkShieldAccessibilityService : AccessibilityService() {

    private val urlRegex = Regex("(?i)\\b((?:https?://|www\\d{0,3}[.]|[a-z0-9.\\-]+[.][a-z]{2,4}/)(?:[^\\s()<>]+|\\(([^\\s()<>]+|(\\([^\\s()<>]+\\)))*\\))+(?:\\(([^\\s()<>]+|(\\([^\\s()<>]+\\)))*\\)|[^\\s`!()\\[\\]{};:'\".,<>?«»“”‘’]))")

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val source = event.source ?: return
        
        // Only scan active apps (Chrome, WhatsApp, etc. can be filtered here if needed)
        scanNodeForUrls(source)
    }

    private fun scanNodeForUrls(node: AccessibilityNodeInfo) {
        if (node.text != null) {
            val text = node.text.toString()
            val match = urlRegex.find(text)
            if (match != null) {
                val foundUrl = match.value
                // Check if we haven't already processed this URL very recently
                // and then send it to Flutter (or trigger a local notification) for scanning
                Log.d("SafeSignalLinkShield", "Found URL on screen: $foundUrl")
                
                // Note: Real app would dispatch to Flutter using MethodChannel, 
                // but since AccessibilityService has its own context, we'd use a BroadcastReceiver or direct plugin call.
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                scanNodeForUrls(child)
                child.recycle()
            }
        }
    }

    override fun onInterrupt() {
        Log.d("SafeSignalLinkShield", "Service Interrupted")
    }
}
