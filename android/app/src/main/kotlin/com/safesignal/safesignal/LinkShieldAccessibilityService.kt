/*
 * SafeSignal Mobile Security Suite
 * Module: LinkShield On-Screen URL Monitoring Service (Architectural Prototype / Reference)
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
 * Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
 *
 * NOTE: This service is an architectural reference and is intentionally NOT declared
 * in AndroidManifest.xml. SafeSignal enforces strict zero-unsolicited-telemetry and
 * local-first privacy. Accessibility service capabilities require explicit Play Store
 * justification and user consent declarations before production enablement.
 * Sensitive URLs are never emitted to system logcat to prevent cross-process data leakage.
 */
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
        
        // Prototype only: inactive unless declared in manifest and granted by user
        scanNodeForUrls(source)
    }

    private fun scanNodeForUrls(node: AccessibilityNodeInfo) {
        if (node.text != null) {
            val text = node.text.toString()
            val match = urlRegex.find(text)
            if (match != null) {
                // Privacy guard: Never log raw URLs to Android logcat
                // In production, dispatched locally and directly to on-device scanner
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
