import os

with open('lib/features/home/home_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace Network image URLs with Asset paths
content = content.replace(
    "imageUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475?q=80&w=2070&auto=format&fit=crop',",
    "imagePath: 'assets/images/ai_spyware_card.png',"
)
content = content.replace(
    "imageUrl: 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?q=80&w=2034&auto=format&fit=crop',",
    "imagePath: 'assets/images/ai_wifi_card.png',"
)
content = content.replace(
    "imageUrl: 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?q=80&w=2070&auto=format&fit=crop',",
    "imagePath: 'assets/images/ai_website_card.png',"
)
content = content.replace(
    "imageUrl: 'https://images.unsplash.com/photo-1563013544-824ae1b704d3?q=80&w=2070&auto=format&fit=crop',",
    "imagePath: 'assets/images/ai_darkweb_card.png',"
)

# Update _ImageCard constructor and implementation
old_card_class = """class _ImageCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final double height;
  final VoidCallback onTap;

  const _ImageCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.height,
    required this.onTap,
  });"""

new_card_class = """class _ImageCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final double height;
  final VoidCallback onTap;

  const _ImageCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.height,
    required this.onTap,
  });"""

old_image_render = """              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),"""

new_image_render = """              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                ),
              ),"""

content = content.replace(old_card_class, new_card_class)
content = content.replace(old_image_render, new_image_render)

with open('lib/features/home/home_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Home screen updated to use AI assets.")
