import 'dart:async';
import 'package:flutter/services.dart';

/// LinkGuardService handles interception of shared links and text from Android system
/// intents (ACTION_SEND and ACTION_VIEW) via the native MethodChannel bridge.
class LinkGuardService {
  static const MethodChannel _channel = MethodChannel('com.safesignal/app_scanner');
  static final StreamController<String> _urlController = StreamController<String>.broadcast();

  /// Live stream of URLs intercepted in real-time while the application is active or resumed
  static Stream<String> get onUrlReceived => _urlController.stream;

  /// Initializes the native MethodChannel handler for real-time link interception
  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onUrlIntercepted') {
        final raw = call.arguments as String?;
        if (raw != null && raw.trim().isNotEmpty) {
          final extracted = extractUrl(raw.trim());
          if (extracted != null && extracted.isNotEmpty) {
            _urlController.add(extracted);
          }
        }
      }
    });
  }

  /// Checks for any pending shared text passed from Android ACTION_SEND or ACTION_VIEW intent
  static Future<String?> checkPendingSharedUrl() async {
    try {
      final sharedText = await _channel.invokeMethod<String?>('getSharedText');
      if (sharedText == null || sharedText.trim().isEmpty) return null;
      return extractUrl(sharedText.trim());
    } catch (_) {
      return null;
    }
  }

  /// Checks if SafeSignal is currently holding the Default Browser role on Android 10+
  static Future<bool> isBrowserRoleHeld() async {
    try {
      final held = await _channel.invokeMethod<bool>('isBrowserRoleHeld');
      return held ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests the Default Browser role from the Android OS (enables 100% WhatsApp interception)
  static Future<bool> requestBrowserRole() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestBrowserRole');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android Settings -> Default Apps so user can select SafeSignal or preferred browser
  static Future<void> openDefaultAppsSettings() async {
    try {
      await _channel.invokeMethod('openDefaultAppsSettings');
    } catch (_) {}
  }

  /// Clears SafeSignal as the default browser so user retains choice of opening in Chrome/browser
  static Future<bool> clearDefaultBrowser() async {
    try {
      final res = await _channel.invokeMethod<bool>('clearDefaultBrowser');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens a URL in an external system browser (Chrome/Firefox) without re-intercepting
  static Future<bool> openUrlInSystemBrowser(String url) async {
    try {
      final res = await _channel.invokeMethod<bool>('openUrlInSystemBrowser', {'url': url});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static String? _lastCheckedClipboardUrl;

  /// Inspects device clipboard for unverified URLs (e.g. copied from WhatsApp)
  static Future<String?> checkClipboardUrl() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return null;

      final url = extractUrl(text);
      if (url != null && url != _lastCheckedClipboardUrl) {
        _lastCheckedClipboardUrl = url;
        return url;
      }
    } catch (_) {}
    return null;
  }

  /// Resets clipboard history tracker
  static void resetClipboardTracker() {
    _lastCheckedClipboardUrl = null;
  }

  /// Extracts the primary URL from a plain text block or message
  static String? extractUrl(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // Direct URL check
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final firstSpace = trimmed.indexOf(RegExp(r'\s'));
      return firstSpace == -1 ? trimmed : trimmed.substring(0, firstSpace);
    }

    // Regex extraction for URLs embedded within messages (e.g. "Check: https://example.com/login")
    final urlRegex = RegExp(
      r'https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );

    final match = urlRegex.firstMatch(trimmed);
    if (match != null) {
      return match.group(0);
    }

    // Bare domain check (e.g. "sbi-kyc.xyz/update")
    final domainRegex = RegExp(
      r'\b(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[-a-zA-Z0-9()@:%_\+.~#?&//=]*)?',
      caseSensitive: false,
    );
    final domainMatch = domainRegex.firstMatch(trimmed);
    if (domainMatch != null) {
      return 'https://${domainMatch.group(0)}';
    }

    return null;
  }
}
