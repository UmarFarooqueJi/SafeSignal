import 'package:flutter/services.dart';

/// LinkGuardService handles interception of shared links and text from Android system
/// intents (ACTION_SEND) via the native MethodChannel bridge.
class LinkGuardService {
  static const MethodChannel _channel = MethodChannel('com.safesignal/app_scanner');

  /// Checks for any pending shared text passed from Android ACTION_SEND intent
  static Future<String?> checkPendingSharedUrl() async {
    try {
      final sharedText = await _channel.invokeMethod<String?>('getSharedText');
      if (sharedText == null || sharedText.trim().isEmpty) return null;
      return extractUrl(sharedText.trim());
    } catch (_) {
      return null;
    }
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
