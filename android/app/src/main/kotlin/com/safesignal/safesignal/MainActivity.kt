/*
 * SafeSignal Mobile Security Suite
 * Module: Main Activity & System Intelligence Bridge
 * Author: Umar Farooque (umarfarooque@safesignal.app)
 * Copyright (c) 2026 SafeSignal Technologies. All rights reserved.
 *
 * Flutter-Kotlin MethodChannel bridge: app auditing with SHA-256 binary
 * hashing, WiFi security type detection, developer options state,
 * and system settings navigation.
 */
package com.safesignal.safesignal

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.safesignal/app_scanner"

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        
        // Start Persistent Background Service
        try {
            val serviceIntent = Intent(this, SafeSignalService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val appScannerHandler: (io.flutter.plugin.common.MethodCall, MethodChannel.Result) -> Unit = { call, result ->
            when (call.method) {
                "getInstalledApps" -> result.success(getInstalledApps())
                "getAppIcon" -> {
                    val pkg = call.argument<String>("package")
                    if (pkg != null) {
                        result.success(getAppIcon(pkg))
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required", null)
                    }
                }
                "getAppHash" -> {
                    val pkg = call.argument<String>("package")
                    if (pkg != null) {
                        result.success(getAppHash(pkg))
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required", null)
                    }
                }
                "getWifiSecurityType" -> result.success(getWifiSecurityType())
                "openWifiSettings" -> {
                    openWifiSettings()
                    result.success(null)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !android.provider.Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            android.net.Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(false)
                    } else {
                        result.success(true)
                    }
                }
                "isNotificationListenerEnabled" -> {
                    result.success(isNotificationListenerEnabled())
                }
                "openNotificationSettings" -> {
                    val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                    startActivity(intent)
                    result.success(null)
                }
                "isDeveloperOptionsEnabled" -> {
                    try {
                        val dev = Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) != 0
                        result.success(dev)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openDeveloperSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                "openSystemUpdateSettings" -> {
                    try {
                        val intent = Intent("android.settings.SYSTEM_UPDATE_SETTINGS")
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_DEVICE_INFO_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                "openAppSettings" -> {
                    val pkg = call.argument<String>("package") ?: packageName
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = android.net.Uri.parse("package:$pkg")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openPermissionSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(appScannerHandler)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "safesignal/device").setMethodCallHandler(appScannerHandler)
    }

    // ─── Installed Apps ──────────────────────────────────────────────────────
    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        val installedApps = pm.getInstalledPackages(PackageManager.GET_PERMISSIONS or PackageManager.GET_SERVICES or PackageManager.GET_RECEIVERS)
        val apps = mutableListOf<Map<String, Any>>()

        val systemSkip = setOf(
            "android", "com.android.systemui", "com.android.settings",
            "com.android.phone", "com.android.inputmethod.latin"
        )

        for (pkg in installedApps) {
            val appInfo = pkg.applicationInfo ?: continue
            val isSystem = (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
            val hasLauncher = pm.getLaunchIntentForPackage(pkg.packageName) != null

            if (!hasLauncher && isSystem) continue
            if (pkg.packageName in systemSkip) continue

            val permissions = pkg.requestedPermissions?.toList() ?: emptyList()
            val appName = pm.getApplicationLabel(appInfo).toString()

            val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    pm.getInstallSourceInfo(pkg.packageName).installingPackageName
                } catch (e: Exception) {
                    pm.getInstallerPackageName(pkg.packageName)
                }
            } else {
                @Suppress("DEPRECATION")
                pm.getInstallerPackageName(pkg.packageName)
            }

            val hasAccessibility = pkg.services?.any { it.permission == android.Manifest.permission.BIND_ACCESSIBILITY_SERVICE } == true
            val hasDeviceAdmin = pkg.receivers?.any { it.permission == android.Manifest.permission.BIND_DEVICE_ADMIN } == true

            apps.add(
                mapOf(
                    "name" to appName,
                    "package" to pkg.packageName,
                    "permissions" to permissions,
                    "isSystem" to isSystem,
                    "versionName" to (pkg.versionName ?: ""),
                    "installer" to (installer ?: "unknown"),
                    "targetSdk" to appInfo.targetSdkVersion,
                    "hasLauncher" to hasLauncher,
                    "hasAccessibility" to hasAccessibility,
                    "hasDeviceAdmin" to hasDeviceAdmin
                )
            )
        }
        return apps
    }

    private fun getAppIcon(packageName: String): ByteArray? {
        return try {
            val pm = packageManager
            val icon = pm.getApplicationIcon(packageName)
            val bitmap = if (icon is android.graphics.drawable.BitmapDrawable) {
                icon.bitmap
            } else {
                val bmp = android.graphics.Bitmap.createBitmap(
                    icon.intrinsicWidth.takeIf { it > 0 } ?: 1,
                    icon.intrinsicHeight.takeIf { it > 0 } ?: 1,
                    android.graphics.Bitmap.Config.ARGB_8888
                )
                val canvas = android.graphics.Canvas(bmp)
                icon.setBounds(0, 0, canvas.width, canvas.height)
                icon.draw(canvas)
                bmp
            }
            val stream = java.io.ByteArrayOutputStream()
            bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        }
    }

    private fun getAppHash(packageName: String): String? {
        return try {
            val pm = packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            val file = java.io.File(appInfo.sourceDir)
            val md = java.security.MessageDigest.getInstance("SHA-256")
            val fis = java.io.FileInputStream(file)
            val buffer = ByteArray(8192)
            var numOfBytesRead: Int
            while (fis.read(buffer).also { numOfBytesRead = it } > 0) {
                md.update(buffer, 0, numOfBytesRead)
            }
            val hashBytes = md.digest()
            hashBytes.joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            null
        }
    }

    // ─── WiFi Security Type ──────────────────────────────────────────────────
    @Suppress("DEPRECATION")
    private fun getWifiSecurityType(): String {
        return try {
            val wifiManager =
                applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                    ?: return "Unknown"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ — use getCurrentNetwork capabilities
                val networkCapabilities = wifiManager.connectionInfo
                val secType = networkCapabilities?.currentSecurityType ?: -1
                return when (secType) {
                    // WifiInfo.SECURITY_TYPE_OPEN
                    0 -> "Open"
                    // WifiInfo.SECURITY_TYPE_WEP
                    1 -> "WEP"
                    // WifiInfo.SECURITY_TYPE_PSK (WPA2)
                    2 -> "WPA2-PSK"
                    // WifiInfo.SECURITY_TYPE_EAP
                    3 -> "WPA2-EAP"
                    // WifiInfo.SECURITY_TYPE_SAE (WPA3)
                    4 -> "WPA3-SAE"
                    // WifiInfo.SECURITY_TYPE_OWE
                    5 -> "WPA3-OWE"
                    // WifiInfo.SECURITY_TYPE_WAPI_PSK
                    6 -> "WAPI-PSK"
                    else -> "WPA2"
                }
            } else {
                // Below Android 12 — scan results (need location permission)
                val scanResults = wifiManager.scanResults ?: return "WPA2"
                val connectionInfo = wifiManager.connectionInfo
                val connectedBssid = connectionInfo?.bssid

                val connectedScan = scanResults.find { it.BSSID == connectedBssid }
                val cap = connectedScan?.capabilities ?: ""

                return when {
                    cap.contains("WPA3") -> "WPA3-SAE"
                    cap.contains("WPA2") -> "WPA2-PSK"
                    cap.contains("WPA") -> "WPA-PSK"
                    cap.contains("WEP") -> "WEP"
                    cap.isEmpty() || cap == "[ESS]" || cap == "[IBSS]" -> "Open"
                    else -> "WPA2"
                }
            }
        } catch (e: Exception) {
            "WPA2"
        }
    }

    // ─── Open WiFi Settings ──────────────────────────────────────────────────
    private fun openWifiSettings() {
        val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    // ─── Notification Listener Check ─────────────────────────────────────────
    private fun isNotificationListenerEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (!flat.isNullOrEmpty()) {
            val names = flat.split(":")
            for (name in names) {
                val componentName = android.content.ComponentName.unflattenFromString(name)
                if (componentName != null && componentName.packageName == pkgName) {
                    return true
                }
            }
        }
        return false
    }
}
