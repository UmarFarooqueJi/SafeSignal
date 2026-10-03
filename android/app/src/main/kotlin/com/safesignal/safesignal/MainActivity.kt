/*
 * SafeSignal Mobile Security Suite
 * Module: Main Activity & System Intelligence Bridge
 * Author: Umar Farooque (https://github.com/UmarFarooqueJi)
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
import android.app.ActivityManager
import android.app.role.RoleManager
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityManager
import android.os.StatFs
import android.os.Environment
import java.io.File
import java.io.BufferedReader
import java.io.FileReader
import java.net.InetAddress
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
                "getMemoryInfo" -> result.success(getMemoryInfo())
                "getStorageInfo" -> result.success(getStorageInfo())
                "scanSuspiciousFiles" -> result.success(scanSuspiciousFiles())
                "deleteSuspiciousFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        result.success(deleteSuspiciousFile(path))
                    } else {
                        result.error("INVALID_ARGUMENT", "Path is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(appScannerHandler)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "safesignal/device").setMethodCallHandler(appScannerHandler)

        // ── Call Shield Channel (CallScreeningService Integration) ───────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "safesignal/call_shield").setMethodCallHandler { call, result ->
            when (call.method) {
                "isCallScreeningActive" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager
                        result.success(roleManager?.isRoleHeld(RoleManager.ROLE_CALL_SCREENING) == true)
                    } else {
                        result.success(false)
                    }
                }
                "requestCallScreeningRole" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager
                        if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
                            if (!roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
                                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
                                startActivityForResult(intent, 9021)
                                result.success(true)
                            } else {
                                result.success(true)
                            }
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "getBlockedCalls" -> {
                    val prefs = getSharedPreferences("safesignal_call_shield", Context.MODE_PRIVATE)
                    val json = prefs.getString("blocked_calls_log", "[]") ?: "[]"
                    result.success(json)
                }
                "clearBlockedCalls" -> {
                    val prefs = getSharedPreferences("safesignal_call_shield", Context.MODE_PRIVATE)
                    prefs.edit().remove("blocked_calls_log").apply()
                    result.success(true)
                }
                "getCallShieldSettings" -> {
                    val prefs = getSharedPreferences("safesignal_call_shield", Context.MODE_PRIVATE)
                    val map = mapOf(
                        "blockTrai" to prefs.getBoolean("block_trai", true),
                        "blockInternational" to prefs.getBoolean("block_international", true),
                        "blockUnknown" to prefs.getBoolean("block_unknown", false)
                    )
                    result.success(map)
                }
                "updateCallShieldSettings" -> {
                    val prefs = getSharedPreferences("safesignal_call_shield", Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    call.argument<Boolean>("blockTrai")?.let { editor.putBoolean("block_trai", it) }
                    call.argument<Boolean>("blockInternational")?.let { editor.putBoolean("block_international", it) }
                    call.argument<Boolean>("blockUnknown")?.let { editor.putBoolean("block_unknown", it) }
                    editor.apply()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── Network Security & ARP Channel ───────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "safesignal/network").setMethodCallHandler { call, result ->
            when (call.method) {
                "getNetworkSecurityTelemetry" -> {
                    Thread {
                        val data = getNetworkSecurityTelemetry()
                        runOnUiThread { result.success(data) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }

        // ── Banking Trojan & Accessibility / Overlay Abuse Channel ───────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "safesignal/trojan_guard").setMethodCallHandler { call, result ->
            when (call.method) {
                "getTrojanVulnerabilities" -> {
                    result.success(getTrojanVulnerabilities())
                }
                else -> result.notImplemented()
            }
        }
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

    // ─── Real RAM Telemetry ──────────────────────────────────────────────────
    private fun getMemoryInfo(): Map<String, Any> {
        return try {
            val actManager = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val memInfo = ActivityManager.MemoryInfo()
            actManager?.getMemoryInfo(memInfo)
            val total = memInfo.totalMem
            val avail = memInfo.availMem
            val used = if (total > avail) total - avail else 0L
            mapOf(
                "totalMem" to total,
                "availMem" to avail,
                "usedMem" to used,
                "lowMemory" to memInfo.lowMemory,
                "threshold" to memInfo.threshold
            )
        } catch (e: Exception) {
            mapOf(
                "totalMem" to 0L,
                "availMem" to 0L,
                "usedMem" to 0L,
                "lowMemory" to false,
                "threshold" to 0L
            )
        }
    }

    // ─── Real Storage Telemetry ──────────────────────────────────────────────
    private fun getStorageInfo(): Map<String, Any> {
        return try {
            val dataDir = Environment.getDataDirectory()
            val stat = StatFs(dataDir.path)
            val blockSize = stat.blockSizeLong
            val totalBlocks = stat.blockCountLong
            val availableBlocks = stat.availableBlocksLong
            val total = totalBlocks * blockSize
            val free = availableBlocks * blockSize
            val used = if (total > free) total - free else 0L
            mapOf(
                "totalStorage" to total,
                "freeStorage" to free,
                "usedStorage" to used
            )
        } catch (e: Exception) {
            mapOf(
                "totalStorage" to 0L,
                "freeStorage" to 0L,
                "usedStorage" to 0L
            )
        }
    }

    // ─── Real Suspicious & Sideloaded File Sweep ─────────────────────────────
    private fun scanSuspiciousFiles(): List<Map<String, Any>> {
        val results = mutableListOf<Map<String, Any>>()
        val candidateDirs = mutableListOf<File>()

        try {
            val pubDownloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (pubDownloads != null && pubDownloads.exists()) candidateDirs.add(pubDownloads)
        } catch (_: Exception) {}

        val altDownload = File("/storage/emulated/0/Download")
        if (altDownload.exists() && !candidateDirs.contains(altDownload)) candidateDirs.add(altDownload)

        val altDocs = File("/storage/emulated/0/Documents")
        if (altDocs.exists() && !candidateDirs.contains(altDocs)) candidateDirs.add(altDocs)

        val doubleExtRegex = Regex("(?i).*\\.(pdf|jpg|jpeg|png|mp4|doc|docx|xls|xlsx|txt)\\.(apk|dex|exe|sh|bin|payload)$")
        val executableExts = setOf("apk", "dex", "sh", "bin", "payload", "elf", "so", "bat")

        for (dir in candidateDirs) {
            scanDirectory(dir, results, doubleExtRegex, executableExts, depth = 0, maxDepth = 2)
        }
        return results
    }

    private fun scanDirectory(
        dir: File,
        out: MutableList<Map<String, Any>>,
        doubleExtRegex: Regex,
        executableExts: Set<String>,
        depth: Int,
        maxDepth: Int
    ) {
        if (depth > maxDepth || out.size >= 50) return
        val files = dir.listFiles() ?: return

        for (f in files) {
            if (f.isDirectory) {
                if (!f.name.startsWith(".")) {
                    scanDirectory(f, out, doubleExtRegex, executableExts, depth + 1, maxDepth)
                }
            } else {
                val name = f.name
                val ext = name.substringAfterLast('.', "").lowercase()

                var riskType: String? = null
                var severity = "MEDIUM"

                if (doubleExtRegex.matches(name)) {
                    riskType = "Disguised Double-Extension Dropper"
                    severity = "CRITICAL"
                } else if (name.startsWith(".") && ext in executableExts) {
                    riskType = "Hidden Executable Payload"
                    severity = "CRITICAL"
                } else if (ext == "apk") {
                    riskType = "Sideloaded APK Package"
                    severity = "HIGH"
                } else if (ext in setOf("sh", "bin", "payload", "elf", "dex")) {
                    riskType = "Executable Script / Binary Payload"
                    severity = "HIGH"
                }

                if (riskType != null) {
                    out.add(mapOf(
                        "name" to name,
                        "path" to f.absolutePath,
                        "size" to f.length(),
                        "lastModified" to f.lastModified(),
                        "riskType" to riskType,
                        "severity" to severity
                    ))
                }
            }
        }
    }

    // ─── Delete Suspicious File ──────────────────────────────────────────────
    private fun deleteSuspiciousFile(path: String): Boolean {
        return try {
            val file = File(path)
            if (file.exists()) {
                file.delete()
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    // ─── Network Security Telemetry ──────────────────────────────────────────
    private fun getNetworkSecurityTelemetry(): Map<String, Any> {
        val out = mutableMapOf<String, Any>()

        // 1. ARP Table & Poisoning / Spoofing Check
        var arpPoisoned = false
        val arpEntries = mutableListOf<Map<String, String>>()
        val macToIps = mutableMapOf<String, MutableList<String>>()

        try {
            val file = File("/proc/net/arp")
            if (file.exists() && file.canRead()) {
                BufferedReader(FileReader(file)).use { reader ->
                    var line: String?
                    var firstLine = true
                    while (reader.readLine().also { line = it } != null) {
                        if (firstLine) {
                            firstLine = false
                            continue
                        }
                        val tokens = line!!.trim().split("\\s+".toRegex())
                        if (tokens.size >= 4) {
                            val ip = tokens[0]
                            val mac = tokens[3]
                            if (mac != "00:00:00:00:00:00" && mac.length == 17) {
                                arpEntries.add(mapOf("ip" to ip, "mac" to mac))
                                val list = macToIps.getOrPut(mac) { mutableListOf() }
                                list.add(ip)
                                if (list.size > 1) {
                                    arpPoisoned = true
                                }
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            // Android 10+ SELinux may restrict /proc/net/arp
        }

        out["arpPoisoned"] = arpPoisoned
        out["arpEntriesCount"] = arpEntries.size

        // 2. DNS Canary / Poisoning Test
        var dnsHealthy = true
        var resolvedIp = "N/A"
        try {
            val canaryHost = "connectivitycheck.gstatic.com"
            val address = InetAddress.getByName(canaryHost)
            resolvedIp = address.hostAddress ?: "N/A"
            if (resolvedIp.startsWith("127.") || resolvedIp.startsWith("192.168.") ||
                resolvedIp.startsWith("10.") || resolvedIp == "0.0.0.0") {
                dnsHealthy = false
            }
        } catch (e: Exception) {
            // DNS resolution failure or network timeout
        }

        out["dnsHealthy"] = dnsHealthy
        out["canaryResolvedIp"] = resolvedIp

        // 3. Captive Portal check
        var isCaptivePortal = false
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? android.net.ConnectivityManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = cm?.activeNetwork
                val caps = cm?.getNetworkCapabilities(network)
                if (caps != null && caps.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL)) {
                    isCaptivePortal = true
                }
            }
        } catch (e: Exception) {
            // ignore
        }
        out["isCaptivePortal"] = isCaptivePortal

        return out
    }

    // ─── Banking Trojan / Accessibility & Overlay Abuse ──────────────────────
    private fun getTrojanVulnerabilities(): Map<String, Any> {
        val pm = packageManager
        val accessibilityAbusers = mutableListOf<Map<String, String>>()
        val overlayAbusers = mutableListOf<Map<String, String>>()

        // 1. Accessibility abusers (Trojan Vector: Keystroke & PIN Logging)
        try {
            val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
            val enabledServices = am?.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK) ?: emptyList()
            for (service in enabledServices) {
                val pkgName = service.resolveInfo.serviceInfo.packageName
                if (pkgName != packageName && !isSystemPackage(pkgName)) {
                    val appLabel = try {
                        pm.getApplicationLabel(pm.getApplicationInfo(pkgName, 0)).toString()
                    } catch (e: Exception) { pkgName }

                    accessibilityAbusers.add(mapOf(
                        "packageName" to pkgName,
                        "appName" to appLabel,
                        "description" to "Active Accessibility Service — Can intercept screen text, keystrokes, and automated taps"
                    ))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 2. High-risk non-system apps with SYSTEM_ALERT_WINDOW (Overlay capability)
        try {
            val installedPackages = pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
            for (pkg in installedPackages) {
                val pkgName = pkg.packageName
                if (pkgName == packageName || isSystemPackage(pkgName)) continue
                val appInfo = pkg.applicationInfo ?: continue
                val permissions = pkg.requestedPermissions ?: continue
                if (Manifest.permission.SYSTEM_ALERT_WINDOW in permissions) {
                    val appLabel = try {
                        pm.getApplicationLabel(appInfo).toString()
                    } catch (e: Exception) { pkgName }

                    overlayAbusers.add(mapOf(
                        "packageName" to pkgName,
                        "appName" to appLabel,
                        "description" to "Floating Window Overlay — Can draw fake overlays over banking and UPI apps"
                    ))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return mapOf(
            "accessibilityAbusers" to accessibilityAbusers,
            "overlayAbusers" to overlayAbusers
        )
    }

    private fun isSystemPackage(packageName: String): Boolean {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
        } catch (e: Exception) {
            false
        }
    }
}
