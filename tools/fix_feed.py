import os
import re

# 1. FIX FEED_SCREEN.DART
with open('lib/features/feed/feed_screen.dart', 'r', encoding='utf-8') as f:
    feed_code = f.read()

# Add share_plus import
if 'import ''package:share_plus/share_plus.dart'';' not in feed_code:
    feed_code = feed_code.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:share_plus/share_plus.dart';")

# Update sharing logic
old_share = '''  void _shareNews(BuildContext context) {
    final shareText = '🚨 \\n\\n...\\n\\n🔗 \\n\\nStay safe with SafeSignal!';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Link copied to clipboard!'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }'''

new_share = '''  void _shareNews(BuildContext context) {
    final shareText = '🚨 \\n\\n\\n\\n🔗 Read more: \\n\\nStay safe with SafeSignal!';
    Share.share(shareText);
  }'''

feed_code = feed_code.replace(old_share, new_share)

# Update emoji to icon
old_emoji = '''  String get _categoryEmoji {
    switch (alert.category) {
      case 'digital_arrest':
        return '👮';
      case 'investment':
        return '💰';
      case 'otp':
        return '📱';
      case 'loan':
        return '💸';
      case 'job':
        return '💼';
      case 'phishing':
        return '🎣';
      default:
        return '🚨';
    }
  }'''

new_emoji = '''  IconData get _categoryIcon {
    switch (alert.category) {
      case 'digital_arrest':
        return Icons.local_police_rounded;
      case 'investment':
        return Icons.monetization_on_rounded;
      case 'otp':
        return Icons.password_rounded;
      case 'loan':
        return Icons.account_balance_rounded;
      case 'job':
        return Icons.work_rounded;
      case 'phishing':
        return Icons.phishing_rounded;
      default:
        return Icons.warning_rounded;
    }
  }'''

feed_code = feed_code.replace(old_emoji, new_emoji)

# Fix rendering of emoji
feed_code = feed_code.replace("Text(_categoryEmoji, style: const TextStyle(fontSize: 16)),", "Icon(_categoryIcon, size: 18, color: color),")

# Fix image rendering to use fallback if it fails
old_img = '''          if (alert.imageUrl != null)
            ClipRRect(
              child: Image.network(
                alert.imageUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
              ),
            ),'''

new_img = '''          ClipRRect(
            child: alert.imageUrl != null 
              ? Image.network(
                  alert.imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Image.asset(
                    'assets/images/news_fallback.png',
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  'assets/images/news_fallback.png',
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
          ),'''

feed_code = feed_code.replace(old_img, new_img)

with open('lib/features/feed/feed_screen.dart', 'w', encoding='utf-8') as f:
    f.write(feed_code)
print("feed_screen.dart updated.")

