import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:safesignal/core/services/visual_osint_engine.dart';

void main() {
  test('VisualOsintEngine.crawlVisualAppearances extracts real matches', () async {
    const testImg = 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Image_created_with_a_mobile_phone.png/640px-Image_created_with_a_mobile_phone.png';
    final matches = await VisualOsintEngine.crawlVisualAppearances(testImg);
    
    print('Total matches returned in Dart: ${matches.length}');
    for (final m in matches.take(5)) {
      print('Platform: ${m.platform} | Title: ${m.title} | Thumb: ${m.thumbnailUrl}');
    }

    expect(matches.isNotEmpty, isTrue);
    expect(matches.first.pageUrl.startsWith('http'), isTrue);
    expect(matches.first.thumbnailUrl.startsWith('http'), isTrue);
  });
}
