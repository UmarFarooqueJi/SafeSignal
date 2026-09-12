import os
import re

# 1. FIX APP_ROUTER.DART (Navigation bar)
with open('lib/core/router/app_router.dart', 'r', encoding='utf-8') as f:
    router_code = f.read()

old_shell = '''      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            widget.child,
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFF1A1A1A).withValues(alpha: 0.85) 
                        : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.white,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.black54 : const Color(0xFFFFB300).withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(3, (index) {
                      final isSelected = index == _selectedIndex;
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      final icons = [
                        Icons.home_outlined, // Home
                        Icons.newspaper_outlined, // News
                        Icons.settings_outlined, // Settings
                      ];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedIndex = index);
                          context.go(_routes[index]);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? const Color(0xFF2979FF) 
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icons[index],
                            color: isSelected 
                                ? Colors.white 
                                : (isDark ? Colors.white54 : const Color(0xFF4CAF50)),
                            size: 24,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),'''

new_shell = '''      child: Scaffold(
        extendBody: false,
        body: widget.child,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF0D1117) 
                : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(3, (index) {
                  final isSelected = index == _selectedIndex;
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final icons = [
                    Icons.home_rounded, 
                    Icons.newspaper_rounded, 
                    Icons.settings_rounded, 
                  ];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      context.go(_routes[index]);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? const Color(0xFF2979FF).withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        icons[index],
                        color: isSelected 
                            ? const Color(0xFF2979FF)
                            : (isDark ? Colors.white54 : Colors.grey.shade600),
                        size: 26,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),'''

if old_shell in router_code:
    router_code = router_code.replace(old_shell, new_shell)
    with open('lib/core/router/app_router.dart', 'w', encoding='utf-8') as f:
        f.write(router_code)
    print("Updated app_router.dart")
else:
    print("Could not find the target code in app_router.dart")

# 3. FIX SETTINGS_SCREEN.DART (Remove text size)
with open('lib/features/settings/settings_screen.dart', 'r', encoding='utf-8') as f:
    settings_code = f.read()

pattern = r"// ── Text Size.*?const SizedBox\(height: 16\),"
settings_code = re.sub(pattern, "", settings_code, flags=re.DOTALL)

with open('lib/features/settings/settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(settings_code)
print("Updated settings_screen.dart")

# 4. FIX FEED_SCREEN.DART (Parse imageUrl)
with open('lib/features/feed/feed_screen.dart', 'r', encoding='utf-8') as f:
    feed_code = f.read()

old_parser_start = '''      final title = item['title']?.toString() ?? 'Scam Alert';
      final description = item['description']?.toString();
      final link = item['link']?.toString();
      final pubDateStr = item['pubDate']?.toString();
      final source = item['source_id']?.toString() ?? 'News';'''

new_parser_start = '''      final title = item['title']?.toString() ?? 'Scam Alert';
      final description = item['description']?.toString();
      final link = item['link']?.toString();
      final pubDateStr = item['pubDate']?.toString();
      final source = item['source_id']?.toString() ?? 'News';
      final imageUrl = item['image_url']?.toString();'''

if old_parser_start in feed_code:
    feed_code = feed_code.replace(old_parser_start, new_parser_start)
    old_alert_model = '''        category: category,
        isNew: true,
      );'''
    new_alert_model = '''        category: category,
        isNew: true,
        imageUrl: imageUrl,
      );'''
    feed_code = feed_code.replace(old_alert_model, new_alert_model)
    with open('lib/features/feed/feed_screen.dart', 'w', encoding='utf-8') as f:
        f.write(feed_code)
    print("Updated feed_screen.dart")
else:
    print("Could not find parser code in feed_screen.dart")
