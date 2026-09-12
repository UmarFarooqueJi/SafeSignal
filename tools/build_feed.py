import os

with open('lib/features/feed/feed_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _categories
old_cats = """  final _categories = [
    ('all', 'Sab', '📋'),
    ('digital_arrest', 'Arrest Scam', '👮'),
    ('otp', 'OTP Fraud', '🔐'),
    ('investment', 'Investment', '💰'),
    ('lottery', 'Lottery', '🎰'),
    ('general', 'Other Alerts', '⚠️'),
  ];"""
new_cats = """  final _categories = [
    ('hi', 'Hindi News', '🇮🇳'),
    ('en', 'Hinglish News', '🔤'),
  ];"""
content = content.replace(old_cats, new_cats)

# Change default category
content = content.replace("String _selectedCategory = 'all';", "String _selectedCategory = 'hi';")

# Change API query parameter
old_query = """          'q': 'scam OR fraud OR cybercrime OR cyber',
          'country': 'in',
          'language': 'en,hi',"""
new_query = """          'q': 'scam OR fraud OR cybercrime OR cyber',
          'country': 'in',
          'language': _selectedCategory, // 'hi' or 'en'"""
content = content.replace(old_query, new_query)

# Change filter logic
old_filter = """  List<AlertModel> get _filtered => _selectedCategory == 'all'
      ? _alerts
      : _alerts.where((a) => a.category == _selectedCategory).toList();"""
new_filter = """  List<AlertModel> get _filtered => _alerts; // The API already filters by language."""
content = content.replace(old_filter, new_filter)

# Insert Image rendering inside _AlertCard
old_card_body = """          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.headline,"""
new_card_body = """          if (alert.imageUrl != null)
            ClipRRect(
              child: Image.network(
                alert.imageUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.headline,"""
content = content.replace(old_card_body, new_card_body)

with open('lib/features/feed/feed_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Feed screen updated.")
